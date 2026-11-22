extends Node2D

@export var level_number := 1
@export var level_name := "Level 1"
@export var show_start_dialogue := true
@export var start_dialogue_lines: Array = []

func _ready() -> void:
	var player = get_node_or_null("Player")
	var boss = get_node_or_null("Boss")
	var hud = get_node_or_null("PlayerHUD")
	var boss_bar = get_node_or_null("BossHealthBar")
	var portal = get_node_or_null("LevelPortal")
	var dialogue_board = get_node_or_null("DialogueBoard")
	if dialogue_board == null:
		dialogue_board = get_tree().get_first_node_in_group("dialogue_board")

	if player and hud:
		hud.setup_player(player)

	if boss and boss_bar:
		boss_bar.setup_boss(boss)

	if boss and portal and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(portal.unlock_portal)

	# Trigger start dialogue if enabled
	if show_start_dialogue and dialogue_board:
		var lines = start_dialogue_lines
		if lines.is_empty():
			lines = [
				{"speaker": "MEUKEUL", "text": "I must go on through this slop brain to get to the man destroying it all."}
			]
		# Brief delay to allow scene and camera to initialize smoothly
		get_tree().create_timer(0.2).timeout.connect(func():
			dialogue_board.show_dialogue(lines, player as CharacterBody2D)
		)
