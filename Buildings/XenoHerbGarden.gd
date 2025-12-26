extends ProducerBuilding
class_name XenoHerbGarden

@export var xenoroot_texture: Texture2D

func _ready() -> void:
	product_item_id = &"XenoRoot"
	var spr := $Sprite2D as Sprite2D
	if spr and xenoroot_texture:
		spr.texture = xenoroot_texture
	super._ready()
