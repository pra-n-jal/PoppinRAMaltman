extends Node2D

@export var mob_scene: PackedScene = preload("res://scene/entities/mob.tscn")
@export var spawn_interval := 4.0
@export var max_active_mobs := 3

var mobs: Array[Node] = []
var timer := 0.0

@onready var spawn_pos: Vector2 = $SpawnPoint.global_position if has_node("SpawnPoint") else global_position

func _process(delta: float) -> void:
	timer += delta
	if timer >= spawn_interval:
		timer = 0.0
		mobs = mobs.filter(func(m): return is_instance_valid(m))
		if mobs.size() < max_active_mobs:
			spawn()

func spawn() -> void:
	if not mob_scene:
		return
	var mob = mob_scene.instantiate()
	mob.global_position = spawn_pos
	get_parent().add_child(mob)
	mobs.append(mob)
