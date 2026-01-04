# uid://dxt1qidw4mvuo
# Godot 4.5 — Economy engine:
# - Producers → Processors → Food consumption → Infrastructure consumption
# - Returns telemetry for pricing: "produced" and "consumed" per tick (positive magnitudes)
extends RefCounted
class_name HubEconomy

var config: EconomyConfig
var item_db: ItemDB
var _hunger_timer_accum: float = 0.0
var _infra_timer_accum: float = 0.0
var _medical_timer_accum: float = 0.0
var _luxury_timer_accum: float = 0.0

func setup(p_config: EconomyConfig, p_item_db: ItemDB) -> void:
	config = p_config
	item_db = p_item_db

func tick(dt: float, cap: int, int_inv: Dictionary, float_inv: Dictionary, buildings: Array[Node], p_productivity_bonus: float = 0.0, p_efficiency_bonus: float = 0.0) -> Dictionary:
	var result: Dictionary = {
		"delta": {},
		"food_level": 0.0,
		"infrastructure_level": 0.0,
		"medical_level": 0.0,
		"luxury_level": 0.0,
		"consumed": {},
		"produced": {},
	}

	if config == null:
		return result

	var working: Dictionary = InventoryUtil.float_mirror(int_inv, float_inv)
	var total_delta: Dictionary = {}

	# Telemetry dicts (positive magnitudes)
	var telemetry_consumed: Dictionary = {}
	var telemetry_produced: Dictionary = {}

	# -------------------------
	# 1) Producers
	# -------------------------
	for n: Node in buildings:
		if n.is_in_group("producer") and n.has_method("produce_tick") and bool(n.get("enabled")):
			var d: Dictionary = (n.call("produce_tick", p_productivity_bonus) as Dictionary)
			InventoryUtil.merge_delta(total_delta, d)
			for k in d.keys():
				var id: StringName = (k if k is StringName else StringName(str(k)))
				var v: float = float(d[k])
				working[id] = float(working.get(id, 0.0)) + v
				if v > 0.0:
					_accum(telemetry_produced, id, v)

	# -------------------------
	# 2) Processors
	# -------------------------
	for n: Node in buildings:
		if n.is_in_group("processor") and n.has_method("refine_tick") and bool(n.get("enabled")):
			var d2: Dictionary = (n.call("refine_tick", working, p_efficiency_bonus) as Dictionary)
			InventoryUtil.merge_delta(total_delta, d2)
			for k in d2.keys():
				var id2: StringName = (k if k is StringName else StringName(str(k)))
				var v2: float = float(d2[k])
				working[id2] = float(working.get(id2, 0.0)) + v2
				if v2 > 0.0:
					_accum(telemetry_produced, id2, v2)
				elif v2 < 0.0:
					_accum(telemetry_consumed, id2, -v2) # store magnitude

	# -------------------------
	# 3) Food consumption (cadence)
	# -------------------------
	if item_db != null:
		var consume_total: Dictionary = _update_consumption(dt, cap, working)
		InventoryUtil.merge_delta(total_delta, consume_total)
		for k in consume_total.keys():
			var idc: StringName = (k if k is StringName else StringName(str(k)))
			var vc: float = float(consume_total[k]) # negative
			working[idc] = float(working.get(idc, 0.0)) + vc
			if vc < 0.0:
				_accum(telemetry_consumed, idc, -vc)

	# -------------------------
	# 4) Infrastructure consumption (cadence)
	# -------------------------
	if item_db != null:
		var infra_total: Dictionary = _update_infrastructure_consumption(dt, buildings, working)
		InventoryUtil.merge_delta(total_delta, infra_total)
		for k in infra_total.keys():
			var idk: StringName = (k if k is StringName else StringName(str(k)))
			var vk: float = float(infra_total[k]) # negative
			working[idk] = float(working.get(idk, 0.0)) + vk
			if vk < 0.0:
				_accum(telemetry_consumed, idk, -vk)

	# -------------------------
	# 5) Medical consumption (cadence)
	# -------------------------
	if item_db != null:
		var medical_total: Dictionary = _update_medical_consumption(dt, cap, working)
		InventoryUtil.merge_delta(total_delta, medical_total)
		for k in medical_total.keys():
			var idm: StringName = (k if k is StringName else StringName(str(k)))
			var vm: float = float(medical_total[k]) # negative
			working[idm] = float(working.get(idm, 0.0)) + vm
			if vm < 0.0:
				_accum(telemetry_consumed, idm, -vm)

	# -------------------------
	# 6) Luxury consumption (cadence)
	# -------------------------
	if item_db != null:
		var luxury_total: Dictionary = _update_luxury_consumption(dt, cap, working)
		InventoryUtil.merge_delta(total_delta, luxury_total)
		for k in luxury_total.keys():
			var idl: StringName = (k if k is StringName else StringName(str(k)))
			var vl: float = float(luxury_total[k]) # negative
			working[idl] = float(working.get(idl, 0.0)) + vl
			if vl < 0.0:
				_accum(telemetry_consumed, idl, -vl)

	# -------------------------
	# 7) Snapshots
	# -------------------------
	var food_level_now: float = _compute_food_level_snapshot(cap, working)
	var infrastructure_level_now: float = _compute_infrastructure_level_snapshot(buildings, working)
	var medical_level_now: float = _compute_medical_level_snapshot(cap, working)
	var luxury_level_now: float = _compute_luxury_level_snapshot(cap, working)

	# Package results
	result["delta"] = total_delta
	result["food_level"] = food_level_now
	result["infrastructure_level"] = infrastructure_level_now
	result["medical_level"] = medical_level_now
	result["luxury_level"] = luxury_level_now
	result["consumed"] = telemetry_consumed
	result["produced"] = telemetry_produced
	
	# New Telemetry for Starvation Calculation
	# Calculate total servings available in current stock (after tick)
	result["food_stock_servings"] = _servings_available_in(working)
	
	return result

