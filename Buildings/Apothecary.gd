extends ProcessorBuilding
class_name Apothecary

@export var healingsalve_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"Aloe"
	output_item_id = &"HealingSalve"
	var spr := $Sprite2D as Sprite2D
	if spr and healingsalve_texture:
		spr.texture = healingsalve_texture
	super._ready()
