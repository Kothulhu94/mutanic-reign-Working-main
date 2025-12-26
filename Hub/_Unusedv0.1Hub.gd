# Hub.gd — Godot 4.5
extends Node2D
class_name _Hubble1

@export var state: HubStates
@export var item_db: ItemDB

@onready var click_and_fade: Area2D = get_node_or_null("ClickAndFade") as Area2D
@onready var slots: BuildSlots      = get_node_or_null("BuildSlots") as BuildSlots

# --- Economy float cache (store fractional amounts here; write whole ints to state.inventory)
var _inventory_float: Dictionary = {}

# ---- Consumption tuning ----
@export var servings_tick_interval: float = 60.0        # ticks between servings checks
@export var servings_per_10_pops: float = 1.0          # servings needed per 10 pops per servings tick

# Stage costs (units consumed per 1 serving)
@export var cost_units_ingredient: float = 5.0
@export var cost_units_processed: float  = 2.5
@export var cost_units_meal: float       = 1.0

# Signed snapshot (servings): +surplus / –deficit
@export var food_level: float = 0.0

# Internal timer (formerly "servings_accum")
var _hunger_timer_accum: float = 0.0

func _ready() -> void:
	if state == null:
		state = HubStates.new()
	state.ensure_slots(9)

	if slots != null:
		slots.realize_from_state(state)
		_inject_building_dependencies()

	if click_and_fade != null:
		# Optional signals; keep if you use them
		click_and_fade.actor_entered.connect(_on_actor_entered)
		click_and_fade.actor_exited.connect(_on_actor_exited)

	var tk: Node = get_node_or_null("/root/Timekeeper")
	if tk == null:
		push_error("Timekeeper autoload not found at /root/Timekeeper")
	elif not tk.is_connected("tick", Callable(self, "_on_timekeeper_tick")):
		tk.connect("tick", Callable(self, "_on_timekeeper_tick"))

func _physics_process(_delta: float) -> void:
	# Reserved for other per-frame logic; economy is on Timekeeper ticks
	pass

func _on_timekeeper_tick(dt: float) -> void:
	if slots == null:
		return

	# Build a float "working" mirror of inventory so multiple processors
	# in the same tick don't double-spend and can see producer output.
	var working: Dictionary = {}
	# start from ints
	for k in state.inventory.keys():
		var key_s: StringName = (k if k is StringName else StringName(str(k)))
		working[key_s] = float(state.inventory.get(k, 0))
	# overlay float cache
	for k in _inventory_float.keys():
		var key_f: StringName = (k if k is StringName else StringName(str(k)))
		working[key_f] = float(_inventory_float.get(k, 0.0))

	var total_delta: Dictionary = {}

	# ---- 1) Producers
	for n: Node in slots.iter_buildings():
		if n.is_in_group("producer") and n.has_method("produce_tick") and bool(n.get("enabled")):
			var d: Dictionary = (n.call("produce_tick") as Dictionary)
			for k in d.keys():
				var key: StringName = (k if k is StringName else StringName(str(k)))
				var val: float = float(d[k])
				total_delta[key] = (total_delta.get(key, 0.0) as float) + val
				working[key] = float(working.get(key, 0.0)) + val

	# ---- 2) Processors
	for n: Node in slots.iter_buildings():
		if n.is_in_group("processor") and n.has_method("refine_tick") and bool(n.get("enabled")):
			var d2: Dictionary = (n.call("refine_tick", working) as Dictionary)
			for k in d2.keys():
				var key2: StringName = (k if k is StringName else StringName(str(k)))
				var val2: float = float(d2[k])
				total_delta[key2] = (total_delta.get(key2, 0.0) as float) + val2
				working[key2] = float(working.get(key2, 0.0)) + val2

	# ---- 3) Apply merged production/processing delta
	_apply_inventory_delta(total_delta)

	# ---- 5) Consumption cadence
	var consume_delta: Dictionary = _update_consumption(dt)
	if consume_delta.size() > 0:
		_apply_inventory_delta(consume_delta)

	# ---- 6) Food-level snapshot (signed servings)
	_update_food_level_snapshot()

# ------------------------------------------------------------------------------------
# Inventory helpers
# ------------------------------------------------------------------------------------
func _apply_inventory_delta(delta: Dictionary) -> void:
	for k in delta.keys():
		var key: StringName = (k if k is StringName else StringName(str(k)))
		var curf: float = float(_inventory_float.get(key, float(state.inventory.get(key, 0))))
		curf += float(delta[k])
		_inventory_float[key] = curf
		state.inventory[key] = int(floor(curf))

func _current_inventory_keys() -> Array[StringName]:
	var keys: Array[StringName] = []
	var seen: Dictionary = {}
	for k in state.inventory.keys():
		var id_s: StringName = (k if k is StringName else StringName(str(k)))
		if not seen.has(id_s):
			seen[id_s] = true
			keys.append(id_s)
	for k in _inventory_float.keys():
		var id_f: StringName = (k if k is StringName else StringName(str(k)))
		if not seen.has(id_f):
			seen[id_f] = true
			keys.append(id_f)
	return keys

func _current_amount(id: StringName) -> float:
	return float(_inventory_float.get(id, float(state.inventory.get(id, 0))))

# ------------------------------------------------------------------------------------
# Consumption
# ------------------------------------------------------------------------------------
func _update_consumption(dt: float) -> Dictionary:
	_hunger_timer_accum += dt
	var total: Dictionary = {}
	while _hunger_timer_accum >= servings_tick_interval:
		_hunger_timer_accum -= servings_tick_interval
		var d: Dictionary = _consume_one_servings_tick()
		for k in d.keys():
			var key: StringName = (k if k is StringName else StringName(str(k)))
			total[key] = (total.get(key, 0.0) as float) + float(d[k])
	return total

