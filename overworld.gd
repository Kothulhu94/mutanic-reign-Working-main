extends Node2D

@export var bus_scene: PackedScene = preload("uid://c14uenn8n47fb")
@export var camera_scene: PackedScene = preload("uid://ckanwjybdtmp4")
@export var caravan_scene: PackedScene = preload("uid://bgbook0avqvjl")

@export var map_origin: Vector2 = Vector2.ZERO
@export var map_size: Vector2 = Vector2(16384, 16384)

@export var bus_spawn_point: Vector2 = Vector2(6000, 10830)

const NAV_LAYERS: int = 1 # keep in lockstep with the NavigationAgent2D

# How close to a waypoint counts as "consumed"
@export var path_trim_tolerance: float = 2.0

# Caravan system
@export var item_db: ItemDB
@export var caravan_types: Array[CaravanType] = []
@export var caravan_spawn_interval: float = 1.0 # Check for spawning every 30 seconds
var caravan_spawn_timer: float = 0.0
var active_caravans: Array[Caravan] = []
var _caravan_type_counters: Dictionary = {}
# Track threshold multipliers per hub per caravan type
# Key format: "hub_id:caravan_type_id" -> multiplier
var caravan_threshold_multipliers: Dictionary = {}

var bus: CharacterBody2D
var cam: Camera2D

var _path_world: PackedVector2Array = PackedVector2Array()
var _is_paused: bool = false
@onready var path_line: Line2D = get_node_or_null("PathLine")

var _player_bus: Bus
var _encounter_ui: Control
var _market_ui: MarketUI # Generic market UI for caravan trading
var _loot_ui: Control
var _game_over_ui: Control

# Grid-Based Pathfinding
var map_manager: MapManager
var _target_actor: Node2D = null # Track target for cleanup

