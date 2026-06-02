extends Control

func _on_btn_5_stones_pressed():
	Global.stone_count = 5
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_btn_7_stones_pressed():
	Global.stone_count = 7
	get_tree().change_scene_to_file("res://Game.tscn")

func _on_btn_12_stones_pressed():
	Global.stone_count = 12
	get_tree().change_scene_to_file("res://Game.tscn")
