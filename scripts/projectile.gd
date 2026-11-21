extends Area2D

@export var speed := 280.0
@export var damage := 15.0

var direction := Vector2.RIGHT

func _ready() -> void:
	body_entered.connect(_on_hit)
	get_tree().create_timer(4.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_hit(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, direction)
		queue_free()
	elif body.is_in_group("terrain"):
		queue_free()
