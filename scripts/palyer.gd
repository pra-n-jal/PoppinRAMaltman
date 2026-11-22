extends CharacterBody2D

signal health_changed(current_hp: float, max_hp: float)
signal stamina_changed(current_stamina: float, max_stamina: float)
signal lives_changed(current_lives: int, max_lives: int)
signal game_over()

# Movement parameters
@export var speed := 320.0
@export var accel := 1800.0
@export var friction := 1500.0
@export var air_friction := 600.0

# Jump parameters (Double jump enabled by default)
@export var jump_velocity := -440.0
@export var double_jump_velocity := -400.0
@export var gravity_scale := 1.0
@export var fall_gravity_multiplier := 1.45 # Snappier fall like Celeste
@export var base_max_jumps := 2
@export var max_jumps := 2

# Celeste-style Dash
@export var dash_speed := 750.0
@export var dash_duration := 0.14
@export var dash_cooldown := 0.2

# Celeste-style Wall Climb & Slide
@export var wall_slide_speed := 75.0
@export var climb_speed_up := 140.0
@export var climb_speed_down := 170.0
@export var wall_jump_impulse := Vector2(360.0, -420.0)
@export var max_climb_stamina := 100.0

# Combat & Health
@export var max_health := 100.0
@export var attack_damage := 25.0
@export var max_lives := 3

# State variables
var hp := 100.0
var lives_left := 3
var jumps_left := 2
var can_dash := true
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_direction := Vector2.ZERO

var is_climbing := false
var climb_stamina := 100.0
var wall_jump_lock_timer := 0.0
var facing_dir := 1.0

var coyote_timer := 0.0
var jump_buffer_timer := 0.0

var can_attack := true
var is_invulnerable := false
var spawn_pos := Vector2.ZERO

# Elastic squash and stretch
var base_scale := Vector2(0.1, 0.1)
var squash_stretch := Vector2.ONE
var was_on_floor := false
var ghost_trail_timer := 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_sprite: Sprite2D = $AttackArea/AttackSprite if has_node("AttackArea/AttackSprite") else null

func _ready() -> void:
	add_to_group("player")
	hp = max_health
	lives_left = max_lives
	climb_stamina = max_climb_stamina
	jumps_left = max_jumps
	spawn_pos = global_position
	if sprite:
		base_scale = sprite.scale
	health_changed.emit(hp, max_health)
	stamina_changed.emit(climb_stamina, max_climb_stamina)
	lives_changed.emit(lives_left, max_lives)
	if attack_sprite:
		attack_sprite.visible = false

func _physics_process(delta: float) -> void:
	handle_timers(delta)

	if is_dashing:
		process_dash(delta)
	else:
		process_normal_movement(delta)

	move_and_slide()
	process_elastic_squash(delta)

	# Pit death threshold (instant responsive pit death without endless void falling)
	if global_position.y > 750:
		handle_death()