# Small helper: accumulate positive magnitudes
func _accum(dst: Dictionary, id: StringName, amt: float) -> void:
	dst[id] = (dst.get(id, 0.0) as float) + amt

# ============================================================
# Food Consumption (cadence + one-tick eat)
# ============================================================
func _update_consumption(dt: float, cap: int, working: Dictionary) -> Dictionary:
	if item_db == null: return {}
	var needed: float = (float(cap) / 10.0) * config.servings_per_10_pops
	var tiers: Array = [
		{tag = &"meal", cost = config.cost_units_meal},
		{tag = &"processed", cost = config.cost_units_processed},
		{tag = StringName(), cost = config.cost_units_ingredient}
	]
	var res: Dictionary = _process_consumption_category(dt, _hunger_timer_accum, config.servings_tick_interval, needed, &"food", tiers, working)
	_hunger_timer_accum = res.new_timer
	return res.delta

func _compute_food_level_snapshot(cap: int, working: Dictionary) -> float:
	if item_db == null: return 0.0
	var need: float = (float(cap) / 10.0) * config.servings_per_10_pops
	var tiers: Array = [
		{tag = &"meal", cost = config.cost_units_meal},
		{tag = &"processed", cost = config.cost_units_processed},
		{tag = StringName(), cost = config.cost_units_ingredient}
	]
	var have: float = _generic_units_available(working, &"food", tiers)
	return have - need

func _servings_available_in(working: Dictionary) -> float:
	var tiers: Array = [
		{tag = &"meal", cost = config.cost_units_meal},
		{tag = &"processed", cost = config.cost_units_processed},
		{tag = StringName(), cost = config.cost_units_ingredient}
	]
	return _generic_units_available(working, &"food", tiers)

