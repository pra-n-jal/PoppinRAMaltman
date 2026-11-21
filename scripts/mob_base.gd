extends CharacterBody2D

signal mob_died(mob: CharacterBody2D)

@export var mob_name := "Mob"
@export var max_health := 30.0
@export var patrol_speed := 70.0
@export var chase_speed := 120.0
@export var contact_damage := 15.0
@export var detection_radius := 220.0
@export var show_health_bar := false

var hp := 30.0
var dir := 1.0
var player: CharacterBody2D = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var ledge_ray: RayCast2D = $LedgeRayCast
@onready var wall_ray: RayCast2D = $WallRayCast
@onready var health_bar: Control = $HealthBar
@onready var hp_line: ColorRect = $HealthBar/BgLine/HpLine

func _ready() -> void:
	add_to_group("enemies")
	hp = max_health
	if health_bar:
		health_bar.visible = show_health_bar
		update_health_bar()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Turn around at wall or ledge
	if is_on_wall() or (wall_ray and wall_ray.is_colliding()) or (is_on_floor() and ledge_ray and not ledge_ray.is_colliding()):
		dir *= -1.0
		if sprite: sprite.flip_h = dir < 0
		if ledge_ray: ledge_ray.position.x = 20 * dir
		if wall_ray: wall_ray.target_position.x = 24 * dir

	# Chase if player detected, else patrol
	var current_speed = patrol_speed
	if player:
		dir = sign(player.global_position.x - global_position.x)
		if sprite: sprite.flip_h = dir < 0
		current_speed = chase_speed

	velocity.x = dir * current_speed
	move_and_slide()

	# Contact damage to player
	for i in get_slide_collision_count():
		var col = get_slide_collision(i).get_collider()
		if col and col.is_in_group("player") and col.has_method("take_damage"):
			col.take_damage(contact_damage, Vector2(dir, -0.4).normalized())

func take_damage(amount: float) -> void:
	hp = max(0, hp - amount)
	update_health_bar()

	if show_health_bar and health_bar:
		health_bar.visible = true

	if sprite: sprite.modulate = Color.RED
	await get_tree().create_timer(0.15).timeout
	if sprite: sprite.modulate = Color.WHITE

	if hp <= 0:
		mob_died.emit(self)
		queue_free()

func update_health_bar() -> void:
	if hp_line:
		hp_line.size.x = 32.0 * max(0.0, hp / max_health)

func _on_detection_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D

func _on_detection_body_exited(body: Node2D) -> void:
	if body == player:
		player = null

func _on_stomp_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("bounce"):
			body.bounce(-360.0)
		take_damage(25.0)
