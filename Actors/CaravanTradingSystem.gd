# CaravanTradingSystem.gd
extends Node
class_name CaravanTradingSystem

## Manages trading logic for a Caravan.
## Handles buying, selling, price evaluation, and destination selection.

var caravan_state: CaravanState
var item_db: ItemDB
var skill_system: CaravanSkillSystem
var all_hubs: Array[Hub] = []
var visited_hubs: Array[Hub] = []
var purchase_prices: Dictionary = {} # item_id -> price paid

var surplus_threshold: float = 200.0

func setup(state: CaravanState, db: ItemDB, skills: CaravanSkillSystem, hubs: Array[Hub], threshold: float) -> void:
	caravan_state = state
	item_db = db
	skill_system = skills
	all_hubs = hubs
	surplus_threshold = threshold

func reset_trip() -> void:
	visited_hubs.clear()
	purchase_prices.clear()
	caravan_state.profit_this_trip = 0
	caravan_state.flip_leg()

func get_effective_max_capacity() -> int:
	if caravan_state == null or caravan_state.caravan_type == null:
		return 1000
	var base: int = caravan_state.caravan_type.base_capacity
	var bonus: float = 0.0
	if skill_system != null:
		bonus = skill_system.capacity_bonus
	if skill_system != null:
		bonus = skill_system.capacity_bonus
	# Apply CaravanType modifier (previously ignored)
	# base_capacity is 1000. modifier is e.g. 0.8 or 1.5.
	var type_mod: float = caravan_state.caravan_type.capacity_modifier
	return int(float(base) * type_mod * (1.0 + bonus))

func home_has_available_preferred_items(home_hub: Hub) -> bool:
	if home_hub == null or caravan_state.pacs <= 0:
		return false
	var items: Dictionary = _get_available_preferred_items(home_hub)
	
	# Filter by affordability to prevent infinite loop (Buy -> Fail -> Idle -> Buy)
	var affordable_count: int = 0
	for item_id in items.keys():
		var price: float = home_hub.get_item_price(item_id)
		# Skill discount
		var discount: float = 0.0
		if skill_system:
			discount = skill_system.get_price_modifier(item_id, item_db)
		var final_price: float = maxf(price * (1.0 - discount), 0.1)
		
		if caravan_state.pacs >= final_price:
			affordable_count += 1
			break
			
	# print("CaravanTrading: checking items at home. Found: ", items.size(), " Affordable: ", affordable_count)
	return affordable_count > 0

func buy_items_at_home(home_hub: Hub) -> int:
	var items_to_buy: Dictionary = _get_available_preferred_items(home_hub)
	var total_bought: int = 0
	
	for item_id: StringName in items_to_buy.keys():
		var available: int = items_to_buy[item_id]
		var base_price: float = home_hub.get_item_price(item_id)
		
		# Apply buy price reduction (bonus)
		var price_modifier: float = 0.0
		if skill_system:
			price_modifier = skill_system.get_price_modifier(item_id, item_db)
			
		var price: float = base_price * (1.0 - price_modifier)
		# Ensure price doesn't go negative or too low
		price = maxf(price, 0.1)
		
		var max_affordable: int = int(floor(float(caravan_state.pacs) / price))
		var amount: int = mini(available, max_affordable)
		
		# Capacity check
		var current_weight: int = caravan_state.get_total_cargo_weight()
		var max_cap: int = get_effective_max_capacity()
		amount = mini(amount, max_cap - current_weight)
		
		if amount > 0:
			var cost: int = int(ceil(price * float(amount)))
			if home_hub.buy_from_hub(item_id, amount, caravan_state):
				caravan_state.pacs -= cost
				caravan_state.add_item(item_id, amount)
				purchase_prices[item_id] = price
				total_bought += amount
				# print("CaravanTrading: Bought %d of %s for %d" % [amount, item_id, cost])
				
				if skill_system:
					skill_system.award_xp(&"trading", float(cost))
			else:
				push_warning("CaravanTrading: Hub refused sale of %s" % item_id)
					
	# print("CaravanTrading: Total bought: ", total_bought)
	return total_bought

