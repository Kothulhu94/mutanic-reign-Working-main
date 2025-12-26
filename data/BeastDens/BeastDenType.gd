class_name BeastDenType extends Resource

## Resource defining configuration for a Beast Den type
## Similar to CaravanType, allows data-driven den variety creation

@export var den_name: String = "Beast Den"

## Scene to spawn during normal operation
@export var normal_beast_scene: PackedScene

## Scene to spawn during emergency (low health)
@export var emergency_beast_scene: PackedScene

## How many ticks between spawns (lower = faster spawning)
@export var spawn_interval_ticks: float = 10.0

## How many beasts to spawn in emergency burst
@export var emergency_spawn_count: int = 3

## Health percentage threshold to trigger emergency spawning (0.0-1.0)
@export var emergency_health_threshold: float = 0.5

## Den health pool
@export var base_health: int = 200

## Den combat stats (for when attacked)
@export var base_damage: int = 5
@export var base_defense: int = 10

## Maximum number of beasts this den can have active at once (0 = unlimited)
@export var max_active_beasts: int = 10

## Radius of the navigation obstacle/hole for this den type
@export var obstacle_radius: float = 45.0
