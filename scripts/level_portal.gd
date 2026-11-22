extends Area2D

@export_file("*.tscn") var next_level_path := ""
@export var is_unlocked := false
@export var portal_label_text := "Next Level"
@export var trigger_clear_dialogue := true

var is_transitioning := false

@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if label: label.text = portal_label_text if is_unlocked else "[LOCKED]"
	modulate.a = 1.0 if is_unlocked else 0.4

func unlock_portal() -> void:
	is_unlocked = true
	if label: label.text = portal_label_text
	modulate.a = 1.0

func _on_body_entered(body: Node2D) -> void:
	if is_unlocked and body.is_in_group("player") and next_level_path != "" and not is_transitioning:
		var dialogue_board = get_tree().get_first_node_in_group("dialogue_board")
		if trigger_clear_dialogue and dialogue_board:
			is_transitioning = true
			var clear_lines = [
				{"speaker": "MEUKEUL", "text": "I must go on through this slop brain to get to the man destroying it all."}
			]
			dialogue_board.dialogue_finished.connect(func(): get_tree().change_scene_to_file(next_level_path), CONNECT_ONE_SHOT)
			dialogue_board.show_dialogue(clear_lines, body as CharacterBody2D)
		else:
			get_tree().change_scene_to_file(next_level_path)
