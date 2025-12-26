class_name GlassfinSwarm extends Beast

## T1 Lake - Glassfin Swarm
## Razor minnows corral fish to shore
## Future: +30% rations from lakeshores (fishing/scavenge)

const BASE_HEALTH: int = 12
const BASE_DAMAGE: int = 6
const BASE_DEFENSE: int = 2

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 100.0
	ai_behavior = "roam"
