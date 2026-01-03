# InventoryUI.gd
extends Control

signal inventory_closed()

@onready var money_label: Label = %MoneyLabel
@onready var item_list_container: VBoxContainer = %ItemListContainer
@onready var close_button: Button = %CloseButton

var item_db: ItemDB = null

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)

	# Load the ItemDB resource
	item_db = load("res://data/Items/ItemsCatalog.tres") as ItemDB
	if item_db == null:
		push_warning("InventoryUI: ItemDB resource not found")

func display_inventory() -> void:
	# Find the Bus in the scene
	var bus: Bus = get_tree().get_first_node_in_group("player") as Bus
	if bus == null:
		push_error("InventoryUI: No Bus found in 'player' group")
		return

	# Clear existing items
	for child in item_list_container.get_children():
		child.queue_free()

	# Display money
	money_label.text = "Pacs: %d" % bus.pacs

	# Display inventory items
	if bus.inventory.is_empty():
		var no_items_label: Label = Label.new()
		no_items_label.text = "No items in inventory"
		no_items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item_list_container.add_child(no_items_label)
	else:
		for item_id in bus.inventory.keys():
			var amount: int = bus.inventory[item_id]
			_create_item_row(item_id, amount)

	show()

func _create_item_row(item_id: StringName, amount: int) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 30)

	# Get item definition for display name and tags
	var item_def: ItemDef = null
	if item_db != null:
		item_def = item_db.get_item(item_id)

	var display_text: String = ""
	if item_def != null:
		# Format: [Display Name] x[Amount] - Tags: [tag1, tag2, ...]
		var tags_str: String = ""
		if item_def.tags.size() > 0:
			tags_str = " - Tags: " + ", ".join(item_def.tags)
		display_text = "%s x%d%s" % [item_def.display_name, amount, tags_str]
	else:
		# Fallback if item definition not found
		display_text = "%s x%d" % [item_id, amount]

	var item_label: Label = Label.new()
	item_label.text = display_text
	item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(item_label)
	item_list_container.add_child(row)

func _on_close_pressed() -> void:
	hide()
	inventory_closed.emit()
