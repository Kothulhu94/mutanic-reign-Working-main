class_name MapManager extends Node2D

# CONFIG
@export var cell_size = Vector2i(4, 4)
@export var map_size_pixels = Vector2i(16384, 16384)

@onready var grid_data_layer = $GridData

# Multiple Grids Management
# Key: Node (or String "camera")
# Value: Dictionary { "astars": Dictionary[int, AStarGrid2D], "center": Vector2i, "radius": int, "shape": int }
var active_grids: Dictionary = {}

@export var show_debug_grid: bool = false:
	set(value):
		show_debug_grid = value
		queue_redraw()

var boundary_calculator: BoundaryCalculator

func _ready():
	add_to_group("MapManager")
	z_index = 100
	boundary_calculator = BoundaryCalculator.new(self, cell_size)
	
	# Create the main camera grid entry
	active_grids["camera"] = {
		"astars": _create_astar_set(),
		"center": Vector2i(-1000, -1000),
		"radius": NavConstants.DEFAULT_RADIUS,
		"shape": NavConstants.GridShape.SQUARE
	}

func register_grid_source(source_id: String, initial_pos: Vector2, radius_override: int = -1, shape: NavConstants.GridShape = NavConstants.GridShape.SQUARE):
	if active_grids.has(source_id):
		return
		
	var r = radius_override if radius_override >= 0 else NavConstants.DEFAULT_RADIUS
		
	active_grids[source_id] = {
		"astars": _create_astar_set(),
		"center": Vector2i(-1000, -1000),
		"radius": r,
		"shape": shape
	}
	
	_update_single_grid(source_id, initial_pos)


func _create_new_astar_instance() -> AStarGrid2D:
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
	var new_center_chunk = Vector2i((local_pos / NavConstants.CHUNK_SIZE).floor())
	
	if new_center_chunk != grid_data["center"]:
		grid_data["center"] = new_center_chunk
		var radius = grid_data["radius"]
		var start_chunk = new_center_chunk - Vector2i(radius, radius)
		
		# Calc Region (Robust Pixel-Based)
		var region_start_px = start_chunk * NavConstants.CHUNK_SIZE
		var region_size_px = Vector2i(radius * 2 + 1, radius * 2 + 1) * NavConstants.CHUNK_SIZE
		
		var region_start_cell = region_start_px / cell_size
		var region_end_cell = (region_start_px + region_size_px) / cell_size
		var region_size_cells = region_end_cell - region_start_cell
		
		var astars = grid_data["astars"]
		for layer in astars:
			var a = astars[layer]
			a.region = Rect2i(region_start_cell, region_size_cells)
			a.update()
		
		_sync_obstacles(astars)
		_reapply_all_dynamic_obstacles(astars)
		_sync_bridges(astars) # Sync saved bridges
		GridMasker.apply_shape_mask(astars, grid_data, cell_size)
		queue_redraw()

func _sync_obstacles(astars: Dictionary):
	var map_loader = get_tree().get_first_node_in_group("MapLoader")
	TerrainSynchronizer.sync_obstacles(astars, map_loader, cell_size)

func _on_terrain_loaded(_coord: Vector2i):
	for key in active_grids:
		var astars = active_grids[key]["astars"]
		_sync_obstacles(astars)
		_reapply_all_dynamic_obstacles(astars)
		_sync_bridges(astars)
		GridMasker.apply_shape_mask(astars, active_grids[key], cell_size)

func _draw() -> void:
	if not show_debug_grid:
		# Always draw bridges even if debug grid is off? User asked for "Permanent" "Visual".
		# Actually user expects them to be visible.
		# For now, let's keep it simple: Draw all bridges
		_draw_bridges()
		return
		
	_draw_bridges() # Draw them here too
		
	var color = Color(1, 1, 1, 0.1)
	
	for key in active_grids:
		var astars = active_grids[key]["astars"]
		var r = astars[NavConstants.LAYER_LAND].region
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

func _draw_bridges() -> void:
	var bridge_color = Color("8B4513") # Dark Brown
	var size = Vector2(cell_size)
	
	for cell in built_bridges:
		if built_bridges[cell]:
			var pos = Vector2(cell * cell_size)
			draw_rect(Rect2(pos, size), bridge_color)

