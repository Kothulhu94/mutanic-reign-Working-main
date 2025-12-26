extends ProcessorBuilding
class_name Perfumery

@export var orchidperfume_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"XenoOrchid"
	output_item_id = &"OrchidPerfume"
	var spr := $Sprite2D as Sprite2D
	if spr and orchidperfume_texture:
		spr.texture = orchidperfume_texture
	super._ready()
