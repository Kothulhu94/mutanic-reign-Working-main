extends ProcessorBuilding
class_name NutrientSynthesizer

@export var proteinbar_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"MycoProtein"
	output_item_id = &"ProteinBar"
	var spr := $Sprite2D as Sprite2D
	if spr and proteinbar_texture:
		spr.texture = proteinbar_texture
	super._ready()
