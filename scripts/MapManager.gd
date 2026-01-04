class_name MapManager extends Node2D

# CONFIG
@export var cell_size = Vector2i(4, 4)
@export var map_size_pixels = Vector2i(16384, 16384)

@onready var grid_data_layer = $GridData

# Dynamic Grid Settings
const CHUNK_SIZE = 1024
const DEFAULT_RADIUS = 1 # radius 1 = 3x3 chunks

enum GridShape {SQUARE, PLUS}

# Multiple Grids Management
# Key: Node (or String "camera"), Value: Dictionary { "astar": AStarGrid2D, "center": Vector2i, "radius": int, "shape": int }
var active_grids: Dictionary = {}

@export var show_debug_grid: bool = false:
	set(value):
		show_debug_grid = value
		queue_redraw()

func _ready():
	z_index = 100
	
	# Create the main camera grid entry
	active_grids["camera"] = {
		"astar": _create_new_astar(),
		"center": Vector2i(-1000, -1000),
		"radius": DEFAULT_RADIUS,
		"shape": GridShape.SQUARE
	}

func register_grid_source(source_id: String, initial_pos: Vector2, radius_override: int = -1, shape: GridShape = GridShape.SQUARE):
	if active_grids.has(source_id):
		return
		
	var r = radius_override if radius_override >= 0 else DEFAULT_RADIUS
		
	var new_astar = _create_new_astar()
	active_grids[source_id] = {
		"astar": new_astar,
		"center": Vector2i(-1000, -1000),
		"radius": r,
		"shape": shape
	}
	
	_update_single_grid(source_id, initial_pos)

func _create_new_astar() -> AStarGrid2D:
	var a = AStarGrid2D.new()
	a.cell_size = cell_size
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	return a

func _process(_delta: float) -> void:
	# Update Camera Grid
	var cam = get_viewport().get_camera_2d()
	if cam:
		_update_single_grid("camera", cam.global_position)

func _update_single_grid(id: String, world_pos: Vector2):
	if not active_grids.has(id):
		return
		
	var grid_data = active_grids[id]
	var local_pos = to_local(world_pos)
	var new_center_chunk = Vector2i((local_pos / CHUNK_SIZE).floor())
	
	if new_center_chunk != grid_data["center"]:
		grid_data["center"] = new_center_chunk
		var radius = grid_data["radius"]
		var start_chunk = new_center_chunk - Vector2i(radius, radius)
		
		# Calc Region (Robust Pixel-Based)
		var region_start_px = start_chunk * CHUNK_SIZE
		var region_size_px = Vector2i(radius * 2 + 1, radius * 2 + 1) * CHUNK_SIZE
		
		var region_start_cell = region_start_px / cell_size
		var region_end_cell = (region_start_px + region_size_px) / cell_size
		var region_size_cells = region_end_cell - region_start_cell
		
		var astar: AStarGrid2D = grid_data["astar"]
		astar.region = Rect2i(region_start_cell, region_size_cells)
		astar.update()
		
		_sync_obstacles(astar)
		_apply_shape_mask(astar, grid_data)
		queue_redraw()

func _apply_shape_mask(astar: AStarGrid2D, grid_data: Dictionary):
	if grid_data["shape"] != GridShape.PLUS:
		return
		
	var center_chunk = grid_data["center"]
	var radius = grid_data["radius"]
	var r = astar.region
	
	var start_chunk_x = floor(r.position.x * cell_size.x / float(CHUNK_SIZE))
	var start_chunk_y = floor(r.position.y * cell_size.y / float(CHUNK_SIZE))
	var end_chunk_x = floor(r.end.x * cell_size.x / float(CHUNK_SIZE))
	var end_chunk_y = floor(r.end.y * cell_size.y / float(CHUNK_SIZE))

	for cx in range(start_chunk_x, end_chunk_x + 1):
		for cy in range(start_chunk_y, end_chunk_y + 1):
			var dist = abs(cx - center_chunk.x) + abs(cy - center_chunk.y)
			if dist > radius:
				_set_chunk_solid(astar, cx, cy)

