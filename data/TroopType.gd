extends Resource
class_name TroopType

## Defines a type of military unit that can be recruited
## Troops provide flat bonuses to health, damage, and defense

## Display name for the troop type
@export var troop_name: String = ""

## Description of the troop
@export_multiline var description: String = ""

## Tier of the troop (1-4)
@export var tier: int = 1

## Archetype category (Balanced, Striker, Tank, Defender, Assault, Support, Brawler)
@export var archetype: String = ""

## Cost in money to recruit one unit
@export var recruitment_cost: int = 10

## Health bonus per troop (can be negative)
@export var health_bonus: int = 0

## Damage bonus per troop (can be negative)
@export var damage_bonus: int = 0

## Defense bonus per troop (can be negative)
@export var defense_bonus: int = 0
