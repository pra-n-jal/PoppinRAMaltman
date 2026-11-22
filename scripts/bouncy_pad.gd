extends Area2D

@export var bounce_force := -650.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	add_to_group("bounce_pads")
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("bounce"):
			body.bounce(bounce_force)

		# Trigger pad squash and stretch
		if sprite:
			var tw = create_tween()
			tw.tween_property(sprite, "scale", Vector2(1.5, 0.4), 0.08)
			tw.tween_property(sprite, "scale", Vector2(0.8, 1.3), 0.12)
			tw.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.15)