# ============================================================
# Infrastructure Consumption (cadence + one-tick consume)
# ============================================================
func _update_infrastructure_consumption(dt: float, buildings: Array[Node], working: Dictionary) -> Dictionary:
	if item_db == null: return {}
	var needed: float = _compute_infrastructure_units_needed(buildings)
	var tiers: Array = [
		{tag = &"component", cost = config.infra_cost_component},
		{tag = &"processed", cost = config.infra_cost_processed},
		{tag = StringName(), cost = config.infra_cost_ingredient}
	]
	var res: Dictionary = _process_consumption_category(dt, _infra_timer_accum, config.infra_tick_interval, needed, &"material", tiers, working)
	_infra_timer_accum = res.new_timer
	return res.delta

func _compute_infrastructure_units_needed(buildings: Array[Node]) -> float:
	var total_building_levels: int = 0
	for n: Node in buildings:
		var lv_any = n.get("level")
		if lv_any is int:
			total_building_levels += int(lv_any)
	var need: float = config.infra_units_per_hub + (config.infra_units_per_building_level * float(total_building_levels))
	return need

func _compute_infrastructure_level_snapshot(buildings: Array[Node], working: Dictionary) -> float:
	if item_db == null: return 0.0
	var need: float = _compute_infrastructure_units_needed(buildings)
	var tiers: Array = [
		{tag = &"component", cost = config.infra_cost_component},
		{tag = &"processed", cost = config.infra_cost_processed},
		{tag = StringName(), cost = config.infra_cost_ingredient}
	]
	var have: float = _generic_units_available(working, &"material", tiers)
	return have - need

func _infrastructure_units_available_in(working: Dictionary) -> float:
	var tiers: Array = [
		{tag = &"component", cost = config.infra_cost_component},
		{tag = &"processed", cost = config.infra_cost_processed},
		{tag = StringName(), cost = config.infra_cost_ingredient}
	]
	return _generic_units_available(working, &"material", tiers)

# ============================================================
# Medical Consumption (cadence + one-tick consume)
# ============================================================
func _update_medical_consumption(dt: float, cap: int, working: Dictionary) -> Dictionary:
	if item_db == null: return {}
	var needed: float = (float(cap) / 10.0) * config.medical_units_per_10_pops
	var tiers: Array = [
		{tag = &"medicine", cost = config.medical_cost_medicine},
		{tag = &"processed", cost = config.medical_cost_processed},
		{tag = StringName(), cost = config.medical_cost_ingredient}
	]
	var res: Dictionary = _process_consumption_category(dt, _medical_timer_accum, config.medical_tick_interval, needed, &"medical", tiers, working)
	_medical_timer_accum = res.new_timer
	return res.delta

func _compute_medical_level_snapshot(cap: int, working: Dictionary) -> float:
	if item_db == null: return 0.0
	var need: float = (float(cap) / 10.0) * config.medical_units_per_10_pops
	var tiers: Array = [
		{tag = &"medicine", cost = config.medical_cost_medicine},
		{tag = &"processed", cost = config.medical_cost_processed},
		{tag = StringName(), cost = config.medical_cost_ingredient}
	]
	var have: float = _generic_units_available(working, &"medical", tiers)
	return have - need

func _medical_units_available_in(working: Dictionary) -> float:
	var tiers: Array = [
		{tag = &"medicine", cost = config.medical_cost_medicine},
		{tag = &"processed", cost = config.medical_cost_processed},
		{tag = StringName(), cost = config.medical_cost_ingredient}
	]
	return _generic_units_available(working, &"medical", tiers)

# ============================================================
# Luxury Consumption (cadence + one-tick consume)
# ============================================================
func _update_luxury_consumption(dt: float, cap: int, working: Dictionary) -> Dictionary:
	if item_db == null: return {}
	var needed: float = (float(cap) / 10.0) * config.luxury_units_per_10_pops
	var tiers: Array = [
		{tag = &"luxury_good", cost = config.luxury_cost_luxury_good},
		{tag = &"processed", cost = config.luxury_cost_processed},
		{tag = StringName(), cost = config.luxury_cost_ingredient}
	]
	var res: Dictionary = _process_consumption_category(dt, _luxury_timer_accum, config.luxury_tick_interval, needed, &"luxury", tiers, working)
	_luxury_timer_accum = res.new_timer
	return res.delta

