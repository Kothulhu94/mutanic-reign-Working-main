class_name BasaltScuttlers extends Beast

## T1 Mesa - Basalt Scuttlers
## Carapace picks up trace vibrations, points to mineral veins
## Future: +25% ore/mineral node detection

const BASE_HEALTH: int = 18
const BASE_DAMAGE: int = 4
const BASE_DEFENSE: int = 4

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 70.0
	ai_behavior = "roam"
