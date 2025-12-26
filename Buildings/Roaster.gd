extends ProcessorBuilding
class_name Roaster

@export var roastedcoffee_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"Coffee"
	output_item_id = &"RoastedCoffee"
	var spr := $Sprite2D as Sprite2D
	if spr and roastedcoffee_texture:
		spr.texture = roastedcoffee_texture
	super._ready()
