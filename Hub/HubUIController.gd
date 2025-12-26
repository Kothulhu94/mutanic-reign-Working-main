# HubUIController.gd
extends Node
class_name HubUIController

## Manages UI interactions for a Hub.
## Handles menu, market, and recruitment UI flows.
## Extracted from Hub.gd to reduce complexity.

var hub_menu_ui: HubMenuUI
var market_ui: MarketUI
var recruitment_ui: RecruitmentUI

var state: HubStates
var trading_system: HubTradingSystem
var hub_node: Hub # Reference back to main hub

func setup(hub: Hub, s: HubStates, menu: HubMenuUI, market: MarketUI, recruit: RecruitmentUI, trade_sys: HubTradingSystem) -> void:
	hub_node = hub
	state = s
	hub_menu_ui = menu
	market_ui = market
	recruitment_ui = recruit
	trading_system = trade_sys
	_connect_signals()

func _connect_signals() -> void:
	if hub_menu_ui != null:
		if hub_menu_ui.has_signal("menu_closed"):
			hub_menu_ui.menu_closed.connect(_on_menu_closed)
		if hub_menu_ui.has_signal("market_opened"):
			hub_menu_ui.market_opened.connect(_on_market_opened)
		if hub_menu_ui.has_signal("recruitment_opened"):
			hub_menu_ui.recruitment_opened.connect(_on_recruitment_opened)
	
	if market_ui != null:
		if market_ui.has_signal("market_closed"):
			market_ui.market_closed.connect(_on_market_closed)
		if market_ui.has_signal("transaction_confirmed"):
			market_ui.transaction_confirmed.connect(_on_transaction_confirmed)
	
	if recruitment_ui != null:
		if recruitment_ui.has_signal("recruitment_closed"):
			recruitment_ui.recruitment_closed.connect(_on_recruitment_closed)
		if recruitment_ui.has_signal("recruitment_confirmed"):
			recruitment_ui.recruitment_confirmed.connect(_on_recruitment_confirmed)

func show_hub_menu() -> void:
	if hub_menu_ui == null:
		push_warning("Hub %s has no HubMenuUI assigned" % hub_node.name)
		return
	
	hub_menu_ui.open_menu(hub_node)

func _on_menu_closed() -> void:
	# Only respond if this hub was the one that opened the menu
	if hub_menu_ui != null and hub_menu_ui.current_hub == hub_node:
		# Menu closed, game resumed automatically by HubMenuUI
		pass

func _on_market_opened() -> void:
	# Only respond if this hub was the one that opened the menu
	if hub_menu_ui == null or hub_menu_ui.current_hub != hub_node:
		return
	
	if market_ui == null:
		push_warning("Hub %s has no MarketUI assigned" % hub_node.name)
		return
	
	# Get bus reference from the overworld scene
	var bus_ref: Bus = _get_bus_from_scene_tree()
	if bus_ref == null:
		push_warning("Hub %s cannot find Bus in scene tree" % hub_node.name)
		return
	
	market_ui.open(bus_ref, hub_node)

func _on_market_closed() -> void:
	# Only respond if this hub was the one that opened the market
	if market_ui != null and market_ui.current_hub == hub_node:
		# Finalize trading session for XP awards
		var bus_ref: Bus = _get_bus_from_scene_tree()
		if bus_ref != null and bus_ref.has_method("finalize_trade_session"):
			bus_ref.finalize_trade_session(hub_node.name)
		
		# Market closed, game resumed automatically by MarketUI
		pass

