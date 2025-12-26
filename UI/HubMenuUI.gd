## HubMenuUI - Main popup menu for hub interactions
## Shows when player Bus enters a hub area for the first time or clicks directly on hub
extends Control
class_name HubMenuUI

signal menu_closed()
signal market_opened()
signal recruitment_opened()

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var options_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/OptionsContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

var current_hub: Hub = null

func _ready() -> void:
	# Hide by default
	hide()

	# Connect close button
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)

	# Make sure we process input
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Close menu on ESC key
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_menu()

## Opens the menu for a specific hub
func open_menu(hub: Hub) -> void:
	if hub == null:
		push_error("HubMenuUI: Cannot open menu for null hub")
		return

	current_hub = hub

	# Update title
	if title_label != null and hub.state != null:
		title_label.text = hub.state.display_name

	# Show menu and pause game
	show()
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("pause"):
		timekeeper.pause()

## Closes the menu and resumes game
func close_menu() -> void:
	hide()

	# Resume game
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("resume"):
		timekeeper.resume()

	menu_closed.emit()
	current_hub = null

func _on_close_pressed() -> void:
	close_menu()

func _on_market_pressed() -> void:
	# Signal that market should be opened
	market_opened.emit()
	# Don't fully close - just hide and let market UI take over
	hide()
	# Note: current_hub is kept so we know this menu was open

func _on_recruitment_pressed() -> void:
	# Signal that recruitment should be opened
	recruitment_opened.emit()
	# Don't fully close - just hide and let recruitment UI take over
	hide()
	# Note: current_hub is kept so we know this menu was open
