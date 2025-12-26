# HubEconomyManager.gd
extends Node
class_name HubEconomyManager

## Manages economy simulation for a Hub.
## Handles tick processing, inventory deltas, and resource tracking.
## Extracted from Hub.gd to reduce complexity.

signal economy_tick_processed(results: Dictionary)

var state: HubStates
var item_db: ItemDB
var economy_config: EconomyConfig
var building_manager: HubBuildingManager

# Internal
var _engine: HubEconomy = HubEconomy.new()
var _inventory_float: Dictionary = {}

# Resource levels (exported for visibility)
var food_level: float = 0.0
var infrastructure_level: float = 0.0
var medical_level: float = 0.0
var luxury_level: float = 0.0

func setup(s: HubStates, db: ItemDB, config: EconomyConfig, bldg_mgr: HubBuildingManager) -> void:
	state = s
	item_db = db
	economy_config = config
	building_manager = bldg_mgr
	_refresh_engine()

func process_tick(dt: float, governor_id: StringName) -> Dictionary:
	var buildings: Array[Node] = building_manager.get_buildings()
	var cap: int = building_manager.get_population_cap()
	var bonuses: Dictionary = _calc_governor_bonuses(governor_id)
	
	var r: Dictionary = _engine.tick(
		dt, cap, state.inventory, _inventory_float, buildings,
		bonuses.get("productivity", 0.0),
		bonuses.get("efficiency", 0.0)
	)
	
	_apply_delta((r.get("delta", {}) as Dictionary))
	_update_resource_levels(r)
	
	economy_tick_processed.emit(r)
	return r

func apply_inventory_delta(delta: Dictionary) -> void:
	_apply_delta(delta)

func get_current_amount(item_id: StringName) -> float:
	return InventoryUtil.read_amount(item_id, state.inventory, _inventory_float)

func _apply_delta(delta: Dictionary) -> void:
	for k in delta.keys():
		var key: StringName = (k if k is StringName else StringName(str(k)))
		var curf: float = float(_inventory_float.get(key, float(state.inventory.get(key, 0))))
		curf += float(delta[k])
		_inventory_float[key] = curf
		state.inventory[key] = int(floor(curf))

func _update_resource_levels(results: Dictionary) -> void:
	food_level = float(results.get("food_level", 0.0))
	infrastructure_level = float(results.get("infrastructure_level", 0.0))
	medical_level = float(results.get("medical_level", 0.0))
	luxury_level = float(results.get("luxury_level", 0.0))

func _calc_governor_bonuses(governor_id: StringName) -> Dictionary:
	var governor_productivity_bonus: float = 0.0
	var governor_efficiency_bonus: float = 0.0
	
	if governor_id != StringName():
		var pm: Node = get_node_or_null("/root/ProgressionManager")
		if pm != null and pm.has_method("get_character_sheet"):
			var governor_sheet: CharacterSheet = pm.get_character_sheet(governor_id)
			if governor_sheet != null:
				# QualityTools skill boosts producer output
				var quality_rank: int = governor_sheet.get_skill_rank(&"quality_tools")
				if quality_rank > 0:
					governor_productivity_bonus = float(quality_rank) * 0.02
				
				# IndustrialPlanning skill boosts processor efficiency
				var planning_rank: int = governor_sheet.get_skill_rank(&"industrial_planning")
				if planning_rank > 0:
					governor_efficiency_bonus = float(planning_rank) * 0.03
	
	return {
		"productivity": governor_productivity_bonus,
		"efficiency": governor_efficiency_bonus
	}

func _refresh_engine() -> void:
	# Safe to call anytime; engine will accept nulls
	_engine.setup(economy_config, item_db)
	# Keep processors in sync with the DB if slots already exist
	if building_manager != null:
		building_manager.inject_item_db()

func refresh_config() -> void:
	_refresh_engine()

func refresh_item_db() -> void:
	_refresh_engine()
