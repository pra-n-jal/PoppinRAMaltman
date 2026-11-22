extends Area2D

@export var is_active := false

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	update_visuals()

func _on_body_entered(body: Node2D) -> void:
	if not is_active and body.is_in_group("player"):
		is_active = true
		body.spawn_pos = global_position + Vector2(0, -20)
		body.reset_air_abilities()
		update_visuals()
		# squash & stretch pulse
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "scale", Vector2(1.4, 0.7), 0.1)
			tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)

func update_visuals() -> void:
	if sprite:
		sprite.modulate = Color(0.4, 1.8, 0.8, 1.0) if is_active else Color(0.9, 0.6, 0.6, 0.8)
	if label:
		label.text = "SYNAPSE SAVED" if is_active else "CHECKPOINT"