func _set_chunk_solid(astar: AStarGrid2D, chunk_x: int, chunk_y: int):
	var chunk_start_px = Vector2i(chunk_x, chunk_y) * CHUNK_SIZE
	var chunk_rect = Rect2i(chunk_start_px, Vector2i(CHUNK_SIZE, CHUNK_SIZE))
	var region_rect_px = Rect2i(astar.region.position * cell_size, astar.region.size * cell_size)
	var intersection = chunk_rect.intersection(region_rect_px)
	
	if intersection.size == Vector2i.ZERO:
		return

	var start_cell = intersection.position / cell_size
	var end_cell = (intersection.position + intersection.size) / cell_size
	
	astar.fill_solid_region(Rect2i(start_cell, end_cell - start_cell), true)

func _sync_obstacles(astar: AStarGrid2D):
	# Optimization: Iterate by CHUNK (Image) rather than by global pixel
	var map_loader = get_tree().get_first_node_in_group("MapLoader")
	if not map_loader: return
	
	if not "loaded_terrain_data" in map_loader: return
	
	var r = astar.region
	
	var start_chunk_x = floor(r.position.x * cell_size.x / float(CHUNK_SIZE))
	var start_chunk_y = floor(r.position.y * cell_size.y / float(CHUNK_SIZE))
	var end_chunk_x = floor(r.end.x * cell_size.x / float(CHUNK_SIZE))
	var end_chunk_y = floor(r.end.y * cell_size.y / float(CHUNK_SIZE))
	
	for cx in range(start_chunk_x, end_chunk_x + 1):
		for cy in range(start_chunk_y, end_chunk_y + 1):
			var chunk_coord = Vector2i(cx, cy)
			
			if not map_loader.loaded_terrain_data.has(chunk_coord):
				continue
				
			var img = map_loader.loaded_terrain_data[chunk_coord]
			if not img: continue
			
			var chunk_pixel_rect = Rect2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
			var region_pixel_rect = Rect2i(r.position * cell_size, r.size * cell_size)
			var intersection = chunk_pixel_rect.intersection(region_pixel_rect)
			
			if intersection.size == Vector2i.ZERO:
				continue
			
			var ratio = img.get_width() / float(CHUNK_SIZE)
			var start_cell = intersection.position / cell_size
			var end_cell = (intersection.position + intersection.size) / cell_size
			
			for x in range(start_cell.x, end_cell.x):
				for y in range(start_cell.y, end_cell.y):
					var cell_pos = Vector2i(x, y)
					var world_px = cell_pos * cell_size + (cell_size / 2)
					var local_px = world_px - (Vector2i(cx, cy) * CHUNK_SIZE)
					
					var img_x = int(local_px.x * ratio)
					var img_y = int(local_px.y * ratio)
					
					img_x = clampi(img_x, 0, img.get_width() - 1)
					img_y = clampi(img_y, 0, img.get_height() - 1)
					
					var col = img.get_pixel(img_x, img_y)
					var terrain_id = int(round(col.r * 255.0))
					
					# Optimization: Skip standard grass (0) to massively reduce function calls
					if terrain_id == 0:
						continue
					
					if terrain_id == 1: # Sand
						astar.set_point_weight_scale(cell_pos, 1.25)
					elif terrain_id == 2: # Snow
						astar.set_point_weight_scale(cell_pos, 2.0)
					elif terrain_id == 3: # Water
						astar.set_point_solid(cell_pos, true)

func _on_terrain_loaded(_coord: Vector2i):
	for key in active_grids:
		var astar = active_grids[key]["astar"]
		_sync_obstacles(astar)
		_apply_shape_mask(astar, active_grids[key])

func _draw() -> void:
	if not show_debug_grid:
		return
		
	var color = Color(1, 1, 1, 0.1)
	
	for key in active_grids:
		var astar = active_grids[key]["astar"]
		var r = astar.region
		if r.size == Vector2i.ZERO: continue
		
		var start_px = r.position * cell_size
		var size_px = r.size * cell_size
		var end_px = start_px + size_px
		
		for x in range(r.size.x + 1):
			var xp = start_px.x + (x * cell_size.x)
			draw_line(Vector2(xp, start_px.y), Vector2(xp, end_px.y), color)
		for y in range(r.size.y + 1):
			var yp = start_px.y + (y * cell_size.y)
			draw_line(Vector2(start_px.x, yp), Vector2(end_px.x, yp), color)

