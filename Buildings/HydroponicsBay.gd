extends ProducerBuilding
class_name HydroponicsBay

@export var hydroberries_texture: Texture2D

func _ready() -> void:
	product_item_id = &"HydroBerries"
	var spr := $Sprite2D as Sprite2D
	if spr and hydroberries_texture:
		spr.texture = hydroberries_texture
	super._ready()
