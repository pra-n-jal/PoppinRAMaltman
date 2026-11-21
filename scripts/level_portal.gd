extends Area2D

@export_file("*.tscn") var next_level_path := ""
@export var is_unlocked := false
@export var portal_label_text := "Next Level"

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
	if is_unlocked and body.is_in_group("player") and next_level_path != "":
		get_tree().change_scene_to_file(next_level_path)
