extends ProcessorBuilding
class_name TextileMill

@export var luxuryfabric_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"Cotton"
	output_item_id = &"LuxuryFabric"
	var spr := $Sprite2D as Sprite2D
	if spr and luxuryfabric_texture:
		spr.texture = luxuryfabric_texture
	super._ready()
