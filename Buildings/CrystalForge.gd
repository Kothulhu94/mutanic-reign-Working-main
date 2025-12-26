extends ProcessorBuilding
class_name CrystalForge

@export var energylens_texture: Texture2D

func _ready() -> void:
	selection_mode = "by_id"
	input_item_id = &"RawCrystal"
	output_item_id = &"EnergyLens"
	var spr := $Sprite2D as Sprite2D
	if spr and energylens_texture:
		spr.texture = energylens_texture
	super._ready()
