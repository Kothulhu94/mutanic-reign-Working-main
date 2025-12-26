extends ProcessorBuilding
class_name StoneMason

@export var cutstone_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"Stone"
	output_item_id = &"CutStone"
	var spr := $Sprite2D as Sprite2D
	if spr and cutstone_texture:
		spr.texture = cutstone_texture
	super._ready()