# API
func is_point_in_active_region(world_pos: Vector2) -> bool:
	var cell = global_to_map(world_pos)
	for key in active_grids:
		if active_grids[key]["astar"].region.has_point(cell):
			return true
	return false

func get_path_world(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var start_cell = global_to_map(start_pos)
	var end_cell = global_to_map(end_pos)
	
	var valid_astar = null
	
	for key in active_grids:
		var a = active_grids[key]["astar"]
		if a.region.has_point(start_cell) and a.region.has_point(end_cell):
			if not a.is_point_solid(start_cell) and not a.is_point_solid(end_cell):
				valid_astar = a
				break
			
	if valid_astar == null:
		return PackedVector2Array()

	var points = valid_astar.get_point_path(start_cell, end_cell)
	var global_pts: PackedVector2Array = []
	for p in points:
		global_pts.append(to_global(p))
	return global_pts

func get_nav_boundary_exit(start_pos: Vector2, target_pos: Vector2) -> Vector2:
	var start_cell = global_to_map(start_pos)
	var current_grid = null
	
	for key in active_grids:
		var grid_data = active_grids[key]
		if grid_data["astar"].region.has_point(start_cell):
			if not grid_data["astar"].is_point_solid(start_cell):
				current_grid = grid_data
				break
	
	if current_grid == null:
		return start_pos
		
	var center_chunk = current_grid["center"]
	var radius = current_grid["radius"]
	var shape = current_grid["shape"]
	
	var world_center = (Vector2(center_chunk) * float(CHUNK_SIZE)) + (Vector2(CHUNK_SIZE, CHUNK_SIZE) / 2.0)
	var extent = float(radius) * float(CHUNK_SIZE) + (float(CHUNK_SIZE) / 2.0)
	
	var relative_end = target_pos - world_center
	var relative_start = start_pos - world_center
	var dir = (relative_end - relative_start).normalized()
	var hit_point = target_pos
	
	if shape == GridShape.SQUARE:
		var t_min = - INF
		var t_max = INF
		var b_min = Vector2(-extent, -extent)
		var b_max = Vector2(extent, extent)
		
		# Check X slab
		if abs(dir.x) < 0.0001:
			if relative_start.x < b_min.x or relative_start.x > b_max.x:
				return start_pos # Outside
		else:
			var t1 = (b_min.x - relative_start.x) / dir.x
			var t2 = (b_max.x - relative_start.x) / dir.x
			t_min = max(t_min, min(t1, t2))
			t_max = min(t_max, max(t1, t2))
			
		# Check Y slab
		if abs(dir.y) < 0.0001:
			if relative_start.y < b_min.y or relative_start.y > b_max.y:
				return start_pos # Outside
		else:
			var t1 = (b_min.y - relative_start.y) / dir.y
			var t2 = (b_max.y - relative_start.y) / dir.y
			t_min = max(t_min, min(t1, t2))
			t_max = min(t_max, max(t1, t2))
			
		if t_max >= t_min and t_max > 0:
			var t_hit = max(t_min, t_max)
			hit_point = world_center + relative_start + dir * t_hit
			
	elif shape == GridShape.PLUS:
		var lines = [
			[Vector2(extent, 0), Vector2(0, extent)],
			[Vector2(0, extent), Vector2(-extent, 0)],
			[Vector2(-extent, 0), Vector2(0, -extent)],
			[Vector2(0, -extent), Vector2(extent, 0)]
		]
		
		var best_t = INF
		
		for line in lines:
			var p1 = line[0]
			var p2 = line[1]
			var intersection = Geometry2D.segment_intersects_segment(relative_start, relative_end, p1, p2)
			if intersection != null:
				var dist = relative_start.distance_to(intersection)
				if dist < best_t:
					best_t = dist
					hit_point = world_center + intersection
	
	var safety_margin = (start_pos - hit_point).normalized() * (cell_size.x * 3.0)
	return hit_point + safety_margin

func global_to_map(global_pos: Vector2) -> Vector2i:
	return Vector2i(to_local(global_pos)) / cell_size
