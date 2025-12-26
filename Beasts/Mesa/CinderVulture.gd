class_name CinderVulture extends Beast

## T3 Mesa - Cinder Vulture
## Circles high and flags movement, dive strikes
## Future: +30% threat detection radius (patrols/encounters)

const BASE_HEALTH: int = 60
const BASE_DAMAGE: int = 18
const BASE_DEFENSE: int = 12

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 110.0
	ai_behavior = "hunt_caravans"
