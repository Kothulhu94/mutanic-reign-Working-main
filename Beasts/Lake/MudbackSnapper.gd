class_name MudbackSnapper extends Beast

## T2 Lake - Mudback Snapper
## Wide plastron tests safe footing, shell turns mishaps into shrugs
## Future: +10% shoreline travel speed (bog/mud)

const BASE_HEALTH: int = 45
const BASE_DAMAGE: int = 9
const BASE_DEFENSE: int = 12

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 65.0
	ai_behavior = "territorial"
