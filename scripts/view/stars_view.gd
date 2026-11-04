class_name StarsView
extends Control
## Tre stelle disegnate a mano (niente caratteri speciali: sul web potrebbero mancare nel font).

const COL_ON := Color("#FFC21A")
const COL_OFF := Color("#D9D0F5")

## Quante stelle accendere (0..3).
var stars := 0:
	set(value):
		stars = value
		queue_redraw()

## Raggio di ogni stella.
var radius := 10.0:
	set(value):
		radius = value
		custom_minimum_size = Vector2(radius * 6.6, radius * 2.2)
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius * 6.6, radius * 2.2)


func _draw() -> void:
	var step := radius * 2.2
	var start := (size.x - step * 2.0) / 2.0
	for i in 3:
		var c := Vector2(start + i * step, size.y / 2.0)
		var pts := PackedVector2Array()
		for k in 10: # 5 punte: alterna raggio esterno e interno
			var r := radius if k % 2 == 0 else radius * 0.45
			var a := -PI / 2.0 + k * PI / 5.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, COL_ON if i < stars else COL_OFF)
		pts.append(pts[0])
		draw_polyline(pts, UIStyle.INK, maxf(1.5, radius * 0.12), true) # contorno, come tutti i pezzi