func _ready() -> void:
	# Robustness: Reload defaults if Inspector overrides set them to null
	if bus_scene == null:
		bus_scene = load("uid://c14uenn8n47fb")
	if camera_scene == null:
		camera_scene = load("uid://ckanwjybdtmp4")
	if caravan_scene == null:
		caravan_scene = load("uid://bgbook0avqvjl")

	# Initialize MapLoader to load chunked map
	# Initialize MapLoader to load chunked map
	var map_loader = MapLoader.new()
	if map_loader:
		map_loader.name = "MapLoader"
		
		# Fix Scaling: Add MapLoader to the 6x Scaled "MapScenery" node if it exists
		var map_scenery = get_node_or_null("MapScenery")
		if map_scenery:
			map_scenery.add_child(map_loader)
		else:
			add_child(map_loader)
			
		# Ensure map is behind everything (in its parent)
		map_loader.get_parent().move_child(map_loader, 0)


	# Cleanup Editor Map logic is now handled by the EditorMapLoader script itself.


	# Find MapManager (Now potentially inside MapScenery)
	map_manager = get_node_or_null("MapScenery/MapManager") as MapManager
	if map_manager == null:
		# Fallback checking root
		map_manager = get_node_or_null("MapManager") as MapManager
		
	if map_manager == null:
		push_warning("Overworld: MapManager node not found! Please create it.")

	if path_line == null:
		path_line = Line2D.new()
		path_line.name = "PathLine"
		path_line.width = 3.0
		add_child(path_line)
	path_line.visible = false

	# 1. Check for Bus in scene (Editor-placed) accounting for user placing it in MapScenery
	var existing_bus = get_node_or_null("Bus")
	if not existing_bus:
		existing_bus = get_node_or_null("MapScenery/Bus")
	if not existing_bus:
		# In case it's named Generic "CharacterBody2D" in root
		existing_bus = get_node_or_null("CharacterBody2D")
	if not existing_bus:
		# In case it's named Generic "CharacterBody2D" (common when dragging in)
		existing_bus = get_node_or_null("MapScenery/CharacterBody2D")
		
	var final_position: Vector2
	
	if existing_bus:
		bus = existing_bus as CharacterBody2D
		_player_bus = bus as Bus
		
		# Fix Scaling: Checked. Bus is now correctly placed in root (overworld.tscn).
		# No need to reparent or scale-fix.
		if bus.get_parent() != self:
			push_warning("Overworld: Bus found in %s, should be in Root." % bus.get_parent().name)
			bus.reparent(self, true)
			# We assume scale is correct IF it was just misplaced, but ideally fix the scene.
			
		final_position = bus.global_position
	else:
		# 2. Fallback: Spawn Bus programmatically
		bus = bus_scene.instantiate() as CharacterBody2D
		
		# If we spawn it, put it in MapScenery for correct scaling consistency? 
		# No, existing code put it in Root. Let's keep Root for now unless we want to change that.
		# Actually, user put theirs in MapScenery. Let's check MapScenery existence.
		var map_scenery = get_node_or_null("MapScenery")
		if map_scenery:
			map_scenery.add_child(bus)
		else:
			add_child(bus)
			
		_player_bus = bus as Bus
		
		# Set position
		final_position = map_origin + bus_spawn_point
		bus.global_position = final_position
	
	# Dependency Injection: Give Bus the MapManager directly
	if _player_bus != null:
		_player_bus.map_manager = map_manager

	# Connect bus signals
	if _player_bus != null:
		_player_bus.encounter_initiated.connect(_on_encounter_initiated)
		_player_bus.chase_started.connect(_on_chase_started)

	# Spawn Camera
	cam = camera_scene.instantiate() as Camera2D
	cam.set("bus", bus)
	cam.set("map_origin", map_origin)
	cam.set("map_size", map_size)
	# Inject MapManager into Camera if it needs it (optional, but good practice)
	# cam.set("map_manager", map_manager) 
	cam.global_position = final_position
	cam.global_position = final_position
	add_child(cam)
	cam.enabled = true

	# Load default ItemDB if not set
	if item_db == null:
		item_db = load("uid://dpu7dor4326r3")

	# Load default caravan types if not set
	if caravan_types.is_empty():
		caravan_types = [
			load("uid://d0kksk2xxwyvv"),
			load("uid://bl0n1whf7nvp5"),
			load("uid://cey8s0xhonm0l"),
			load("uid://calnlbpqgqy7v")
		]

	# Connect to Timekeeper pause/resume signals
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null:
		if timekeeper.has_signal("paused"):
			timekeeper.paused.connect(_on_timekeeper_paused)
		if timekeeper.has_signal("resumed"):
			timekeeper.resumed.connect(_on_timekeeper_resumed)

	# Initialize combat UIs with CanvasLayers for proper rendering
	var encounter_canvas: CanvasLayer = CanvasLayer.new()
	encounter_canvas.layer = 10
	encounter_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(encounter_canvas)

	var encounter_ui_scene: PackedScene = preload("uid://b8kj3x4n2qp5m")
	_encounter_ui = encounter_ui_scene.instantiate() as Control
	_encounter_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	encounter_canvas.add_child(_encounter_ui)
	_encounter_ui.combat_ended.connect(_on_combat_ended)
	_encounter_ui.exit_pressed.connect(_on_encounter_exit)
	if _encounter_ui.has_signal("trade_requested"):
		_encounter_ui.trade_requested.connect(_on_encounter_trade_requested)

	# Initialize Generic Market UI (for Caravan trading)
	var market_canvas: CanvasLayer = CanvasLayer.new()
	market_canvas.layer = 10
	market_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(market_canvas)
	
	# Reuse existing MarketUI scene if possible, or load it
	# Reuse existing MarketUI scene if possible, or load it
	var market_ui_scene: PackedScene = load("uid://bxn5d8qv2mw5k")
	if market_ui_scene:
		_market_ui = market_ui_scene.instantiate() as MarketUI
		_market_ui.process_mode = Node.PROCESS_MODE_ALWAYS
		market_canvas.add_child(_market_ui)
		_market_ui.market_closed.connect(_on_market_closed)
		_market_ui.transaction_confirmed.connect(_on_market_transaction_confirmed)


	var loot_canvas: CanvasLayer = CanvasLayer.new()
	loot_canvas.layer = 10
	loot_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(loot_canvas)

	var loot_ui_scene: PackedScene = preload("uid://c2m7k9x3p5qn8")
	_loot_ui = loot_ui_scene.instantiate() as Control
	_loot_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	loot_canvas.add_child(_loot_ui)
	_loot_ui.loot_closed.connect(_on_loot_closed)

	var game_over_canvas: CanvasLayer = CanvasLayer.new()
	game_over_canvas.layer = 10
	game_over_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(game_over_canvas)

	var game_over_ui_scene: PackedScene = preload("uid://d3k9m7x5p2qn4")
	_game_over_ui = game_over_ui_scene.instantiate() as Control
	_game_over_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	game_over_canvas.add_child(_game_over_ui)

	# Connect any pre-existing caravan signals
	# Connect any pre-existing caravan signals
	for caravan in get_tree().get_nodes_in_group("caravans"):
		if caravan.has_signal("player_initiated_chase"):
			caravan.player_initiated_chase.connect(_on_chase_initiated)

	# Connect any pre-existing beast den signals
	for den in get_tree().get_nodes_in_group("beast_den"):
		if den is BeastDen:
			den.player_initiated_chase.connect(_on_chase_initiated)

	# Connect any pre-existing beast signals
	for beast in get_tree().get_nodes_in_group("beasts"):
		if beast is Beast:
			beast.player_initiated_chase.connect(_on_chase_initiated)

