# HubTroopProduction.gd
extends Node
class_name HubTroopProduction

## Manages troop production, upgrades, and spawning for a Hub.
## Implements tier-based upgrade system with pity mechanic for T1 spawns.
## Extracted from Hub.gd to reduce complexity.

var state: HubStates
var economy_manager: HubEconomyManager
var building_manager: HubBuildingManager

var _production_timer: float = 0.0

func setup(s: HubStates, econ_mgr: HubEconomyManager, bldg_mgr: HubBuildingManager) -> void:
	state = s
	economy_manager = econ_mgr
	building_manager = bldg_mgr

func process(dt: float) -> void:
	_production_timer += dt
	
	if _production_timer >= state.troop_production_interval:
		_production_timer -= state.troop_production_interval
		_produce_troops()

func _produce_troops() -> void:
	var troop_db: TroopDatabase = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return
	
	var current_total: int = _count_total_troops()
	var cap: int = building_manager.get_population_cap()
	
	# === STEP 0: Early Exit ===
	if current_total >= cap and _all_troops_are_elite():
		return
	
	var food_met_but_no_t1: bool = false
	
	# === STEP 1: T3 → T4 ===
	# Needs: Food + Infrastructure + Medical + Luxury
	if economy_manager.food_level >= 0.0 and economy_manager.infrastructure_level >= 0.0 and economy_manager.medical_level >= 0.0 and economy_manager.luxury_level >= 0.0:
		var t3_troops: Array[StringName] = _get_troops_of_tier(3)
		if t3_troops.size() > 0:
			var from_id: StringName = t3_troops[0]
			var to_id: StringName = troop_db.get_upgrade_target(from_id)
			if to_id != StringName():
				_upgrade_troop(from_id, to_id)
				current_total = _count_total_troops()
		elif current_total < cap:
			var t3_id: StringName = _get_random_troop_of_tier(troop_db, 3)
			if t3_id != StringName():
				state.troop_stock[t3_id] = state.troop_stock.get(t3_id, 0) + 1
				current_total += 1
	
	# === STEP 2: T2 → T3 ===
	# Needs: Food + Infrastructure
	if economy_manager.food_level >= 0.0 and economy_manager.infrastructure_level >= 0.0:
		var t2_troops: Array[StringName] = _get_troops_of_tier(2)
		if t2_troops.size() > 0:
			var from_id: StringName = t2_troops[0]
			var to_id: StringName = troop_db.get_upgrade_target(from_id)
			if to_id != StringName():
				_upgrade_troop(from_id, to_id)
				current_total = _count_total_troops()
		elif current_total < cap:
			var t2_id: StringName = _get_random_troop_of_tier(troop_db, 2)
			if t2_id != StringName():
				state.troop_stock[t2_id] = state.troop_stock.get(t2_id, 0) + 1
				current_total += 1
	
	# === STEP 3: T1 → T2 ===
	# Needs: Food only
	if economy_manager.food_level >= 0.0:
		var t1_troops: Array[StringName] = _get_troops_of_tier(1)
		if t1_troops.size() > 0:
			var from_id: StringName = t1_troops[0]
			var to_id: StringName = troop_db.get_upgrade_target(from_id)
			if to_id != StringName():
				_upgrade_troop(from_id, to_id)
				current_total = _count_total_troops()
		else:
			food_met_but_no_t1 = true
	
	# === STEP 4: T1 Spawning ===
	var t1_count: int = _count_troops_of_tier(1)
	
	if t1_count == 0:
		if current_total + 2 <= cap:
			_spawn_random_t1_pity(troop_db)
			_spawn_random_t1_pity(troop_db)
			current_total += 2
		elif current_total + 1 <= cap:
			_spawn_random_t1_pity(troop_db)
			current_total += 1
	elif t1_count < 5 and current_total < cap:
		_spawn_random_t1_pity(troop_db)
		current_total += 1
	
	# === STEP 5: Bonus T1 ===
	if food_met_but_no_t1 and current_total < cap:
		_spawn_random_t1_pity(troop_db)

# -------------------------------------------------------------------
# Troop management helpers
# -------------------------------------------------------------------
func _count_total_troops() -> int:
	var total: int = 0
	for count in state.troop_stock.values():
		total += int(count)
	return total

func _all_troops_are_elite() -> bool:
	var troop_db: TroopDatabase = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return false
	for troop_id in state.troop_stock.keys():
		var count: int = int(state.troop_stock[troop_id])
		if count > 0 and troop_db.get_tier(troop_id) < 3:
			return false
	return true

func _get_troops_of_tier(tier: int) -> Array[StringName]:
	var troop_db: TroopDatabase = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return []
	var result: Array[StringName] = []
	for troop_id in state.troop_stock.keys():
		var count: int = int(state.troop_stock[troop_id])
		if count > 0 and troop_db.get_tier(troop_id) == tier:
			result.append(troop_id)
	return result

func _count_troops_of_tier(tier: int) -> int:
	var troop_db: TroopDatabase = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return 0
	var total: int = 0
	for troop_id in state.troop_stock.keys():
		var count: int = int(state.troop_stock[troop_id])
		if count > 0 and troop_db.get_tier(troop_id) == tier:
			total += count
	return total

func _upgrade_troop(from_id: StringName, to_id: StringName) -> void:
	var current: int = int(state.troop_stock.get(from_id, 0))
	if current > 0:
		state.troop_stock[from_id] = current - 1
		if state.troop_stock[from_id] <= 0:
			state.troop_stock.erase(from_id)
		state.troop_stock[to_id] = state.troop_stock.get(to_id, 0) + 1

func _get_random_troop_of_tier(troop_db: TroopDatabase, tier: int) -> StringName:
	var troops: Array[StringName] = troop_db.get_troops_by_tier(tier)
	if troops.size() > 0:
		return troops[randi() % troops.size()]
	return StringName()

func _spawn_random_t1_pity(troop_db: TroopDatabase) -> void:
	var all_archetypes: Array[String] = troop_db.get_all_archetypes()
	
	# Reset pity if all 7 spawned
	if state.archetype_spawn_pity.size() >= 7:
		state.archetype_spawn_pity.clear()
	
	# Find archetypes not yet spawned
	var available: Array[String] = []
	for arch: String in all_archetypes:
		if not state.archetype_spawn_pity.has(arch):
			available.append(arch)
	
	# Pick random from available
	if available.size() > 0:
		var chosen: String = available[randi() % available.size()]
		var t1_id: StringName = troop_db.get_t1_troop_for_archetype(chosen)
		if t1_id != StringName():
			state.troop_stock[t1_id] = state.troop_stock.get(t1_id, 0) + 1
			state.archetype_spawn_pity.append(chosen)
