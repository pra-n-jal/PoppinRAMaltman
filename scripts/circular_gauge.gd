@tool
extends Control

@export var value := 100.0:
	set(v):
		value = v
		queue_redraw()

@export var max_value := 100.0:
	set(v):
		max_value = max(0.001, v)
		queue_redraw()

@export var gauge_title := "HP":
	set(v):
		gauge_title = v
		if title_label: title_label.text = v
		queue_redraw()

@export var fg_color := Color(0.95, 0.2, 0.25, 1.0): # Default solid red for HP
	set(v):
		fg_color = v
		queue_redraw()

@export var bg_color := Color(0.12, 0.08, 0.1, 0.85): # Dark background for empty pie
	set(v):
		bg_color = v
		queue_redraw()

@export var border_color := Color(1.0, 1.0, 1.0, 0.2):
	set(v):
		border_color = v
		queue_redraw()

@export var radius := 28.0:
	set(v):
		radius = v
		custom_minimum_size = Vector2(v * 2 + 8, v * 2 + 8)
		queue_redraw()

var display_value := 100.0
@onready var val_label: Label = get_node_or_null("ValueLabel")
@onready var title_label: Label = get_node_or_null("TitleLabel")

func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2 + 8, radius * 2 + 8)
	display_value = value
	_update_labels()

func set_gauge_value(current: float, maximum: float) -> void:
	max_value = maximum
	value = current
	_update_labels()
	queue_redraw()

func _process(delta: float) -> void:
	if abs(display_value - value) > 0.1:
		display_value = lerp(display_value, value, delta * 12.0)
		_update_labels()
		queue_redraw()

func _update_labels() -> void:
	if val_label:
		if gauge_title == "STAMINA":
			val_label.text = "%d%%" % int((value / max_value) * 100.0)
		else:
			val_label.text = "%d" % int(value)
	if title_label:
		title_label.text = gauge_title

func _draw() -> void:
	var center = size * 0.5
	var r = radius
	var ratio = clamp(display_value / max_value, 0.0, 1.0)

	# 1. Solid background circle (unfilled portion of pie)
	draw_circle(center, r, bg_color)

	# 2. Solid filled pie chart wedge
	if ratio > 0.001:
		var start_angle = -PI * 0.5
		var sweep = ratio * TAU
		var segments = int(max(16, 64 * ratio))

		var points = PackedVector2Array()
		points.append(center)
		for i in range(segments + 1):
			var a = start_angle + (float(i) / segments) * sweep
			points.append(center + Vector2(cos(a), sin(a)) * r)
		points.append(center)

		# Color scheme
		var fill_color = fg_color
		if gauge_title == "HP":
			# Crisp solid red for HP, brighter when high
			fill_color = Color(0.95, 0.2, 0.25, 0.95) if ratio > 0.25 else Color(1.0, 0.1, 0.1, 1.0)
		elif gauge_title == "STAMINA":
			fill_color = Color(0.2, 0.75, 1.0, 0.95)

		draw_polygon(points, PackedColorArray([fill_color]))

	# 3. Clean subtle border ring
	draw_arc(center, r, 0, TAU, 48, border_color, 1.5, true)
