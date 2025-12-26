extends ProducerBuilding
class_name ExoticGarden

@export var xenoorchid_texture: Texture2D

func _ready() -> void:
	product_item_id = &"XenoOrchid"
	var spr := $Sprite2D as Sprite2D
	if spr and xenoorchid_texture:
		spr.texture = xenoorchid_texture
	super._ready()
