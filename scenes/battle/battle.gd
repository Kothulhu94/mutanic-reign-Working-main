extends Node3D
func _ready() -> void:
	print("Battle stub loaded (press confirm to return)")

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("confirm"):
		SceneLoader.goto_overworld()
