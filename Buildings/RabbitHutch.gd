# RabbitHutch.gd
extends ProducerBuilding
class_name RabbitHutch

@export var hutch_texture: Texture2D

func _ready() -> void:
	product_item_id = &"RabbitMeat"
	var spr := $Sprite2D as Sprite2D
	if spr and hutch_texture:
		spr.texture = hutch_texture
	super._ready()
