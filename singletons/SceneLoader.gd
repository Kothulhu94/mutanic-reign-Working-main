extends Node

const OVERWORLD := "res://scenes/Overworld.tscn"
const BATTLE    := "res://scenes/Battle.tscn"

func goto_overworld() -> void:
	get_tree().change_scene_to_file(OVERWORLD)

func goto_battle() -> void:
	get_tree().change_scene_to_file(BATTLE)

func reload() -> void:
	get_tree().reload_current_scene()
