class_name SunspineRam extends Beast

## T2 Mesa - Sunspine Ram
## Knows switchbacks and ledges, ramming charge
## Future: -20% slope/climb movement penalty

const BASE_HEALTH: int = 35
const BASE_DAMAGE: int = 9
const BASE_DEFENSE: int = 7

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 85.0
	ai_behavior = "territorial"