func _compute_luxury_level_snapshot(cap: int, working: Dictionary) -> float:
	if item_db == null: return 0.0
	var need: float = (float(cap) / 10.0) * config.luxury_units_per_10_pops
	var tiers: Array = [
		{tag = &"luxury_good", cost = config.luxury_cost_luxury_good},
		{tag = &"processed", cost = config.luxury_cost_processed},
		{tag = StringName(), cost = config.luxury_cost_ingredient}
	]
	var have: float = _generic_units_available(working, &"luxury", tiers)
	return have - need

func _luxury_units_available_in(working: Dictionary) -> float:
	var tiers: Array = [
		{tag = &"luxury_good", cost = config.luxury_cost_luxury_good},
		{tag = &"processed", cost = config.luxury_cost_processed},
		{tag = StringName(), cost = config.luxury_cost_ingredient}
	]
	return _generic_units_available(working, &"luxury", tiers)

# ============================================================
# GENERIC HELPERS
# ============================================================

func _consume_units_from_items(items: Array, units_needed: float, working: Dictionary) -> Dictionary:
	var d: Dictionary = {}
	var remain: float = units_needed
	for id: StringName in items:
		if remain <= 0.0:
			break
		var avail: float = float(working.get(id, 0.0))
		if avail <= 0.0:
			continue
		var take: float = min(avail, remain)
		d[id] = (d.get(id, 0.0) as float) - take
		remain -= take
	return d

func _process_consumption_category(dt: float, timer: float, interval: float, needed: float, main_tag: StringName, tiers: Array, working: Dictionary) -> Dictionary:
	timer += dt
	var total_delta: Dictionary = {}
	
	while timer >= interval:
		timer -= interval
		if needed > 0.0:
			var d: Dictionary = _consume_generic_tick(needed, main_tag, tiers, working)
			InventoryUtil.merge_delta(total_delta, d)
			# Apply immediately to working so next tick sees updated stock
			for k in d.keys():
				var id: StringName = (k if k is StringName else StringName(str(k)))
				working[id] = float(working.get(id, 0.0)) + float(d[k])
				
	return {"delta": total_delta, "new_timer": timer}

func _consume_generic_tick(units_needed: float, main_tag: StringName, tiers: Array, working: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	
	# Classify items into tiers
	var buckets: Array = []
	buckets.resize(tiers.size())
	for i in range(buckets.size()): buckets[i] = []
	
	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0: continue
		if not item_db.has_tag(id, main_tag): continue
		
		# Assign to first matching tier
		for i in range(tiers.size()):
			var t_tag: StringName = tiers[i].tag
			# Empty tag acts as "else" / catch-all
			if t_tag == StringName() or item_db.has_tag(id, t_tag):
				buckets[i].append(id)
				break

	var remain: float = units_needed
	for i in range(tiers.size()):
		if remain <= 0.0: break
		var items: Array = buckets[i]
		if items.size() > 0:
			var cost: float = tiers[i].cost
			var units_for_tier: float = remain * cost
			var d_tier: Dictionary = _consume_units_from_items(items, units_for_tier, working)
			InventoryUtil.merge_delta(out, d_tier)
			
			# Calc taken
			var taken_units: float = 0.0
			for v in d_tier.values():
				if v < 0: taken_units += -float(v)
			remain -= taken_units / max(0.0001, cost)
			
	return out

func _generic_units_available(working: Dictionary, main_tag: StringName, tiers: Array) -> float:
	if item_db == null: return 0.0
	var total: float = 0.0
	
	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0: continue
		if not item_db.has_tag(id, main_tag): continue
		
		for i in range(tiers.size()):
			var t_tag: StringName = tiers[i].tag
			if t_tag == StringName() or item_db.has_tag(id, t_tag):
				total += units / max(0.0001, tiers[i].cost)
				break
	return total
