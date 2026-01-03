class_name MapLoader extends Node2D

# Refreshed at 2025-12-26T06:20:00

signal terrain_loaded(coord: Vector2i)

const CHUNK_SIZE = 1024
const GRID_SIZE = 16 # 16 * 1024 = 16384 pixels
const LOAD_RADIUS = 2 # Load 2 chunks out (5x5 grid)

var loaded_chunks: Dictionary = {} # Vector2i -> Sprite2D

var loading_sources: Array[Node2D] = []

func register_source(node: Node2D):
	if node not in loading_sources:
		loading_sources.append(node)
		print("MapLoader: Registered new chunk source: %s" % node.name)

func _ready():
	add_to_group("MapLoader")
	print("MapLoader: Initialized dynamic loader.")
	
func _process(_delta):
	# Collect all "centers" that need chunks loaded
	var loader_centers: Array[Vector2i] = []
	
	# 1. Camera is always a source
	var cam = get_viewport().get_camera_2d()
	if cam:
		var local_pos = to_local(cam.global_position)
		loader_centers.append(Vector2i((local_pos / CHUNK_SIZE).floor()))
		
	# 2. Registered sources (Hubs, etc)
	# Clean up freed sources first
	for i in range(loading_sources.size() - 1, -1, -1):
		if not is_instance_valid(loading_sources[i]):
			loading_sources.remove_at(i)
		else:
			var local_pos = to_local(loading_sources[i].global_position)
			loader_centers.append(Vector2i((local_pos / CHUNK_SIZE).floor()))
			
	# Determine set of required chunks
	var required_chunks: Dictionary = {} # Use Dict as Set
	
	for center in loader_centers:
		for x in range(center.x - LOAD_RADIUS, center.x + LOAD_RADIUS + 1):
			for y in range(center.y - LOAD_RADIUS, center.y + LOAD_RADIUS + 1):
				if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
					required_chunks[Vector2i(x, y)] = true

	# Load needed
	for coord in required_chunks:
		if not loaded_chunks.has(coord):
			_load_chunk(coord)
	
	# Unload unneeded
	var to_remove = []
	for coord in loaded_chunks:
		if not required_chunks.has(coord):
			to_remove.append(coord)
			
	for coord in to_remove:
		_unload_chunk(coord)

func _load_chunk(coord: Vector2i):
	var path = "res://assets/map_chunks/map_%d_%d.png" % [coord.x, coord.y]
	if ResourceLoader.exists(path):
		var sprite = Sprite2D.new()
		sprite.texture = load(path)
		sprite.centered = false
		sprite.position = Vector2(coord.x * CHUNK_SIZE, coord.y * CHUNK_SIZE)
		add_child(sprite)
		loaded_chunks[coord] = sprite
		
		# Also load data layer
		_load_chunk_data(coord)
	else:
		# Mark as null to prevent retrying every frame if missing
		loaded_chunks[coord] = null

func _unload_chunk(coord: Vector2i):
	var node = loaded_chunks[coord]
	if node:
		node.queue_free()
	loaded_chunks.erase(coord)
	loaded_terrain_data.erase(coord)

# Terrain Data
var loaded_terrain_data: Dictionary = {} # Vector2i -> Image

func get_terrain_at(global_pos: Vector2) -> int:
	var local_pos = to_local(global_pos)
	if local_pos.x < 0 or local_pos.y < 0: return 0
	
	var chunk_coord = Vector2i((local_pos / CHUNK_SIZE).floor())
	if not loaded_terrain_data.has(chunk_coord):
		return 0 # Default/Walkable
		
	var img = loaded_terrain_data[chunk_coord]
	if not img: return 0
	
	var chunk_pos = chunk_coord * CHUNK_SIZE
	var pixel_pos = local_pos - Vector2(chunk_pos)
	
	# Mapping: The Data texture size might differ from Visual Chunk Size
	# If Data is 512, Chunk is 1024, ratio is 0.5
	var ratio = img.get_width() / float(CHUNK_SIZE)
	var x = int(pixel_pos.x * ratio)
	var y = int(pixel_pos.y * ratio)
	
	# Clamp to be safe
	x = clampi(x, 0, img.get_width() - 1)
	y = clampi(y, 0, img.get_height() - 1)
	
	# In L8 format, get_pixel returns color.r = value/255.0
	# We need the raw byte value.
	# get_pixel(x,y).r8 is available in Godot 4 OR just floor(col.r * 255)
	
	# Optimization: If using 'L', Godot usually imports as R8 or similar.
	var col = img.get_pixel(x, y)
	return int(round(col.r * 255.0))

func _load_chunk_data(coord: Vector2i):
	var path_data = "res://assets/map_data/data_%d_%d.png" % [coord.x, coord.y]
	if ResourceLoader.exists(path_data):
		var img = load(path_data).get_image()
		loaded_terrain_data[coord] = img
		terrain_loaded.emit(coord)
	else:
		loaded_terrain_data[coord] = null
