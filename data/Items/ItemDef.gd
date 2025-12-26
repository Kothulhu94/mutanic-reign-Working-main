extends Resource
class_name ItemDef

@export var id: StringName            # canonical id: e.g., &"wheat"
@export var display_name: String = "" # UI label
@export var tags: Array[StringName] = []   # e.g., [&"food", &"flora", &"ingredient"]
@export var base_price: float = 1.0        # nominal price; traders can modify
@export var stack_size: int = 999999       # optional; for UI limits, etc.

func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
