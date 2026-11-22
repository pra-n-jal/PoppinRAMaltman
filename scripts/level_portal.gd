extends Area2D

@export_file("*.tscn") var next_level_path := "res://scene/levels/boss_level_sam_altman.tscn"
@export var is_unlocked := true
@export var portal_label_text := "BOSS ARENA ▶"

var is_transitioning := false
var pulse_time := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = get_node_or_null("Label")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if label:
		label.text = portal_label_text if is_unlocked else "[LOCKED]"
	modulate = Color(1.2, 1.2, 1.5, 1.0) if is_unlocked else Color(0.5, 0.5, 0.5, 0.4)

func _process(delta: float) -> void:
	if is_unlocked and not is_transitioning:
		pulse_time += delta
		var s = 1.0 + sin(pulse_time * 4.0) * 0.08
		scale = Vector2(s, s)
		if sprite:
			sprite.rotation += delta * 1.2

func unlock_portal() -> void:
	is_unlocked = true
	if label: label.text = portal_label_text
	modulate = Color(1.2, 1.2, 1.5, 1.0)

func _on_body_entered(body: Node2D) -> void:
	if not is_unlocked or is_transitioning:
		return
	if body.is_in_group("player") and next_level_path != "":
		is_transitioning = true
		if body.has_method("set_physics_process"):
			body.set_physics_process(false)

		# Warp animation into boss level
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(2.2, 2.2), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(self, "modulate", Color(3.0, 3.0, 4.0, 1.0), 0.2)
		tw.tween_property(self, "scale", Vector2(0.05, 0.05), 0.15)
		tw.tween_callback(func():
			get_tree().change_scene_to_file(next_level_path)
		)
