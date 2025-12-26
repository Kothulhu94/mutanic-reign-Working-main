extends ProcessorBuilding
class_name MedicalLoom

@export var synthweavebandage_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"Hemp"
	output_item_id = &"SynthWeaveBandage"
	var spr := $Sprite2D as Sprite2D
	if spr and synthweavebandage_texture:
		spr.texture = synthweavebandage_texture
	super._ready()