func _on_transaction_confirmed(cart: Array[Dictionary]) -> void:
	var bus_ref: Bus = _get_bus_from_scene_tree()
	if bus_ref == null:
		push_error("Hub %s: Cannot process transaction - Bus not found" % hub_node.name)
		return
	
	for entry: Dictionary in cart:
		var item_id: StringName = entry.get("item_id", StringName())
		var buy_qty: int = int(entry.get("buy_qty", 0))
		var sell_qty: int = int(entry.get("sell_qty", 0))
		var unit_price: float = float(entry.get("unit_price", 0.0))
		
		if buy_qty > 0:
			var cost: int = int(ceil(float(buy_qty) * unit_price))
			
			if bus_ref.money < cost:
				push_warning("Hub %s: Player cannot afford to buy %d %s" % [hub_node.name, buy_qty, item_id])
				continue
			
			if state.inventory.get(item_id, 0) < buy_qty:
				push_warning("Hub %s: Not enough %s in hub inventory" % [hub_node.name, item_id])
				continue
			
			# Use trading system to handle inventory
			if not trading_system.buy_from_hub(item_id, buy_qty, null):
				push_warning("Hub %s: Failed to process buy transaction for %s" % [hub_node.name, item_id])
				continue
			
			if not bus_ref.add_item(item_id, buy_qty):
				push_warning("Hub %s: Failed to add %d %s to player inventory" % [hub_node.name, buy_qty, item_id])
				continue
			
			bus_ref.money -= cost
			state.money += cost
			
			# Award XP for market_analysis (trading_goods)
			if bus_ref.has_method("award_skill_xp"):
				bus_ref.award_skill_xp(&"market_analysis", float(cost))
			
			# Track transaction for session-based XP
			if bus_ref.has_method("track_trade_transaction"):
				bus_ref.track_trade_transaction(hub_node.name, float(cost))
		
		if sell_qty > 0:
			var revenue: int = int(floor(float(sell_qty) * unit_price))
			
			if bus_ref.inventory.get(item_id, 0) < sell_qty:
				push_warning("Hub %s: Player doesn't have %d %s to sell" % [hub_node.name, sell_qty, item_id])
				continue
			
			if not bus_ref.remove_item(item_id, sell_qty):
				push_warning("Hub %s: Failed to remove %d %s from player inventory" % [hub_node.name, sell_qty, item_id])
				continue
			
			# Use trading system to handle inventory
			trading_system.sell_to_hub(item_id, sell_qty, null)
			
			bus_ref.money += revenue
			state.money -= revenue
			
			# Award XP for market_analysis (trading_goods)
			if bus_ref.has_method("award_skill_xp"):
				bus_ref.award_skill_xp(&"market_analysis", float(revenue))
				
				# Award XP for negotiation_tactics (negotiating_deals)
				bus_ref.award_skill_xp(&"negotiation_tactics", float(revenue))
				
				# Award XP for master_merchant (profitable_trade_completed)
				bus_ref.award_skill_xp(&"master_merchant", float(revenue))
				
				# Award XP for market_monopoly (controlling_markets) when selling >50 units
				if sell_qty > 50:
					bus_ref.award_skill_xp(&"market_monopoly", float(revenue))
			
			# Track transaction for session-based XP
			if bus_ref.has_method("track_trade_transaction"):
				bus_ref.track_trade_transaction(hub_node.name, float(revenue))

func _on_recruitment_opened() -> void:
	# Only respond if this hub was the one that opened the menu
	if hub_menu_ui == null or hub_menu_ui.current_hub != hub_node:
		return
	
	if recruitment_ui == null:
		push_warning("Hub %s has no RecruitmentUI assigned" % hub_node.name)
		return
	
	# Get bus reference from the overworld scene
	var bus_ref: Bus = _get_bus_from_scene_tree()
	if bus_ref == null:
		push_warning("Hub %s cannot find Bus in scene tree" % hub_node.name)
		return
	
	recruitment_ui.open(bus_ref, hub_node)

func _on_recruitment_closed() -> void:
	# Only respond if this hub was the one that opened the recruitment
	if recruitment_ui != null and recruitment_ui.current_hub == hub_node:
		# Reset hub menu state when recruitment closes
		if hub_menu_ui != null:
			hub_menu_ui.current_hub = null

func _on_recruitment_confirmed(_recruits: Array[Dictionary]) -> void:
	# Additional logic can go here if needed (e.g., logging, achievements)
	pass

func _get_bus_from_scene_tree() -> Bus:
	var root: Window = hub_node.get_tree().root
	if root == null:
		return null
	
	var overworld: Node = root.get_node_or_null("Overworld")
	if overworld == null:
		return null
	
	var bus_node: Node = overworld.get("bus")
	if bus_node != null and bus_node is Bus:
		return bus_node as Bus
	
	return null
