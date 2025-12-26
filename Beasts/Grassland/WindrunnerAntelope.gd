class_name WindrunnerAntelope extends Beast

## T2 Grassland - Windrunner Antelope
## Built for endurance, finds the firmest track
## Future: +8% road travel speed

const BASE_HEALTH: int = 40
const BASE_DAMAGE: int = 8
const BASE_DEFENSE: int = 5

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 120.0
	ai_behavior = "roam"
