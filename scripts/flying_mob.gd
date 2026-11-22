extends CharacterBody2D

signal mob_died(mob: CharacterBody2D)

@export var mob_name := "Neuron Mob"
@export var max_health := 25.0
@export var patrol_speed := 60.0
@export var chase_speed := 130.0
@export var contact_damage := 15.0
@export var detection_radius := 300.0
@export var patrol_distance := 180.0
@export var hover_amplitude := 18.0
@export var hover_frequency := 2.5
@export var mob_scale := Vector2(1.7, 1.7)

var hp := 25.0
var is_dead := false
var spawn_pos := Vector2.ZERO
var hover_time := 0.0
var patrol_dir := 1.0
var player: CharacterBody2D = null
var contact_cooldown := 0.0

static var _cached_anim_frames: Array[Texture2D] = []

var anim_frames: Array[Texture2D] = []
var cur_frame := 0
var anim_timer := 0.0
const FRAME_DURATION := 0.14

@onready var sprite: Sprite2D = $Sprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var stomp_area: Area2D = $StompArea

func _ready() -> void:
	add_to_group("enemies")
	hp = max_health
	spawn_pos = global_position
	hover_time = randf() * 10.0 # desynchronize hover phase

	if _cached_anim_frames.size() == 0:
		_cached_anim_frames = [
			load("res://assets/entities/neuron_mob/frame_0.png"),
			load("res://assets/entities/neuron_mob/frame_1.png"),
			load("res://assets/entities/neuron_mob/frame_2.png")
		]
	anim_frames = _cached_anim_frames

	if sprite:
		sprite.scale = mob_scale

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if stomp_area:
		stomp_area.body_entered.connect(_on_stomp_area_body_entered)

func reset_to_spawn() -> void:
	is_dead = false
	set_physics_process(true)
	collision_layer = 4
	collision_mask = 3
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape: col_shape.disabled = false
	if stomp_area: stomp_area.monitoring = true
	if detection_area: detection_area.monitoring = true

	global_position = spawn_pos
	velocity = Vector2.ZERO
	player = null
	patrol_dir = 1.0
	contact_cooldown = 0.5
	hp = max_health
	cur_frame = 0
	anim_timer = 0.0
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.scale = mob_scale
		if anim_frames.size() > 0:
			sprite.texture = anim_frames[0]

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if contact_cooldown > 0.0:
		contact_cooldown -= delta

	# Animate undulating dendrites / tentacles
	if anim_frames.size() > 1:
		anim_timer += delta
		if anim_timer >= FRAME_DURATION:
			anim_timer -= FRAME_DURATION
			cur_frame = (cur_frame + 1) % anim_frames.size()
			if sprite:
				sprite.texture = anim_frames[cur_frame]

	hover_time += delta
	var hover_offset_y = sin(hover_time * hover_frequency) * hover_amplitude

	# Organic biological subtle pulsing
	var pulse = 1.0 + sin(hover_time * 3.5) * 0.04
	if sprite:
		sprite.scale = mob_scale * Vector2(pulse, 2.0 - pulse)

	if player:
		# Chase player with smooth steering
		var to_player = (player.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * chase_speed, 350.0 * delta)
		if sprite:
			sprite.flip_h = to_player.x < 0
	else:
		# Patrol horizontally around spawn position
		var target_x = spawn_pos.x + patrol_dir * patrol_distance
		if (patrol_dir > 0 and global_position.x >= target_x) or (patrol_dir < 0 and global_position.x <= target_x):
			patrol_dir *= -1.0

		var target_vel_x = patrol_dir * patrol_speed
		velocity.x = move_toward(velocity.x, target_vel_x, 200.0 * delta)
		# Smoothly float near spawn Y with sinusoidal wave
		var desired_y = spawn_pos.y + hover_offset_y
		velocity.y = (desired_y - global_position.y) * 3.0

		if sprite:
			sprite.flip_h = patrol_dir < 0

	move_and_slide()

	# Contact check with player
	if contact_cooldown <= 0.0 and not is_dead:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i).get_collider()
			if col and col.is_in_group("player") and col.has_method("take_damage"):
				# Stomp priority: If player is above mob or descending downward, STOMP WINS!
				if col.velocity.y > 0 or col.global_position.y < global_position.y - 8.0:
					if col.has_method("bounce"):
						col.bounce(-480.0)
					if col.has_method("reset_air_abilities"):
						col.reset_air_abilities()
					take_damage(max_health)
					return
				var knock = (col.global_position - global_position).normalized()
				col.take_damage(contact_damage, knock)
				contact_cooldown = 0.6
				break

func take_damage(amount: float) -> void:
	if is_dead:
		return

	hp = max(0, hp - amount)

	if sprite:
		sprite.modulate = Color(2.5, 0.3, 0.3, 1.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.12)

	if hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	hp = 0.0
	set_physics_process(false)

	# Disable all collisions immediately so player can pass freely
	collision_layer = 0
	collision_mask = 0
	var col_shape = get_node_or_null("CollisionShape2D")
	if col_shape:
		col_shape.set_deferred("disabled", true)
	if stomp_area:
		stomp_area.set_deferred("monitoring", false)
		stomp_area.set_deferred("monitorable", false)
	if detection_area:
		detection_area.set_deferred("monitoring", false)
		detection_area.set_deferred("monitorable", false)

	mob_died.emit(self)

	# Fleshy splatter explosion particles!
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 26
	p.lifetime = 0.55
	p.spread = 180.0
	p.gravity = Vector2(0, 180)
	p.initial_velocity_min = 130.0
	p.initial_velocity_max = 260.0
	p.scale_amount_min = 3.5
	p.scale_amount_max = 7.0
	p.color = Color(0.15, 0.6, 0.95, 1.0) # Electric neuron blue splatter
	p.global_position = global_position
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)

	# Elastic pop animation
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale", Vector2(2.4, 0.2), 0.08)
		tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.08)
		await tw.finished
	queue_free()

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_dead:
		player = body as CharacterBody2D

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

func _on_stomp_area_body_entered(body: Node2D) -> void:
	if is_dead:
		return
	if body.is_in_group("player"):
		# Player stomps the neuron mob!
		if body.has_method("bounce"):
			body.bounce(-480.0)
		if body.has_method("reset_air_abilities"):
			body.reset_air_abilities()
		take_damage(max_health)
