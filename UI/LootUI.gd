extends Control
class_name LootUI

signal loot_closed(target_actor)

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var player_name_label: Label = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/PlayerNameLabel
@onready var player_item_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentContainer/LeftPanel/PlayerScrollContainer/PlayerItemList
@onready var defeated_name_label: Label = $MarginContainer/VBoxContainer/ContentContainer/RightPanel/DefeatedNameLabel
@onready var defeated_item_list: VBoxContainer = $MarginContainer/VBoxContainer/ContentContainer/RightPanel/DefeatedScrollContainer/DefeatedItemList
@onready var take_all_button: Button = $MarginContainer/VBoxContainer/FooterContainer/TakeAllButton
@onready var done_button: Button = $MarginContainer/VBoxContainer/FooterContainer/DoneButton

var player_actor: Node2D = null
var target_actor: Node2D = null

var loot_cart: Dictionary = {} # item_id -> quantity to take
var last_clicked_item: StringName = StringName()

var player_row_nodes: Dictionary = {}
var defeated_row_nodes: Dictionary = {}

func _ready() -> void:
	hide()
	set_process_input(true)

	if take_all_button != null:
		take_all_button.pressed.connect(_on_take_all_pressed)

	if done_button != null:
		done_button.pressed.connect(_on_done_pressed)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_done_pressed()

func open(player_ref: Node2D, target_ref: Node2D) -> void:
	if player_ref == null or target_ref == null:
		return

	player_actor = player_ref
	target_actor = target_ref

	if target_actor != null and target_actor.get("_is_paused") != null:
		target_actor.set("_is_paused", true)

	_clear_cart()
	_populate_ui()
	show()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

func close_loot() -> void:
	hide()

	if target_actor != null and target_actor.get("_is_paused") != null:
		target_actor.set("_is_paused", false)

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

	loot_closed.emit(target_actor)
	player_actor = null
	target_actor = null

func _clear_cart() -> void:
	loot_cart.clear()
	last_clicked_item = StringName()

func _populate_ui() -> void:
	if player_actor == null or target_actor == null:
		return

	if title_label != null:
		title_label.text = "Victory! Take Your Loot"

	if player_name_label != null:
		player_name_label.text = player_actor.name

	if defeated_name_label != null:
		defeated_name_label.text = target_actor.name

	_populate_player_list()
	_populate_defeated_list()

func _populate_player_list() -> void:
	if player_item_list == null or player_actor == null:
		return

	for child in player_item_list.get_children():
		child.queue_free()
	player_row_nodes.clear()

	if player_actor.get("inventory") == null:
		return

	var sorted_items: Array[StringName] = []
	for k in player_actor.inventory.keys():
		sorted_items.append(k if k is StringName else StringName(str(k)))
	sorted_items.sort_custom(func(a: StringName, b: StringName): return str(a) < str(b))

	for item_id: StringName in sorted_items:
		var stock: int = player_actor.inventory.get(item_id, 0)
		if stock > 0:
			_create_player_item_row(item_id, stock)

func _populate_defeated_list() -> void:
	if defeated_item_list == null or target_actor == null:
		return

	for child in defeated_item_list.get_children():
		child.queue_free()
	defeated_row_nodes.clear()

	var defeated_inventory: Dictionary = _get_defeated_inventory()
	var sorted_items: Array[StringName] = []
	for k in defeated_inventory.keys():
		sorted_items.append(k if k is StringName else StringName(str(k)))
	sorted_items.sort_custom(func(a: StringName, b: StringName): return str(a) < str(b))

	for item_id: StringName in sorted_items:
		var stock: int = defeated_inventory.get(item_id, 0)
		if stock > 0:
			_create_defeated_item_row(item_id, stock)

func _create_player_item_row(item_id: StringName, stock: int) -> void:
	if player_item_list == null:
		return

	var label: Label = Label.new()
	label.text = "%s: %d" % [item_id, stock]
	player_item_list.add_child(label)

	player_row_nodes[item_id] = {"label": label, "stock": stock}

