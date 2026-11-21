extends Node2D

@export var level_number := 1
@export var level_name := "Level 1"

func _ready() -> void:
	var player = get_node_or_null("Player")
	var boss = get_node_or_null("Boss")
	var hud = get_node_or_null("PlayerHUD")
	var boss_bar = get_node_or_null("BossHealthBar")
	var portal = get_node_or_null("LevelPortal")

	if player and hud:
		hud.setup_player(player)

	if boss and boss_bar:
		boss_bar.setup_boss(boss)

	if boss and portal and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(portal.unlock_portal)
