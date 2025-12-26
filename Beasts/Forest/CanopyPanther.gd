class_name CanopyPanther extends Beast

## T3 Forest - Canopy Panther
## Shadow-silent sentry, spots snare lines and kill-zones
## Future: -25% ambush chance while traveling

const BASE_HEALTH: int = 50
const BASE_DAMAGE: int = 20
const BASE_DEFENSE: int = 12

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 130.0
	ai_behavior = "hunt_player"
