extends CanvasLayer

@export var level_title_text := "PARKOUR RUN: NEURAL HIGHWAY"

var max_hp := 100.0
var max_stamina := 100.0

@onready var hp_gauge: Control = get_node_or_null("HUD/LeftHUDBox/GaugesHBox/HPContainer/HpGauge")
@onready var stamina_gauge: Control = get_node_or_null("HUD/LeftHUDBox/GaugesHBox/StaminaContainer/StaminaGauge")
@onready var lives_label: Label = get_node_or_null("HUD/LeftHUDBox/LivesLabel")
@onready var test_boss_btn: Button = get_node_or_null("HUD/TestBossHudBtn")
@onready var level_label: Label = get_node_or_null("HUD/LeftHUDBox/LevelLabel")
@onready var controls_label: Label = get_node_or_null("HUD/LeftHUDBox/ControlsLabel")

# Game Over Screen Nodes
@onready var game_over_panel: Control = get_node_or_null("GameOverPanel")
@onready var restart_btn: Button = get_node_or_null("GameOverPanel/CenterContainer/VBox/ButtonsHBox/RestartBtn")
@onready var menu_btn: Button = get_node_or_null("GameOverPanel/CenterContainer/VBox/ButtonsHBox/MenuBtn")

func _ready() -> void:
	if level_label:
		level_label.text = level_title_text
	if game_over_panel:
		game_over_panel.visible = false
	if test_boss_btn:
		test_boss_btn.pressed.connect(_on_test_boss_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_menu_pressed)

	_update_controls_label()
	if KeybindManager:
		KeybindManager.keybindings_changed.connect(_update_controls_label)

func _update_controls_label() -> void:
	if controls_label and KeybindManager:
		controls_label.text = "%s/%s: Move | %s: Jump (Double Jump) | %s: Dash (8-Way) | %s: Climb" % [
			KeybindManager.get_action_key_string("move_left"),
			KeybindManager.get_action_key_string("move_right"),
			KeybindManager.get_action_key_string("jump"),
			KeybindManager.get_action_key_string("dash"),
			KeybindManager.get_action_key_string("climb")
		]

func setup_player(player: Node) -> void:
	if not player: return
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_stamina_changed)
	if player.has_signal("lives_changed"):
		player.lives_changed.connect(_on_lives_changed)
	if player.has_signal("game_over"):
		player.game_over.connect(_on_game_over)

	if "hp" in player and "max_health" in player:
		_on_health_changed(player.hp, player.max_health)
	if "climb_stamina" in player and "max_climb_stamina" in player:
		_on_stamina_changed(player.climb_stamina, player.max_climb_stamina)
	if "lives_left" in player and "max_lives" in player:
		_on_lives_changed(player.lives_left, player.max_lives)

func _on_health_changed(current: float, maximum: float) -> void:
	max_hp = maximum
	if hp_gauge and hp_gauge.has_method("set_gauge_value"):
		hp_gauge.set_gauge_value(current, maximum)

func _on_stamina_changed(current: float, maximum: float) -> void:
	max_stamina = maximum
	if stamina_gauge and stamina_gauge.has_method("set_gauge_value"):
		stamina_gauge.set_gauge_value(current, maximum)

func _on_lives_changed(current_lives: int, max_lives: int) -> void:
	if lives_label:
		var hearts = ""
		for i in range(max_lives):
			if i < current_lives:
				hearts += "❤️ "
			else:
				hearts += "🖤 "
		lives_label.text = "LIVES: %s" % hearts.strip_edges()

func _on_game_over() -> void:
	if game_over_panel:
		game_over_panel.visible = true
		if menu_btn:
			menu_btn.grab_focus()
	# Auto return to main menu after 1.8s
	get_tree().create_timer(1.8).timeout.connect(func():
		if game_over_panel and game_over_panel.visible:
			_on_menu_pressed()
	)

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/ui/start_menu.tscn")

func _on_test_boss_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/levels/boss_level_sam_altman.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode in [KEY_F1, KEY_B]:
			_on_test_boss_pressed()
