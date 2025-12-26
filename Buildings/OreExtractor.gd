extends ProducerBuilding
class_name OreExtractor

@export var ironore_texture: Texture2D

func _ready() -> void:
	product_item_id = &"IronOre"
	var spr := $Sprite2D as Sprite2D
	if spr and ironore_texture:
		spr.texture = ironore_texture
	super._ready()
