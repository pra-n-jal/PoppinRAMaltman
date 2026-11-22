extends CharacterBody2D

signal boss_activated(boss_name: String, boss_title: String, boss_quote: String, max_hp: float)
signal health_changed(current_hp: float, max_hp: float)
signal boss_defeated()

enum State {
	IDLE,
	WALKING,
	SHOULDERS_TAUNT,
	POWER_STRIKE_WINDUP,
	POWER_STRIKE_LUNGE,
	POWER_STRIKE_RECOVERY,
	SKILL_CHARGING,
	AIMING,
	RAM_THROW,
	DEFEATED
}

@export var boss_name := "Sam Altman"
@export var boss_title := "The Sloppenheimer"
@export var boss_quote := "Behold my compute. All the RAM belongs to me."
@export var phase2_quote := "Overclocking datacenters! Prepare for instant allocation!"
@export var max_health := 500.0
@export var move_speed := 130.0
@export var dash_speed := 430.0
@export var attack_interval := 2.2
@export var contact_damage := 20.0

@export var ram_projectile_scene: PackedScene = preload("res://scene/entities/ram_projectile.tscn")
@export var slop_blast_scene: PackedScene = preload("res://scene/entities/slop_blast.tscn")

var hp := 500.0
var is_active := false
var is_phase2 := false
var is_phase3 := false
var player: CharacterBody2D = null
var current_state: State = State.IDLE
var state_timer := 0.0
var attack_cooldown := 1.0
var facing_dir := 1.0
var attack_counter := 0
var contact_cooldown := 0.0
var spawn_pos := Vector2.ZERO

# Static cached resources to eliminate all scene load stutter
static var _cached_frames: SpriteFrames = null
static var _cached_banners: Dictionary = {}

var section_banners: Dictionary = {}
var banner_tween: Tween = null

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var shoot_point: Marker2D = $ShootPoint
@onready var melee_area: Area2D = $MeleeArea
@onready var charge_aura: CPUParticles2D = get_node_or_null("ChargeAura")
@onready var warning_label: Label = get_node_or_null("WarningLabel")
@onready var section_banner: Sprite2D = get_node_or_null("SectionBanner")

func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemies")
	hp = max_health
	spawn_pos = global_position
	_setup_sprite_frames()
	_load_section_banners()

	if warning_label:
		warning_label.visible = false
	if charge_aura:
		charge_aura.emitting = false
	if melee_area:
		melee_area.monitoring = false
	if section_banner:
		section_banner.visible = false

func _load_section_banners() -> void:
	if _cached_banners.size() > 0:
		section_banners = _cached_banners
		return
	var path_base = "res://assets/boss/sam_altman/banners/"
	_cached_banners = {
		"power_strike": load(path_base + "banner_power_strike_clean.png"),
		"skill_charging": load(path_base + "banner_skill_charging_clean.png"),
		"aiming": load(path_base + "banner_aiming_clean.png"),
		"walking": load(path_base + "banner_walking_clean.png"),
		"shoulders": load(path_base + "banner_shoulders_clean.png")
	}
	section_banners = _cached_banners

