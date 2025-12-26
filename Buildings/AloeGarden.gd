# AloeGarden.gd
extends ProducerBuilding
class_name AloeGarden

@export var aloe_texture: Texture2D

func _ready() -> void:
	product_item_id = &"Aloe"
	var spr := $Sprite2D as Sprite2D
	if spr and aloe_texture:
		spr.texture = aloe_texture
	super._ready()