func evaluate_trade_at_hub(hub: Hub) -> bool:
	if hub != null and not visited_hubs.has(hub):
		visited_hubs.append(hub)
		
	var has_profit: bool = false
	for item_id: StringName in caravan_state.inventory.keys():
		var buy_price: float = purchase_prices.get(item_id, 0.0)
		var base_sell: float = hub.get_item_price(item_id)
		
		# Calculate dynamic bonus
		var bonus: float = 0.0
		if skill_system:
			bonus = skill_system.get_price_modifier(item_id, item_db)
			
		# Sell price increase
		var sell_price: float = base_sell * (1.0 + bonus)
		
		if sell_price > buy_price:
			has_profit = true
			break
			
	return has_profit

func sell_items_at_hub(hub: Hub, force_sell: bool = false) -> void:
	var items: Array[StringName] = []
	for k in caravan_state.inventory.keys():
		items.append(k)
		
	for item_id in items:
		var amount: int = caravan_state.inventory.get(item_id, 0)
		if amount <= 0: continue
		
		var buy_price: float = purchase_prices.get(item_id, 0.0)
		var base_sell: float = hub.get_item_price(item_id)
		
		# Calculate dynamic bonus
		var bonus: float = 0.0
		if skill_system:
			bonus = skill_system.get_price_modifier(item_id, item_db)
			
		# Sell price increase
		var sell_price: float = base_sell * (1.0 + bonus)
		
		if force_sell or sell_price > buy_price:
			var revenue: int = int(floor(sell_price * float(amount)))
			if hub.sell_to_hub(item_id, amount, caravan_state):
				var profit: int = revenue - int(buy_price * float(amount))
				caravan_state.pacs += revenue
				caravan_state.profit_this_trip += profit
				caravan_state.remove_item(item_id, amount)
				
				if skill_system:
					skill_system.award_xp(&"trading", float(revenue))
					if profit > 0:
						skill_system.award_xp(&"trading", float(profit))
						skill_system.award_xp(&"trading", float(profit) * 0.5) # Bonus for profit
					if amount > 50:
						skill_system.award_xp(&"trading", float(revenue) * 0.2) # Bonus for bulk


	if hub != null and not visited_hubs.has(hub):
		visited_hubs.append(hub)

func find_next_destination(home_hub: Hub) -> Hub:
	var available: Array[Hub] = []
	for h in all_hubs:
		if h == home_hub: continue
		if visited_hubs.has(h): continue
		available.append(h)
		
	if available.is_empty():
		# Reset visited if we've seen them all (except home)
		visited_hubs.clear()
		for h in all_hubs:
			if h != home_hub:
				available.append(h)
				
	if available.size() > 0:
		return available[0]
	return null

func get_visited_count_excluding(home_hub: Hub) -> int:
	var count: int = 0
	for h in visited_hubs:
		if h != home_hub:
			count += 1
	return count

func get_total_hubs_excluding(home_hub: Hub) -> int:
	var count: int = 0
	for h in all_hubs:
		if h != home_hub:
			count += 1
	return count

func _get_available_preferred_items(hub: Hub) -> Dictionary:
	var result: Dictionary = {}
	if hub == null or item_db == null or caravan_state == null or caravan_state.caravan_type == null:
		return result
		
	var tags: Array[StringName] = caravan_state.caravan_type.preferred_tags
	if tags.is_empty():
		return result
		
	for item_id: StringName in hub.state.inventory.keys():
		var stock: int = hub.state.inventory.get(item_id, 0)
		if stock <= 0: continue
		
		var match_tag: bool = false
		for t in tags:
			if item_db.has_tag(item_id, t):
				match_tag = true
				break
		
		if match_tag:
			result[item_id] = stock
			
	return result
