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
	return result

# Small helper: accumulate positive magnitudes
func _accum(dst: Dictionary, id: StringName, amt: float) -> void:
	dst[id] = (dst.get(id, 0.0) as float) + amt

# ============================================================
# Food Consumption (cadence + one-tick eat)
# ============================================================
func _update_consumption(dt: float, cap: int, working: Dictionary) -> Dictionary:
	_hunger_timer_accum += dt
	var total: Dictionary = {}
	while _hunger_timer_accum >= config.servings_tick_interval:
		_hunger_timer_accum -= config.servings_tick_interval
		var d: Dictionary = _consume_one_servings_tick(cap, working)
		InventoryUtil.merge_delta(total, d)
		for k in d.keys():
			var id: StringName = (k if k is StringName else StringName(str(k)))
			working[id] = float(working.get(id, 0.0)) + float(d[k])
	return total

func _consume_one_servings_tick(cap: int, working: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if item_db == null:
		return out

	var servings_needed: float = (float(cap) / 10.0) * config.servings_per_10_pops
	if servings_needed <= 0.0:
		return out

	var meal_items: Array[StringName] = []
	var processed_items: Array[StringName] = []
	var ingredient_items: Array[StringName] = []

	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0:
			continue
		if not item_db.has_tag(id, &"food"):
			continue
		if item_db.has_tag(id, &"meal"):
			meal_items.append(id)
		elif item_db.has_tag(id, &"processed"):
			processed_items.append(id)
		else:
			ingredient_items.append(id)

	var remain_servings: float = servings_needed

	if remain_servings > 0.0 and meal_items.size() > 0:
		var units_meal: float = remain_servings * config.cost_units_meal
		var d_meal: Dictionary = _consume_units_from_items(meal_items, units_meal, working)
		InventoryUtil.merge_delta(out, d_meal)
		remain_servings -= _units_to_servings_taken(d_meal, config.cost_units_meal)

	if remain_servings > 0.0 and processed_items.size() > 0:
		var units_proc: float = remain_servings * config.cost_units_processed
		var d_proc: Dictionary = _consume_units_from_items(processed_items, units_proc, working)
		InventoryUtil.merge_delta(out, d_proc)
		remain_servings -= _units_to_servings_taken(d_proc, config.cost_units_processed)

	if remain_servings > 0.0 and ingredient_items.size() > 0:
		var units_ing: float = remain_servings * config.cost_units_ingredient
		var d_ing: Dictionary = _consume_units_from_items(ingredient_items, units_ing, working)
		InventoryUtil.merge_delta(out, d_ing)
		remain_servings -= _units_to_servings_taken(d_ing, config.cost_units_ingredient)

	return out

func _consume_units_from_items(items: Array[StringName], units_needed: float, working: Dictionary) -> Dictionary:
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

# ------------------------------------------------------------
# Food-level snapshot (servings)
# ------------------------------------------------------------
func _compute_food_level_snapshot(cap: int, working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var need: float = (float(cap) / 10.0) * config.servings_per_10_pops
	var have: float = _servings_available_in(working)
	return have - need

func _servings_available_in(working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var servings: float = 0.0
	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0:
			continue
		if not item_db.has_tag(id, &"food"):
			continue
		if item_db.has_tag(id, &"meal"):
			servings += units / max(0.0001, config.cost_units_meal)
		elif item_db.has_tag(id, &"processed"):
			servings += units / max(0.0001, config.cost_units_processed)
		else:
			servings += units / max(0.0001, config.cost_units_ingredient)
	return servings

func _units_to_servings_taken(d: Dictionary, units_per_serving: float) -> float:
	var units_total: float = 0.0
	for v in d.values():
		if float(v) < 0.0:
			units_total += -float(v)
	return units_total / max(0.0001, units_per_serving)

# ============================================================
# Infrastructure Consumption (cadence + one-tick consume)
# ============================================================
func _update_infrastructure_consumption(dt: float, buildings: Array[Node], working: Dictionary) -> Dictionary:
	_infra_timer_accum += dt
	var total: Dictionary = {}
	while _infra_timer_accum >= config.infra_tick_interval:
		_infra_timer_accum -= config.infra_tick_interval
		var d: Dictionary = _consume_one_infrastructure_tick(buildings, working)
		InventoryUtil.merge_delta(total, d)
		for k in d.keys():
			var id: StringName = (k if k is StringName else StringName(str(k)))
			working[id] = float(working.get(id, 0.0)) + float(d[k])
	return total

func _consume_one_infrastructure_tick(buildings: Array[Node], working: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if item_db == null:
		return out

	var units_needed: float = _compute_infrastructure_units_needed(buildings)
	if units_needed <= 0.0:
		return out

	var component_items: Array[StringName] = []
	var processed_items: Array[StringName] = []
	var ingredient_items: Array[StringName] = []

	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0:
			continue
		if not item_db.has_tag(id, &"material"):
			continue
		if item_db.has_tag(id, &"component"):
			component_items.append(id)
		elif item_db.has_tag(id, &"processed"):
			processed_items.append(id)
		else:
			ingredient_items.append(id)

	var remain_units: float = units_needed

	# Component → Processed → Ingredient
	if remain_units > 0.0 and component_items.size() > 0:
		var units_comp: float = remain_units * config.infra_cost_component
		var d_comp: Dictionary = _consume_units_from_items(component_items, units_comp, working)
		InventoryUtil.merge_delta(out, d_comp)
		remain_units -= _units_to_infrastructure_taken(d_comp, config.infra_cost_component)

	if remain_units > 0.0 and processed_items.size() > 0:
		var units_proc: float = remain_units * config.infra_cost_processed
		var d_proc: Dictionary = _consume_units_from_items(processed_items, units_proc, working)
		InventoryUtil.merge_delta(out, d_proc)
		remain_units -= _units_to_infrastructure_taken(d_proc, config.infra_cost_processed)

	if remain_units > 0.0 and ingredient_items.size() > 0:
		var units_ing: float = remain_units * config.infra_cost_ingredient
		var d_ing: Dictionary = _consume_units_from_items(ingredient_items, units_ing, working)
		InventoryUtil.merge_delta(out, d_ing)
		remain_units -= _units_to_infrastructure_taken(d_ing, config.infra_cost_ingredient)

	return out

func _compute_infrastructure_units_needed(buildings: Array[Node]) -> float:
	var total_building_levels: int = 0
	for n: Node in buildings:
		var lv_any = n.get("level")
		if lv_any is int:
			total_building_levels += int(lv_any)
	var need: float = config.infra_units_per_hub + (config.infra_units_per_building_level * float(total_building_levels))
	return need

# ------------------------------------------------------------
# Infrastructure-level snapshot (units)
# ------------------------------------------------------------
func _compute_infrastructure_level_snapshot(buildings: Array[Node], working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var need: float = _compute_infrastructure_units_needed(buildings)
	var have: float = _infrastructure_units_available_in(working)
	return have - need

func _infrastructure_units_available_in(working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var units: float = 0.0
	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var amount: float = float(working.get(k, 0.0))
		if amount <= 0.0:
			continue
		if not item_db.has_tag(id, &"material"):
			continue
		if item_db.has_tag(id, &"component"):
			units += amount / max(0.0001, config.infra_cost_component)
		elif item_db.has_tag(id, &"processed"):
			units += amount / max(0.0001, config.infra_cost_processed)
		else:
			units += amount / max(0.0001, config.infra_cost_ingredient)
	return units

func _units_to_infrastructure_taken(d: Dictionary, units_per_point: float) -> float:
	var units_total: float = 0.0
	for v in d.values():
		if float(v) < 0.0:
			units_total += -float(v)
	return units_total / max(0.0001, units_per_point)

# ============================================================
# Medical Consumption (cadence + one-tick consume)
# ============================================================
func _update_medical_consumption(dt: float, cap: int, working: Dictionary) -> Dictionary:
	_medical_timer_accum += dt
	var total: Dictionary = {}
	while _medical_timer_accum >= config.medical_tick_interval:
		_medical_timer_accum -= config.medical_tick_interval
		var d: Dictionary = _consume_one_medical_tick(cap, working)
		InventoryUtil.merge_delta(total, d)
		for k in d.keys():
			var id: StringName = (k if k is StringName else StringName(str(k)))
			working[id] = float(working.get(id, 0.0)) + float(d[k])
	return total

func _consume_one_medical_tick(cap: int, working: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if item_db == null:
		return out

	var units_needed: float = (float(cap) / 10.0) * config.medical_units_per_10_pops
	if units_needed <= 0.0:
		return out

	var medicine_items: Array[StringName] = []
	var processed_items: Array[StringName] = []
	var ingredient_items: Array[StringName] = []

	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0:
			continue
		if not item_db.has_tag(id, &"medical"):
			continue
		if item_db.has_tag(id, &"medicine"):
			medicine_items.append(id)
		elif item_db.has_tag(id, &"processed"):
			processed_items.append(id)
		else:
			ingredient_items.append(id)

	var remain_units: float = units_needed

	# Medicine → Processed → Ingredient
	if remain_units > 0.0 and medicine_items.size() > 0:
		var units_med: float = remain_units * config.medical_cost_medicine
		var d_med: Dictionary = _consume_units_from_items(medicine_items, units_med, working)
		InventoryUtil.merge_delta(out, d_med)
		remain_units -= _units_to_medical_taken(d_med, config.medical_cost_medicine)

	if remain_units > 0.0 and processed_items.size() > 0:
		var units_proc: float = remain_units * config.medical_cost_processed
		var d_proc: Dictionary = _consume_units_from_items(processed_items, units_proc, working)
		InventoryUtil.merge_delta(out, d_proc)
		remain_units -= _units_to_medical_taken(d_proc, config.medical_cost_processed)

	if remain_units > 0.0 and ingredient_items.size() > 0:
		var units_ing: float = remain_units * config.medical_cost_ingredient
		var d_ing: Dictionary = _consume_units_from_items(ingredient_items, units_ing, working)
		InventoryUtil.merge_delta(out, d_ing)
		remain_units -= _units_to_medical_taken(d_ing, config.medical_cost_ingredient)

	return out

# ------------------------------------------------------------
# Medical-level snapshot (units)
# ------------------------------------------------------------
func _compute_medical_level_snapshot(cap: int, working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var need: float = (float(cap) / 10.0) * config.medical_units_per_10_pops
	var have: float = _medical_units_available_in(working)
	return have - need

func _medical_units_available_in(working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var units: float = 0.0
	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var amount: float = float(working.get(k, 0.0))
		if amount <= 0.0:
			continue
		if not item_db.has_tag(id, &"medical"):
			continue
		if item_db.has_tag(id, &"medicine"):
			units += amount / max(0.0001, config.medical_cost_medicine)
		elif item_db.has_tag(id, &"processed"):
			units += amount / max(0.0001, config.medical_cost_processed)
		else:
			units += amount / max(0.0001, config.medical_cost_ingredient)
	return units

func _units_to_medical_taken(d: Dictionary, units_per_point: float) -> float:
	var units_total: float = 0.0
	for v in d.values():
		if float(v) < 0.0:
			units_total += -float(v)
	return units_total / max(0.0001, units_per_point)

# ============================================================
# Luxury Consumption (cadence + one-tick consume)
# ============================================================
func _update_luxury_consumption(dt: float, cap: int, working: Dictionary) -> Dictionary:
	_luxury_timer_accum += dt
	var total: Dictionary = {}
	while _luxury_timer_accum >= config.luxury_tick_interval:
		_luxury_timer_accum -= config.luxury_tick_interval
		var d: Dictionary = _consume_one_luxury_tick(cap, working)
		InventoryUtil.merge_delta(total, d)
		for k in d.keys():
			var id: StringName = (k if k is StringName else StringName(str(k)))
			working[id] = float(working.get(id, 0.0)) + float(d[k])
	return total

func _consume_one_luxury_tick(cap: int, working: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if item_db == null:
		return out

	var units_needed: float = (float(cap) / 10.0) * config.luxury_units_per_10_pops
	if units_needed <= 0.0:
		return out

	var luxury_good_items: Array[StringName] = []
	var processed_items: Array[StringName] = []
	var ingredient_items: Array[StringName] = []

	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var units: float = float(working.get(k, 0.0))
		if units <= 0.0:
			continue
		if not item_db.has_tag(id, &"luxury"):
			continue
		if item_db.has_tag(id, &"luxury_good"):
			luxury_good_items.append(id)
		elif item_db.has_tag(id, &"processed"):
			processed_items.append(id)
		else:
			ingredient_items.append(id)

	var remain_units: float = units_needed

	# Luxury Good → Processed → Ingredient
	if remain_units > 0.0 and luxury_good_items.size() > 0:
		var units_lux: float = remain_units * config.luxury_cost_luxury_good
		var d_lux: Dictionary = _consume_units_from_items(luxury_good_items, units_lux, working)
		InventoryUtil.merge_delta(out, d_lux)
		remain_units -= _units_to_luxury_taken(d_lux, config.luxury_cost_luxury_good)

	if remain_units > 0.0 and processed_items.size() > 0:
		var units_proc: float = remain_units * config.luxury_cost_processed
		var d_proc: Dictionary = _consume_units_from_items(processed_items, units_proc, working)
		InventoryUtil.merge_delta(out, d_proc)
		remain_units -= _units_to_luxury_taken(d_proc, config.luxury_cost_processed)

	if remain_units > 0.0 and ingredient_items.size() > 0:
		var units_ing: float = remain_units * config.luxury_cost_ingredient
		var d_ing: Dictionary = _consume_units_from_items(ingredient_items, units_ing, working)
		InventoryUtil.merge_delta(out, d_ing)
		remain_units -= _units_to_luxury_taken(d_ing, config.luxury_cost_ingredient)

	return out

# ------------------------------------------------------------
# Luxury-level snapshot (units)
# ------------------------------------------------------------
func _compute_luxury_level_snapshot(cap: int, working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var need: float = (float(cap) / 10.0) * config.luxury_units_per_10_pops
	var have: float = _luxury_units_available_in(working)
	return have - need

func _luxury_units_available_in(working: Dictionary) -> float:
	if item_db == null:
		return 0.0
	var units: float = 0.0
	for k in working.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var amount: float = float(working.get(k, 0.0))
		if amount <= 0.0:
			continue
		if not item_db.has_tag(id, &"luxury"):
			continue
		if item_db.has_tag(id, &"luxury_good"):
			units += amount / max(0.0001, config.luxury_cost_luxury_good)
		elif item_db.has_tag(id, &"processed"):
			units += amount / max(0.0001, config.luxury_cost_processed)
		else:
			units += amount / max(0.0001, config.luxury_cost_ingredient)
	return units

func _units_to_luxury_taken(d: Dictionary, units_per_point: float) -> float:
	var units_total: float = 0.0
	for v in d.values():
		if float(v) < 0.0:
			units_total += -float(v)
	return units_total / max(0.0001, units_per_point)
