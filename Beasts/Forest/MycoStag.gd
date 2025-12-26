class_name MycoStag extends Beast

## T2 Forest - Myco Stag
## Symbiotic antlers host biolumyn lichens, glow near curatives
## Future: +25% medicinal herb/fungus detection

const BASE_HEALTH: int = 35
const BASE_DAMAGE: int = 8
const BASE_DEFENSE: int = 9

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 95.0
	ai_behavior = "roam"
