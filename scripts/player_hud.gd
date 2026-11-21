extends CanvasLayer

@export var level_title_text := "Level 1"

var max_hp := 100.0
var bar_width := 150.0

@onready var hp_line: ColorRect = $HUD/HpBgLine/HpLine
@onready var hp_text: Label = $HUD/HpText
@onready var level_label: Label = $HUD/LevelLabel

func _ready() -> void:
	if level_label:
		level_label.text = level_title_text

func setup_player(player: Node) -> void:
	if not player: return
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_health_changed)
	if "hp" in player and "max_health" in player:
		_on_health_changed(player.hp, player.max_health)

func _on_health_changed(current: float, maximum: float) -> void:
	max_hp = maximum
	if hp_line:
		hp_line.size.x = bar_width * max(0.0, current / max_hp)
	if hp_text:
		hp_text.text = "HP: %d/%d" % [int(current), int(max_hp)]
