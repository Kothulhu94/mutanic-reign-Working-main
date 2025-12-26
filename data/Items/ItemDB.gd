extends Resource
class_name ItemDB

# Map of item id -> ItemDef (ids are StringName)
@export var items: Dictionary = {}  # { StringName: ItemDef }

func get_item(id) -> ItemDef:
	var key: StringName = (id if id is StringName else StringName(str(id)))
	return items.get(key)

func price_of(id) -> float:
	var it := get_item(id)
	return it.base_price if it != null else 0.0

func has_tag(id, tag) -> bool:
	var it := get_item(id)
	var t: StringName = (tag if tag is StringName else StringName(str(tag)))
	return it != null and it.tags.has(t)

func ensure_registered(def: ItemDef) -> void:
	if def == null: return
	if def.id == StringName():
		push_error("ItemDef missing 'id'"); return
	items[def.id] = def

func all_ids() -> Array[StringName]:
	return items.keys()
