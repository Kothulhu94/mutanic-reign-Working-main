# StoneQuarry.gd
extends ProducerBuilding
class_name StoneQuarry

@export var quarry_texture: Texture2D

func _ready() -> void:
	product_item_id = &"Stone"
	var spr := $Sprite2D as Sprite2D
	if spr and quarry_texture:
		spr.texture = quarry_texture
	super._ready()
