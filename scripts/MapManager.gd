class_name MapManager extends Node2D

# Refreshed at 2025-12-26T14:00:00

# CONFIG
@export var cell_size = Vector2i(2, 2)
@export var map_size_pixels = Vector2i(16384, 16384)

@onready var grid_data_layer = $GridData

# Dynamic Grid Settings
const CHUNK_SIZE = 1024
const GRID_RADIUS = 1 # radius 1 = 3x3 chunks

# Multiple Grids Management
# Key: Node (or String "camera"), Value: Dictionary { "astar": AStarGrid2D, "center": Vector2i }
var active_grids: Dictionary = {}

@export var show_debug_grid: bool = true:
	set(value):
		show_debug_grid = value
		queue_redraw()

func _ready():
	z_index = 100
	print("MapManager: Ready.")
	
	# Create the main camera grid entry
	active_grids["camera"] = {
		"astar": _create_new_astar(),
		"center": Vector2i(-1000, -1000)
	}

func register_grid_source(source_id: String, initial_pos: Vector2):
	if active_grids.has(source_id):
		return
		
	var new_astar = _create_new_astar()
	active_grids[source_id] = {
		"astar": new_astar,
		"center": Vector2i(-1000, -1000)
	}
	
	# Force immediate update
	_update_single_grid(source_id, initial_pos)
	print("MapManager: Registered grid source '%s'" % source_id)

func _create_new_astar() -> AStarGrid2D:
	var a = AStarGrid2D.new()
	a.cell_size = cell_size
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	return a

func _process(_delta: float) -> void:
	# 1. Update Camera Grid
	var cam = get_viewport().get_camera_2d()
	if cam:
		_update_single_grid("camera", cam.global_position)

	# 2. Update other registered grids (static hubs usually don't move, but we check just in case or for init)
	# (For static hubs, we rely on them calling register, but if they moved we'd need loop. 
	# For now, assuming static, but let's handle dynamic calls via register/updates if needed.
	# Actually, Hubs are static. They register once.
	pass

func _update_single_grid(id: String, world_pos: Vector2):
	if not active_grids.has(id):
		return
		
	var grid_data = active_grids[id]
	var local_pos = to_local(world_pos)
	var new_center_chunk = Vector2i((local_pos / CHUNK_SIZE).floor())
	
	if new_center_chunk != grid_data["center"]:
		grid_data["center"] = new_center_chunk
		var start_chunk = new_center_chunk - Vector2i(GRID_RADIUS, GRID_RADIUS)
		
		# Calc Region
		# Calc Region (Robust Pixel-Based)
		var region_start_px = start_chunk * CHUNK_SIZE
		var region_size_px = Vector2i(GRID_RADIUS * 2 + 1, GRID_RADIUS * 2 + 1) * CHUNK_SIZE
		
		var region_start_cell = region_start_px / cell_size
		var region_end_cell = (region_start_px + region_size_px) / cell_size
		var region_size_cells = region_end_cell - region_start_cell
		
		var astar: AStarGrid2D = grid_data["astar"]
		astar.region = Rect2i(region_start_cell, region_size_cells)
		astar.update()
		
		_sync_obstacles(astar)
		queue_redraw()

