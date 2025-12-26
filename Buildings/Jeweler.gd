extends ProcessorBuilding
class_name Jeweler

@export var cutazuregem_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"AzureGem"
	output_item_id = &"CutAzureGem"
	var spr := $Sprite2D as Sprite2D
	if spr and cutazuregem_texture:
		spr.texture = cutazuregem_texture
	super._ready()
