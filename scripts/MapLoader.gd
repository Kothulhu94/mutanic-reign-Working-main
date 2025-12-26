class_name MapLoader extends Node2D

# Refreshed at 2025-12-26T06:20:00

const CHUNK_SIZE = 1024
const GRID_SIZE = 16 # 16 * 1024 = 16384 pixels

func _ready():
	print("MapLoader: Starting map chunk loading...")
	var loaded_count = 0
	
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			# Expects files named map_0_0.png, map_15_15.png, etc. in res://assets/map_chunks/
			var path = "res://assets/map_chunks/map_%d_%d.png" % [x, y]
			
			# Use ResourceLoader instead of FileAccess for better compatibility with exported PCKs
			if ResourceLoader.exists(path):
				var sprite = Sprite2D.new()
				sprite.texture = load(path)
				sprite.centered = false
				sprite.position = Vector2(x * CHUNK_SIZE, y * CHUNK_SIZE)
				add_child(sprite)
				loaded_count += 1
			else:
				# Only print sparingly or if important. 256 lines of "missing" is noise if expected.
				# But for debugging now, let's see failures for the first few.
				if x < 2 and y < 2:
					print("MapLoader: Chunk not found at %s" % path)
		
		# Yield every row to prevent freezing the browser tab
		await get_tree().process_frame

	print("MapLoader: Finished. Loaded %d chunks." % loaded_count)
