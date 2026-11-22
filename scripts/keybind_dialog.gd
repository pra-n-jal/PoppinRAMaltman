extends Control

signal closed

const ACTIONS := [
	"move_left",
	"move_right",
	"move_up",
	"move_down",
	"jump",
	"dash",
	"climb",
	"attack"
]

var active_action := ""
var action_buttons: Dictionary = {}

@onready var action_list_container: VBoxContainer = $CenterContainer/Panel/MarginContainer/VBoxContainer/ScrollContainer/ActionList
@onready var reset_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonsHBox/ResetBtn
@onready var done_button: Button = $CenterContainer/Panel/MarginContainer/VBoxContainer/ButtonsHBox/DoneBtn
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/VBoxContainer/StatusLabel

func _ready() -> void:
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if done_button:
		done_button.pressed.connect(_on_done_pressed)

	build_action_rows()
	refresh_buttons()

	if KeybindManager:
		KeybindManager.keybindings_changed.connect(refresh_buttons)

func build_action_rows() -> void:
	if not action_list_container:
		return

	# Clear existing children
	for child in action_list_container.get_children():
		child.queue_free()
	action_buttons.clear()

	for action in ACTIONS:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 20)

		var label = Label.new()
		label.text = KeybindManager.ACTION_NAMES.get(action, action.capitalize())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		row.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 32)
		btn.text = KeybindManager.get_action_key_string(action)
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_action_button_pressed.bind(action, btn))
		row.add_child(btn)

		action_buttons[action] = btn
		action_list_container.add_child(row)

func refresh_buttons() -> void:
	for action in action_buttons:
		var btn: Button = action_buttons[action]
		if active_action == action:
			btn.text = "[ Press Key... ]"
			btn.modulate = Color(1.5, 1.2, 0.4)
		else:
			btn.text = KeybindManager.get_action_key_string(action)
			btn.modulate = Color.WHITE

func _on_action_button_pressed(action: String, btn: Button) -> void:
	if active_action != "":
		# Cancel previous waiting action
		active_action = ""
		refresh_buttons()

	active_action = action
	refresh_buttons()
	if status_label:
		status_label.text = "Press any key for '%s' (ESC to cancel)..." % KeybindManager.ACTION_NAMES.get(action, action)

func _input(event: InputEvent) -> void:
	if active_action == "":
		return

	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			# Cancel rebinding
			active_action = ""
			if status_label:
				status_label.text = "Rebinding cancelled."
			refresh_buttons()
			return

		# Rebind action
		KeybindManager.rebind(active_action, event)
		if status_label:
			status_label.text = "Bound '%s' to %s" % [
				KeybindManager.ACTION_NAMES.get(active_action, active_action),
				KeybindManager.get_action_key_string(active_action)
			]
		active_action = ""
		refresh_buttons()
	elif event is InputEventMouseButton and event.is_pressed():
		# Allow binding mouse buttons (like Right Mouse for Climb, Left Mouse for Attack)
		get_viewport().set_input_as_handled()
		KeybindManager.rebind(active_action, event)
		if status_label:
			status_label.text = "Bound '%s' to %s" % [
				KeybindManager.ACTION_NAMES.get(active_action, active_action),
				KeybindManager.get_action_key_string(active_action)
			]
		active_action = ""
		refresh_buttons()

func _on_reset_pressed() -> void:
	active_action = ""
	KeybindManager.reset_to_defaults()
	refresh_buttons()
	if status_label:
		status_label.text = "All controls reset to defaults."

func _on_done_pressed() -> void:
	active_action = ""
	visible = false
	closed.emit()
