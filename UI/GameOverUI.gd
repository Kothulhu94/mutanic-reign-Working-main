extends Control
class_name GameOverUI

@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

func _ready() -> void:
	hide()

	if restart_button != null:
		restart_button.pressed.connect(_on_restart_pressed)

	if quit_button != null:
		quit_button.pressed.connect(_on_quit_pressed)

func show_game_over() -> void:
	show()

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
