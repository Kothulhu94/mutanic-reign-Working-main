extends Control
class_name MarketUI

signal transaction_confirmed(cart: Array[Dictionary])
signal cart_updated()
signal transaction_canceled()
signal market_closed()

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var player_name_label: Label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/PlayerNameLabel
@onready var player_money_label: Label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/PlayerMoneyLabel
@onready var player_item_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/PlayerScrollContainer/PlayerItemList
@onready var hub_name_label: Label = $MarginContainer/VBoxContainer/ContentContainer/RightPanel/HubNameLabel
@onready var hub_money_label: Label = $MarginContainer/VBoxContainer/ContentContainer/RightPanel/HubMoneyLabel
@onready var hub_item_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentContainer/RightPanel/HubScrollContainer/HubItemList
@onready var net_total_label: Label = $MarginContainer/VBoxContainer/FooterContainer/NetTotalLabel
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/FooterContainer/ConfirmButton
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/FooterContainer/CancelButton

var current_bus: Bus = null
var current_merchant: Node = null # Can be Hub or Caravan

var cart: Dictionary = {}
var last_clicked_item: StringName = StringName()

var player_row_nodes: Dictionary = {}
var hub_row_nodes: Dictionary = {}

func _ready() -> void:
	hide()
	set_process_input(true)

	if confirm_button != null:
		confirm_button.pressed.connect(_on_confirm_pressed)

	if cancel_button != null:
		cancel_button.pressed.connect(_on_cancel_pressed)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()

func open(bus_ref: Bus, merchant_ref: Node) -> void:
	if bus_ref == null:
		push_error("MarketUI: Cannot open with null bus")
		return

	if merchant_ref == null:
		push_error("MarketUI: Cannot open with null merchant")
		return

	current_bus = bus_ref
	current_merchant = merchant_ref

	_clear_cart()
	_populate_ui()

	show()
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

func close_market() -> void:
	hide()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

	market_closed.emit()
	current_bus = null
	current_merchant = null

func _clear_cart() -> void:
	cart.clear()
	last_clicked_item = StringName()
	_update_net_total()

func _populate_ui() -> void:
	if current_bus == null or current_merchant == null:
		return

	if title_label != null:
		title_label.text = "%s - Market" % _get_merchant_name()

	if player_name_label != null:
		player_name_label.text = current_bus.name

	if hub_name_label != null:
		hub_name_label.text = _get_merchant_name()

	_update_money_labels()
	_populate_player_list()
	_populate_hub_list()

func _update_money_labels() -> void:
	if current_bus != null and player_money_label != null:
		player_money_label.text = "Pacs: %d" % current_bus.pacs

	if current_merchant != null and hub_money_label != null:
		hub_money_label.text = "Pacs: %d" % _get_merchant_money()

func _populate_player_list() -> void:
	if player_item_list == null or current_bus == null:
		return

	for child in player_item_list.get_children():
		child.queue_free()
	player_row_nodes.clear()

	var sorted_items: Array[StringName] = []
	for k in current_bus.inventory.keys():
		sorted_items.append(k if k is StringName else StringName(str(k)))
	sorted_items.sort_custom(func(a: StringName, b: StringName): return str(a) < str(b))

	for item_id: StringName in sorted_items:
		var stock: int = current_bus.inventory.get(item_id, 0)
		if stock > 0:
			_create_item_row(item_id, "player", stock)

func _populate_hub_list() -> void:
	if hub_item_list == null or current_merchant == null:
		return

	for child in hub_item_list.get_children():
		child.queue_free()
	hub_row_nodes.clear()

	var merchant_inv: Dictionary = _get_merchant_inventory()
	var sorted_items: Array[StringName] = []
	for k in merchant_inv.keys():
		sorted_items.append(k if k is StringName else StringName(str(k)))
	sorted_items.sort_custom(func(a: StringName, b: StringName): return str(a) < str(b))

	for item_id: StringName in sorted_items:
		var stock: int = merchant_inv.get(item_id, 0)
		if stock > 0:
			_create_item_row(item_id, "hub", stock)

