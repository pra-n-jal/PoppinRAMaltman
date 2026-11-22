extends Node

signal keybindings_changed

const CONFIG_PATH := "user://keybindings.cfg"

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

const ACTION_NAMES := {
	"move_left": "Move Left",
	"move_right": "Move Right",
	"move_up": "Climb Up / Up",
	"move_down": "Climb Down / Down",
	"jump": "Jump & Double Jump",
	"dash": "Celeste Dash",
	"climb": "Wall Climb / Grab",
	"attack": "Attack / Slash"
}

const DEFAULT_KEYS := {
	"move_left": KEY_A,
	"move_right": KEY_D,
	"move_up": KEY_W,
	"move_down": KEY_S,
	"jump": KEY_SPACE,
	"dash": KEY_K,
	"climb": KEY_SHIFT,
	"attack": KEY_J
}

func _ready() -> void:
	init_input_map()
	load_bindings()

func init_input_map() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)

func reset_to_defaults() -> void:
	for action in ACTIONS:
		var keycode: int = DEFAULT_KEYS.get(action, KEY_NONE)
		set_action_key(action, keycode)
	save_bindings()
	keybindings_changed.emit()

func set_action_key(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)

	var ev = InputEventKey.new()
	ev.physical_keycode = keycode as Key
	InputMap.action_add_event(action, ev)

	# Also add alternative arrow keys for basic directions
	if action == "move_left" and keycode != KEY_LEFT:
		var alt = InputEventKey.new()
		alt.physical_keycode = KEY_LEFT
		InputMap.action_add_event(action, alt)
	elif action == "move_right" and keycode != KEY_RIGHT:
		var alt = InputEventKey.new()
		alt.physical_keycode = KEY_RIGHT
		InputMap.action_add_event(action, alt)
	elif action == "move_up" and keycode != KEY_UP:
		var alt = InputEventKey.new()
		alt.physical_keycode = KEY_UP
		InputMap.action_add_event(action, alt)
	elif action == "move_down" and keycode != KEY_DOWN:
		var alt = InputEventKey.new()
		alt.physical_keycode = KEY_DOWN
		InputMap.action_add_event(action, alt)

func rebind(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_bindings()
	keybindings_changed.emit()

func get_action_key_string(action: String) -> String:
	if not InputMap.has_action(action):
		return "None"
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "None"

	var ev = events[0]
	if ev is InputEventKey:
		var code = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return OS.get_keycode_string(code)
	elif ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Left Mouse"
			MOUSE_BUTTON_RIGHT: return "Right Mouse"
			MOUSE_BUTTON_MIDDLE: return "Middle Mouse"
			_: return "Mouse " + str(ev.button_index)
	return ev.as_text()

func get_controls_summary() -> String:
	return "Move: %s/%s | Jump: %s | Dash: %s | Climb: %s" % [
		get_action_key_string("move_left"),
		get_action_key_string("move_right"),
		get_action_key_string("jump"),
		get_action_key_string("dash"),
		get_action_key_string("climb")
	]

func save_bindings() -> void:
	var cfg = ConfigFile.new()
	for action in ACTIONS:
		var events = InputMap.action_get_events(action)
		if not events.is_empty():
			var ev = events[0]
			if ev is InputEventKey:
				var code = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
				cfg.set_value("keybindings", action, code)
	cfg.save(CONFIG_PATH)

func load_bindings() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err == OK:
		for action in ACTIONS:
			if cfg.has_section_key("keybindings", action):
				var code = cfg.get_value("keybindings", action)
				set_action_key(action, code)
	else:
		reset_to_defaults()
