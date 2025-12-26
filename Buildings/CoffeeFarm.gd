# CoffeeFarm.gd
extends ProducerBuilding
class_name CoffeeFarm

@export var coffee_texture: Texture2D

func _ready() -> void:
	product_item_id = &"Coffee"
	var spr := $Sprite2D as Sprite2D
	if spr and coffee_texture:
		spr.texture = coffee_texture
	super._ready()
