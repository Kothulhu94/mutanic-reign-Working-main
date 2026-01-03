# HubTradingSystem.gd
extends Node
class_name HubTradingSystem

## Manages dynamic pricing and trading API for caravans.
## Uses EMA-based consumption tracking for supply/demand pricing.
## Extracted from Hub.gd to reduce complexity.

var state: HubStates
var item_db: ItemDB
var economy_manager: HubEconomyManager

# Pricing state
var item_prices: Dictionary = {}
var _consumption_ema: Dictionary = {}
var _last_consumed: Dictionary = {}
var _last_produced: Dictionary = {}
const PRICE_ALPHA: float = 0.2

func setup(s: HubStates, db: ItemDB, econ_mgr: HubEconomyManager) -> void:
	state = s
	item_db = db
	economy_manager = econ_mgr
	economy_manager.economy_tick_processed.connect(_on_economy_tick)

func get_item_price(item_id: StringName) -> float:
	# Return current dynamic price, or calculate on-demand if not tracked
	if item_prices.has(item_id):
		return float(item_prices[item_id])
	# Calculate price on the fly if item exists but not tracked yet
	var stock: float = economy_manager.get_current_amount(item_id)
	var rate: float = _estimate_consumption_rate(item_id)
	return _calculate_item_price(item_id, stock, rate)

func buy_from_hub(item_id: StringName, amount: int, _caravan_state: CaravanState) -> bool:
	# Caravan buys from hub (hub loses inventory, caravan gains)
	var available: int = state.inventory.get(item_id, 0)
	if available < amount:
		return false
	
	# Remove from hub inventory via economy manager
	var delta: Dictionary = {item_id: - amount}
	economy_manager.apply_inventory_delta(delta)
	
	# Update telemetry: buying from hub counts as consumption (demand)
	_last_consumed[item_id] = _last_consumed.get(item_id, 0.0) + float(amount)
	_ingest_consumption_telemetry({item_id: float(amount)})
	
	return true

func sell_to_hub(item_id: StringName, amount: int, _caravan_state: CaravanState) -> bool:
	# Caravan sells to hub (hub gains inventory, caravan loses)
	# Add to hub inventory
	var delta: Dictionary = {item_id: amount}
	economy_manager.apply_inventory_delta(delta)
	
	# Update telemetry: selling to hub counts as production (supply)
	_last_produced[item_id] = _last_produced.get(item_id, 0.0) + float(amount)
	
	return true

func _on_economy_tick(results: Dictionary) -> void:
	_last_consumed = results.get("consumed", {})
	_last_produced = results.get("produced", {})
	_ingest_consumption_telemetry(_last_consumed)
	_update_item_prices()

func _ingest_consumption_telemetry(consumed: Dictionary) -> void:
	for k in consumed.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		var inst: float = float(consumed[k]) # positive magnitude (units eaten this tick)
		var prev: float = float(_consumption_ema.get(id, 0.0))
		_consumption_ema[id] = lerp(prev, inst, PRICE_ALPHA)

func _estimate_consumption_rate(item_id: StringName) -> float:
	return float(_consumption_ema.get(item_id, 0.0))

func _get_tracked_items() -> Array[StringName]:
	var keys: Array[StringName] = InventoryUtil.union_keys(state.inventory, {})
	for k in _last_consumed.keys():
		var id: StringName = (k if k is StringName else StringName(str(k)))
		if not keys.has(id):
			keys.append(id)
	for k in _last_produced.keys():
		var id2: StringName = (k if k is StringName else StringName(str(k)))
		if not keys.has(id2):
			keys.append(id2)
	return keys

func _calculate_item_price(item_id: StringName, current_stock: float, consumption_rate: float) -> float:
	if item_db == null:
		return 0.0
	var base_price: float = 1.0
	if item_db.has_method("price_of"):
		base_price = float(item_db.price_of(item_id))
	else:
		# Fallback: try to read ItemDef.base_price from the DB's items map
		var def = item_db.items.get(item_id, null)
		if def != null and def.has_method("get"):
			var bp = def.get("base_price")
			if bp != null:
				base_price = float(bp)
	# Simple supply/demand: more demand or lower stock -> higher price
	# Fix 1: Always clamp the denominator to avoid Divide by Zero
	var supply_factor: float = max(1.0, current_stock)
	
	# Equilibrium: 10 ticks of consumption.
	var demand_factor: float = max(1.0, consumption_rate * 10.0)
	
	var raw_ratio: float = demand_factor / supply_factor
	
	# Fix 2: Clamp the final multiplier to prevent infinity prices (or near-zero)
	var final_multiplier: float = clampf(raw_ratio, 0.1, 4.0)
	
	return base_price * final_multiplier

func _update_item_prices() -> void:
	if item_db == null:
		return
	var tracked: Array[StringName] = _get_tracked_items()
	for id in tracked:
		var stock: float = economy_manager.get_current_amount(id)
		var rate: float = _estimate_consumption_rate(id)
		item_prices[id] = _calculate_item_price(id, stock, rate)