func show_section_banner(section_key: String, duration := 1.0) -> void:
	if not section_banner or not section_banners.has(section_key):
		return
	var tex = section_banners[section_key]
	if not tex:
		return

	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()

	section_banner.texture = tex
	section_banner.visible = true
	section_banner.scale = Vector2(0.5, 0.5)
	section_banner.modulate = Color(1, 1, 1, 1)

	banner_tween = create_tween()
	banner_tween.tween_property(section_banner, "scale", Vector2(0.85, 0.85), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tween.tween_interval(duration)
	banner_tween.tween_property(section_banner, "modulate:a", 0.0, 0.25)
	banner_tween.tween_callback(func(): if section_banner: section_banner.visible = false)

func _setup_sprite_frames() -> void:
	if _cached_frames != null:
		animated_sprite.sprite_frames = _cached_frames
		animated_sprite.play("idle")
		return

	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
		return

	var frames = SpriteFrames.new()
	var path_base = "res://assets/boss/sam_altman/"

	# 1. Idle (calm stance)
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 6.0)
	frames.set_animation_loop("idle", true)
	for i in range(2):
		var tex = load(path_base + "idle/idle_%d.png" % i)
		if tex: frames.add_frame("idle", tex)

	# 2. Section: WALKING (8 frames)
	frames.add_animation("walking")
	frames.set_animation_speed("walking", 9.0)
	frames.set_animation_loop("walking", true)
	for i in range(8):
		var tex = load(path_base + "walk/walk_%d.png" % i)
		if tex: frames.add_frame("walking", tex)

	# 3. Section: SHOULDERS (8 frames - flex / shoulder shrug taunt)
	frames.add_animation("shoulders")
	frames.set_animation_speed("shoulders", 8.0)
	frames.set_animation_loop("shoulders", true)
	for i in range(8):
		var tex = load(path_base + "shoulders/shoulders_%d.png" % i)
		if tex: frames.add_frame("shoulders", tex)

	# 4. Section: POWER STRIKE (8 frames - melee lunge punch)
	frames.add_animation("power_strike")
	frames.set_animation_speed("power_strike", 10.0)
	frames.set_animation_loop("power_strike", false)
	for i in range(8):
		var tex = load(path_base + "strike/strike_%d.png" % i)
		if tex: frames.add_frame("power_strike", tex)

	# 5. Section: SKILL CHARGING (6 frames - aura energy charge)
	frames.add_animation("skill_charging")
	frames.set_animation_speed("skill_charging", 8.0)
	frames.set_animation_loop("skill_charging", true)
	for i in range(6):
		var tex = load(path_base + "charge/charge_%d.png" % i)
		if tex: frames.add_frame("skill_charging", tex)

	# 6. Section: AIMING (2 frames - target lock stance)
	frames.add_animation("aiming")
	frames.set_animation_speed("aiming", 6.0)
	frames.set_animation_loop("aiming", true)
	for i in range(2):
		var tex = load(path_base + "aim/aim_%d.png" % i)
		if tex: frames.add_frame("aiming", tex)

	_cached_frames = frames
	animated_sprite.sprite_frames = _cached_frames
	animated_sprite.play("idle")

