extends Control

func _ready() -> void:
	$VBox/RestartBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://scene/ui/start_menu.tscn"))
	$VBox/QuitBtn.pressed.connect(func(): get_tree().quit())
