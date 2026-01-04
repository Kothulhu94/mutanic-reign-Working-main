extends Node
class_name OverworldUIManager

var overworld: Node2D
var player_bus: Bus
var _target_actor: Node2D = null

# UI Instances
var _encounter_ui: Control
var _market_ui: MarketUI
var _loot_ui: Control
var _game_over_ui: Control

const ENCOUNTER_UI_SCENE = preload("uid://b8kj3x4n2qp5m")
const MARKET_UI_SCENE = preload("uid://bxn5d8qv2mw5k")
const LOOT_UI_SCENE = preload("uid://c2m7k9x3p5qn8")
const GAME_OVER_UI_SCENE = preload("uid://d3k9m7x5p2qn4")

func setup(p_overworld: Node2D, p_bus: Bus) -> void:
	overworld = p_overworld
	player_bus = p_bus
	
	_initialize_uis()
	_connect_signals()

func _initialize_uis() -> void:
	# Initialize combat UIs with CanvasLayers for proper rendering
	var encounter_canvas: CanvasLayer = CanvasLayer.new()
	encounter_canvas.layer = 10
	encounter_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	overworld.add_child(encounter_canvas)

	_encounter_ui = ENCOUNTER_UI_SCENE.instantiate() as Control
	_encounter_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	encounter_canvas.add_child(_encounter_ui)
	_encounter_ui.combat_ended.connect(_on_combat_ended)
	_encounter_ui.exit_pressed.connect(_on_encounter_exit)
	if _encounter_ui.has_signal("trade_requested"):
		_encounter_ui.trade_requested.connect(_on_encounter_trade_requested)

	# Initialize Generic Market UI (for Caravan trading)
	var market_canvas: CanvasLayer = CanvasLayer.new()
	market_canvas.layer = 10
	market_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	overworld.add_child(market_canvas)
	
	if MARKET_UI_SCENE:
		_market_ui = MARKET_UI_SCENE.instantiate() as MarketUI
		_market_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		market_canvas.add_child(_market_ui)
		_market_ui.market_closed.connect(_on_market_closed)
		_market_ui.transaction_confirmed.connect(_on_market_transaction_confirmed)

	var loot_canvas: CanvasLayer = CanvasLayer.new()
	loot_canvas.layer = 10
	loot_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	overworld.add_child(loot_canvas)

	_loot_ui = LOOT_UI_SCENE.instantiate() as Control
	_loot_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	loot_canvas.add_child(_loot_ui)
	_loot_ui.loot_closed.connect(_on_loot_closed)

	var game_over_canvas: CanvasLayer = CanvasLayer.new()
	game_over_canvas.layer = 10
	game_over_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	overworld.add_child(game_over_canvas)

	_game_over_ui = GAME_OVER_UI_SCENE.instantiate() as Control
	_game_over_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_canvas.add_child(_game_over_ui)

func _connect_signals() -> void:
	if player_bus:
		player_bus.encounter_initiated.connect(_on_encounter_initiated)

func _on_encounter_initiated(attacker: Node2D, defender: Node2D) -> void:
	if attacker == player_bus:
		_target_actor = defender
	else:
		_target_actor = attacker
		
	if _encounter_ui != null:
		_encounter_ui.open_encounter(attacker, defender)

func _on_combat_ended(attacker: Node2D, defender: Node2D, winner: Node2D) -> void:
	if _encounter_ui != null:
		_encounter_ui.close_ui()

	if winner == null:
		return

	if winner == player_bus:
		var defeated: Node2D = defender if attacker == player_bus else attacker

		if _loot_ui != null:
			_loot_ui.open(player_bus, defeated)
	elif winner == attacker or winner == defender:
		if winner != player_bus:
			if _game_over_ui != null:
				_game_over_ui.show_game_over()

func _on_encounter_exit() -> void:
	if _encounter_ui != null:
		_encounter_ui.close_ui()

	if _target_actor != null and _target_actor != player_bus:
		_target_actor.queue_free()

func _on_encounter_trade_requested(attacker: Node2D, defender: Node2D) -> void:
	var merchant = defender
	if attacker != player_bus:
		merchant = attacker
		
	if _market_ui != null:
		if merchant is Hub or merchant.is_in_group("caravans"):
			_market_ui.open(player_bus, merchant)
		else:
			push_warning("Cannot trade with non-merchant entity")

func _on_market_closed() -> void:
	var timekeeper: Node = overworld.get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("set_paused"):
		timekeeper.set_paused(false)

func _on_loot_closed(_target: Node2D = null) -> void:
	var timekeeper: Node = overworld.get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("set_paused"):
		timekeeper.set_paused(false)
	
	if _target_actor != null:
		_target_actor.queue_free()
		_target_actor = null

func _on_market_transaction_confirmed(cart: Array[Dictionary]) -> void:
	if player_bus == null:
		return
		
	for entry in cart:
		var item_id = entry.get("item_id")
		var buy_qty = entry.get("buy_qty", 0)
		var sell_qty = entry.get("sell_qty", 0)
		var price = entry.get("unit_price", 0.0)
		var cost = buy_qty * price
		var revenue = sell_qty * price
		var side = entry.get("side") # "buy" or "sell"
		
		var merchant = _market_ui.current_merchant
		if merchant == null:
			return

		if side == "buy":
			if player_bus.pacs >= cost:
				player_bus.pacs -= cost
				player_bus.add_item(item_id, buy_qty)
				
				# Update Merchant
				if merchant.is_in_group("caravans") and "caravan_state" in merchant:
					var s = merchant.caravan_state
					if s:
						s.pacs += cost
						s.remove_item(item_id, buy_qty)
				elif merchant is Hub:
					merchant.state.pacs += cost
					# Hub inventory logic...
					# Basic override for now
					var current = merchant.state.inventory.get(item_id, 0)
					merchant.state.inventory[item_id] = max(0, current - buy_qty)

				# Skill XP
				if player_bus.has_method("award_skill_xp"):
					player_bus.award_skill_xp(&"market_analysis", float(cost))

		elif side == "sell":
			if player_bus.remove_item(item_id, sell_qty):
				# Add money
				player_bus.pacs += revenue
				
				# Update Merchant
				if merchant.is_in_group("caravans") and "caravan_state" in merchant:
					var s = merchant.caravan_state
					if s:
						s.pacs -= revenue
						s.add_item(item_id, sell_qty)
				elif merchant is Hub:
					merchant.state.pacs -= revenue
					merchant.state.inventory[item_id] = merchant.state.inventory.get(item_id, 0) + sell_qty
				
				# Skill XP
				if player_bus.has_method("award_skill_xp"):
					player_bus.award_skill_xp(&"market_analysis", float(revenue))
					player_bus.award_skill_xp(&"negotiation_tactics", float(revenue))
					player_bus.award_skill_xp(&"master_merchant", float(revenue))
					if sell_qty > 50:
						player_bus.award_skill_xp(&"market_monopoly", float(revenue))

	# Refresh UI
