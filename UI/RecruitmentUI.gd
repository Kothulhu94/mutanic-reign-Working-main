extends Control
class_name RecruitmentUI

signal recruitment_confirmed(recruits: Array[Dictionary])
signal recruitment_canceled()
signal recruitment_closed()

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var player_info_label: Label = $MarginContainer/VBoxContainer/PlayerInfoContainer/PlayerInfoLabel
@onready var troop_list: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/TroopList
@onready var total_cost_label: Label = $MarginContainer/VBoxContainer/FooterContainer/TotalCostLabel
@onready var confirm_button: Button = $MarginContainer/VBoxContainer/FooterContainer/ConfirmButton
@onready var cancel_button: Button = $MarginContainer/VBoxContainer/FooterContainer/CancelButton

var current_bus: Bus = null
var current_hub: Hub = null

var recruitment_cart: Dictionary = {}
var troop_row_nodes: Dictionary = {}

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
		push_error("RecruitmentUI: Cannot open with null bus")
		return

	if hub_ref == null:
		push_error("RecruitmentUI: Cannot open with null hub")
		return

	current_bus = bus_ref
	current_hub = hub_ref

	_clear_cart()
	_populate_ui()

	show()
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

func close_recruitment() -> void:
	hide()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

	recruitment_closed.emit()
	current_bus = null
	current_hub = null

func _clear_cart() -> void:
	recruitment_cart.clear()
	_update_total_cost()

func _populate_ui() -> void:
	if current_bus == null or current_hub == null:
		return

	if title_label != null:
		title_label.text = "Recruitment - %s" % current_hub.state.display_name if current_hub.state != null else "Recruitment"

	_update_player_info()
	_populate_troop_list()

func _update_player_info() -> void:
	if current_bus == null or player_info_label == null:
		return

	var sheet: CharacterSheet = current_bus.charactersheet
	if sheet == null:
		return

	var troop_count: int = sheet.get_total_troop_count()
	var max_troops: int = sheet.max_troop_capacity

	player_info_label.text = "Money: %d | Troops: %d / %d" % [current_bus.money, troop_count, max_troops]

func _populate_troop_list() -> void:
	if troop_list == null:
		return

	for child in troop_list.get_children():
		child.queue_free()
	troop_row_nodes.clear()

	var troop_db: Node = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return

	var all_troop_ids: Array[StringName] = troop_db.get_all_troop_ids()

	for troop_id: StringName in all_troop_ids:
		var hub_stock: int = _get_hub_stock(troop_id)
		if hub_stock <= 0:
			continue

		var troop_type: TroopType = troop_db.get_troop(troop_id)
		if troop_type != null:
			_create_troop_row(troop_id, troop_type)

func _create_troop_row(troop_id: StringName, troop_type: TroopType) -> void:
	if troop_list == null:
		return

	var container: VBoxContainer = VBoxContainer.new()
	container.set_meta("troop_id", troop_id)
	troop_list.add_child(container)

	var info_row: HBoxContainer = HBoxContainer.new()
	container.add_child(info_row)

	var name_button: Button = Button.new()
	name_button.text = "%s - %d PACs" % [troop_type.troop_name, troop_type.recruitment_cost]
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.pressed.connect(_on_troop_row_clicked.bind(troop_id))
	info_row.add_child(name_button)

	var details_container: VBoxContainer = VBoxContainer.new()
	details_container.visible = false
	container.add_child(details_container)

	var desc_label: Label = Label.new()
	desc_label.text = troop_type.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_container.add_child(desc_label)

	var stats_label: Label = Label.new()
	stats_label.text = "Bonuses: Health +%d, Damage +%d, Defense +%d" % [troop_type.health_bonus, troop_type.damage_bonus, troop_type.defense_bonus]
	details_container.add_child(stats_label)

	var stock_label: Label = Label.new()
	var available_stock: int = _get_hub_stock(troop_id)
	stock_label.text = "Available: %d" % available_stock
	details_container.add_child(stock_label)

	var adjuster_container: HBoxContainer = HBoxContainer.new()
	details_container.add_child(adjuster_container)

	var minus_button: Button = Button.new()
	minus_button.text = "-"
	minus_button.custom_minimum_size = Vector2(30, 0)
	minus_button.pressed.connect(_on_quantity_adjust.bind(troop_id, -1))

	var qty_input: LineEdit = LineEdit.new()
	qty_input.text = "0"
	qty_input.custom_minimum_size = Vector2(60, 0)
	qty_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	qty_input.text_changed.connect(_on_quantity_text_changed.bind(troop_id))

	var plus_button: Button = Button.new()
	plus_button.text = "+"
	plus_button.custom_minimum_size = Vector2(30, 0)
	plus_button.pressed.connect(_on_quantity_adjust.bind(troop_id, 1))

	var cost_label: Label = Label.new()
	cost_label.text = "= 0 PACs"

	adjuster_container.add_child(minus_button)
	adjuster_container.add_child(qty_input)
	adjuster_container.add_child(plus_button)
	adjuster_container.add_child(cost_label)

	var node_data: Dictionary = {
		"container": container,
		"name_button": name_button,
		"details_container": details_container,
		"qty_input": qty_input,
		"cost_label": cost_label,
		"stock_label": stock_label,
		"troop_type": troop_type
	}

	troop_row_nodes[troop_id] = node_data

