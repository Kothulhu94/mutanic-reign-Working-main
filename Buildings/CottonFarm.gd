# CottonFarm.gd
extends ProducerBuilding
class_name CottonFarm

@export var cotton_texture: Texture2D

func _ready() -> void:
	product_item_id = &"Cotton"
	var spr := $Sprite2D as Sprite2D
	if spr and cotton_texture:
		spr.texture = cotton_texture
	super._ready()
