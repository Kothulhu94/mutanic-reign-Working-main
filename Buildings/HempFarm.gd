# HempFarm.gd
extends ProducerBuilding
class_name HempFarm

@export var hemp_texture: Texture2D

func _ready() -> void:
	product_item_id = &"Hemp"
	var spr := $Sprite2D as Sprite2D
	if spr and hemp_texture:
		spr.texture = hemp_texture
	super._ready()
