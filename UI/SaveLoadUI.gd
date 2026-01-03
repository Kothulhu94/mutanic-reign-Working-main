extends Control
class_name SaveLoadUI

signal save_load_closed()

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var slot_list_container: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/SlotListContainer
@onready var new_slot_input: LineEdit = $Panel/VBoxContainer/NewSlotContainer/NewSlotInput
@onready var create_slot_button: Button = $Panel/VBoxContainer/NewSlotContainer/CreateSlotButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton

enum Mode {SAVE, LOAD}
var current_mode: Mode = Mode.SAVE

func _ready() -> void:
	hide()

	if create_slot_button != null:
		create_slot_button.pressed.connect(_on_create_slot_pressed)

	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	if new_slot_input != null:
		new_slot_input.text_submitted.connect(_on_slot_name_submitted)

func open_save_menu() -> void:
	current_mode = Mode.SAVE
	if title_label != null:
		title_label.text = "Save Game"
	_refresh_slot_list()
	show()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

func open_load_menu() -> void:
	current_mode = Mode.LOAD
	if title_label != null:
		title_label.text = "Load Game"
	_refresh_slot_list()
	show()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

func close_menu() -> void:
	hide()

	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

	save_load_closed.emit()

func _refresh_slot_list() -> void:
	if slot_list_container == null:
		return

	for child: Node in slot_list_container.get_children():
		child.queue_free()

	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	var slots: Array[String] = save_manager.list_save_slots()

	if slots.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "No save files found"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_list_container.add_child(empty_label)
		return

	for slot_name: String in slots:
		_create_slot_row(slot_name)

func _create_slot_row(slot_name: String) -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	var info: Dictionary = save_manager.get_save_info(slot_name)

	var row_container: HBoxContainer = HBoxContainer.new()
	row_container.set("theme_override_constants/separation", 10)

	var info_container: VBoxContainer = VBoxContainer.new()
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label: Label = Label.new()
	name_label.text = "Slot: %s" % slot_name
	name_label.add_theme_font_size_override("font_size", 16)
	info_container.add_child(name_label)

	if info.has("player_name"):
		var player_label: Label = Label.new()
		player_label.text = "Character: %s (Level %d)" % [info.get("player_name", "Unknown"), info.get("player_level", 1)]
		player_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		info_container.add_child(player_label)

	if info.has("player_pacs"):
		var money_label: Label = Label.new()
		money_label.text = "Pacs: %d" % info.get("player_pacs", 0)
		money_label.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		info_container.add_child(money_label)

	if info.has("modified_time"):
		var time_dict: Dictionary = Time.get_datetime_dict_from_unix_time(info.get("modified_time", 0))
		var time_label: Label = Label.new()
		time_label.text = "Last Modified: %04d-%02d-%02d %02d:%02d" % [
			time_dict.year, time_dict.month, time_dict.day,
			time_dict.hour, time_dict.minute
		]
		time_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		info_container.add_child(time_label)

	row_container.add_child(info_container)

	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(80, 0)

	if current_mode == Mode.SAVE:
		action_button.text = "Overwrite"
		action_button.pressed.connect(_on_save_to_slot.bind(slot_name))
	else:
		action_button.text = "Load"
		action_button.pressed.connect(_on_load_from_slot.bind(slot_name))

	row_container.add_child(action_button)

	var delete_button: Button = Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(80, 0)
	delete_button.pressed.connect(_on_delete_slot.bind(slot_name))
	row_container.add_child(delete_button)

	var separator: HSeparator = HSeparator.new()

	slot_list_container.add_child(row_container)
	slot_list_container.add_child(separator)

func _on_create_slot_pressed() -> void:
	if new_slot_input == null:
		return

	var slot_name: String = new_slot_input.text.strip_edges()
	_create_new_save(slot_name)

func _on_slot_name_submitted(slot_name: String) -> void:
	_create_new_save(slot_name.strip_edges())

func _create_new_save(slot_name: String) -> void:
	if slot_name.is_empty():
		return

	if current_mode != Mode.SAVE:
		return

	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	if save_manager.save_game(slot_name):
		new_slot_input.text = ""
		_refresh_slot_list()

func _on_save_to_slot(slot_name: String) -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	if save_manager.save_game(slot_name):
		_refresh_slot_list()

func _on_load_from_slot(slot_name: String) -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	if save_manager.load_game(slot_name):
		close_menu()

func _on_delete_slot(slot_name: String) -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return

	if save_manager.delete_save(slot_name):
		_refresh_slot_list()

func _on_close_pressed() -> void:
	close_menu()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()
