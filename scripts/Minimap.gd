extends Control

@export var map_atlas: Texture2D
@export var player_marker: Node2D
@export var zoom_level: float = 0.1 # 10% of original size

var minimap_texture: ImageTexture

func _ready():
	create_minimap()

func create_minimap():
	if not map_atlas:
		push_warning("Minimap: map_atlas not assigned")
		return
	
	# Load the full map atlas
	var atlas_image = map_atlas.get_image()
	
	# Scale down for minimap (8192×8192 → 819×819 at 0.1 zoom)
	var minimap_size = Vector2i(
		int(atlas_image.get_width() * zoom_level),
		int(atlas_image.get_height() * zoom_level)
	)
	atlas_image.resize(minimap_size.x, minimap_size.y)
	
	# Create texture for minimap
	minimap_texture = ImageTexture.create_from_image(atlas_image)
	
	# Display in UI (assuming TextureRect child)
	var minimap_display = $MinimapDisplay as TextureRect
	if minimap_display:
		minimap_display.texture = minimap_texture

func _process(_delta):
	# Update player position marker
	if player_marker and has_node("PlayerMarker"):
		var world_pos = player_marker.global_position
		var minimap_pos = world_pos * zoom_level
		$PlayerMarker.position = minimap_pos
