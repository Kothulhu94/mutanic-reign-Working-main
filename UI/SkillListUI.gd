# uid://7hwqum185vfm
extends Control

## UI for displaying all skills (formerly domains) with tabbed pages
## Shows all skills from SkillDatabase and allows buying Perks.

@onready var tab_container: TabContainer = %TabContainer
@onready var close_button: Button = %CloseButton

# Reference to the SkillDatabase resource
@export var skill_database: SkillDatabase

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	hide() # Start hidden

## Display all skills from the database tabs
func display_skills(sheet: CharacterSheet) -> void:
	if not sheet:
		push_error("SkillListUI: Invalid CharacterSheet passed to display_skills")
		return

	if not skill_database:
		push_error("SkillListUI: No SkillDatabase assigned to skill_database export variable")
		return

	# Clear previous tabs
	_clear_tab_container()

	# Get all skills from the database
	# Note: These are the "base" resources. We need to find the instance on the CharacterSheet
	# to see actual Level/XP.
	
	if skill_database.skills.is_empty():
		skill_database.validate() # Force cache build/check
		
	for base_skill in skill_database.skills:
		if base_skill == null:
			continue
			
		# Find the actual active skill instance on the character
		var active_skill = sheet.get_skill(base_skill.id)
		
		# If character doesn't have it initialized, we might want to show it as "Locked" or 0
		# For now, let's assume we show it if it exists in DB, using a fallback or 
		# creating a temporary preview if not learned.
		# However, CharacterSheet logic suggests we should instance it.
		if active_skill == null:
			# Use the base skill for display info, but it has 0 progress
			_create_skill_tab(base_skill, null)
		else:
			_create_skill_tab(active_skill, sheet)

	show()


## Clear all children from the tab container
func _clear_tab_container() -> void:
	for child in tab_container.get_children():
		child.queue_free()


## Create a tab page for a single Skill (formerly Domain)
func _create_skill_tab(skill: Skill, sheet: CharacterSheet) -> void:
	var current_level: int = skill.current_level if sheet else 1
	var current_xp: float = skill.current_xp if sheet else 0.0
	var xp_needed: float = skill.get_xp_for_next_level()
	var perk_points: int = skill.perk_points if sheet else 0
	
	# Create a ScrollContainer for this tab
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.name = str(skill.display_name)
	tab_container.add_child(scroll_container)

	# Set the tab title
	var tab_index: int = tab_container.get_tab_count() - 1
	var title: String = "%s (Lv %d)" % [skill.display_name, current_level]
	if perk_points > 0:
		title += " [%d Pts]" % perk_points
	tab_container.set_tab_title(tab_index, title)

	# Create main content container
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_vbox)

	# --- Header ---
	var header_label: Label = Label.new()
	header_label.text = skill.display_name
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(header_label)

	# --- Description ---
	var desc_label: Label = Label.new()
	desc_label.text = skill.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.9, 0.9, 0.9)
	content_vbox.add_child(desc_label)

	# --- Level & XP ---
	var level_label: Label = Label.new()
	level_label.text = "Level %d" % current_level
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(level_label)
	
	var xp_bar: ProgressBar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 20)
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp
	xp_bar.show_percentage = true
	content_vbox.add_child(xp_bar)
	
	var xp_text: Label = Label.new()
	xp_text.text = "%d / %d XP" % [int(current_xp), int(xp_needed)]
	xp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_text.add_theme_font_size_override("font_size", 12)
	content_vbox.add_child(xp_text)

	# --- Perk Points ---
	if perk_points > 0:
		var choice_label: Label = Label.new()
		choice_label.text = "You have %d Perk Point(s) available!" % perk_points
		choice_label.modulate = Color(1.0, 1.0, 0.0)
		choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_vbox.add_child(choice_label)

	# Add spacing
	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer1)

	# --- Perks List ---
	var perks_header: Label = Label.new()
	perks_header.text = "Perk Tree:"
	perks_header.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(perks_header)

	for perk in skill.available_perks:
		if perk == null:
			continue
		_create_perk_entry(perk, skill, sheet, content_vbox)

	# Add bottom spacer
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(spacer2)


## Create a single perk entry
func _create_perk_entry(perk: Perk, skill: Skill, sheet: CharacterSheet, parent: VBoxContainer) -> void:
	if not sheet: return # Can't show interaction without sheet
	
	var is_unlocked: bool = skill.has_perk(perk.id)
	var can_unlock: bool = false
	var reject_reason: String = ""
	
	if not is_unlocked:
		# Check requirements manually for display feedback
		var points_ok = skill.perk_points >= perk.cost
		var level_ok = skill.current_level >= perk.required_skill_level
		var prereqs_ok = true
		for req_id in perk.prerequisite_perks:
			if not skill.has_perk(req_id):
				prereqs_ok = false
				break
				
		if points_ok and level_ok and prereqs_ok:
			can_unlock = true
		else:
			if not level_ok: reject_reason = "Requires Level %d" % perk.required_skill_level
			elif not prereqs_ok: reject_reason = "Requires previous perks"
			elif not points_ok: reject_reason = "Not enough points"

	# Create a panel
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 60)
	parent.add_child(panel)
	
	# Style
	if is_unlocked:
		panel.modulate = Color(1, 1, 1)
	elif can_unlock:
		panel.modulate = Color(1, 1, 0.9)
	else:
		panel.modulate = Color(0.6, 0.6, 0.6)

	var hbox: HBoxContainer = HBoxContainer.new()
	panel.add_child(hbox)
	
	# Icon (Placeholder)
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if perk.icon:
		icon_rect.texture = perk.icon
	# else could show default icon
	hbox.add_child(icon_rect)
	
	var info_vbox: VBoxContainer = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_lbl: Label = Label.new()
	name_lbl.text = perk.display_name
	info_vbox.add_child(name_lbl)
	
	var desc_lbl: Label = Label.new()
	desc_lbl.text = perk.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(desc_lbl)
	
	# Action Button / Status
	if is_unlocked:
		var status: Label = Label.new()
		status.text = "OWNED"
		status.modulate = Color(0.2, 1.0, 0.2)
		hbox.add_child(status)
	elif can_unlock:
		var btn: Button = Button.new()
		btn.text = "Buy (%d)" % perk.cost
		btn.pressed.connect(func(): _on_buy_perk_pressed(skill, perk.id, sheet))
		hbox.add_child(btn)
	else:
		var reason: Label = Label.new()
		reason.text = reject_reason
		reason.modulate = Color(1.0, 0.4, 0.4)
		reason.add_theme_font_size_override("font_size", 10)
		hbox.add_child(reason)

func _on_buy_perk_pressed(skill: Skill, perk_id: StringName, sheet: CharacterSheet) -> void:
	if skill.buy_perk(perk_id):
		# Refresh UI
		display_skills(sheet)

func _on_close_pressed() -> void:
	hide()
