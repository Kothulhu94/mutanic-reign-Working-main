class_name ThornbackBoar extends Beast

## T1 Forest - Thornback Boar
## Rooters expose tubers and grubs, bristled hide
## Future: +20% forage yield (rations/edibles)

const BASE_HEALTH: int = 20
const BASE_DAMAGE: int = 5
const BASE_DEFENSE: int = 3

func _ready() -> void:
	super._ready()
	initialize_charactersheet(BASE_HEALTH, BASE_DAMAGE, BASE_DEFENSE)
	movement_speed = 75.0
	ai_behavior = "roam"
