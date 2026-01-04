extends Resource
class_name BuildSlotState

@export var scene: PackedScene # drag WheatFarm.tscn here (preferred)
@export var scene_path: String = "" # optional fallback
@export var level: int = 1
@export var custom: Dictionary = {}

func to_dict() -> Dictionary:
	var path = scene_path
	if scene != null:
		path = scene.resource_path
		
	return {
		"scene_path": path,
		"level": level,
		"custom": custom.duplicate(true)
	}

func from_dict(data: Dictionary) -> void:
	scene_path = data.get("scene_path", "")
	level = data.get("level", 1)
	custom = data.get("custom", {}).duplicate(true)
	
	if not scene_path.is_empty():
		scene = load(scene_path)
