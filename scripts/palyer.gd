extends CharacterBody2D

signal health_changed(current_hp: float, max_hp: float)

@export var speed := 300.0
@export var jump_velocity := -420.0
@export var max_health := 100.0
@export var attack_damage := 25.0

var hp := 100.0
var can_attack := true
var is_invulnerable := false
var spawn_pos := Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_sprite: Sprite2D = $AttackArea/AttackSprite

func _ready() -> void:
	add_to_group("player")
	hp = max_health
	spawn_pos = global_position
	health_changed.emit(hp, max_health)
	if attack_sprite:
		attack_sprite.visible = false

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if (Input.is_action_just_pressed("ui_accept") or Input.is_key_pressed(KEY_W)) and is_on_floor():
		velocity.y = jump_velocity

	# Left/Right movement
	var dir := Input.get_axis("ui_left", "ui_right")
	if dir == 0:
		if Input.is_key_pressed(KEY_A): dir -= 1.0
		if Input.is_key_pressed(KEY_D): dir += 1.0

	if dir != 0:
		velocity.x = dir * speed
		if sprite: sprite.flip_h = dir < 0
		if attack_area: attack_area.scale.x = -1 if dir < 0 else 1
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	# Attack
	if can_attack and (Input.is_action_just_pressed("ui_select") or Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		attack()

	move_and_slide()

	if global_position.y > 1400:
		respawn()

func attack() -> void:
	can_attack = false
	if attack_area: attack_area.monitoring = true
	if attack_sprite: attack_sprite.visible = true

	if attack_area:
		for body in attack_area.get_overlapping_bodies():
			if body != self and body.has_method("take_damage"):
				body.take_damage(attack_damage)

	await get_tree().create_timer(0.2).timeout
	if attack_area: attack_area.monitoring = false
	if attack_sprite: attack_sprite.visible = false
	can_attack = true

func bounce(force := -380.0) -> void:
	velocity.y = force

func take_damage(amount: float, knock_dir := Vector2.ZERO) -> void:
	if is_invulnerable or hp <= 0:
		return

	hp = max(0, hp - amount)
	health_changed.emit(hp, max_health)
	velocity = knock_dir * 250.0 + Vector2(0, -150)

	if hp <= 0:
		respawn()
		return

	is_invulnerable = true
	if sprite: sprite.modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	if sprite: sprite.modulate = Color.WHITE
	is_invulnerable = false

func respawn() -> void:
	hp = max_health
	velocity = Vector2.ZERO
	global_position = spawn_pos
	is_invulnerable = false
	if sprite: sprite.modulate = Color.WHITE
	health_changed.emit(hp, max_health)