func handle_timers(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer -= delta
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
	if coyote_timer > 0.0:
		coyote_timer -= delta

	# Check jump buffer
	if is_jump_just_pressed():
		jump_buffer_timer = 0.12

func process_dash(delta: float) -> void:
	dash_timer -= delta
	velocity = dash_direction * dash_speed

	ghost_trail_timer += delta
	if ghost_trail_timer >= 0.05:
		ghost_trail_timer = 0.0
		spawn_ghost_trail()

	if dash_timer <= 0.0:
		is_dashing = false
		velocity = dash_direction * (speed * 0.9) # retain momentum smoothly

func process_normal_movement(delta: float) -> void:
	var on_floor = is_on_floor()
	var on_wall = is_on_wall()
	var wall_normal = get_wall_normal() if on_wall else Vector2.ZERO

	# Landing impact squash
	if on_floor and not was_on_floor:
		squash_stretch = Vector2(1.35, 0.65) # squash down on landing
		reset_air_abilities()
		climb_stamina = max_climb_stamina
		stamina_changed.emit(climb_stamina, max_climb_stamina)

	if on_floor:
		coyote_timer = 0.12
		jumps_left = max_jumps
	was_on_floor = on_floor

	# Direction inputs from rebindable actions with fallback to ui_*
	var input_x := Input.get_axis("move_left", "move_right") if InputMap.has_action("move_left") and InputMap.has_action("move_right") else 0.0
	if input_x == 0.0:
		input_x = Input.get_axis("ui_left", "ui_right")
	if input_x == 0.0:
		if Input.is_key_pressed(KEY_A): input_x -= 1.0
		if Input.is_key_pressed(KEY_D): input_x += 1.0

	var input_y := Input.get_axis("move_up", "move_down") if InputMap.has_action("move_up") and InputMap.has_action("move_down") else 0.0
	if input_y == 0.0:
		input_y = Input.get_axis("ui_up", "ui_down")
	if input_y == 0.0:
		if Input.is_key_pressed(KEY_W): input_y -= 1.0
		if Input.is_key_pressed(KEY_S): input_y += 1.0

	# Update facing direction
	if input_x != 0:
		facing_dir = sign(input_x)
		if sprite:
			sprite.flip_h = (facing_dir < 0)
		if attack_area:
			attack_area.scale.x = -1 if facing_dir < 0 else 1

	# Wall Climbing & Sliding
	var climb_held = is_climb_held()
	if on_wall and not on_floor and climb_held and climb_stamina > 0.0:
		is_climbing = true
		climb_stamina = max(0.0, climb_stamina - delta * 25.0)
		stamina_changed.emit(climb_stamina, max_climb_stamina)

		if input_y < 0:
			velocity.y = -climb_speed_up
		elif input_y > 0:
			velocity.y = climb_speed_down
		else:
			velocity.y = 0.0 # Hang in place
		reset_air_abilities()
	elif on_wall and not on_floor and velocity.y > 0:
		is_climbing = false
		# Wall slide with friction
		velocity.y = min(velocity.y, wall_slide_speed)
	else:
		is_climbing = false

	# Gravity
	if not on_floor and not is_climbing:
		var grav = get_gravity().y * gravity_scale
		if velocity.y > 0:
			grav *= fall_gravity_multiplier
		velocity.y += grav * delta

	# Jump handling
	if jump_buffer_timer > 0.0:
		if is_climbing or (on_wall and not on_floor):
			# Wall jump!
			jump_buffer_timer = 0.0
			var push_dir = wall_normal.x if wall_normal.x != 0 else -facing_dir
			velocity.x = push_dir * wall_jump_impulse.x
			velocity.y = wall_jump_impulse.y
			wall_jump_lock_timer = 0.14
			squash_stretch = Vector2(0.7, 1.4)
			reset_air_abilities()
		elif coyote_timer > 0.0 or jumps_left > 0:
			# Normal or Double jump!
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			var is_double = not on_floor and jumps_left < max_jumps
			velocity.y = double_jump_velocity if is_double else jump_velocity
			jumps_left -= 1
			squash_stretch = Vector2(0.65, 1.45) if is_double else Vector2(0.75, 1.35)

	# Variable jump height: release early to cut jump short
	if not is_jump_held() and velocity.y < -100.0:
		velocity.y *= 0.65

	# Horizontal movement with acceleration/friction
	if wall_jump_lock_timer <= 0.0 and not is_climbing:
		if input_x != 0:
			velocity.x = move_toward(velocity.x, input_x * speed, accel * delta)
		else:
			var cur_fric = friction if on_floor else air_friction
			velocity.x = move_toward(velocity.x, 0.0, cur_fric * delta)

	# Celeste 8-Way Dash
	if can_dash and dash_cooldown_timer <= 0.0 and is_dash_just_pressed():
		start_dash(input_x, input_y)

	# Attack
	if can_attack and is_attack_just_pressed():
		attack()

func is_jump_just_pressed() -> bool:
	if InputMap.has_action("jump") and Input.is_action_just_pressed("jump"):
		return true
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)

func is_jump_held() -> bool:
	if InputMap.has_action("jump") and Input.is_action_pressed("jump"):
		return true
	return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W)

func is_dash_just_pressed() -> bool:
	if InputMap.has_action("dash") and Input.is_action_just_pressed("dash"):
		return true
	return Input.is_key_pressed(KEY_K) or Input.is_key_pressed(KEY_X)

func is_climb_held() -> bool:
	if InputMap.has_action("climb") and Input.is_action_pressed("climb"):
		return true
	return Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_C) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func is_attack_just_pressed() -> bool:
	if InputMap.has_action("attack") and Input.is_action_just_pressed("attack"):
		return true
	return Input.is_key_pressed(KEY_L) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func start_dash(input_x: float, input_y: float) -> void:
	can_dash = false
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown

	var dir = Vector2(input_x, input_y)
	if dir == Vector2.ZERO:
		dir = Vector2(facing_dir, 0.0)
	dash_direction = dir.normalized()

	squash_stretch = Vector2(1.5, 0.6)
	spawn_ghost_trail()

