extends ProcessorBuilding
class_name Foundry

@export var ironingot_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"IronOre"
	output_item_id = &"IronIngot"
	var spr := $Sprite2D as Sprite2D
	if spr and ironingot_texture:
		spr.texture = ironingot_texture
	super._ready()