func _process(delta: float) -> void:
	# Don't process when game is paused (UI is open)
	if _is_paused:
		return

	# Update caravan spawn timer
	caravan_spawn_timer += delta
	if caravan_spawn_timer >= caravan_spawn_interval:
		caravan_spawn_timer = 0.0
		_try_spawn_caravans()

	# Update pathline during chase
	# Update pathline from bus
	if _player_bus != null and bus != null:
		var current_points = _player_bus.get_current_path_points()
		if not current_points.is_empty():
			_set_path_line(current_points)
		elif _path_world.size() > 0:
			# Clear if bus has no path
			_set_path_line(PackedVector2Array())
		
func _physics_process(_delta: float) -> void:
	# Path trimming is now handled by refreshing from bus every frame
	if bus == null or path_line == null:
		return
	_update_line2d_from_world_path()

func _unhandled_input(event: InputEvent) -> void:
	# Ignore input when game is paused (UI is open)
	if _is_paused:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if bus == null:
				return

			# Cancel any active chase
			if _player_bus != null and _player_bus.get_chase_target() != null:
				_player_bus.chase_target(null)

			var click_pos: Vector2 = get_global_mouse_position()


			# 2. Visualize Path (Handled by _process sync now)
			# if map_manager != null:
			# 	var world_path: PackedVector2Array = map_manager.get_path_world(bus.global_position, click_pos)
			# 	_set_path_line(world_path)

			# 3. Move Bus
			# The bus script handles the actual movement along the path
			if _player_bus != null:
				_player_bus.move_to(click_pos)

func _set_path_line(points_world: PackedVector2Array) -> void:
	# Store the world-space path; Line2D will be updated each physics tick
	_path_world = points_world.duplicate()
	# Hide if empty; show otherwise and ensure the first visual draw happens now
	if _path_world.size() <= 1:
		path_line.points = PackedVector2Array()
		path_line.visible = false
	else:
		path_line.visible = true
		_update_line2d_from_world_path()

# Trim from the start as the bus moves forward
func _trim_path_as_bus_moves(bus_pos_world: Vector2) -> void:
	# Nothing to trim if we have < 2 points
	while _path_world.size() >= 2:
		var a: Vector2 = _path_world[0]
		var b: Vector2 = _path_world[1]
		var v: Vector2 = b - a
		var len2: float = v.length_squared()
		if len2 < 0.0001:
			_path_world.remove_at(0)
			continue

		# Project bus onto segment AB
		var t: float = clamp((bus_pos_world - a).dot(v) / len2, 0.0, 1.0)
		var proj: Vector2 = a.lerp(b, t)

		# If we have essentially reached/passed B, drop A and continue
		if t >= 1.0 or proj.distance_to(b) <= path_trim_tolerance:
			_path_world.remove_at(0)
			continue

		# Otherwise, move the start of the path up to the projection point
		_path_world[0] = proj
		break

	# If only one point remains and we're close to it, clear the path entirely
	if _path_world.size() == 1:
		if bus_pos_world.distance_to(_path_world[0]) <= path_trim_tolerance:
			_path_world.clear()

