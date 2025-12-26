@tool
extends Node2D

# ------------------------------------------------------------------------------
# Editor Map Loader
# ------------------------------------------------------------------------------
# This script loads the map chunks into the editor for visualization purposes.
# It is designed to NOT save the chunks to the scene file to avoid bloating
# the version control with 256 Sprite2D nodes.
# ------------------------------------------------------------------------------

const CHUNK_SIZE = 1024
const GRID_SIZE = 16 # 16 * 1024 = 16384 pixels

@export var load_map: bool = false:
	set(value):
		load_map = false # Toggle back off immediately
		if value:
			_load_chunks()

@export var clear_map: bool = false:
	set(value):
		clear_map = false
		if value:
			_clear_chunks()

func _ready():
	if Engine.is_editor_hint():
		# Optional: Auto-load if you want, but safer to let user trigger it
		# _load_chunks()
		pass
	else:
		# In game runtime, we don't want this node to do anything or exist.
		# The main MapLoader handles runtime streaming.
		queue_free()

func _load_chunks():
	_clear_chunks()
	print("EditorMapLoader: Loading %d x %d chunks..." % [GRID_SIZE, GRID_SIZE])
	
	var count = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var path = "res://assets/map_chunks/map_%d_%d.png" % [x, y]
			
			if FileAccess.file_exists(path):
				var sprite = Sprite2D.new()
				sprite.texture = load(path)
				sprite.centered = false
				sprite.position = Vector2(x * CHUNK_SIZE, y * CHUNK_SIZE)
				sprite.name = "Chunk_%d_%d" % [x, y]
				
				# CRITICAL: We do NOT set the owner. 
				# This ensures these nodes are NOT saved to the .tscn file.
				add_child(sprite)
				count += 1
				
	print("EditorMapLoader: Loaded %d chunks." % count)

func _clear_chunks():
	var children = get_children()
	for child in children:
		child.queue_free()
	print("EditorMapLoader: Cleared chunks.")
