class_name IconButton
extends Button
## Pulsante tondo con un'icona disegnata a mano: grande abbastanza per un dito
## anche su uno smartphone in orizzontale.

const SIZE := 80.0

## "levels", "restart", "undo", "hint", "home" o "exit".
var icon_name := ""


func _init(name_: String = "", bg := UIStyle.WHITE, tooltip := "") -> void:
	icon_name = name_
	tooltip_text = tooltip
	custom_minimum_size = Vector2(SIZE, SIZE)
	UIStyle.style_button(self, bg, 20, int(SIZE / 2.0))


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.y / 2.0 - 2.0)
	if is_pressed() or button_pressed:
		c.y += 4.0 # l'icona scende insieme al tasto
	var ink := UIStyle.INK if not disabled else Color(UIStyle.INK, 0.35)
	var w := 5.0
	match icon_name:
		"levels": # quattro quadratini
			for p in [Vector2(-9, -9), Vector2(9, -9), Vector2(-9, 9), Vector2(9, 9)]:
				var r := Rect2(c + p - Vector2(6.5, 6.5), Vector2(13, 13))
				draw_rect(r, ink, false, w - 1.0)
		"restart": # freccia circolare
			draw_arc(c, 15.0, deg_to_rad(-60), deg_to_rad(250), 32, ink, w, true)
			var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * 15.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-9, -6), tip + Vector2(7, -3), tip + Vector2(0, 10)]), ink)
		"undo": # freccia che torna indietro
			draw_polyline(PackedVector2Array([c + Vector2(-14, -4), c + Vector2(6, -4)]), ink, w, true)
			draw_arc(c + Vector2(6, 5), 9.0, deg_to_rad(-90), deg_to_rad(90), 16, ink, w, true)
			draw_line(c + Vector2(6, 14), c + Vector2(-4, 14), ink, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-20, -4), c + Vector2(-9, -13), c + Vector2(-9, 5)]), ink)
		"hint": # lampadina
			draw_arc(c + Vector2(0, -5), 12.0, deg_to_rad(140), deg_to_rad(400), 32, ink, w, true)
			draw_line(c + Vector2(-6, 8), c + Vector2(6, 8), ink, w, true)
			draw_line(c + Vector2(-4, 15), c + Vector2(4, 15), ink, w, true)
		"home": # casetta
			draw_polyline(PackedVector2Array([c + Vector2(-17, 0), c + Vector2(0, -16), c + Vector2(17, 0)]), ink, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-11, -5), c + Vector2(-11, 15), c + Vector2(11, 15), c + Vector2(11, -5)]), ink, w, true)
			draw_rect(Rect2(c + Vector2(-3.5, 5), Vector2(7, 10)), ink)
		"exit": # porta con la freccia che esce
			draw_polyline(PackedVector2Array([c + Vector2(2, -10), c + Vector2(2, -17), c + Vector2(-16, -17), c + Vector2(-16, 17), c + Vector2(2, 17), c + Vector2(2, 10)]), ink, w, true)
			draw_line(c + Vector2(-6, 0), c + Vector2(12, 0), ink, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(20, 0), c + Vector2(10, -9), c + Vector2(10, 9)]), ink)
