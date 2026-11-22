extends CharacterBody2D

signal mob_died(mob: CharacterBody2D)

@export var mob_name := "Neuron Mob"
@export var max_health := 25.0
@export var patrol_speed := 60.0
@export var chase_speed := 130.0
@export var contact_damage := 15.0
@export var detection_radius := 260.0
@export var patrol_distance := 180.0
@export var hover_amplitude := 18.0
@export var hover_frequency := 2.5

var hp := 25.0
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

	if detection_area:
		detection_area.body_entered.connect(_on_detection_body_entered)
		detection_area.body_exited.connect(_on_detection_body_exited)
	if stomp_area:
		stomp_area.body_entered.connect(_on_stomp_area_body_entered)

func reset_to_spawn() -> void:
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
		sprite.scale = Vector2(0.5, 0.5)
		if anim_frames.size() > 0:
			sprite.texture = anim_frames[0]

func _physics_process(delta: float) -> void:
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

	# Contact damage to player
	if contact_cooldown <= 0.0:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i).get_collider()
			if col and col.is_in_group("player") and col.has_method("take_damage"):
				var knock = (col.global_position - global_position).normalized()
				col.take_damage(contact_damage, knock)
				contact_cooldown = 0.6
				break

func take_damage(amount: float) -> void:
	hp = max(0, hp - amount)

	if sprite:
		sprite.modulate = Color(1.5, 0.4, 0.4, 1.0)
		var tw = create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.15)

	if hp <= 0:
		die()

func die() -> void:
	mob_died.emit(self)
	# Elastic pop animation
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.5, 0.2), 0.1)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.1)
		await tw.finished
	queue_free()

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

func _on_stomp_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		# Player stomps the neuron mob!
		if body.has_method("bounce"):
			body.bounce(-460.0)
		if body.has_method("reset_air_abilities"):
			body.reset_air_abilities()
		take_damage(25.0)
