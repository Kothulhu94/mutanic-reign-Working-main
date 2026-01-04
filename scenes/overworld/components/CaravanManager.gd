extends Node
class_name OverworldCaravanManager

# Dependencies (Injected)
var overworld: Node2D
var map_manager: MapManager
var item_db: ItemDB

# Config
var caravan_scene: PackedScene
var caravan_types: Array[CaravanType] = []
var caravan_spawn_interval: float = 1.0

# State
var caravan_spawn_timer: float = 0.0
var active_caravans: Array[Caravan] = []
var _caravan_type_counters: Dictionary = {}
var caravan_threshold_multipliers: Dictionary = {}

func setup(p_overworld: Node2D, p_map_manager: MapManager, p_item_db: ItemDB, p_caravan_scene: PackedScene, p_caravan_types: Array[CaravanType], p_spawn_interval: float) -> void:
	overworld = p_overworld
	map_manager = p_map_manager
	item_db = p_item_db
	caravan_scene = p_caravan_scene
	caravan_types = p_caravan_types
	caravan_spawn_interval = p_spawn_interval
	
	# Connect Hub Signals
	for h in _get_all_hubs():
		if not h.is_connected("caravan_spawn_requested", self._on_hub_caravan_spawn_requested):
			h.connect("caravan_spawn_requested", self._on_hub_caravan_spawn_requested)
			
	# Connect existing caravans
	for caravan in overworld.get_tree().get_nodes_in_group("caravans"):
		if caravan.has_signal("player_initiated_chase"):
			caravan.player_initiated_chase.connect(overworld._on_chase_initiated)
		
		if caravan is Caravan and caravan.home_hub != null:
			caravan.home_hub.register_caravan(caravan)

func _process(delta: float) -> void:
	# Caravan Spawning Logic for Garage System
	caravan_spawn_timer -= delta
	if caravan_spawn_timer <= 0.0:
		caravan_spawn_timer = caravan_spawn_interval
		
		# Check all hubs for potential trade runs
		var hubs = _get_all_hubs()
		for hub in hubs:
			_try_spawn_caravan_from_hub(hub, hubs)

func _try_spawn_caravan_from_hub(home_hub: Hub, _all_hubs: Array[Hub]) -> void:
	if home_hub == null:
		return

	if home_hub.item_db == null:
		return

	if home_hub.state == null:
		return

	# Check each caravan type to see if hub has surplus of preferred items
	for caravan_type: CaravanType in caravan_types:
		if caravan_type == null:
			continue

		# Get current threshold multiplier for this hub + caravan type
		var key: String = "%s:%s" % [home_hub.state.hub_id, caravan_type.type_id]
		var threshold_multiplier: float = caravan_threshold_multipliers.get(key, 1.0)

		# Check if this hub has surplus of this type's preferred items (with progressive threshold)
		var has_surplus: bool = _hub_has_surplus_for_type(home_hub, caravan_type, threshold_multiplier)
		if not has_surplus:
			continue

		# Request Trade Run (Garage System)
		home_hub.request_trade_run(caravan_type)

		caravan_threshold_multipliers[key] = threshold_multiplier * 5.0

		break # Only spawn one caravan per hub per check

func _on_hub_caravan_spawn_requested(hub: Hub, type: CaravanType) -> void:
	_spawn_caravan(hub, type, _get_all_hubs())

func _hub_has_surplus_for_type(hub: Hub, caravan_type: CaravanType, threshold_multiplier: float = 1.0) -> bool:
	if hub == null or hub.item_db == null or caravan_type == null:
		return false

	var preferred_tags: Array[StringName] = caravan_type.preferred_tags
	if preferred_tags.is_empty():
		return false

	var surplus_threshold: float = 200.0
	if hub.economy_config != null:
		surplus_threshold = hub.economy_config.caravan_surplus_threshold

	# Apply progressive multiplier
	surplus_threshold *= threshold_multiplier

	for item_id: StringName in hub.state.inventory.keys():
		var stock: int = hub.state.inventory.get(item_id, 0)
		if stock <= surplus_threshold:
			continue

		# Check Export Cooldown (Prevent spamming failed exports)
		if hub.has_method("get_export_cooldown"):
			if hub.get_export_cooldown(item_id) > 0.0:
				continue

		# Check if item has any preferred tag
		for tag: StringName in preferred_tags:
			if hub.item_db.has_tag(item_id, tag):
				# Check if hub has positive surplus level
				var has_positive_surplus: bool = false
				if hub.item_db.has_tag(item_id, &"food"):
					has_positive_surplus = hub.food_level > 0.0
				elif hub.item_db.has_tag(item_id, &"material"):
					has_positive_surplus = hub.infrastructure_level > 0.0
				else:
					# For other types (luxury, medical), just check stock
					has_positive_surplus = true


				if has_positive_surplus:
					return true

	return false

