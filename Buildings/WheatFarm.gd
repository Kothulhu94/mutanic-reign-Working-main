extends ProducerBuilding
class_name WheatFarm

@export var farm_texture: Texture2D    # drag your 300×300 wheat farm sprite here

func _ready() -> void:
	# Identify the product for this specific building type (not in the base Producer).
	product_item_id = &"Wheat"

	# Optional visual hookup
	var spr := $Sprite2D as Sprite2D
	if spr and farm_texture:
		spr.texture = farm_texture

	# Keep Producer base behavior (groups, clamps, etc.)
	super._ready()
