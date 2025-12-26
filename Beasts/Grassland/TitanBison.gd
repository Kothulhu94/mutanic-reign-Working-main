class_name TitanBison extends Beast

## T3 Grassland - Titan Bison
## Living freight hauler with bone-plated shoulders
## Future: +20% inventory capacity

const BASE_HEALTH: int = 80
const BASE_DAMAGE: int = 12
const BASE_DEFENSE: int = 14

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 60.0
	ai_behavior = "territorial"
