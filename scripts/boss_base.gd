extends CharacterBody2D

signal boss_activated(boss_name: String, boss_title: String, boss_quote: String, max_hp: float)
signal health_changed(current_hp: float, max_hp: float)
signal boss_defeated()

@export var boss_name := "Boss"
@export var boss_title := ""
@export var boss_quote := ""
@export var phase2_quote := ""
@export var max_health := 200.0
@export var move_speed := 100.0
@export var dash_speed := 300.0
@export var attack_interval := 2.5
@export var contact_damage := 20.0
@export var projectile_scene: PackedScene = preload("res://scene/entities/projectile.tscn")

var hp := 200.0
var is_active := false
var player: CharacterBody2D = null
var attack_timer := 0.0
var dir := -1.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var shoot_point: Marker2D = $ShootPoint

func _ready() -> void:
	add_to_group("boss")
	hp = max_health

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_active:
		move_and_slide()
		return

	# Move toward player
	if player:
		dir = sign(player.global_position.x - global_position.x)
		velocity.x = dir * move_speed
		if sprite: sprite.flip_h = dir > 0
	else:
		_find_player()

	# Attack cooldown
	attack_timer += delta
	if attack_timer >= attack_interval:
		attack_timer = 0.0
		attack()

	move_and_slide()

	# Contact damage
	for i in get_slide_collision_count():
		var col = get_slide_collision(i).get_collider()
		if col and col.is_in_group("player") and col.has_method("take_damage"):
			col.take_damage(contact_damage, Vector2(dir, -0.4).normalized())

func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D

func activate_boss() -> void:
	if is_active:
		return
	is_active = true
	_find_player()
	boss_activated.emit(boss_name, "", "", max_health)
	health_changed.emit(hp, max_health)

func attack() -> void:
	if not player or not projectile_scene:
		return

	# Telegraph flash then shoot
	if sprite: sprite.modulate = Color.YELLOW
	await get_tree().create_timer(0.3).timeout
	if hp <= 0:
		return
	if sprite: sprite.modulate = Color.WHITE

	var proj = projectile_scene.instantiate()
	proj.global_position = shoot_point.global_position if shoot_point else global_position
	proj.direction = (player.global_position - proj.global_position).normalized()
	get_parent().add_child(proj)

func take_damage(amount: float) -> void:
	if hp <= 0:
		return

	if not is_active:
		activate_boss()

	hp = max(0, hp - amount)
	health_changed.emit(hp, max_health)

	if sprite: sprite.modulate = Color.RED
	await get_tree().create_timer(0.15).timeout
	if sprite: sprite.modulate = Color.WHITE

	if hp <= 0:
		boss_defeated.emit()
		queue_free()

func _on_arena_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_active:
		player = body as CharacterBody2D
		activate_boss()
