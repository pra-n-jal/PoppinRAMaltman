extends CanvasLayer

var max_hp := 200.0
var bar_width := 400.0

@onready var container: Control = $BarContainer
@onready var name_label: Label = $BarContainer/BossName
@onready var hp_line: ColorRect = $BarContainer/BgLine/HpLine

func _ready() -> void:
	container.visible = false

func setup_boss(boss: Node) -> void:
	if not boss: return
	if boss.has_signal("boss_activated"): boss.boss_activated.connect(_on_activated)
	if boss.has_signal("health_changed"): boss.health_changed.connect(_on_health_changed)
	if boss.has_signal("boss_defeated"): boss.boss_defeated.connect(_on_defeated)

func _on_activated(b_name: String, _title: String, _quote: String, b_max: float) -> void:
	max_hp = b_max
	name_label.text = b_name
	container.visible = true
	_on_health_changed(max_hp, max_hp)

func _on_health_changed(hp: float, _max: float) -> void:
	if hp_line:
		hp_line.size.x = bar_width * max(0.0, hp / max_hp)

func _on_defeated() -> void:
	name_label.text += " (DEFEATED)"
	await get_tree().create_timer(1.5).timeout
	container.visible = false