func _create_item_row(item_id: StringName, side: String, stock: int) -> void:
	var parent: VBoxContainer = (player_item_list if side == "player" else hub_item_list)
	if parent == null:
		return

	var container: VBoxContainer = VBoxContainer.new()
	container.set_meta("item_id", item_id)
	container.set_meta("side", side)
	parent.add_child(container)

	var base_row: HBoxContainer = HBoxContainer.new()
	base_row.set_meta("item_id", item_id)
	base_row.set_meta("side", side)
	container.add_child(base_row)

	var base_button: Button = Button.new()
	base_button.text = "%s · %s: %d" % [item_id, "Owned" if side == "player" else "Stock", stock]
	base_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_button.pressed.connect(_on_item_row_clicked.bind(item_id, side))
	base_row.add_child(base_button)

	var adjuster_container: HBoxContainer = HBoxContainer.new()
	adjuster_container.visible = false
	adjuster_container.set_meta("item_id", item_id)
	adjuster_container.set_meta("side", side)
	container.add_child(adjuster_container)

	var minus_button: Button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(30, 0)
	minus_button.pressed.connect(_on_quantity_adjust.bind(item_id, side, -1))

	var qty_input: LineEdit = LineEdit.new()
	qty_input.text = "0"
	qty_input.custom_minimum_size = Vector2(60, 0)
	qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_input.text_changed.connect(_on_quantity_text_changed.bind(item_id, side))

	var plus_button: Button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(30, 0)
	plus_button.pressed.connect(_on_quantity_adjust.bind(item_id, side, 1))

	var price: float = _get_item_price(item_id, current_merchant, side)
	var price_label: Label = Label.new()
	price_label.text = "× %.1f" % price

	var equals_label: Label = Label.new()
	equals_label.text = "="

	var subtotal_label: Label = Label.new()
	subtotal_label.text = "0"

	if side == "hub":
		adjuster_container.add_child(minus_button)
		adjuster_container.add_child(qty_input)
		adjuster_container.add_child(plus_button)
		adjuster_container.add_child(price_label)
		adjuster_container.add_child(equals_label)
		adjuster_container.add_child(subtotal_label)
	else:
		adjuster_container.add_child(minus_button)
		adjuster_container.add_child(qty_input)
		adjuster_container.add_child(plus_button)
		adjuster_container.add_child(price_label)
		adjuster_container.add_child(equals_label)
		adjuster_container.add_child(subtotal_label)

	var node_data: Dictionary = {
		"container": container,
		"base_row": base_row,
		"base_button": base_button,
		"adjuster": adjuster_container,
		"qty_input": qty_input,
		"subtotal_label": subtotal_label,
		"stock": stock,
		"price": price
	}

	if side == "player":
		player_row_nodes[item_id] = node_data
	else:
		hub_row_nodes[item_id] = node_data

func _on_item_row_clicked(item_id: StringName, side: String) -> void:
	var row_nodes: Dictionary = (player_row_nodes if side == "player" else hub_row_nodes)

	if not row_nodes.has(item_id):
		return

	var node_data: Dictionary = row_nodes[item_id]
	var adjuster: HBoxContainer = node_data.get("adjuster")

	if adjuster == null:
		return

	var current_qty: int = _get_cart_quantity(item_id, side)

	if current_qty == 0 and last_clicked_item != StringName() and last_clicked_item != item_id:
		var last_side: String = _find_item_side(last_clicked_item)
		if last_side != "":
			_collapse_row(last_clicked_item, last_side)

	adjuster.visible = not adjuster.visible
	last_clicked_item = item_id if adjuster.visible else StringName()

func _collapse_row(item_id: StringName, side: String) -> void:
	var row_nodes: Dictionary = (player_row_nodes if side == "player" else hub_row_nodes)

	if not row_nodes.has(item_id):
		return

	var node_data: Dictionary = row_nodes[item_id]
	var adjuster: HBoxContainer = node_data.get("adjuster")

	if adjuster != null:
		adjuster.visible = false

func _find_item_side(item_id: StringName) -> String:
	if player_row_nodes.has(item_id):
		return "player"
	elif hub_row_nodes.has(item_id):
		return "hub"
	return ""

func _on_quantity_adjust(item_id: StringName, side: String, delta: int) -> void:
	var current_qty: int = _get_cart_quantity(item_id, side)
	var new_qty: int = current_qty + delta
	_update_cart_for_item(item_id, side, new_qty)

func _on_quantity_text_changed(new_text: String, item_id: StringName, side: String) -> void:
	if new_text.is_empty():
		return

	var new_qty: int = new_text.to_int()
	_update_cart_for_item(item_id, side, new_qty)

func _update_cart_for_item(item_id: StringName, side: String, new_qty: int) -> void:
	var row_nodes: Dictionary = (player_row_nodes if side == "player" else hub_row_nodes)

	if not row_nodes.has(item_id):
		return

	var node_data: Dictionary = row_nodes[item_id]
	var stock: int = node_data.get("stock", 0)
	var price: float = node_data.get("price", 0.0)

	var clamped_qty: int = clampi(new_qty, 0, stock)

	if not cart.has(item_id):
		cart[item_id] = {"buy_qty": 0, "sell_qty": 0, "unit_price": price}

	if side == "player":
		cart[item_id]["sell_qty"] = clamped_qty
	else:
		cart[item_id]["buy_qty"] = clamped_qty

	cart[item_id]["unit_price"] = price

	var qty_input: LineEdit = node_data.get("qty_input")
	if qty_input != null:
		qty_input.text = str(clamped_qty)

	var subtotal: float = float(clamped_qty) * price
	var subtotal_label: Label = node_data.get("subtotal_label")
	if subtotal_label != null:
		subtotal_label.text = "%.1f" % subtotal

	_update_net_total()
	_update_money_labels()
	cart_updated.emit()

