extends ProducerBuilding
class_name FungusVat

@export var mycoprotein_texture: Texture2D

func _ready() -> void:
	product_item_id = &"MycoProtein"
	var spr := $Sprite2D as Sprite2D
	if spr and mycoprotein_texture:
		spr.texture = mycoprotein_texture
	super._ready()
