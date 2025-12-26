extends Node2D
class_name BuildSlots

@export var grid_size: Vector2i = Vector2i(3, 3)
@export var cell_size: Vector2  = Vector2(300, 300)   # each slot is 300×300 px
@export var center_reserved: bool = true

var _anchors: Array[Node2D] = []

func _ready() -> void:
	_make_anchors()

# ----------------------------------------------------
# Anchor grid
# ----------------------------------------------------
func _make_anchors() -> void:
	for c in _anchors:
		c.queue_free()
	_anchors.clear()

	var idx: int = 0
	for y in range(grid_size.y):
		for x in range(grid_size.x):
			var slot := Node2D.new()
			slot.name = "Slot_%s" % idx
			# center grid on (0,0)
			var ox := (x - (grid_size.x - 1) * 0.5) * cell_size.x
			var oy := (y - (grid_size.y - 1) * 0.5) * cell_size.y
			slot.position = Vector2(ox, oy)
			add_child(slot)
			_anchors.append(slot)
			idx += 1

func _is_center(slot_id: int) -> bool:
	if not center_reserved:
		return false
	var cx: int = grid_size.x >> 1
	var cy: int = grid_size.y >> 1
	return slot_id == cy * grid_size.x + cx

# ----------------------------------------------------
# Slot operations
# ----------------------------------------------------
func clear_slot(slot_id: int) -> void:
	if slot_id < 0 or slot_id >= _anchors.size():
		return
	for c in _anchors[slot_id].get_children():
		c.queue_free()

func place_building(slot_id: int, scene: PackedScene, state: BuildSlotState = null) -> Node:
	if slot_id < 0 or slot_id >= _anchors.size():
		return null
	if _is_center(slot_id):
		return null

	var anchor := _anchors[slot_id]
	# one building per slot
	for c in anchor.get_children():
		c.queue_free()

	var b := scene.instantiate()
	anchor.add_child(b)

	# Duck-typed state application (works for ProducerBuilding, etc.)
	if state != null and b != null and b.has_method("apply_state"):
		b.call("apply_state", state)

	return b

# ----------------------------------------------------
# Realize from hub state
# Accepts BuildSlotState (scene or scene_path),
# direct PackedScene, or string path in the slots array.
# ----------------------------------------------------
func realize_from_state(state: HubStates) -> void:
	if state == null:
		return

	var arr: Array = state.slots
	if arr == null:
		return

	var total: int = grid_size.x * grid_size.y
	var count: int = min(arr.size(), total)

	for i in range(count):
		if _is_center(i):
			continue

		var ps: PackedScene = null
		var slot_state: BuildSlotState = null
		var entry: Variant = arr[i]

		if entry is BuildSlotState:
			var bs: BuildSlotState = entry as BuildSlotState
			slot_state = bs
			var sc: PackedScene = bs.scene
			if sc != null:
				ps = sc
			elif bs.scene_path != "":
				var path: String = bs.scene_path
				ps = load(path) as PackedScene
		elif entry is PackedScene:
			ps = entry as PackedScene
		elif entry is String or entry is StringName:
			ps = load(String(entry)) as PackedScene

		if ps != null:
			place_building(i, ps, slot_state)
		else:
			clear_slot(i)

	# clear any extra grid slots beyond the array
	for i in range(count, total):
		if _is_center(i):
			continue
		clear_slot(i)

# Enumerate all placed nodes (Hub will filter by group/method).
func iter_buildings() -> Array[Node]:
	var out: Array[Node] = []
	for a in _anchors:
		for c in a.get_children():
			out.append(c)
	return out