func _get_cart_quantity(item_id: StringName, side: String) -> int:
	if not cart.has(item_id):
		return 0

	if side == "player":
		return int(cart[item_id].get("sell_qty", 0))
	else:
		return int(cart[item_id].get("buy_qty", 0))

func _update_net_total() -> void:
	if net_total_label == null:
		return

	var total_cost: float = 0.0
	var total_revenue: float = 0.0

	for item_id in cart.keys():
		var entry: Dictionary = cart[item_id]
		var buy_qty: int = int(entry.get("buy_qty", 0))
		var sell_qty: int = int(entry.get("sell_qty", 0))
		var price: float = float(entry.get("unit_price", 0.0))

		total_cost += float(buy_qty) * price
		total_revenue += float(sell_qty) * price

	var net: float = total_cost - total_revenue

	net_total_label.text = "Net: %.1f" % net

	if net > 0.1:
		net_total_label.add_theme_color_override("font_color", Color.RED)
	elif net < -0.1:
		net_total_label.add_theme_color_override("font_color", Color.GREEN)
	else:
		net_total_label.remove_theme_color_override("font_color")

	_validate_and_update_confirm_button(net)

func _validate_and_update_confirm_button(net_cost: float) -> void:
	if confirm_button == null or current_bus == null:
		return

	var can_afford: bool = current_bus.pacs >= int(ceil(max(0.0, net_cost)))

	confirm_button.disabled = not can_afford

	if not can_afford:
		confirm_button.add_theme_color_override("font_color", Color.RED)
	else:
		confirm_button.remove_theme_color_override("font_color")

func _get_item_price(item_id: StringName, merchant: Node, side: String = "") -> float:
	var base_price: float = 1.0

	if merchant != null:
		# Duck-type attempt 1: item_prices dict (Hub)
		if merchant.get("item_prices") != null and merchant.item_prices.has(item_id):
			base_price = float(merchant.item_prices[item_id])
		# Duck-type attempt 2: get_item_price method (Hub or Caravan)
		elif merchant.has_method("get_item_price"):
			base_price = merchant.get_item_price(item_id)
		# Duck-type attempt 3: item_db method
		elif merchant.get("item_db") != null and merchant.item_db.has_method("price_of"):
			base_price = merchant.item_db.price_of(item_id)

	# Apply Trading Skills
	var player_bonus: float = 0.0
	if current_bus and current_bus.charactersheet:
		player_bonus = _calculate_skill_bonus(current_bus.charactersheet)

	var merchant_bonus: float = _get_merchant_skill_bonus()
	var net_modifier: float = player_bonus - merchant_bonus

	if side == "hub": # Buying from hub
		# Discount (positive net_modifier reduces price)
		# User Request: Buying prices rounded UP
		return ceil(maxf(0.1, base_price * (1.0 - net_modifier)))
	elif side == "player": # Selling to hub
		# Premium (positive net_modifier increases yield)
		# User Request: Selling prices rounded DOWN
		return floor(base_price * (1.0 + net_modifier))
	
	return base_price

