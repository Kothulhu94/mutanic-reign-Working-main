extends Node

## Singleton database for managing all troop types
## Accessible via get_node("/root/TroopDatabase")

## Dictionary mapping troop_id (StringName) to TroopType resource
var troops: Dictionary = {}

func _ready() -> void:
	_register_all_troops()

## Registers all available troop types
func _register_all_troops() -> void:
	var aegis_warden: TroopType = load("res://data/troops/aegis_warden.tres")
	register_troop(&"aegis_warden", aegis_warden)

	var apex_predator: TroopType = load("res://data/troops/apex_predator.tres")
	register_troop(&"apex_predator", apex_predator)

	var avatar_of_war: TroopType = load("res://data/troops/avatar_of_war.tres")
	register_troop(&"avatar_of_war", avatar_of_war)

	var bastion_titan: TroopType = load("res://data/troops/bastion_titan.tres")
	register_troop(&"bastion_titan", bastion_titan)

	var brawler: TroopType = load("res://data/troops/brawler.tres")
	register_troop(&"brawler", brawler)

	var chrono_warden: TroopType = load("res://data/troops/chrono_warden.tres")
	register_troop(&"chrono_warden", chrono_warden)

	var combat_engineer: TroopType = load("res://data/troops/combat_engineer.tres")
	register_troop(&"combat_engineer", combat_engineer)

	var colossus: TroopType = load("res://data/troops/colossus.tres")
	register_troop(&"colossus", colossus)

	var cyborg_commando: TroopType = load("res://data/troops/cyborg_commando.tres")
	register_troop(&"cyborg_commando", cyborg_commando)

	var dreadnought: TroopType = load("res://data/troops/dreadnought.tres")
	register_troop(&"dreadnought", dreadnought)

	var enforcer: TroopType = load("res://data/troops/enforcer.tres")
	register_troop(&"enforcer", enforcer)

	var field_medic: TroopType = load("res://data/troops/field_medic.tres")
	register_troop(&"field_medic", field_medic)

	var infiltrator: TroopType = load("res://data/troops/infiltrator.tres")
	register_troop(&"infiltrator", infiltrator)

	var juggernaut: TroopType = load("res://data/troops/juggernaut.tres")
	register_troop(&"juggernaut", juggernaut)

	var leviathan: TroopType = load("res://data/troops/leviathan.tres")
	register_troop(&"leviathan", leviathan)

	var marine: TroopType = load("res://data/troops/marine.tres")
	register_troop(&"marine", marine)

	var militia: TroopType = load("res://data/troops/militia.tres")
	register_troop(&"militia", militia)

	var obliterator: TroopType = load("res://data/troops/obliterator.tres")
	register_troop(&"obliterator", obliterator)

	var paladin: TroopType = load("res://data/troops/paladin.tres")
	register_troop(&"paladin", paladin)

	var phalanx_unit: TroopType = load("res://data/troops/phalanx_unit.tres")
	register_troop(&"phalanx_unit", phalanx_unit)

	var psionic_overlord: TroopType = load("res://data/troops/psionic_overlord.tres")
	register_troop(&"psionic_overlord", psionic_overlord)

	var recruit: TroopType = load("res://data/troops/recruit.tres")
	register_troop(&"recruit", recruit)

	var revenant_assassin: TroopType = load("res://data/troops/revenant_assassin.tres")
	register_troop(&"revenant_assassin", revenant_assassin)

	var riot_guard: TroopType = load("res://data/troops/riot_guard.tres")
	register_troop(&"riot_guard", riot_guard)

	var scout: TroopType = load("res://data/troops/scout.tres")
	register_troop(&"scout", scout)

	var sentinel: TroopType = load("res://data/troops/sentinel.tres")
	register_troop(&"sentinel", sentinel)

	var shieldbearer: TroopType = load("res://data/troops/shieldbearer.tres")
	register_troop(&"shieldbearer", shieldbearer)

	var shock_trooper: TroopType = load("res://data/troops/shock_trooper.tres")
	register_troop(&"shock_trooper", shock_trooper)

	var sniper: TroopType = load("res://data/troops/sniper.tres")
	register_troop(&"sniper", sniper)

	var thug: TroopType = load("res://data/troops/thug.tres")
	register_troop(&"thug", thug)

	var vanguard: TroopType = load("res://data/troops/vanguard.tres")
	register_troop(&"vanguard", vanguard)

	var void_hunter: TroopType = load("res://data/troops/void_hunter.tres")
	register_troop(&"void_hunter", void_hunter)

	var war_droid: TroopType = load("res://data/troops/war_droid.tres")
	register_troop(&"war_droid", war_droid)

	var watchman: TroopType = load("res://data/troops/watchman.tres")
	register_troop(&"watchman", watchman)

	var wraith_operative: TroopType = load("res://data/troops/wraith_operative.tres")
	register_troop(&"wraith_operative", wraith_operative)

## Registers a troop type with the database
func register_troop(troop_id: StringName, troop_type: TroopType) -> void:
	if troops.has(troop_id):
		push_warning("TroopDatabase: Troop '%s' already registered, overwriting" % troop_id)
	troops[troop_id] = troop_type

## Gets a troop type by ID, returns null if not found
func get_troop(troop_id: StringName) -> TroopType:
	return troops.get(troop_id, null)

## Returns all registered troop types as an array
func get_all_troops() -> Array[TroopType]:
	var result: Array[TroopType] = []
	for troop_type: TroopType in troops.values():
		result.append(troop_type)
	return result

## Returns all troop IDs in alphabetical order
func get_all_troop_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for troop_id: StringName in troops.keys():
		result.append(troop_id)
	result.sort()
	return result

## Returns the tier (1-4) of a troop
func get_tier(troop_id: StringName) -> int:
	var troop: TroopType = get_troop(troop_id)
	return troop.tier if troop != null else 0

## Returns the archetype name of a troop
func get_archetype(troop_id: StringName) -> String:
	var troop: TroopType = get_troop(troop_id)
	return troop.archetype if troop != null else ""

## Returns all troop IDs of a specific tier
func get_troops_by_tier(tier: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for troop_id: StringName in troops.keys():
		if get_tier(troop_id) == tier:
			result.append(troop_id)
	return result

## Returns the upgrade target for a troop (next tier, same archetype)
func get_upgrade_target(troop_id: StringName) -> StringName:
	var troop: TroopType = get_troop(troop_id)
	if troop == null or troop.tier >= 4:
		return StringName()

	var target_tier: int = troop.tier + 1
	var archetype: String = troop.archetype

	for other_id: StringName in troops.keys():
		var other: TroopType = get_troop(other_id)
		if other != null and other.tier == target_tier and other.archetype == archetype:
			return other_id

	return StringName()

## Returns T1 troop ID for a given archetype
func get_t1_troop_for_archetype(archetype: String) -> StringName:
	for troop_id: StringName in troops.keys():
		var troop: TroopType = get_troop(troop_id)
		if troop != null and troop.tier == 1 and troop.archetype == archetype:
			return troop_id
	return StringName()

## Returns all 7 archetype names
func get_all_archetypes() -> Array[String]:
	var archetypes: Dictionary = {}
	for troop: TroopType in troops.values():
		if troop != null and troop.archetype != "" and troop.tier == 1:
			archetypes[troop.archetype] = true
	var result: Array[String] = []
	for arch in archetypes.keys():
		result.append(arch)
	result.sort()
	return result