# ... API ...

func _create_astar_set() -> Dictionary:
	var astar_set = {}
	astar_set[NavConstants.LAYER_LAND] = _create_new_astar_instance()
	astar_set[NavConstants.LAYER_WATER] = _create_new_astar_instance()
	astar_set[NavConstants.LAYER_BUILDER] = _create_new_astar_instance()
	return astar_set

# ...

# Bridge System
var built_bridges: Dictionary = {} # Key: Vector2i (Map Cell), Value: bool

func get_bridging_path(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	# Use LAYER_BUILDER to find a path that allows crossing water
	var start_cell = global_to_map(start_pos)
	var end_cell = global_to_map(end_pos)
	
	for key in active_grids:
		var a = active_grids[key]["astars"][NavConstants.LAYER_BUILDER]
		if a.region.has_point(start_cell) and a.region.has_point(end_cell):
			if not a.is_point_solid(start_cell) and not a.is_point_solid(end_cell):
				var points = a.get_point_path(start_cell, end_cell)
				var global_pts: PackedVector2Array = []
				for p in points:
					global_pts.append(to_global(p))
				return global_pts
				
	return PackedVector2Array()

func build_bridge_if_water(world_pos: Vector2) -> void:
	var cell = global_to_map(world_pos)
	if built_bridges.has(cell):
		return # Already built
		
	# Water Check: Only build if strictly water
	var map_loader = get_tree().get_first_node_in_group("MapLoader")
	if map_loader:
		var t_id = map_loader.get_terrain_at(world_pos)
		if t_id < 140 or t_id > 160: # Not Water (150)
			return
			
	# Store
	built_bridges[cell] = true
	
	# Update active grids IMMEDIATELY
	for key in active_grids:
		var astars = active_grids[key]["astars"]
		# Update Land Layer: Make it walkable
		if astars[NavConstants.LAYER_LAND].region.has_point(cell):
			astars[NavConstants.LAYER_LAND].set_point_solid(cell, false)
			astars[NavConstants.LAYER_LAND].set_point_weight_scale(cell, 1.0)
			
		# Update Builder Layer: Make it CHEAP (it's now an existing bridge)
		if astars.has(NavConstants.LAYER_BUILDER):
			if astars[NavConstants.LAYER_BUILDER].region.has_point(cell):
				astars[NavConstants.LAYER_BUILDER].set_point_solid(cell, false)
				astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell, 1.0)
			
	queue_redraw()

func _sync_bridges(astars: Dictionary) -> void:
	# Re-apply all known bridges to the grid
	# This handles the case where a chunk loads or re-centers
	# Inefficient if bridges > 10000, but fine for now.
	for cell in built_bridges:
		if astars[NavConstants.LAYER_LAND].region.has_point(cell):
			astars[NavConstants.LAYER_LAND].set_point_solid(cell, false)
			astars[NavConstants.LAYER_LAND].set_point_weight_scale(cell, 1.0)
			
		if astars.has(NavConstants.LAYER_BUILDER):
			if astars[NavConstants.LAYER_BUILDER].region.has_point(cell):
				astars[NavConstants.LAYER_BUILDER].set_point_solid(cell, false)
				astars[NavConstants.LAYER_BUILDER].set_point_weight_scale(cell, 1.0)

# API
func is_point_in_active_region(world_pos: Vector2, grid_type: String = "camera") -> bool:
	var cell = global_to_map(world_pos)
	if active_grids.has(grid_type):
		return active_grids[grid_type]["astars"][NavConstants.LAYER_LAND].region.has_point(cell)
	
	# Fallback
	for key in active_grids:
		if active_grids[key]["astars"][NavConstants.LAYER_LAND].region.has_point(cell):
			return true
	return false

func is_in_same_active_grid(start_pos: Vector2, end_pos: Vector2) -> bool:
	var start_cell = global_to_map(start_pos)
	var end_cell = global_to_map(end_pos)
	
	for key in active_grids:
		# Use LAND layer region as the master region definition for connectivity check
		var region = active_grids[key]["astars"][NavConstants.LAYER_LAND].region
		if region.has_point(start_cell) and region.has_point(end_cell):
			return true
	return false

