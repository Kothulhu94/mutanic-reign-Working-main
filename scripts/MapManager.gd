class_name MapManager extends Node2D

# CONFIG: Match this to your TileMapLayer cell size
@export var cell_size = Vector2i(64, 64)
# CONFIG: The total size of your 16k map in PIXELS
@export var map_size_pixels = Vector2i(16384, 16384)

@onready var grid_data_layer = $GridData

var astar = AStarGrid2D.new()

func _ready():
	# Wait one frame to ensure TileMapLayer is ready if needed
	await get_tree().process_frame
	_setup_grid()

func _setup_grid():
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
	# (We scan the Used Cells from the TileMapLayer)
	for cell_pos in grid_data_layer.get_used_cells():
		# Using get_used_cells() without arguments gets cells from coordinate 0 ?? 
		# No, get_used_cells() returns array of Vector2i.
		# LOGIC: Check custom data or just tile IDs. 
		# For now, let's assume ANY painted tile is an obstacle.
		# Ideally, use Custom Data Layers in TileSet for "Cost" vs "Solid"
		# Example: Mark as Solid (Water)
		astar.set_point_solid(cell_pos, true)
		
	print("MapManager: Grid Initialized. Size: ", grid_size)

# API FOR UNITS
func get_path_world(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	var start_cell = local_to_map(start_pos)
	var end_cell = local_to_map(end_pos)
	
	# Get the path (as grid IDs)
	# var id_path = astar.get_id_path(start_cell, end_cell) # Unused
	var point_path = astar.get_point_path(start_cell, end_cell)
	
	# Note: get_point_path returns world positions centered on cells *if* AStarGrid2D is configured right?
	# Actually get_point_path returns vector2 array.
	
	return point_path

func local_to_map(world_pos: Vector2) -> Vector2i:
	return Vector2i(world_pos) / cell_size
