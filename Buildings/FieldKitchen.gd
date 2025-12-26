extends ProcessorBuilding
class_name FieldKitchen

@export var smokedmeat_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"RabbitMeat"
	output_item_id = &"SmokedMeat"
	var spr := $Sprite2D as Sprite2D
	if spr and smokedmeat_texture:
		spr.texture = smokedmeat_texture
	super._ready()