func _consume_one_servings_tick() -> Dictionary:
	var out: Dictionary = {}
	if item_db == null:
		return out

	var servings_needed: float = _compute_servings_needed_from_cap()
	if servings_needed <= 0.0:
		return out

	# Classify edible items: only primary-tag = food
	var meal_items: Array[StringName] = []
	var processed_items: Array[StringName] = []
	var ingredient_items: Array[StringName] = []

	for k in _current_inventory_keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		if not _is_primary_food(id):
			continue
		if item_db.has_tag(id, &"meal"):
			meal_items.append(id)
		elif item_db.has_tag(id, &"processed"):
			processed_items.append(id)
		else:
			ingredient_items.append(id)

	var remain_servings: float = servings_needed

	# Meals first
	if remain_servings > 0.0 and meal_items.size() > 0:
		var units_meal: float = remain_servings * cost_units_meal
		var d_meal: Dictionary = _consume_units_from_items(meal_items, units_meal)
		_merge_delta(out, d_meal)
		remain_servings -= _units_to_servings_taken(d_meal, cost_units_meal)

	# Processed next
	if remain_servings > 0.0 and processed_items.size() > 0:
		var units_proc: float = remain_servings * cost_units_processed
		var d_proc: Dictionary = _consume_units_from_items(processed_items, units_proc)
		_merge_delta(out, d_proc)
		remain_servings -= _units_to_servings_taken(d_proc, cost_units_processed)

	# Ingredients last
	if remain_servings > 0.0 and ingredient_items.size() > 0:
		var units_ing: float = remain_servings * cost_units_ingredient
		var d_ing: Dictionary = _consume_units_from_items(ingredient_items, units_ing)
		_merge_delta(out, d_ing)
		remain_servings -= _units_to_servings_taken(d_ing, cost_units_ingredient)

	# Optional: store shortage if you want later
	# state.last_food_shortage_servings = max(remain_servings, 0.0)

	return out

func _consume_units_from_items(items: Array[StringName], units_needed: float) -> Dictionary:
	var d: Dictionary = {}
	var remain: float = units_needed
	for id: StringName in items:
		if remain <= 0.0:
			break
		var avail: float = _current_amount(id)
		if avail <= 0.0:
			continue
		var take: float = min(avail, remain)
		d[id] = (d.get(id, 0.0) as float) - take   # negative = consumed
		remain -= take
	return d

func _merge_delta(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		var key: StringName = (k if k is StringName else StringName(str(k)))
		dst[key] = (dst.get(key, 0.0) as float) + float(src[k])

func _units_to_servings_taken(d: Dictionary, units_per_serving: float) -> float:
	var units_total: float = 0.0
	for v in d.values():
		if float(v) < 0.0:
			units_total += -float(v)
	return units_total / max(0.0001, units_per_serving)

# Food primary-tag guard
func _is_primary_food(id: StringName) -> bool:
	if item_db == null:
		return false
	var def: ItemDef = item_db.items.get(id, null)
	if def == null:
		return false
	var tags: Array = def.tags
	return tags.size() > 0 and tags[0] == &"food"

# ------------------------------------------------------------------------------------
# Food-level snapshot
# ------------------------------------------------------------------------------------
func _update_food_level_snapshot() -> void:
	var need: float = _compute_servings_needed_from_cap()
	var have: float = _compute_servings_available_now()
	food_level = have - need

func _compute_servings_needed_from_cap() -> float:
	var cap: int = _compute_population_cap_now()
	return (float(cap) / 10.0) * servings_per_10_pops

func _compute_population_cap_now() -> int:
	var cap: int = state.base_population_cap
	if slots != null:
		for n: Node in slots.iter_buildings():
			if n.has_method("get_population_cap_bonus"):
				cap += int(n.call("get_population_cap_bonus"))
	return cap

func _compute_servings_available_now() -> float:
	var servings: float = 0.0
	for k in _current_inventory_keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		if not _is_primary_food(id):
			continue
		var units: float = _current_amount(id)
		if units <= 0.0:
			continue
		if item_db.has_tag(id, &"meal"):
			servings += units / max(0.0001, cost_units_meal)
		elif item_db.has_tag(id, &"processed"):
			servings += units / max(0.0001, cost_units_processed)
		else:
			servings += units / max(0.0001, cost_units_ingredient)
	return servings

# ------------------------------------------------------------------------------------
# Dependency injection for processors
# ------------------------------------------------------------------------------------
func _inject_building_dependencies() -> void:
	if slots == null or item_db == null:
		return
	for n: Node in slots.iter_buildings():
		if n == null:
			continue
		if n.is_in_group("processor") or n.has_method("refine_tick"):
			n.set("item_db", item_db)

# ------------------------------------------------------------------------------------
# Public API (optional helpers)
# ------------------------------------------------------------------------------------
func place_building(slot_id: int, ps: PackedScene, s: BuildSlotState) -> Node:
	if slots == null:
		return null
	var node: Node = slots.place_building(slot_id, ps, s)
	if node != null:
		state.slots[slot_id] = s
		if item_db != null and (node.is_in_group("processor") or node.has_method("refine_tick")):
			node.set("item_db", item_db)
	return node

func clear_building(slot_id: int) -> void:
	if slots == null:
		return
	slots.clear_slot(slot_id)
	state.slots[slot_id] = null

# ------------------------------------------------------------------------------------
# Area callbacks (optional)
# ------------------------------------------------------------------------------------
func _on_actor_entered(_actor: Node) -> void:
	pass

func _on_actor_exited(_actor: Node) -> void:
	pass
