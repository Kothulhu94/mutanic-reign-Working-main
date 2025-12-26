extends Control
class_name ActorHealthVisual

@onready var health_label: Label = $ColorRect/HealthLabel

## Updates the health display with current and max HP
func update_health(current_hp: int, max_hp: int) -> void:
	if max_hp == 0:
		health_label.text = "0%"
		health_label.add_theme_color_override("font_color", Color.RED)
		return

	var percent: float = float(current_hp) / float(max_hp)
	health_label.text = "%d%%" % int(percent * 100.0)

	if percent > 0.66:
		health_label.add_theme_color_override("font_color", Color.GREEN)
	elif percent > 0.33:
		health_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		health_label.add_theme_color_override("font_color", Color.RED)
