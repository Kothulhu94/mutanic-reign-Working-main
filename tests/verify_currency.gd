@tool
extends SceneTree

func _init() -> void:
	print("Verifying Currency Refactor...")
	var success: bool = true

	# 1. Check Bus
	var bus = load("res://Actors/Bus.tscn").instantiate()
	if "pacs" in bus:
		print("✅ Bus has 'pacs' property")
	else:
		print("❌ Bus missing 'pacs' property")
		success = false
		
	if "money" in bus:
		print("⚠️ Bus still has 'money' property (might be intentional export or leftover)")
		# Usually we want it gone, unless it's a built-in I forgot about? No.
		success = false
	
	# 2. Check CaravanState
	var cs_script = load("res://data/CaravanState.gd")
	var cs = cs_script.new()
	if "pacs" in cs:
		print("✅ CaravanState has 'pacs' property")
	else:
		print("❌ CaravanState missing 'pacs' property")
		success = false

	# 3. Check HubState
	var hs_script = load("res://data/HubState.gd")
	var hs = hs_script.new()
	if "pacs" in hs:
		print("✅ HubState has 'pacs' property")
	else:
		print("❌ HubState missing 'pacs' property")
		success = false

	if success:
		print("VERIFICATION SUCCESS")
		quit(0)
	else:
		print("VERIFICATION FAILED")
		quit(1)