func spawn_ghost_trail() -> void:
	if not sprite: return
	var ghost = Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.scale = sprite.global_scale
	ghost.global_position = sprite.global_position
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(1.8, 1.0, 1.0, 0.6)
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)

	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)

func process_elastic_squash(delta: float) -> void:
	if not sprite: return
	squash_stretch = squash_stretch.lerp(Vector2.ONE, delta * 12.0)
	sprite.scale = base_scale * squash_stretch

	if can_dash:
		sprite.modulate = sprite.modulate.lerp(Color.WHITE, delta * 10.0)
	else:
		sprite.modulate = sprite.modulate.lerp(Color(0.8, 0.85, 1.1, 0.9), delta * 10.0)

func bounce(force := -480.0) -> void:
	velocity.y = force
	reset_air_abilities()
	squash_stretch = Vector2(0.6, 1.55)

func reset_air_abilities() -> void:
	jumps_left = max_jumps
	can_dash = true

func attack() -> void:
	can_attack = false
	if attack_area: attack_area.monitoring = true
	if attack_sprite: attack_sprite.visible = true

	if attack_area:
		for body in attack_area.get_overlapping_bodies():
			if body != self and body.has_method("take_damage"):
				body.take_damage(attack_damage)

	await get_tree().create_timer(0.18).timeout
	if attack_area: attack_area.monitoring = false
	if attack_sprite: attack_sprite.visible = false
	can_attack = true

func take_damage(amount: float, knock_dir := Vector2.ZERO) -> void:
	if is_invulnerable or hp <= 0:
		return

	hp = max(0, hp - amount)
	health_changed.emit(hp, max_health)
	velocity = knock_dir * 320.0 + Vector2(0, -180)
	squash_stretch = Vector2(1.3, 0.7)

	if hp <= 0:
		handle_death()
		return

	is_invulnerable = true
	if sprite: sprite.modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	if sprite: sprite.modulate = Color.WHITE
	is_invulnerable = false

func handle_death() -> void:
	lives_left = max(0, lives_left - 1)
	lives_changed.emit(lives_left, max_lives)

	if lives_left > 0:
		_reset_level_entities()
		respawn()
	else:
		hp = 0.0
		health_changed.emit(0.0, max_health)
		velocity = Vector2.ZERO
		set_physics_process(false)
		if sprite:
			sprite.modulate = Color(0.4, 0.4, 0.4, 0.6)
		game_over.emit()
		# Return to main screen after 3 deaths
		get_tree().create_timer(1.8).timeout.connect(func():
			get_tree().change_scene_to_file("res://scene/ui/start_menu.tscn")
		)

func _reset_level_entities() -> void:
	# Despawn all active projectiles to prevent spawn kills
	for group_name in ["projectiles", "ram_projectile", "slop_blast"]:
		for proj in get_tree().get_nodes_in_group(group_name):
			if is_instance_valid(proj) and proj != self:
				proj.queue_free()

	# Clear any projectile areas in the scene root
	var root = get_tree().current_scene
	if root:
		for child in root.get_children():
			if is_instance_valid(child) and (child.name.contains("Ram") or child.name.contains("Slop") or child.name.contains("Projectile")):
				child.queue_free()

	# Reset all enemies and boss to their starting positions and states
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy):
			if enemy.has_method("reset_boss"):
				enemy.reset_boss()
			elif enemy.has_method("reset_to_spawn"):
				enemy.reset_to_spawn()

func respawn() -> void:
	hp = max_health
	velocity = Vector2.ZERO
	global_position = spawn_pos
	is_invulnerable = true
	jumps_left = max_jumps
	reset_air_abilities()
	climb_stamina = max_climb_stamina
	squash_stretch = Vector2.ONE
	health_changed.emit(hp, max_health)
	stamina_changed.emit(climb_stamina, max_climb_stamina)

	# Invulnerability post-respawn with flashing effect (prevents any spawn kill!)
	if sprite:
		var flash_tw = create_tween().set_loops(4)
		flash_tw.tween_property(sprite, "modulate:a", 0.3, 0.15)
		flash_tw.tween_property(sprite, "modulate:a", 1.0, 0.15)
		await flash_tw.finished
		if sprite:
			sprite.modulate = Color.WHITE
	is_invulnerable = false