func _update_line2d_from_world_path() -> void:
	if path_line == null:
		return
	if _path_world.size() <= 1:
		path_line.points = PackedVector2Array()
		path_line.visible = false
		return

	var local: PackedVector2Array = PackedVector2Array()
	local.resize(_path_world.size())
	for i in range(_path_world.size()):
		local[i] = to_local(_path_world[i])
	path_line.points = local
	path_line.visible = true

func _await_nav_ready() -> void:
	# Deprecated with MapManager, but keeping empty to not break await calls if any remain
	pass

# ============================================================
# Caravan Spawning System
# ============================================================
func _try_spawn_caravans() -> void:
	if item_db == null:
		return

	if caravan_types.is_empty():
		return

	var hubs: Array[Hub] = _get_all_hubs()
	if hubs.is_empty():
		return

	# Try to spawn a caravan from each hub
	for hub in hubs:
		_try_spawn_caravan_from_hub(hub, hubs)

func _try_spawn_caravan_from_hub(home_hub: Hub, all_hubs: Array[Hub]) -> void:
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

		# Spawn the caravan
		_spawn_caravan(home_hub, caravan_type, all_hubs)

		# Increase threshold for next spawn by 5x
		caravan_threshold_multipliers[key] = threshold_multiplier * 5.0

		break # Only spawn one caravan per hub per check

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
	var type_id_str: String = str(caravan_type.type_id) # Get the type name as a string
	var current_count: int = _caravan_type_counters.get(type_id_str, 0) + 1 # Get current count for this type (default 0) + 1
	_caravan_type_counters[type_id_str] = current_count # Store the updated count
	caravan.name = "%s_%d" % [type_id_str, current_count]
	var leader_sheet: CharacterSheet = CharacterSheet.new()
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
	add_child(caravan)
	caravan.setup(home_hub, state, item_db, all_hubs, map_manager)
	active_caravans.append(caravan)

	# Connect combat and cleanup signals
	caravan.player_initiated_chase.connect(_on_chase_initiated)
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
	for child in get_children():
		if child is Hub:
			hubs.append(child as Hub)
	return hubs

# -------------------------------------------------------------------
# Pause/Resume Callbacks
# -------------------------------------------------------------------
func _on_timekeeper_paused() -> void:
	_is_paused = true

func _on_timekeeper_resumed() -> void:
	_is_paused = false

# -------------------------------------------------------------------
# Combat System Callbacks
# -------------------------------------------------------------------
func _on_chase_started() -> void:
	pass # Pathline will update automatically during chase

func _on_chase_initiated(target_actor: Node2D) -> void:
	if _player_bus != null and bus != null:
		# Set up pathline to show route to target (caravan or beast den)
		if map_manager != null:
			var world_path: PackedVector2Array = map_manager.get_path_world(bus.global_position, target_actor.global_position)
			_set_path_line(world_path)

		# Start the chase
		_player_bus.chase_target(target_actor)

func _on_encounter_initiated(attacker: Node2D, defender: Node2D) -> void:
	# Track defender as potential target to remove
	if attacker == _player_bus:
		_target_actor = defender
	else:
		_target_actor = attacker
		
	if _encounter_ui != null:
		_encounter_ui.open_encounter(attacker, defender)

func _on_combat_ended(attacker: Node2D, defender: Node2D, winner: Node2D) -> void:
	if _encounter_ui != null:
		_encounter_ui.close_ui()

	if winner == null:
		return

	if winner == _player_bus:
		# Identify defeated actor (will be freed after looting)
		var defeated: Node2D = defender if attacker == _player_bus else attacker

		# Open loot UI
		if _loot_ui != null:
			_loot_ui.open(_player_bus, defeated)
	elif winner == attacker or winner == defender:
		if winner != _player_bus:
			if _game_over_ui != null:
				_game_over_ui.show_game_over()

