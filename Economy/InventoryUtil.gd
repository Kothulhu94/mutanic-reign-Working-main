# uid://de1ytl42b8gqk
extends RefCounted
class_name InventoryUtil

# Build a float "working" mirror of int + float inventories
static func float_mirror(int_inv: Dictionary, float_inv: Dictionary) -> Dictionary:
	var working: Dictionary = {}
	for k in int_inv.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		working[id] = float(int_inv.get(k, 0))
	for k in float_inv.keys():
		var id2: StringName = (k if k is StringName else StringName(str(k)))
		working[id2] = float(float_inv.get(k, 0.0))
	return working

# Union of keys from both inventories
static func union_keys(int_inv: Dictionary, float_inv: Dictionary) -> Array[StringName]:
	var keys: Array[StringName] = []
	var seen: Dictionary = {}
	for k in int_inv.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		if not seen.has(id):
			seen[id] = true
			keys.append(id)
	for k in float_inv.keys():
		var id2: StringName = (k if k is StringName else StringName(str(k)))
		if not seen.has(id2):
			seen[id2] = true
			keys.append(id2)
	return keys

# Read current amount for an id, preferring float cache
static func read_amount(id: StringName, int_inv: Dictionary, float_inv: Dictionary) -> float:
	return float(float_inv.get(id, float(int_inv.get(id, 0))))

# Merge src into dst (additive)
static func merge_delta(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		dst[id] = (dst.get(id, 0.0) as float) + float(src[k])
