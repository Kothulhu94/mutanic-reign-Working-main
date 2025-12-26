# uid://7hwqum185vfm
extends Control

## UI for displaying all skills organized by domain with tabbed pages
## Shows all skills from SkillDatabase, displaying learned skills with actual ranks
## and unlearned skills at rank 0

@onready var tab_container: TabContainer = %TabContainer
@onready var close_button: Button = %CloseButton

# Reference to the SkillDatabase resource
@export var skill_database: SkillDatabase

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	hide() # Start hidden


## Display all skills from the database, organized by domain tabs
func display_skills(sheet: CharacterSheet) -> void:
	if not sheet:
		push_error("SkillListUI: Invalid CharacterSheet passed to display_skills")
		return

	if not skill_database:
		push_error("SkillListUI: No SkillDatabase assigned to skill_database export variable")
		return

	# Clear previous tabs
	_clear_tab_container()

	# Get all domains from the database
	var all_domains: Array[SkillDomain] = skill_database.get_all_domains()

	# Create a tab for each domain
	for domain in all_domains:
		if domain == null:
			continue

		_create_domain_tab(domain, sheet)

	show()


## Clear all children from the tab container
func _clear_tab_container() -> void:
	for child in tab_container.get_children():
		child.queue_free()


## Create a tab page for a single domain
func _create_domain_tab(domain: SkillDomain, sheet: CharacterSheet) -> void:
	# Get or initialize domain state
	var state: DomainState = sheet.get_domain_state(domain.domain_id)
	if state == null:
		state = sheet.initialize_domain(domain)
		
	var current_level: int = state.current_level if state else 1
	var current_xp: float = state.current_xp if state else 0.0
	var xp_needed: float = state.xp_to_next_level if state else 100.0
	var pending_choices: int = state.pending_perk_choices if state else 0

	# Create a ScrollContainer for this tab
	var scroll_container: ScrollContainer = ScrollContainer.new()
	scroll_container.name = str(domain.display_name)
	tab_container.add_child(scroll_container)

	# Set the tab title
	var tab_index: int = tab_container.get_tab_count() - 1
	var title: String = "%s (Lv %d)" % [domain.display_name, current_level]
	if pending_choices > 0:
		title += " [!]"
	tab_container.set_tab_title(tab_index, title)

	# Create main content container
	var content_vbox: VBoxContainer = VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(content_vbox)

	# --- Domain Header ---
	var header_label: Label = Label.new()
	header_label.text = domain.display_name
	header_label.add_theme_font_size_override("font_size", 20)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content_vbox.add_child(header_label)

	# --- Domain Description ---
	var desc_label: Label = Label.new()
	desc_label.text = domain.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.9, 0.9, 0.9)
	content_vbox.add_child(desc_label)

	# --- Domain Level & XP ---
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

	# --- Pending Choices ---
	if pending_choices > 0:
		var choice_label: Label = Label.new()
		choice_label.text = "You have %d perk choice(s) available!" % pending_choices
		choice_label.modulate = Color(1.0, 1.0, 0.0)
		choice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content_vbox.add_child(choice_label)

	# Add spacing
	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	content_vbox.add_child(spacer1)

	# --- Domain Bonuses ---
	var bonuses_label: Label = Label.new()
	bonuses_label.text = "Passive Bonus:"
	bonuses_label.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(bonuses_label)

	if "passive_bonus_description" in domain and domain.passive_bonus_description != "":
		var passive_label: Label = Label.new()
		passive_label.text = domain.passive_bonus_description
		passive_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		passive_label.modulate = Color(0.7, 0.7, 1.0)
		content_vbox.add_child(passive_label)
		
	if domain.has_bonus_rank_5():
		var bonus5_label: Label = Label.new()
		bonus5_label.text = "  ★ Rank 5: %s" % domain.bonus_at_rank_5
		bonus5_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus5_label.modulate = Color(0.2, 1.0, 0.2) if current_level >= 5 else Color(0.5, 0.5, 0.5)
		content_vbox.add_child(bonus5_label)

	if domain.has_bonus_rank_10():
		var bonus10_label: Label = Label.new()
		bonus10_label.text = "  ★★ Rank 10: %s" % domain.bonus_at_rank_10
		bonus10_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bonus10_label.modulate = Color(1.0, 0.8, 0.0) if current_level >= 10 else Color(0.5, 0.5, 0.5)
		content_vbox.add_child(bonus10_label)

	# Add separator
	var separator1: HSeparator = HSeparator.new()
	content_vbox.add_child(separator1)

	# --- Skills Header ---
	var skills_header: Label = Label.new()
	skills_header.text = "Perks:"
	skills_header.add_theme_font_size_override("font_size", 16)
	content_vbox.add_child(skills_header)

	# Add all skills from this domain
	for skill in domain.skills:
		if skill == null:
			continue

		_create_skill_entry(skill, sheet, state, content_vbox)

	# Add bottom spacer
	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(spacer2)


