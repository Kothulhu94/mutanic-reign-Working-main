class_name RippleLeviathan extends Beast

## T3 Lake - Ripple Leviathan
## Barometric ears warn of squalls, escorts around whitecaps
## Future: Can travel on water

const BASE_HEALTH: int = 80
const BASE_DAMAGE: int = 18
const BASE_DEFENSE: int = 14

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 90.0
	ai_behavior = "territorial"