func _create_defeated_item_row(item_id: StringName, stock: int) -> void:
	if defeated_item_list == null:
		return

	var container: VBoxContainer = VBoxContainer.new()
	container.set_meta("item_id", item_id)
	defeated_item_list.add_child(container)

	# Base row with item name button
	var base_row: HBoxContainer = HBoxContainer.new()
	base_row.set_meta("item_id", item_id)
	container.add_child(base_row)

	var base_button: Button = Button.new()
	base_button.text = "%s: %d" % [item_id, stock]
	base_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	base_button.pressed.connect(_on_item_row_clicked.bind(item_id))
	base_row.add_child(base_button)

	# Adjuster row with quantity selector (hidden by default)
	var adjuster_container: HBoxContainer = HBoxContainer.new()
	adjuster_container.visible = false
	adjuster_container.set_meta("item_id", item_id)
	container.add_child(adjuster_container)

	var minus_button: Button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(30, 0)
	minus_button.pressed.connect(_on_quantity_adjust.bind(item_id, -1))

	var qty_input: LineEdit = LineEdit.new()
	qty_input.text = "0"
	qty_input.custom_minimum_size = Vector2(60, 0)
	qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_input.text_changed.connect(_on_quantity_text_changed.bind(item_id))

	var plus_button: Button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(30, 0)
	plus_button.pressed.connect(_on_quantity_adjust.bind(item_id, 1))

	var take_button: Button = Button.new()
	take_button.text = "Take"
	take_button.custom_minimum_size = Vector2(60, 0)
	take_button.pressed.connect(_on_take_item_pressed.bind(item_id))

	var take_label: Label = Label.new()
	take_label.text = "Take:"

	adjuster_container.add_child(take_label)
	adjuster_container.add_child(minus_button)
	adjuster_container.add_child(qty_input)
	adjuster_container.add_child(plus_button)
	adjuster_container.add_child(take_button)

	var node_data: Dictionary = {
		"container": container,
		"base_row": base_row,
		"base_button": base_button,
		"adjuster": adjuster_container,
		"qty_input": qty_input,
		"take_button": take_button,
		"stock": stock
	}

	defeated_row_nodes[item_id] = node_data

func _on_item_row_clicked(item_id: StringName) -> void:
	if not defeated_row_nodes.has(item_id):
		return

	var node_data: Dictionary = defeated_row_nodes[item_id]
	var adjuster: HBoxContainer = node_data.get("adjuster")

	if adjuster == null:
		return

	var current_qty: int = loot_cart.get(item_id, 0)

	# Collapse previous item if it has 0 quantity
	if current_qty == 0 and last_clicked_item != StringName() and last_clicked_item != item_id:
		_collapse_row(last_clicked_item)

	adjuster.visible = not adjuster.visible
	last_clicked_item = item_id if adjuster.visible else StringName()

func _collapse_row(item_id: StringName) -> void:
	if not defeated_row_nodes.has(item_id):
		return

	var node_data: Dictionary = defeated_row_nodes[item_id]
	var adjuster: HBoxContainer = node_data.get("adjuster")

	if adjuster != null:
		adjuster.visible = false

func _on_quantity_adjust(item_id: StringName, delta: int) -> void:
	var current_qty: int = loot_cart.get(item_id, 0)
	var new_qty: int = current_qty + delta
	_update_cart_for_item(item_id, new_qty)

func _on_quantity_text_changed(new_text: String, item_id: StringName) -> void:
	if new_text.is_empty():
		return

	var new_qty: int = new_text.to_int()
	_update_cart_for_item(item_id, new_qty)

func _update_cart_for_item(item_id: StringName, new_qty: int) -> void:
	if not defeated_row_nodes.has(item_id):
		return

	var node_data: Dictionary = defeated_row_nodes[item_id]
	var stock: int = node_data.get("stock", 0)

	var clamped_qty: int = clampi(new_qty, 0, stock)

	loot_cart[item_id] = clamped_qty

	var qty_input: LineEdit = node_data.get("qty_input")
	if qty_input != null:
		qty_input.text = str(clamped_qty)

func _get_defeated_inventory() -> Dictionary:
	if target_actor == null:
		return {}

	var inventory: Variant = target_actor.get("inventory")
	if inventory != null:
		return inventory

	var caravan_state: Variant = target_actor.get("caravan_state")
	if caravan_state != null and caravan_state.get("inventory") != null:
		return caravan_state.inventory

	return {}

func _on_take_item_pressed(item_id: StringName) -> void:
	var amount: int = loot_cart.get(item_id, 0)
	if amount <= 0:
		return

	if _transfer_item_to_player(item_id, amount):
		loot_cart[item_id] = 0
		_refresh_ui()

func _on_take_all_pressed() -> void:
	var defeated_inventory: Dictionary = _get_defeated_inventory()

	for item_id in defeated_inventory.keys():
		var amount: int = defeated_inventory.get(item_id, 0)
		if amount > 0:
			_transfer_item_to_player(item_id, amount)

	close_loot()

func _on_done_pressed() -> void:
	# Transfer items from loot cart to player
	for item_id in loot_cart.keys():
		var amount: int = loot_cart.get(item_id, 0)
		if amount > 0:
			_transfer_item_to_player(item_id, amount)

	close_loot()

func _remove_from_defeated(item_id: StringName, amount: int) -> void:
	if target_actor == null:
		return

	if target_actor.has_method("remove_item"):
		target_actor.remove_item(item_id, amount)
	else:
		var caravan_state: Variant = target_actor.get("caravan_state")
		if caravan_state != null and caravan_state.has_method("remove_item"):
			caravan_state.remove_item(item_id, amount)

func _transfer_item_to_player(item_id: StringName, amount: int) -> bool:
	if player_actor == null or target_actor == null:
		return false

	if amount <= 0:
		return false

	if not player_actor.has_method("add_item"):
		return false

	var success: bool = player_actor.add_item(item_id, amount)
	if success:
		_remove_from_defeated(item_id, amount)
		return true

	return false

func _refresh_ui() -> void:
	_populate_player_list()
	_populate_defeated_list()
