extends Node2D

const CHUNK_SIZE = 1024
const GRID_SIZE = 16 # 16 * 1024 = 16384 pixels

func _ready():
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var sprite = Sprite2D.new()
			# Expects files named map_0_0.png, map_15_15.png, etc. in res://assets/map_chunks/
			var path = "res://assets/map_chunks/map_%d_%d.png" % [x, y]
			
			if FileAccess.file_exists(path):
				sprite.texture = load(path)
				sprite.centered = false
				sprite.position = Vector2(x * CHUNK_SIZE, y * CHUNK_SIZE)
				add_child(sprite)
