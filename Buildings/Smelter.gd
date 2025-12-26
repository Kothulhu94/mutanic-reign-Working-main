extends ProcessorBuilding
class_name Smelter

@export var refinedmetal_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"Scrap"
	output_item_id = &"RefinedMetal"
	var spr := $Sprite2D as Sprite2D
	if spr and refinedmetal_texture:
		spr.texture = refinedmetal_texture
	super._ready()
