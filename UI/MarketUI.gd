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
var current_hub: Hub = null

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

func open(bus_ref: Bus, hub_ref: Hub) -> void:
	if bus_ref == null:
		push_error("MarketUI: Cannot open with null bus")
		return

	if hub_ref == null:
		push_error("MarketUI: Cannot open with null hub")
		return

	current_bus = bus_ref
	current_hub = hub_ref

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
	current_hub = null

func _clear_cart() -> void:
	cart.clear()
	last_clicked_item = StringName()
	_update_net_total()

func _populate_ui() -> void:
	if current_bus == null or current_hub == null or current_hub.state == null:
		return

	if title_label != null:
		title_label.text = "%s - Market" % current_hub.state.display_name

	if player_name_label != null:
		player_name_label.text = current_bus.name

	if hub_name_label != null:
		hub_name_label.text = current_hub.state.display_name

	_update_money_labels()
	_populate_player_list()
	_populate_hub_list()

func _update_money_labels() -> void:
	if current_bus != null and player_money_label != null:
		player_money_label.text = "Money: %d" % current_bus.money

	if current_hub != null and current_hub.state != null and hub_money_label != null:
		hub_money_label.text = "Money: %d" % current_hub.state.money

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
	if hub_item_list == null or current_hub == null or current_hub.state == null:
		return

	for child in hub_item_list.get_children():
		child.queue_free()
	hub_row_nodes.clear()

	var sorted_items: Array[StringName] = []
	for k in current_hub.state.inventory.keys():
		sorted_items.append(k if k is StringName else StringName(str(k)))
	sorted_items.sort_custom(func(a: StringName, b: StringName): return str(a) < str(b))

	for item_id: StringName in sorted_items:
		var stock: int = current_hub.state.inventory.get(item_id, 0)
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

	var price: float = _get_item_price(item_id, current_hub)
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

	var can_afford: bool = current_bus.money >= int(ceil(max(0.0, net_cost)))

	confirm_button.disabled = not can_afford

	if not can_afford:
		confirm_button.add_theme_color_override("font_color", Color.RED)
	else:
		confirm_button.remove_theme_color_override("font_color")

func _get_item_price(item_id: StringName, hub: Hub) -> float:
	if hub == null:
		return 1.0

	if hub.item_prices.has(item_id):
		return float(hub.item_prices[item_id])

	if hub.has_method("get_item_price"):
		return hub.get_item_price(item_id)

	if hub.item_db != null and hub.item_db.has_method("price_of"):
		return hub.item_db.price_of(item_id)

	return 1.0

func _on_confirm_pressed() -> void:
	if current_bus == null or current_hub == null or current_hub.state == null:
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
		transaction_confirmed.emit(transaction_cart)

	_clear_cart()
	_populate_ui()

func _on_cancel_pressed() -> void:
	transaction_canceled.emit()
	_clear_cart()
	close_market()