func _on_confirm_pressed() -> void:
	if current_bus == null or current_merchant == null:
		return

	var transaction_cart: Array[Dictionary] = []

	for item_id in cart.keys():
		var entry: Dictionary = cart[item_id]
		var buy_qty: int = int(entry.get("buy_qty", 0))
		var sell_qty: int = int(entry.get("sell_qty", 0))
		var unit_price: float = float(entry.get("unit_price", 0.0))

		if buy_qty > 0:
			transaction_cart.append({
				"item_id": item_id,
				"buy_qty": buy_qty,
				"sell_qty": 0,
				"unit_price": unit_price,
				"side": "buy",
				"subtotal": float(buy_qty) * unit_price
			})

		if sell_qty > 0:
			transaction_cart.append({
				"item_id": item_id,
				"buy_qty": 0,
				"sell_qty": sell_qty,
				"unit_price": unit_price,
				"side": "sell",
				"subtotal": float(sell_qty) * unit_price
			})

	if transaction_cart.size() > 0:
		# Process generic transaction directly here if simple
		# Or emit signal for controller to handle.
		# For generic implementation, let's process it here or rely on signal listener.
		# Hubs use HubUIController. Caravans use Overworld?
		# To standardize, MarketUI should arguably APPLY the transaction if it owns the logic,
		# or emit.
		# Existing Hub logic relied on HubUIController listening to 'transaction_confirmed'.
		# For Caravans, Overworld/EncounterUI will listen.
		transaction_confirmed.emit(transaction_cart)
		
		# Execute transaction logic right here as fallback/standard?
		# No, kept separate to avoid breaking Hub logic which is external.
		# BUT wait, the Hub logic in HubUIController duplicates checks.
		# Let's support SELF-execution for Caravan mode if listener handles it?
		# Actually, let's just emit. The listener (Overworld) will apply changes.
		
		# --- Award Trading XP ---
		if current_bus != null and current_bus.charactersheet != null:
			var trading_skill: Skill = current_bus.charactersheet.get_skill(&"Trading")
			if trading_skill != null:
				var total_xp: float = 0.0
				
				for item in transaction_cart:
					var subtotal: float = float(item.get("subtotal", 0.0))
					var side: String = item.get("side", "")
					
					# 1 XP per Pac when buying
					if side == "buy":
						total_xp += subtotal
					# 2 XP per Pac when selling
					elif side == "sell":
						total_xp += (subtotal * 2.0)
				
				if total_xp > 0:
					trading_skill.add_xp(total_xp)
					print("MarketUI: Awarded %.1f XP to Trading skill" % total_xp)

		transaction_confirmed.emit(transaction_cart)
		pass

	_clear_cart()
	_populate_ui()

	_clear_cart()
	close_market()

func _get_merchant_name() -> String:
	if current_merchant == null:
		return "Unknown"
	if current_merchant is Hub:
		return current_merchant.state.display_name if current_merchant.state else "Hub"
	elif current_merchant.is_in_group("caravans"):
		return current_merchant.name
	return current_merchant.name

func _get_merchant_money() -> int:
	if current_merchant == null:
		return 0
	if current_merchant is Hub:
		return current_merchant.state.pacs if current_merchant.state else 0
	elif current_merchant.is_in_group("caravans") and "caravan_state" in current_merchant:
		var s = current_merchant.caravan_state
		return s.pacs if s else 0
	return 0

func _get_merchant_inventory() -> Dictionary:
	if current_merchant == null:
		return {}
	if current_merchant is Hub:
		return current_merchant.state.inventory if current_merchant.state else {}
	elif current_merchant.is_in_group("caravans") and "caravan_state" in current_merchant:
		var s = current_merchant.caravan_state
		return s.inventory if s else {}
	return {}

func _update_merchant_inventory_delta(item_id: StringName, amount: int) -> void:
	if current_merchant == null:
		return
		
	# Both generic logic
	if current_merchant is Hub:
		if amount > 0: # Adding to merchant (sell)
			current_merchant.state.inventory[item_id] = current_merchant.state.inventory.get(item_id, 0) + amount
		else: # Removing from merchant (buy)
			var current: int = current_merchant.state.inventory.get(item_id, 0)
			current_merchant.state.inventory[item_id] = max(0, current + amount)
			
	elif current_merchant.is_in_group("caravans") and "caravan_state" in current_merchant:
		if amount > 0:
			current_merchant.caravan_state.add_item(item_id, amount)
		else:
			current_merchant.caravan_state.remove_item(item_id, abs(amount))

func _update_merchant_money(delta: int) -> void:
	if current_merchant == null:
		return
	if current_merchant is Hub:
		current_merchant.state.pacs += delta
	elif current_merchant.is_in_group("caravans") and "caravan_state" in current_merchant:
		current_merchant.caravan_state.pacs += delta

func _get_merchant_skill_bonus() -> float:
	if current_merchant == null:
		return 0.0
		
	if current_merchant.is_in_group("caravans"):
		# Caravans have a CaravanSkillSystem component
		if "skill_system" in current_merchant and current_merchant.skill_system != null:
			return current_merchant.skill_system.price_modifier_bonus
			
	# Hubs now have a Governor sheet
	if current_merchant is Hub:
		if current_merchant.state != null and current_merchant.state.governor_sheet != null:
			return _calculate_skill_bonus(current_merchant.state.governor_sheet)

	return 0.0

func _calculate_skill_bonus(sheet: CharacterSheet) -> float:
	if sheet == null:
		return 0.0
		
	var skill = sheet.get_skill(&"Trading")
	if skill == null:
		return 0.0
		
	# 0.5% per level
	var bonus: float = float(skill.current_level) * 0.005
	
	# Perk Bonuses
	if skill.has_perk(&"economic_dominance"):
		bonus += 0.1
	if skill.has_perk(&"market_monopoly"):
		bonus += 0.1
		
	return bonus

func _on_cancel_pressed() -> void:
	transaction_canceled.emit()
	_clear_cart()
	hide()
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("set_paused"):
		timekeeper.set_paused(false)