func reset_boss() -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	hp = max_health
	is_active = false
	is_phase2 = false
	is_phase3 = false
	current_state = State.IDLE
	state_timer = 0.0
	attack_cooldown = 1.0
	attack_counter = 0
	contact_cooldown = 1.0
	modulate = Color.WHITE

	if warning_label:
		warning_label.visible = false
	if charge_aura:
		charge_aura.emitting = false
	if melee_area:
		melee_area.monitoring = false
	if section_banner:
		section_banner.visible = false
	if animated_sprite:
		animated_sprite.play("idle")
		animated_sprite.modulate = Color.WHITE
	health_changed.emit(hp, max_health)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if contact_cooldown > 0.0:
		contact_cooldown -= delta

	if current_state == State.DEFEATED:
		move_and_slide()
		return

	if not is_active:
		if animated_sprite and animated_sprite.animation != "idle":
			animated_sprite.play("idle")
		velocity.x = move_toward(velocity.x, 0, 15.0)
		move_and_slide()
		return

	if not player or not is_instance_valid(player):
		_find_player()

	state_timer += delta

	# State Machine matching the sprite sheet sectioners
	match current_state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0, 20.0)
			if animated_sprite and animated_sprite.animation != "idle":
				animated_sprite.play("idle")
			if player:
				_update_facing_to_player()
				attack_cooldown -= delta
				if attack_cooldown <= 0.0:
					_decide_next_phase_action()
				elif abs(player.global_position.x - global_position.x) > 110.0:
					_change_state(State.WALKING)

		State.WALKING:
			if player:
				_update_facing_to_player()
				var diff = player.global_position.x - global_position.x
				var dist = abs(diff)
				var cur_speed = move_speed * (1.35 if is_phase3 else (1.15 if is_phase2 else 1.0))
				velocity.x = facing_dir * cur_speed

				if animated_sprite and animated_sprite.animation != "walking":
					animated_sprite.play("walking")

				attack_cooldown -= delta
				if attack_cooldown <= 0.0:
					_decide_next_phase_action()
				elif dist <= 95.0:
					_change_state(State.IDLE)
			else:
				_change_state(State.IDLE)

		State.SHOULDERS_TAUNT:
			velocity.x = move_toward(velocity.x, 0, 20.0)
			if animated_sprite and animated_sprite.animation != "shoulders":
				animated_sprite.play("shoulders")
			if state_timer >= 1.0:
				attack_cooldown = 0.5
				_change_state(State.IDLE)

		State.SKILL_CHARGING:
			velocity.x = move_toward(velocity.x, 0, 25.0)
			var charge_dur = 0.8 if is_phase3 else 1.1
			if state_timer >= charge_dur:
				# If far or every 3rd attack -> transition to AIMING for RAM throw
				if attack_counter % 3 == 0 or (player and abs(player.global_position.x - global_position.x) > 340.0):
					_change_state(State.AIMING)
				else:
					# Otherwise unleash POWER STRIKE
					_change_state(State.POWER_STRIKE_WINDUP)

		State.POWER_STRIKE_WINDUP:
			velocity.x = move_toward(velocity.x, 0, 25.0)
			if state_timer >= 0.22:
				_change_state(State.POWER_STRIKE_LUNGE)

		State.POWER_STRIKE_LUNGE:
			velocity.x = facing_dir * (dash_speed * (1.2 if is_phase3 else 1.0))
			if melee_area and not melee_area.monitoring:
				melee_area.monitoring = true
			if melee_area:
				for body in melee_area.get_overlapping_bodies():
					if body.is_in_group("player") and body.has_method("take_damage"):
						body.take_damage(35.0, Vector2(facing_dir, -0.4).normalized())
			if state_timer >= 0.22:
				if melee_area:
					melee_area.monitoring = false
				_change_state(State.POWER_STRIKE_RECOVERY)

		State.POWER_STRIKE_RECOVERY:
			velocity.x = move_toward(velocity.x, 0, 20.0)
			if state_timer >= 0.25:
				attack_cooldown = (attack_interval * 0.6) if is_phase2 else attack_interval
				_change_state(State.IDLE)

		State.AIMING:
			velocity.x = move_toward(velocity.x, 0, 25.0)
			if player:
				_update_facing_to_player()
			if state_timer >= 0.35:
				_change_state(State.RAM_THROW)

		State.RAM_THROW:
			velocity.x = move_toward(velocity.x, 0, 25.0)
			if state_timer >= 0.45:
				attack_cooldown = (attack_interval * 0.7) if is_phase2 else (attack_interval * 1.1)
				_change_state(State.IDLE)

	move_and_slide()

	# Contact damage with player
	if contact_cooldown <= 0.0 and current_state != State.DEFEATED:
		for i in get_slide_collision_count():
			var col = get_slide_collision(i).get_collider()
			if col and col.is_in_group("player") and col.has_method("take_damage"):
				col.take_damage(contact_damage, Vector2(facing_dir, -0.4).normalized())
				contact_cooldown = 0.75
				break

func _change_state(new_state: State) -> void:
	current_state = new_state
	state_timer = 0.0

	match new_state:
		State.IDLE:
			if animated_sprite:
				animated_sprite.play("idle")
			modulate = Color.WHITE

		State.WALKING:
			if animated_sprite:
				animated_sprite.play("walking")
			modulate = Color.WHITE

		State.SHOULDERS_TAUNT:
			if animated_sprite:
				animated_sprite.play("shoulders")
			show_section_banner("shoulders", 1.0)
			modulate = Color(1.2, 1.1, 0.9, 1.0)

		State.SKILL_CHARGING:
			if animated_sprite:
				animated_sprite.play("skill_charging")
			if charge_aura:
				charge_aura.emitting = true
			show_section_banner("skill_charging", 1.0)

		State.POWER_STRIKE_WINDUP:
			if charge_aura:
				charge_aura.emitting = false
			if animated_sprite:
				animated_sprite.play("power_strike")
				animated_sprite.frame = 0
			show_section_banner("power_strike", 0.8)
			modulate = Color(1.3, 0.9, 0.3, 1.0) # Yellow telegraph

		State.POWER_STRIKE_LUNGE:
			modulate = Color.WHITE
			# Also spawn shockwave projectile in phase 2/3
			if is_phase2 or is_phase3:
				_fire_slop_blast()

		State.POWER_STRIKE_RECOVERY:
			modulate = Color.WHITE

		State.AIMING:
			if charge_aura:
				charge_aura.emitting = false
			if animated_sprite:
				animated_sprite.play("aiming")
			if warning_label:
				warning_label.text = "⚠ ALLOCATING LETHAL RAM ⚠"
				warning_label.visible = true
			show_section_banner("aiming", 0.8)

		State.RAM_THROW:
			if warning_label:
				warning_label.visible = false
			_sling_ram_projectile()
			if animated_sprite:
				animated_sprite.play("power_strike")
				animated_sprite.frame = 5

