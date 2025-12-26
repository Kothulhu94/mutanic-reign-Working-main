# PauseMenu.gd
extends CanvasLayer

@onready var resume_button: Button = %ResumeButton
@onready var character_sheet_button: Button = %CharacterSheetButton
@onready var inventory_button: Button = %InventoryButton
@onready var save_button: Button = %SaveButton
@onready var load_button: Button = %LoadButton
@export var character_sheet_scene: PackedScene
@export var inventory_ui_scene: PackedScene
@export var save_load_ui_scene: PackedScene
var character_sheet_instance: Control = null
var inventory_ui_instance: Control = null
var save_load_ui_instance: Control = null# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Don't hide the CanvasLayer - instead hide the ColorRect child
	# CanvasLayers need to stay visible to receive input
	$ColorRect.hide()
	# Connect button signals
	resume_button.pressed.connect(_on_resume_pressed)
	character_sheet_button.pressed.connect(_on_character_sheet_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	save_button.pressed.connect(_on_save_pressed)
	load_button.pressed.connect(_on_load_pressed)

	_setup_inventory_ui()
	_setup_save_load_ui()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Use Input polling instead of _input() event handling
	# This is more reliable for autoloaded CanvasLayers
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()


func _pause_game() -> void:
	# Pause the scene tree
	get_tree().paused = true
	# Show the pause menu (show the ColorRect, not the CanvasLayer)
	$ColorRect.show()


func _resume_game() -> void:
	# Resume the scene tree
	get_tree().paused = false
	# Hide the pause menu (hide the ColorRect, not the CanvasLayer)
	$ColorRect.hide()
	# Hide the Character Sheet UI if it's open
	if character_sheet_instance != null:
		character_sheet_instance.hide()
	# Hide the Inventory UI if it's open
	if inventory_ui_instance != null:
		inventory_ui_instance.hide()


func _on_resume_pressed() -> void:
	_resume_game()


func _on_character_sheet_pressed() -> void:
	# Find the player in the scene
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		push_error("PauseMenu: No player found in 'player' group")
		return

	# Get the player's character sheet (Godot 4 uses "property" in player instead of has())
	if not "charactersheet" in player:
		push_error("PauseMenu: Player does not have a 'charactersheet' property")
		return

	var character_sheet: CharacterSheet = player.charactersheet
	if character_sheet == null:
		push_error("PauseMenu: Player's charactersheet is null")
		return

	# Instantiate the character sheet UI if needed
	if character_sheet_instance == null and character_sheet_scene:
		character_sheet_instance = character_sheet_scene.instantiate()
		add_child(character_sheet_instance)

	# Display the character sheet
	if character_sheet_instance != null and character_sheet_instance.has_method("display_sheet"):
		character_sheet_instance.display_sheet(character_sheet)

func _setup_inventory_ui() -> void:
	if inventory_ui_scene != null:
		inventory_ui_instance = inventory_ui_scene.instantiate() as Control
		add_child(inventory_ui_instance)
		inventory_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		inventory_ui_instance.hide()

func _on_inventory_pressed() -> void:
	if inventory_ui_instance == null:
		push_error("PauseMenu: inventory_ui_instance is null!")
		return

	$ColorRect.hide()
	if inventory_ui_instance.has_method("display_inventory"):
		inventory_ui_instance.display_inventory()
	if not inventory_ui_instance.inventory_closed.is_connected(_on_inventory_closed):
		inventory_ui_instance.inventory_closed.connect(_on_inventory_closed)

func _on_inventory_closed() -> void:
	if inventory_ui_instance != null and inventory_ui_instance.inventory_closed.is_connected(_on_inventory_closed):
		inventory_ui_instance.inventory_closed.disconnect(_on_inventory_closed)
	$ColorRect.show()

func _setup_save_load_ui() -> void:
	if save_load_ui_scene != null:
		save_load_ui_instance = save_load_ui_scene.instantiate() as Control
		add_child(save_load_ui_instance)
		save_load_ui_instance.process_mode = Node.PROCESS_MODE_ALWAYS
		save_load_ui_instance.hide()

func _on_save_pressed() -> void:
	if save_load_ui_instance == null:
		push_error("PauseMenu: save_load_ui_instance is null!")
		return

	$ColorRect.hide()
	save_load_ui_instance.open_save_menu()
	if not save_load_ui_instance.save_load_closed.is_connected(_on_save_load_closed):
		save_load_ui_instance.save_load_closed.connect(_on_save_load_closed)

func _on_load_pressed() -> void:
	if save_load_ui_instance == null:
		push_error("PauseMenu: save_load_ui_instance is null!")
		return

	$ColorRect.hide()
	save_load_ui_instance.open_load_menu()
	if not save_load_ui_instance.save_load_closed.is_connected(_on_save_load_closed):
		save_load_ui_instance.save_load_closed.connect(_on_save_load_closed)

func _on_save_load_closed() -> void:
	if save_load_ui_instance != null and save_load_ui_instance.save_load_closed.is_connected(_on_save_load_closed):
		save_load_ui_instance.save_load_closed.disconnect(_on_save_load_closed)
	$ColorRect.show()
