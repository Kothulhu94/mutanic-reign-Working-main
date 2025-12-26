extends ProducerBuilding
class_name LichenFarm

@export var synthlichen_texture: Texture2D

func _ready() -> void:
	product_item_id = &"SynthLichen"
	var spr := $Sprite2D as Sprite2D
	if spr and synthlichen_texture:
		spr.texture = synthlichen_texture
	super._ready()
