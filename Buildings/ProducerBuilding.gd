extends Node2D
class_name ProducerBuilding

# ----- Assigned per building instance -----
@export var product_item_id: StringName = StringName()  # REQUIRED at placement; empty = produces nothing

# ----- Core rates (per Timekeeper tick) -----
@export var base_amount_per_tick: float = 0.5           # level 1 output per TK tick
@export var base_pop_cap_bonus: int = 100               # level 1 pop-cap bonus

# ----- State -----
@export var level: int = 1
@export var enabled: bool = true

# ----- Economics (ticks = Timekeeper ticks) -----
const BUILD_COST_PACS_BASE: int  = 100
const BUILD_TIME_TICKS_BASE: int = 100
const UPG_COST_PACS_BASE: int    = 200   # cost for 1->2
const UPG_TIME_TICKS_BASE: int   = 200   # time  for 1->2

# ----- Scaling -----
const PER_LEVEL_MULT: float = 1.5        # +50% per level to BOTH production and pop-cap

func _ready() -> void:
	add_to_group("producer")
	level = max(1, level)
	if product_item_id == StringName():
		push_warning("Producer '%s' has no product_item_id set; it will produce nothing." % name)

# Hub calls this ONCE per Timekeeper tick; no buffers, no side-effects.
func produce_tick(governor_bonus: float = 0.0) -> Dictionary:
	if not enabled or product_item_id == StringName():
		return {}
	var mult: float = pow(PER_LEVEL_MULT, float(max(level - 1, 0)))
	var amt: float = base_amount_per_tick * mult * (1.0 + governor_bonus)
	return { product_item_id: amt}

# Compatibility with any existing Hub loop that calls tick_economy(dt)
func tick_economy(_dt: float) -> Dictionary:
	return produce_tick()

func get_population_cap_bonus() -> int:
	if not enabled:
		return 0
	var mult: float = pow(PER_LEVEL_MULT, float(max(level - 1, 0)))
	return int(round(float(base_pop_cap_bonus) * mult))

# Optional: inject state from your slot resource (BuildSlotState / ProducerState).
# NOTE: all locals are explicitly typed (Variant) so there is NO inference warning.
func apply_state(state: Resource) -> void:
	if state == null:
		return
	if state.has_method("get"):
		var pid_any: Variant = state.get("product_item_id")
		if pid_any is StringName:
			product_item_id = pid_any
		elif pid_any is String:
			product_item_id = StringName(pid_any)
		elif pid_any != null:
			product_item_id = StringName(str(pid_any))

		var lvl_any: Variant = state.get("level")
		if lvl_any is int:
			level = lvl_any
		elif lvl_any is float:
			level = int(lvl_any)

		var en_any: Variant = state.get("enabled")
		if en_any is bool:
			enabled = en_any
		elif en_any != null:
			enabled = bool(en_any)

	level = max(1, level)

# Build/upgrade helpers (deterministic doubling per level)
func get_build_cost_pacs() -> int:
	return BUILD_COST_PACS_BASE

func get_build_time_ticks() -> int:
	return BUILD_TIME_TICKS_BASE

# Cost/time to upgrade FROM `from_level` TO `from_level + 1`:
# 1->2 = 200/200, 2->3 = 400/400, 3->4 = 800/800, ...
func get_upgrade_cost_pacs(from_level: int) -> int:
	return int(round(float(UPG_COST_PACS_BASE) * pow(2.0, float(max(from_level - 1, 0)))))

func get_upgrade_time_ticks(from_level: int) -> int:
	return int(round(float(UPG_TIME_TICKS_BASE) * pow(2.0, float(max(from_level - 1, 0)))))