func _decide_next_phase_action() -> void:
	if not player or hp <= 0:
		return
	attack_counter += 1
	var dist = abs(player.global_position.x - global_position.x)

	# In Phase 1: Occasional SHOULDERS flex / taunt
	if not is_phase2 and attack_counter % 4 == 0:
		_change_state(State.SHOULDERS_TAUNT)
	# Long range or every 3 attacks: SKILL CHARGING into AIMING & LETHAL RAM
	elif attack_counter % 3 == 0 or dist > 360.0:
		_change_state(State.SKILL_CHARGING)
	elif dist < 130.0:
		# Close range POWER STRIKE
		_change_state(State.POWER_STRIKE_WINDUP)
	else:
		# Mid-range: SKILL CHARGING
		_change_state(State.SKILL_CHARGING)

func _fire_slop_blast() -> void:
	if slop_blast_scene and player:
		var blast = slop_blast_scene.instantiate()
		blast.global_position = shoot_point.global_position if shoot_point else global_position
		blast.direction = Vector2(facing_dir, 0).normalized()
		get_parent().add_child(blast)

		if is_phase3:
			var blast2 = slop_blast_scene.instantiate()
			blast2.global_position = blast.global_position + Vector2(0, -30)
			var aim = (player.global_position - blast2.global_position).normalized()
			blast2.direction = aim
			get_parent().add_child(blast2)

func _sling_ram_projectile() -> void:
	if ram_projectile_scene and player:
		var ram = ram_projectile_scene.instantiate()
		ram.global_position = shoot_point.global_position if shoot_point else global_position
		var target_vector = (player.global_position - ram.global_position).normalized()
		ram.direction = target_vector
		get_parent().add_child(ram)

func _update_facing_to_player() -> void:
	if not player: return
	var diff = player.global_position.x - global_position.x
	facing_dir = 1.0 if diff >= 0 else -1.0
	if animated_sprite:
		animated_sprite.flip_h = (facing_dir < 0)
	if shoot_point:
		shoot_point.position.x = abs(shoot_point.position.x) * facing_dir
	if melee_area:
		melee_area.position.x = abs(melee_area.position.x) * facing_dir

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D

func activate_boss() -> void:
	if is_active:
		return
	is_active = true
	_find_player()
	boss_activated.emit(boss_name, boss_title, boss_quote, max_health)
	health_changed.emit(hp, max_health)
	show_section_banner("shoulders", 1.2)
	_change_state(State.SHOULDERS_TAUNT)

func take_damage(amount: float) -> void:
	if hp <= 0 or current_state == State.DEFEATED:
		return

	if not is_active:
		activate_boss()

	hp = max(0, hp - amount)
	health_changed.emit(hp, max_health)

	# Hit flash
	if animated_sprite:
		animated_sprite.modulate = Color.RED
		var tw = create_tween()
		tw.tween_property(animated_sprite, "modulate", Color.WHITE, 0.12)

	# Phase 2 trigger at 66% HP
	if hp <= max_health * 0.66 and not is_phase2:
		is_phase2 = true
		show_section_banner("skill_charging", 1.5)

	# Phase 3 trigger at 33% HP
	if hp <= max_health * 0.33 and not is_phase3:
		is_phase3 = true
		if warning_label:
			warning_label.text = "⚡ OVERCLOCK MODE: MAXIMUM COMPUTE ⚡"
			warning_label.visible = true
			get_tree().create_timer(1.8).timeout.connect(func(): if warning_label: warning_label.visible = false)
		show_section_banner("aiming", 1.5)

	if hp <= 0:
		_die()

func _die() -> void:
	current_state = State.DEFEATED
	is_active = false
	velocity = Vector2.ZERO
	if charge_aura:
		charge_aura.emitting = false
	if warning_label:
		warning_label.visible = false
	if section_banner:
		section_banner.visible = false

	# Dramatic defeat explosion
	var p = CPUParticles2D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 55
	p.lifetime = 1.4
	p.spread = 180.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 300.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	p.color = Color(0.2, 0.9, 1.0, 1.0)
	p.global_position = global_position
	get_parent().add_child(p)

	boss_defeated.emit()
	queue_free()

func _on_arena_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_active:
		player = body as CharacterBody2D
		activate_boss()