func _on_troop_row_clicked(troop_id: StringName) -> void:
	if not troop_row_nodes.has(troop_id):
		return

	var node_data: Dictionary = troop_row_nodes[troop_id]
	var details: VBoxContainer = node_data.get("details_container")

	if details != null:
		details.visible = not details.visible

func _on_quantity_adjust(troop_id: StringName, delta: int) -> void:
	var current_qty: int = recruitment_cart.get(troop_id, 0)
	var new_qty: int = current_qty + delta
	_update_cart_for_troop(troop_id, new_qty)

func _on_quantity_text_changed(new_text: String, troop_id: StringName) -> void:
	if new_text.is_empty():
		return

	var new_qty: int = new_text.to_int()
	_update_cart_for_troop(troop_id, new_qty)

func _get_hub_stock(troop_id: StringName) -> int:
	if current_hub == null or current_hub.state == null:
		return 0
	return current_hub.state.troop_stock.get(troop_id, 0)

func _update_cart_for_troop(troop_id: StringName, new_qty: int) -> void:
	if not troop_row_nodes.has(troop_id):
		return

	if current_bus == null or current_bus.charactersheet == null:
		return

	var sheet: CharacterSheet = current_bus.charactersheet
	var current_troop_count: int = sheet.get_total_troop_count()
	var max_capacity: int = sheet.max_troop_capacity

	var total_cart_qty: int = 0
	for qty: int in recruitment_cart.values():
		total_cart_qty += qty

	var available_capacity: int = max_capacity - current_troop_count

	var hub_stock: int = _get_hub_stock(troop_id)
	var max_can_recruit: int = mini(available_capacity + recruitment_cart.get(troop_id, 0), hub_stock)

	var clamped_qty: int = clampi(new_qty, 0, max_can_recruit)

	recruitment_cart[troop_id] = clamped_qty

	if clamped_qty == 0:
		recruitment_cart.erase(troop_id)

	var node_data: Dictionary = troop_row_nodes[troop_id]
	var qty_input: LineEdit = node_data.get("qty_input")
	if qty_input != null:
		qty_input.text = str(clamped_qty)

	var troop_type: TroopType = node_data.get("troop_type")
	if troop_type != null:
		var cost: int = clamped_qty * troop_type.recruitment_cost
		var cost_label: Label = node_data.get("cost_label")
		if cost_label != null:
			cost_label.text = "= %d PACs" % cost

	var stock_label: Label = node_data.get("stock_label")
	if stock_label != null:
		stock_label.text = "Available: %d" % _get_hub_stock(troop_id)

	_update_total_cost()
	_update_player_info()

func _update_total_cost() -> void:
	if total_cost_label == null:
		return

	var total_cost: int = 0

	var troop_db: Node = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return

	for troop_id: StringName in recruitment_cart.keys():
		var qty: int = recruitment_cart.get(troop_id, 0)
		var troop_type: TroopType = troop_db.get_troop(troop_id)

		if troop_type != null:
			total_cost += qty * troop_type.recruitment_cost

	total_cost_label.text = "Total Cost: %d PACs" % total_cost

	_validate_and_update_confirm_button(total_cost)

func _validate_and_update_confirm_button(total_cost: int) -> void:
	if confirm_button == null or current_bus == null:
		return

	var can_afford: bool = current_bus.money >= total_cost

	confirm_button.disabled = not can_afford or recruitment_cart.is_empty()

	if not can_afford:
		confirm_button.add_theme_color_override("font_color", Color.RED)
	else:
		confirm_button.remove_theme_color_override("font_color")

func _on_confirm_pressed() -> void:
	if current_bus == null or current_bus.charactersheet == null:
		return

	var troop_db: Node = get_node_or_null("/root/TroopDatabase")
	if troop_db == null:
		return

	var recruits: Array[Dictionary] = []
	var total_cost: int = 0

	for troop_id: StringName in recruitment_cart.keys():
		var qty: int = recruitment_cart.get(troop_id, 0)
		if qty <= 0:
			continue

		var hub_stock: int = _get_hub_stock(troop_id)
		if hub_stock < qty:
			continue

		var troop_type: TroopType = troop_db.get_troop(troop_id)
		if troop_type == null:
			continue

		var cost: int = qty * troop_type.recruitment_cost

		if current_bus.money >= cost:
			if current_bus.charactersheet.add_troop(troop_id, qty):
				current_bus.money -= cost
				total_cost += cost

				if current_hub != null and current_hub.state != null:
					current_hub.state.troop_stock[troop_id] = hub_stock - qty

				recruits.append({
					"troop_id": troop_id,
					"quantity": qty,
					"cost": cost
				})

	if recruits.size() > 0:
		recruitment_confirmed.emit(recruits)

	_clear_cart()
	_populate_ui()

func _on_cancel_pressed() -> void:
	recruitment_canceled.emit()
	_clear_cart()
	close_recruitment()