func _spawn_caravan(home_hub: Hub, caravan_type: CaravanType, all_hubs: Array[Hub]) -> void:
	if caravan_scene == null:
		return
	
	var caravan: Caravan = caravan_scene.instantiate() as Caravan
	if caravan == null:
		return
	var type_id_str: String = str(caravan_type.type_id)
	var current_count: int = _caravan_type_counters.get(type_id_str, 0) + 1
	_caravan_type_counters[type_id_str] = current_count
	
	# Rename to include Home Hub for clarity in Scene Tree
	caravan.name = "%s_%s_%d" % [home_hub.name, type_id_str, current_count]
	
	var leader_sheet: CharacterSheet = CharacterSheet.new()
	
	# Initialize Trading Skill to Level 5 and distribute perks
	var trading_skill_res: Skill = load("res://data/Skills/Trading.tres")
	if trading_skill_res:
		leader_sheet.add_skill(trading_skill_res)
		var trading_skill: Skill = leader_sheet.get_skill(trading_skill_res.id)
		
		if trading_skill:
			trading_skill.current_level = 5
			trading_skill.perk_points = 5
			
			# Determine Expertise Perk based on Caravan type
			var expertise_perk_id: StringName = StringName()
			match str(caravan_type.type_id):
				"food": expertise_perk_id = &"food_market_expertise"
				"material": expertise_perk_id = &"materials_expertise"
				"luxury": expertise_perk_id = &"luxury_expertise"
				"medicine": expertise_perk_id = &"medicine_expertise"
			
			var target_perks: Array[StringName] = [&"dense_stockpiling", &"efficient_packing"]
			if expertise_perk_id != StringName():
				target_perks.append(expertise_perk_id)
				
			# 1. Ensure at least one point in each target perk (Round-Robin)
			for perk_id in target_perks:
				trading_skill.buy_perk(perk_id)
				
			# 2. Distribute remaining points randomly among the target perks
			while trading_skill.perk_points > 0 and not target_perks.is_empty():
				var random_perk_id: StringName = target_perks.pick_random()
				# Attempt to buy (checks max rank, etc.)
				if not trading_skill.buy_perk(random_perk_id):
					# If failed (e.g. maxed out), remove from rotation to prevent infinite loop
					target_perks.erase(random_perk_id)
	# Create caravan state
	var calculated_money: int = caravan_type.get_starting_money(home_hub.state.base_population_cap)
	# Enforce minimum starting capital (2000 pacs) to prevent "broke" caravans that can't trade
	var starting_money: int = maxi(2000, calculated_money)
	var state: CaravanState = CaravanState.new(home_hub.state.hub_id, StringName(), starting_money, caravan_type, leader_sheet)
	
	# Set surplus threshold from config
	if home_hub.economy_config != null:
		caravan.surplus_threshold = home_hub.economy_config.caravan_surplus_threshold
		caravan.home_tax_rate = home_hub.economy_config.caravan_home_tax_rate

	# Set sprite texture from caravan type
	var sprite: Sprite2D = caravan.get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null and caravan_type.sprite != null:
		sprite.texture = caravan_type.sprite

	# Add to scene FIRST, then setup (setup sets position)
	# Add as child of Overworld to maintain hierarchy expectation
	overworld.add_child(caravan)
	caravan.setup(home_hub, state, item_db, all_hubs, map_manager)
	active_caravans.append(caravan)
	
	# Register with Fleet
	home_hub.register_caravan(caravan)

	# Connect combat and cleanup signals
	# Note: Calling overworld._on_chase_initiated requires access
	if overworld.has_method("_on_chase_initiated"):
		caravan.player_initiated_chase.connect(overworld._on_chase_initiated)
	
	caravan.tree_exited.connect(_on_caravan_removed.bind(caravan))

func _on_caravan_removed(caravan: Caravan) -> void:
	active_caravans.erase(caravan)

	# Reset threshold multiplier when caravan is destroyed (e.g., combat)
	# Caravans normally persist forever and loop between hubs
	if caravan.home_hub != null and caravan.caravan_state != null and caravan.caravan_state.caravan_type != null:
		var key: String = "%s:%s" % [caravan.home_hub.state.hub_id, caravan.caravan_state.caravan_type.type_id]
		caravan_threshold_multipliers[key] = 1.0

func _get_all_hubs() -> Array[Hub]:
	var hubs: Array[Hub] = []
	if overworld == null:
		return hubs
	
	# 1. Check Root Children
	for child in overworld.get_children():
		if child is Hub:
			hubs.append(child as Hub)
			
	# 2. Check MapScenery Children (Common user placement)
	var map_scenery = overworld.get_node_or_null("MapScenery")
	if map_scenery:
		for child in map_scenery.get_children():
			if child is Hub:
				hubs.append(child as Hub)
	
	return hubs
