extends ProcessorBuilding
class_name StimLab

@export var combatstims_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"XenoRoot"
	output_item_id = &"CombatStims"
	var spr := $Sprite2D as Sprite2D
	if spr and combatstims_texture:
		spr.texture = combatstims_texture
	super._ready()
