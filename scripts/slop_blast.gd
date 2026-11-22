extends Area2D

@export var speed := 420.0
@export var damage := 25.0
@export var lifetime := 0.55

var direction := Vector2.RIGHT

func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("slop_blast")
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, direction)
		queue_free()
	elif body.is_in_group("terrain"):
		queue_free()
