# res://buildings/ProcessorBuilding.gd
extends Node2D
class_name ProcessorBuilding

# --------------------------
# Identity / state
# --------------------------
@export var enabled: bool = true
@export var level: int = 1

# --------------------------
# Recipe selection
# --------------------------
@export_enum("by_id", "by_tags") var selection_mode: String = "by_tags"
@export var input_item_id: StringName = StringName()                      # when selection_mode == "by_id"
@export var required_tags: Array[StringName] = []                          # when selection_mode == "by_tags"
@export_enum("any", "all") var tag_match: String = "all"                  # tag rule
@export_enum("first_match", "highest_stock", "lowest_price")
var input_pick_strategy: String = "first_match"

# Tag lookups / price need this (Hub injects it)
@export var item_db: ItemDB

# --------------------------
# Output (static optional; subclasses may compute dynamically)
# --------------------------
@export var output_item_id: StringName = StringName()
@export var input_per_output: float = 1.0
@export var output_per_cycle: float = 1.0

# --------------------------
# Throughput / timing (Timekeeper ticks)
# --------------------------
@export var base_cycle_time_ticks: float = 2.0
@export var efficiency_mult: float = 1.0

# --------------------------
# Economics
# --------------------------
const BUILD_COST_PACS_BASE: int  = 200
const BUILD_TIME_TICKS_BASE: int = 200
const UPG_COST_PACS_BASE: int    = 400
const UPG_TIME_TICKS_BASE: int   = 400

# --------------------------
# Shared behavior constants
# --------------------------
const PER_LEVEL_MULT: float = 1.5

# --------------------------
# Internals
# --------------------------
var work_progress: float = 0.0
var last_picked_input: StringName = StringName()

func _ready() -> void:
	add_to_group("processor")
	level = max(1, level)

# Hub pulls this once per tick. Returns additive delta.
func refine_tick(hub_inventory: Dictionary, governor_bonus: float = 0.0) -> Dictionary:
	var result: Dictionary = {}
	if not enabled:
		return result

	# Accumulate work
	var lvl_mult: float = pow(PER_LEVEL_MULT, float(max(level - 1, 0)))
	var denom: float = max(0.0001, base_cycle_time_ticks)
	var outputs_per_tick: float = (output_per_cycle / denom) * efficiency_mult * lvl_mult * (1.0 + governor_bonus)
	work_progress += outputs_per_tick

	var outputs_ready: int = int(floor(work_progress))
	if outputs_ready <= 0:
		return result

	# **FIX STARTS HERE**
	# 1. Pick an input that can pay for at least ONE output, not the whole batch.
	var min_need_for_one: float = input_per_output
	var picked: StringName = _pick_input_candidate(hub_inventory, min_need_for_one)
	if picked == StringName():
		return result # Not enough input for even one item; keep progress and wait.

	# 2. Compute output id (dynamic or static)
	var out_id: StringName = _compute_output_id(picked)
	if out_id == StringName():
		return result # No valid output configured; keep progress.
	
	# 3. Cap by stock: craft as many as we can *right now*
	var have: float = float(hub_inventory.get(picked, 0.0))
	var craftable: int = min(outputs_ready, int(floor(have / input_per_output)))
	if craftable <= 0:
		return result

	# 4. Consume and produce based on the craftable amount
	var input_used: float = float(craftable) * input_per_output
	result[picked] = -input_used
	result[out_id] = float(craftable)

	# 5. Only subtract the work that was actually done
	work_progress -= float(craftable)
	last_picked_input = picked
	return result

# Virtual hook for dynamic recipes
func _compute_output_id(_picked: StringName) -> StringName:
	return output_item_id

# --------------------------
# Helpers (Candidate picker now uses a minimum amount)
# --------------------------
func _pick_input_candidate(hub_inventory: Dictionary, min_units_needed: float) -> StringName:
	if selection_mode == "by_id":
		var id: StringName = input_item_id
		if id == StringName(): return StringName()
		var have: float = float(hub_inventory.get(id, 0))
		return id if have >= min_units_needed else StringName()

	# by_tags
	if item_db == null: return StringName()

	var candidates: Array[StringName] = []
	var stocks: Dictionary = {}
	for k in hub_inventory.keys():
		var key: StringName = (k if k is StringName else StringName(str(k)))
		var have_stock: float = float(hub_inventory.get(k, 0))
		if have_stock < min_units_needed:
			continue # Skip if it can't even afford one craft
		if _matches_tags(key):
			candidates.append(key)
			stocks[key] = have_stock
	
	if candidates.is_empty(): return StringName()

	match input_pick_strategy:
		"highest_stock":
			var best: StringName = candidates[0]
			for c in candidates:
				if float(stocks[c]) > float(stocks[best]):
					best = c
			return best

		"lowest_price":
			var best_p: float = item_db.price_of(candidates[0])
			var best_id: StringName = candidates[0]
			for c in candidates:
				var p: float = item_db.price_of(c)
				if p < best_p:
					best_p = p
					best_id = c
			return best_id

		_: # "first_match"
			return candidates[0]

func _matches_tags(item_id: StringName) -> bool:
	if required_tags.is_empty(): return true
	if item_db == null: return false
	if tag_match == "all":
		for t in required_tags:
			if not item_db.has_tag(item_id, t): return false
		return true
	else: # "any"
		for t in required_tags:
			if item_db.has_tag(item_id, t): return true
		return false

# --------------------------
# Unchanged Functions
# --------------------------
func tick_economy(_dt: float) -> Dictionary: return {}
func get_population_cap_bonus() -> int: return 0
func get_build_cost_pacs() -> int: return BUILD_COST_PACS_BASE
func get_build_time_ticks() -> int: return BUILD_TIME_TICKS_BASE
func get_upgrade_cost_pacs(from_level: int) -> int:
	var steps: int = max(from_level - 1, 0)
	return int(round(float(UPG_COST_PACS_BASE) * pow(2.0, float(steps))))
func get_upgrade_time_ticks(from_level: int) -> int:
	var steps: int = max(from_level - 1, 0)
	return int(round(float(UPG_TIME_TICKS_BASE) * pow(2.0, float(steps))))
func apply_state(state: Resource) -> void:
	if state == null: return
	if state.has_method("get"):
		if state.get("level") is int: level = max(1, int(state.get("level")))
		if state.get("enabled") is bool: enabled = bool(state.get("enabled"))
