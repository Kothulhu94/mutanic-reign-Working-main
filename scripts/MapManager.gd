class_name MapManager extends Node2D

# Refreshed at 2025-12-26T06:17:00

# CONFIG: Match this to your TileMapLayer cell size
# NOTE: 16k map @ 2x2 cells = ~67 million cells (Extreme!). 
# Recommended: 32x32 (500x500 grid) or 16x16 (1000x1000 grid).
@export var cell_size = Vector2i(2, 2)
# CONFIG: The total size of your 16k map in PIXELS
@export var map_size_pixels = Vector2i(16384, 16384)

@onready var grid_data_layer = $GridData

var astar = AStarGrid2D.new()

@export var show_debug_grid: bool = true:
	set(value):
		show_debug_grid = value
		queue_redraw()

func _draw() -> void:
	if not show_debug_grid:
		return

	# Draw grid lines
	var grid_size = map_size_pixels / cell_size
	var color = Color(1, 1, 1, 0.2) # Faint white

	# Vertical lines
	for x in range(grid_size.x + 1):
		var start = Vector2(x * cell_size.x, 0)
		var end = Vector2(x * cell_size.x, map_size_pixels.y)
		draw_line(start, end, color)

	# Horizontal lines
	for y in range(grid_size.y + 1):
		var start = Vector2(0, y * cell_size.y)
		var end = Vector2(map_size_pixels.x, y * cell_size.y)
		draw_line(start, end, color)

	# Draw obstacles (solid points)
	if astar.region.size == Vector2i.ZERO:
		return # Grid not ready

	var obstacle_color = Color(1, 0, 0, 0.5) # Red for obstacles
	
	# Optimization: Only draw obstacles near mouse or viewport if needed, 
	# but for now iterating all is okay for debug *if* grid isn't 16 million cells.
	for x in range(grid_size.x):
		for y in range(grid_size.y):
			var id = Vector2i(x, y)
			if astar.is_point_solid(id):
				# Only draw if roughly visible? No, simple draw_rect is fast enough for ~50k cells (16x16 -> 1M cells, might be slow)
				# Only draw blocks if we aren't overloaded
				if grid_size.x * grid_size.y < 1000000:
					var rect = Rect2(id * cell_size, cell_size)
					draw_rect(rect, obstacle_color, true)

func _ready():
	_setup_grid()

func _setup_grid():
	if grid_data_layer == null:
		# Try to find it dynamically if not direct child (e.g. different scene structure)
		grid_data_layer = get_node_or_null("GridData")
	
	if grid_data_layer == null:
		push_warning("MapManager: GridData TileMapLayer not found. Please add it as a child.")
		return

	# 1. Calculate grid dimensions (16384 / 64 = 256x256 cells)
	var grid_size = map_size_pixels / cell_size


	astar.region = Rect2i(Vector2i.ZERO, grid_size)
	astar.cell_size = cell_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	astar.update() # Build the empty grid
	
	# 2. Read the TileMap to mark obstacles
	# We handle resolution mismatch (e.g. TileMap 64x64, AStar 16x16)
	var tile_set_size = Vector2i(64, 64) # Default fallback
	if grid_data_layer.tile_set:
		tile_set_size = grid_data_layer.tile_set.tile_size
		
	var ratio = tile_set_size / cell_size # e.g. 64 / 16 = 4
	

	# We iterate used cells and check if the tile data has collision
	for cell_pos in grid_data_layer.get_used_cells():
		var tile_data: TileData = grid_data_layer.get_cell_tile_data(cell_pos)
		if tile_data == null:
			continue
			
		# Check Physics Layer 0 for collisions
		if tile_data.get_collision_polygons_count(0) > 0:
			# Mark the corresponding block of AStar cells as solid
			# TileMap (1, 1) -> AStar base (4, 4) if ratio is 4
			var base_astar_pos = cell_pos * ratio
			
			for dx in range(ratio.x):
				for dy in range(ratio.y):
					var astar_pos = base_astar_pos + Vector2i(dx, dy)
					if astar.region.has_point(astar_pos):
						astar.set_point_solid(astar_pos, true)
		

# API FOR UNITS
func get_path_world(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var start_cell = local_to_map(start_pos)
	var end_cell = local_to_map(end_pos)
	

	# Get the path (as grid IDs)
	# var id_path = astar.get_id_path(start_cell, end_cell) # Unused
	var point_path = astar.get_point_path(start_cell, end_cell)
	

	# Convert the local point path back to global positions for the actor
	var global_path: PackedVector2Array = []
	for point in point_path:
		global_path.append(to_global(point))
		
	return global_path

func local_to_map(world_pos: Vector2) -> Vector2i:
	# Convert global 'world_pos' to local node space (handling parent scale)
	var local_pos = to_local(world_pos)
	return Vector2i(local_pos) / cell_size