func _sync_obstacles(astar: AStarGrid2D):
	# Optimization: Iterate by CHUNK (Image) rather than by global pixel
	# This avoids thousands of to_global/to_local and Dict lookups per cell.
	var map_loader = get_tree().get_first_node_in_group("MapLoader")
	if not map_loader: return
	
	# We need to access MapLoader's data directly for speed
	if not "loaded_terrain_data" in map_loader: return
	
	var r = astar.region
	
	# Determine which chunks intersect with the AStar region
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
			
			# Calculate overlap between Chunk and AStar Region
			var chunk_pixel_rect = Rect2i(cx * CHUNK_SIZE, cy * CHUNK_SIZE, CHUNK_SIZE, CHUNK_SIZE)
			var region_pixel_rect = Rect2i(r.position * cell_size, r.size * cell_size)
			var intersection = chunk_pixel_rect.intersection(region_pixel_rect)
			
			if intersection.size == Vector2i.ZERO:
				continue
			
			# Data Image Scaling (Texture might be smaller than ChunkSize)
			var ratio = img.get_width() / float(CHUNK_SIZE)
			
			# Convert Intersection (Pixels) to Grid Cells
			# We iterate the cells that fall within this intersection
			var start_cell = intersection.position / cell_size
			var end_cell = (intersection.position + intersection.size) / cell_size
			
			# Loop Cells in this specific chunk intersection
			for x in range(start_cell.x, end_cell.x):
				for y in range(start_cell.y, end_cell.y):
					var cell_pos = Vector2i(x, y)
					
					# Find pixel in local chunk image
					var world_px = cell_pos * cell_size + (cell_size / 2) # Center of cell
					var local_px = world_px - (Vector2i(cx, cy) * CHUNK_SIZE)
					
					var img_x = int(local_px.x * ratio)
					var img_y = int(local_px.y * ratio)
					
					img_x = clampi(img_x, 0, img.get_width() - 1)
					img_y = clampi(img_y, 0, img.get_height() - 1)
					
					var col = img.get_pixel(img_x, img_y)
					var terrain_id = int(round(col.r * 255.0))
					
					# Apply Logic
					# Reset
					astar.set_point_solid(cell_pos, false)
					astar.set_point_weight_scale(cell_pos, 1.0)
					
					if terrain_id == 1: # Sand
						astar.set_point_weight_scale(cell_pos, 1.25)
					elif terrain_id == 2: # Snow
						astar.set_point_weight_scale(cell_pos, 2.0)
					elif terrain_id == 3: # Water
						astar.set_point_solid(cell_pos, true)

func _on_terrain_loaded(_coord: Vector2i):
	# When a chunk loads, re-sync all active grids
	for key in active_grids:
		var astar = active_grids[key]["astar"]
		_sync_obstacles(astar)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var map_loader = get_tree().get_first_node_in_group("MapLoader")
		if map_loader:
			var global_pos = get_global_mouse_position()
			var t_id = map_loader.get_terrain_at(global_pos)
			var _type_name = "Unknown"
			var _cost = 1.0
			
			match t_id:
				0: _type_name = "Grass/Default"
				1:
					_type_name = "Sand"
					_cost = 1.25
				2:
					_type_name = "Snow"
					_cost = 2.0
				3:
					_type_name = "Water"
					_cost = "Impassable"
			
			
			var cell_pos = global_to_map(global_pos)
			var _is_astar_solid = false
			var _region_info = "None"
			if active_grids.has("camera"):
				var ag = active_grids["camera"]["astar"]
				_is_astar_solid = ag.is_point_solid(cell_pos)
				_region_info = str(ag.region)
			
			# print("Terrain Click: ", global_pos, " | ID=", t_id, " (", type_name, ") | Solid=", is_astar_solid)

func _draw() -> void:
	if not show_debug_grid:
		return
		
	var color = Color(1, 1, 1, 0.1)
	
	for key in active_grids:
		var astar = active_grids[key]["astar"]
		var r = astar.region
		if r.size == Vector2i.ZERO: continue
		
		# Draw Grid Lines
		var start_px = r.position * cell_size
		var size_px = r.size * cell_size
		var end_px = start_px + size_px
		
		# Vert
		for x in range(r.size.x + 1):
			var xp = start_px.x + (x * cell_size.x)
			draw_line(Vector2(xp, start_px.y), Vector2(xp, end_px.y), color)
		# Horz
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
	
	# Find a grid that contains BOTH points
	# (Assumption: Navigation only works strictly inside one contiguous loaded region)
	var valid_astar = null
	
	for key in active_grids:
		var a = active_grids[key]["astar"]
		if a.region.has_point(start_cell) and a.region.has_point(end_cell):
			valid_astar = a
			break
			
	if valid_astar == null:
		return PackedVector2Array()

	var points = valid_astar.get_point_path(start_cell, end_cell)
	var global_pts: PackedVector2Array = []
	for p in points:
		global_pts.append(to_global(p))
	return global_pts

func global_to_map(global_pos: Vector2) -> Vector2i:
	return Vector2i(to_local(global_pos)) / cell_size
