extends ProcessorBuilding
class_name PharmaLab

@export var medigel_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"SynthLichen"
	output_item_id = &"MediGel"
	var spr := $Sprite2D as Sprite2D
	if spr and medigel_texture:
		spr.texture = medigel_texture
	super._ready()
