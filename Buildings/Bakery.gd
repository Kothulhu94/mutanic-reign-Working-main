# Bakery.gd — Godot 4.5

extends ProcessorBuilding
class_name Bakery

@export var bakery_texture: Texture2D   # assign your 300×300 sprite

func _ready() -> void:
	# Visual-only hookup; recipe/throughput/tags come from the Inspector (selection_mode, required_tags, etc.).
	var spr := $Sprite2D as Sprite2D
	if spr and bakery_texture:
		spr.texture = bakery_texture
	super._ready()  # keep group/tag setup from ProcessorBuilding

func _compute_output_id(picked: StringName) -> StringName:
	
	return StringName(String(picked) + "Bread")
