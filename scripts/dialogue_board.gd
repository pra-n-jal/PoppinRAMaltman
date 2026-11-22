extends CanvasLayer

signal dialogue_started
signal dialogue_finished

@export var default_portrait: Texture2D = preload("res://assets/ui/portrait_operator.png")
@export var player_portrait: Texture2D = preload("res://assets/ui/portrait_player.png")
@export var sam_portrait: Texture2D = preload("res://assets/ui/portrait_sam_altman.png")

# Sectioned animated dialogue box frames (128x48 each)
@export var box_frame_textures: Array[Texture2D] = [
	preload("res://assets/ui/dialogue_frames/frame_0.png"),
	preload("res://assets/ui/dialogue_frames/frame_1.png"),
	preload("res://assets/ui/dialogue_frames/frame_2.png"),
	preload("res://assets/ui/dialogue_frames/frame_3.png"),
	preload("res://assets/ui/dialogue_frames/frame_4.png"),
	preload("res://assets/ui/dialogue_frames/frame_5.png"),
	preload("res://assets/ui/dialogue_frames/frame_6.png"),
	preload("res://assets/ui/dialogue_frames/frame_7.png")
]

var dialogue_queue: Array = []
var is_typing := false
var typewriter_tween: Tween = null
var current_player: CharacterBody2D = null

# Animated frame cycling
var anim_timer := 0.0
var current_box_frame := 0

@onready var root_control: Control = $RootControl
@onready var dim_overlay: ColorRect = $RootControl/DimOverlay
@onready var board_panel: PanelContainer = $RootControl/CenterContainer/BoardPanel
@onready var nine_patch_box: NinePatchRect = get_node_or_null("RootControl/CenterContainer/NinePatchBox")
@onready var portrait_rect: TextureRect = $RootControl/CenterContainer/BoardPanel/Margin/HBox/Portrait
@onready var speaker_label: Label = $RootControl/CenterContainer/BoardPanel/Margin/HBox/ContentVBox/SpeakerHBox/SpeakerLabel
@onready var text_label: Label = $RootControl/CenterContainer/BoardPanel/Margin/HBox/ContentVBox/TextLabel
@onready var prompt_label: Label = $RootControl/CenterContainer/BoardPanel/Margin/HBox/ContentVBox/PromptLabel

func _ready() -> void:
	add_to_group("dialogue_board")
	root_control.visible = false
	prompt_label.modulate = Color(1, 1, 1, 0.7)
	_start_prompt_pulse()
	if nine_patch_box and not box_frame_textures.is_empty():
		nine_patch_box.texture = box_frame_textures[0]

func _process(delta: float) -> void:
	if root_control and root_control.visible and nine_patch_box and not box_frame_textures.is_empty():
		anim_timer += delta
		if anim_timer >= 0.075:
			anim_timer = 0.0
			current_box_frame = (current_box_frame + 1) % box_frame_textures.size()
			nine_patch_box.texture = box_frame_textures[current_box_frame]

func _start_prompt_pulse() -> void:
	var tw = create_tween().set_loops()
	tw.tween_property(prompt_label, "modulate:a", 1.0, 0.6)
	tw.tween_property(prompt_label, "modulate:a", 0.35, 0.6)

func show_dialogue(lines: Array, player_node: CharacterBody2D = null) -> void:
	if lines.is_empty():
		return

	dialogue_queue = lines.duplicate()
	current_player = player_node
	if current_player == null:
		var players = get_tree().get_nodes_in_group("player")
		if not players.is_empty():
			current_player = players[0] as CharacterBody2D

	if current_player:
		current_player.set_physics_process(false)
		current_player.velocity = Vector2.ZERO

	root_control.visible = true
	current_box_frame = 0
	if nine_patch_box and not box_frame_textures.is_empty():
		nine_patch_box.texture = box_frame_textures[0]

	dialogue_started.emit()
	_display_next_line()

func _display_next_line() -> void:
	if dialogue_queue.is_empty():
		_close_dialogue()
		return

	var line = dialogue_queue.pop_front()
	var speaker = line.get("speaker", "OPERATOR")
	var text = line.get("text", "")

	if speaker_label:
		speaker_label.text = "[ %s ]" % speaker.to_upper()
		if "SAM" in speaker.to_upper() or "ALTMAN" in speaker.to_upper() or "SLOPPENHEIMER" in speaker.to_upper():
			speaker_label.modulate = Color(1.0, 0.85, 0.3, 1.0)
		elif "PLAYER" in speaker.to_upper() or "MEUKEUL" in speaker.to_upper():
			speaker_label.modulate = Color(0.4, 1.0, 0.4, 1.0)
		else:
			speaker_label.modulate = Color(0.2, 0.9, 1.0, 1.0)

	# Choose portrait
	if portrait_rect:
		if line.has("portrait") and line["portrait"] != null:
			portrait_rect.texture = line["portrait"]
		elif "SAM" in speaker.to_upper() or "ALTMAN" in speaker.to_upper() or "SLOPPENHEIMER" in speaker.to_upper():
			portrait_rect.texture = sam_portrait
		elif "PLAYER" in speaker.to_upper() or "MEUKEUL" in speaker.to_upper():
			portrait_rect.texture = player_portrait
		else:
			portrait_rect.texture = default_portrait

	if text_label:
		text_label.text = text
		text_label.visible_ratio = 0.0

		if typewriter_tween and typewriter_tween.is_valid():
			typewriter_tween.kill()

		is_typing = true
		var duration = max(0.4, text.length() * 0.022)
		typewriter_tween = create_tween()
		typewriter_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
		typewriter_tween.tween_callback(func(): is_typing = false)

func advance() -> void:
	if not root_control.visible:
		return

	if is_typing:
		if typewriter_tween and typewriter_tween.is_valid():
			typewriter_tween.kill()
		if text_label:
			text_label.visible_ratio = 1.0
		is_typing = false
	else:
		_display_next_line()

func _close_dialogue() -> void:
	root_control.visible = false
	if current_player and is_instance_valid(current_player):
		current_player.set_physics_process(true)
	current_player = null
	dialogue_finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not root_control.visible:
		return

	if event.is_action_pressed("ui_accept") or event.is_action_pressed("jump"):
		get_viewport().set_input_as_handled()
		advance()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E, KEY_F]:
			get_viewport().set_input_as_handled()
			advance()
	elif event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		advance()

func _on_board_panel_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		advance()