func _on_encounter_exit() -> void:
	if _encounter_ui != null:
		_encounter_ui.close_ui()

	if _target_actor != null and _target_actor != _player_bus:
		_target_actor.queue_free()

func _on_encounter_trade_requested(attacker: Node2D, defender: Node2D) -> void:
	# Open market with defender (Caravan)
	# Encounter UI is typically attacker=Player, defender=Caravan
	# But verify.
	var merchant = defender
	if attacker != _player_bus:
		merchant = attacker
		
	if _market_ui != null:
		# Pause game (MarketUI handles it internally usually, but let's be safe)
		# Duck typing check instead of class check
		if merchant is Hub or merchant.is_in_group("caravans"):
			_market_ui.open(_player_bus, merchant)
		else:
			push_warning("Cannot trade with non-merchant entity")

func _on_market_closed() -> void:
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("set_paused"):
		timekeeper.set_paused(false)

func _on_loot_closed(_target: Node2D = null) -> void:
	var timekeeper: Node = get_node_or_null("/root/Timekeeper")
	if timekeeper != null and timekeeper.has_method("set_paused"):
		timekeeper.set_paused(false)
	
	if _target_actor != null:
		_target_actor.queue_free()
		_target_actor = null

func _on_market_transaction_confirmed(cart: Array[Dictionary]) -> void:
	if _player_bus == null:
		return
		
	for entry in cart:
		var item_id = entry.get("item_id")
		var buy_qty = entry.get("buy_qty", 0)
		var sell_qty = entry.get("sell_qty", 0)
		var price = entry.get("unit_price", 0.0)
		var cost = buy_qty * price
		var revenue = sell_qty * price
		var side = entry.get("side") # "buy" or "sell"
		
		# Validate active merchant? MarketUI holds reference `current_merchant`.
		# We should probably trust the cart or re-validate.
		# Ideally use _market_ui.current_merchant
		var merchant = _market_ui.current_merchant
		if merchant == null:
			return

		if side == "buy":
			if _player_bus.pacs >= cost:
				# Deduct money
				_player_bus.pacs -= cost
				# Add item to player
				_player_bus.add_item(item_id, buy_qty)
				
				# Update Merchant
				if merchant.is_in_group("caravans") and "caravan_state" in merchant:
					var s = merchant.caravan_state
					if s:
						s.pacs += cost
						s.remove_item(item_id, buy_qty)
				elif merchant is Hub:
					merchant.state.pacs += cost
					# Hub inventory logic...
					# Basic override for now
					var current = merchant.state.inventory.get(item_id, 0)
					merchant.state.inventory[item_id] = max(0, current - buy_qty)

				# Skill XP
				if _player_bus.has_method("award_skill_xp"):
					_player_bus.award_skill_xp(&"market_analysis", float(cost))

		elif side == "sell":
			if _player_bus.remove_item(item_id, sell_qty):
				# Add money
				_player_bus.pacs += revenue
				
				# Update Merchant
				if merchant.is_in_group("caravans") and "caravan_state" in merchant:
					var s = merchant.caravan_state
					if s:
						s.pacs -= revenue
						s.add_item(item_id, sell_qty)
				elif merchant is Hub:
					merchant.state.pacs -= revenue
					merchant.state.inventory[item_id] = merchant.state.inventory.get(item_id, 0) + sell_qty
				
				# Skill XP
				if _player_bus.has_method("award_skill_xp"):
					_player_bus.award_skill_xp(&"market_analysis", float(revenue))
					_player_bus.award_skill_xp(&"negotiation_tactics", float(revenue))
					_player_bus.award_skill_xp(&"master_merchant", float(revenue))
					if sell_qty > 50:
						_player_bus.award_skill_xp(&"market_monopoly", float(revenue))

	# Refresh UI
	_market_ui._clear_cart()
	_market_ui._populate_ui()