## Create a single skill entry (learned or unlearned)
func _create_skill_entry(skill: Skill, sheet: CharacterSheet, state: DomainState, parent: VBoxContainer) -> void:
	var is_unlocked: bool = false
	if state and state.has_perk(skill.skill_id):
		is_unlocked = true
		
	var can_unlock: bool = false
	if state and not is_unlocked and state.pending_perk_choices > 0:
		# Check tier requirements? For now assume all valid if choices available
		# Or maybe check if previous tier perks are needed?
		# User requirement: "level 1 gets to pick one, level 3 gets to pick one..."
		# Doesn't explicitly say tier restrictions, but usually implied.
		# Let's assume any perk in the domain is pickable for now.
		can_unlock = true

	# Create a panel for each skill for better visibility
	var skill_panel: PanelContainer = PanelContainer.new()
	skill_panel.custom_minimum_size = Vector2(0, 60)
	parent.add_child(skill_panel)
	
	# Style based on unlocked state
	if is_unlocked:
		skill_panel.modulate = Color(1, 1, 1)
	elif can_unlock:
		skill_panel.modulate = Color(1, 1, 0.8) # Slight yellow tint
	else:
		skill_panel.modulate = Color(0.6, 0.6, 0.6) # Dimmed

	# Main skill container
	var skill_vbox: VBoxContainer = VBoxContainer.new()
	skill_panel.add_child(skill_vbox)

	# Top row: Name and Status
	var top_hbox: HBoxContainer = HBoxContainer.new()
	skill_vbox.add_child(top_hbox)

	# Skill name
	var name_label: Label = Label.new()
	name_label.text = skill.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(name_label)

	# Status / Unlock Button
	if is_unlocked:
		var status_label: Label = Label.new()
		status_label.text = "UNLOCKED"
		status_label.modulate = Color(0.2, 1.0, 0.2)
		top_hbox.add_child(status_label)
	elif can_unlock:
		var unlock_btn: Button = Button.new()
		unlock_btn.text = "UNLOCK"
		unlock_btn.modulate = Color(0.2, 1.0, 0.2)
		unlock_btn.pressed.connect(func(): _on_unlock_perk_pressed(state, skill.skill_id, sheet))
		top_hbox.add_child(unlock_btn)
	else:
		var status_label: Label = Label.new()
		status_label.text = "LOCKED"
		status_label.modulate = Color(0.5, 0.5, 0.5)
		top_hbox.add_child(status_label)

	# Skill description
	var desc_label: Label = Label.new()
	desc_label.text = skill.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	desc_label.add_theme_font_size_override("font_size", 12)
	skill_vbox.add_child(desc_label)

	# Effect info
	var effect_value: float = skill.get_effect_at_rank(1) # Base effect
	if effect_value != 0.0:
		var effect_label: Label = Label.new()
		var effect_text: String = ""
		if skill.is_multiplicative:
			effect_text = "Effect: +%.1f%%" % (effect_value * 100.0)
		else:
			effect_text = "Effect: +%.1f" % effect_value
		effect_label.text = effect_text
		effect_label.modulate = Color(0.5, 1.0, 0.5)
		effect_label.add_theme_font_size_override("font_size", 12)
		skill_vbox.add_child(effect_label)

func _on_unlock_perk_pressed(state: DomainState, skill_id: StringName, sheet: CharacterSheet) -> void:
	if state.unlock_perk(skill_id):
		# Refresh UI
		display_skills(sheet)


func _on_close_pressed() -> void:
	hide()
