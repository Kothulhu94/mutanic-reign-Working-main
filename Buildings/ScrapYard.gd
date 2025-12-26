# ScrapYard.gd
extends ProducerBuilding
class_name ScrapYard

@export var scrapyard_texture: Texture2D

func _ready() -> void:
	product_item_id = &"Scrap"
	var spr := $Sprite2D as Sprite2D
	if spr and scrapyard_texture:
		spr.texture = scrapyard_texture
	super._ready()
