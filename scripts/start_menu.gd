extends Control

@onready var background: TextureRect = $Background
@onready var start_btn: BaseButton = $VBox/StartBtn
@onready var test_boss_btn: Button = get_node_or_null("VBox/TestBossBtn")
@onready var controls_btn: Button = $VBox/ControlsBtn
@onready var quit_btn: Button = $VBox/QuitBtn
@onready var controls_label: Label = $ControlsLabel
@onready var keybind_dialog: Control = $KeybindDialog

var backdrop_frames: Array[Texture2D] = []
var current_frame_idx: int = 0
var frame_timer: float = 0.0
const FRAME_DURATION: float = 0.16

func _ready() -> void:
	backdrop_frames = [
		load("res://assets/ui/title_banner/title_0.png"),
		load("res://assets/ui/title_banner/title_1.png"),
		load("res://assets/ui/title_banner/title_2.png")
	]

	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if test_boss_btn:
		test_boss_btn.pressed.connect(_on_test_boss_pressed)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

	if keybind_dialog and keybind_dialog.has_signal("closed"):
		keybind_dialog.closed.connect(_update_controls_label)

	if KeybindManager:
		KeybindManager.keybindings_changed.connect(_update_controls_label)

	_update_controls_label()

func _process(delta: float) -> void:
	if background and backdrop_frames.size() > 1:
		frame_timer += delta
		if frame_timer >= FRAME_DURATION:
			frame_timer -= FRAME_DURATION
			current_frame_idx = (current_frame_idx + 1) % backdrop_frames.size()
			background.texture = backdrop_frames[current_frame_idx]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_B:
			_on_test_boss_pressed()

func _update_controls_label() -> void:
	if controls_label and KeybindManager:
		controls_label.text = KeybindManager.get_controls_summary()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/levels/parkour_run.tscn")

func _on_test_boss_pressed() -> void:
	get_tree().change_scene_to_file("res://scene/levels/boss_level_sam_altman.tscn")

func _on_controls_pressed() -> void:
	if keybind_dialog:
		keybind_dialog.visible = true
		if keybind_dialog.has_method("refresh_buttons"):
			keybind_dialog.refresh_buttons()

func _on_quit_pressed() -> void:
	get_tree().quit()
