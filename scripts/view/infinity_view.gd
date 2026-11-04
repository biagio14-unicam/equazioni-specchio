class_name InfinityView
extends Control
## Il simbolo ∞ disegnato a mano (la lemniscata), per l'allenamento libero.

var color := Color("#2B2440"):
	set(value):
		color = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(44, 24)


func _draw() -> void:
	var c := size / 2.0
	var a := minf(size.x * 0.42, size.y * 0.9)
	var pts := PackedVector2Array()
	for i in 65:
		var t := TAU * i / 64.0
		var d := 1.0 + sin(t) * sin(t)
		pts.append(c + Vector2(a * cos(t) / d, a * sin(t) * cos(t) / d))
	draw_polyline(pts, color, 6.0, true)
