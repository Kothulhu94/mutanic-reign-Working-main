extends ProducerBuilding
class_name GemMine

@export var azuregem_texture: Texture2D

func _ready() -> void:
	product_item_id = &"AzureGem"
	var spr := $Sprite2D as Sprite2D
	if spr and azuregem_texture:
		spr.texture = azuregem_texture
	print("GemMine: Ready at ", global_position)
	super._ready()
