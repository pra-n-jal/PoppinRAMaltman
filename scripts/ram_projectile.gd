extends Area2D

@export var speed := 580.0
@export var spin_speed := 18.0

var direction := Vector2.RIGHT

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail: CPUParticles2D = get_node_or_null("TrailParticles")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("projectiles")
	add_to_group("ram_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	# Safety self-destruction after 5 seconds if offscreen
	get_tree().create_timer(5.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if sprite:
		sprite.rotation += spin_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_hit_player(body)
	elif body.is_in_group("terrain") or body is StaticBody2D:
		_impact_effect()
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	var parent_body = area.get_parent()
	if parent_body and parent_body.is_in_group("player"):
		_hit_player(parent_body)

func _hit_player(player_node: Node) -> void:
	# INSTANT KILL! Slung RAM unconditionally consumes a life
	if player_node.has_method("handle_death"):
		player_node.handle_death()
	elif player_node.has_method("take_damage"):
		player_node.take_damage(999999.0, direction)
	_impact_effect()
	queue_free()

func _impact_effect() -> void:
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 26
	p.lifetime = 0.6
	p.direction = -direction
	p.spread = 80.0
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 3.5
	p.scale_amount_max = 8.0
	p.color = Color(0.1, 1.0, 0.4, 1.0) # Matrix green
	p.global_position = global_position
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)
