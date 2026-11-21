extends Control

func _ready() -> void:
	$VBox/StartBtn.pressed.connect(_on_start_pressed)
	$VBox/QuitBtn.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/levels/level1.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