func get_path_world(start_pos: Vector2, end_pos: Vector2, navigation_layers: int = 1) -> PackedVector2Array:
	var start_cell = global_to_map(start_pos)
	var end_cell = global_to_map(end_pos)
	
	var valid_astar = null
	
	# Resolve Layer (Simple bitmask check, prioritized)
	var layer_id = NavConstants.LAYER_LAND
	if navigation_layers & 2: # Has Water Capability (Bit 2)
		layer_id = NavConstants.LAYER_WATER
	
	for key in active_grids:
		var a = active_grids[key]["astars"][layer_id]
		if a.region.has_point(start_cell) and a.region.has_point(end_cell):
			if not a.is_point_solid(start_cell) and not a.is_point_solid(end_cell):
				valid_astar = a
				break
			
	if valid_astar == null:
		return PackedVector2Array()

	var points = valid_astar.get_point_path(start_cell, end_cell)
	
	# Safety Check: If the path is non-empty but the destination is Water (and we are on Land), reject it.
	# This catches cases where the AStar grid might be desynced or the destination pixel is just on the edge.
	if not points.is_empty() and layer_id == NavConstants.LAYER_LAND:
		var map_loader = get_tree().get_first_node_in_group("MapLoader")
		if map_loader:
			var t_id = map_loader.get_terrain_at(end_pos)
			if t_id >= 140 and t_id <= 160: # Water ID 150 range
				return PackedVector2Array()

	var global_pts: PackedVector2Array = []
	for p in points:
		global_pts.append(to_global(p))
	return global_pts

func get_nav_boundary_exit(start_pos: Vector2, target_pos: Vector2) -> Vector2:
	return boundary_calculator.get_nav_boundary_exit(start_pos, target_pos, active_grids)

func get_nav_boundary_entry(target_pos: Vector2, from_pos: Vector2) -> Vector2:
	return boundary_calculator.get_nav_boundary_entry(target_pos, from_pos, active_grids)

func global_to_map(global_pos: Vector2) -> Vector2i:
	return boundary_calculator.global_to_map(global_pos)

# Dynamic Obstacles API
var dynamic_obstacles: Dictionary = {} # Key: ID (String), Value: {pos, radius, solid}

func set_dynamic_obstacle(id: String, center_pos: Vector2, radius_pixels: float, is_solid: bool = true) -> void:
	dynamic_obstacles[id] = {
		"pos": center_pos,
		"radius": radius_pixels,
		"solid": is_solid
	}
	# Apply immediately to current grids
	for key in active_grids:
		_apply_circle_to_astars(active_grids[key]["astars"], center_pos, radius_pixels, is_solid)

func remove_dynamic_obstacle(id: String) -> void:
	if dynamic_obstacles.has(id):
		var d = dynamic_obstacles[id]
		# clear it (solid = false)
		for key in active_grids:
			_apply_circle_to_astars(active_grids[key]["astars"], d["pos"], d["radius"], false)
		dynamic_obstacles.erase(id)

func _apply_circle_to_astars(astars: Dictionary, center_pos: Vector2, radius_pixels: float, is_solid: bool) -> void:
	var center_cell = global_to_map(center_pos)
	var radius_cells = int(radius_pixels / cell_size.x) + 1
	
	for layer_id in astars:
		var astar = astars[layer_id]
		
		for x in range(center_cell.x - radius_cells, center_cell.x + radius_cells + 1):
			for y in range(center_cell.y - radius_cells, center_cell.y + radius_cells + 1):
				var cell = Vector2i(x, y)
				
				if not astar.region.has_point(cell):
					continue
					
				var world_cell_pos = (Vector2(cell) * Vector2(cell_size)) + (Vector2(cell_size) / 2.0)
				if world_cell_pos.distance_to(center_pos) <= radius_pixels:
					astar.set_point_solid(cell, is_solid)

func _reapply_all_dynamic_obstacles(astars: Dictionary) -> void:
	for id in dynamic_obstacles:
		var d = dynamic_obstacles[id]
		_apply_circle_to_astars(astars, d["pos"], d["radius"], d["solid"])
