extends Node2D
## Anteprima di tutti i tipi di pezzo. Esegui questa scena con ⌘+R (scena corrente).

const EXAMPLE := "3 - 7 + 12 + 2x - x + x/2 - 5x/6 - 3/4 = 0"


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#F5F3EE"))

	var eq := Equation.new()
	eq.load_equation(EXAMPLE)
	eq.group(3) # il 12 viene raggruppato: unità + disco

	var pos := Vector2(80, 140)
	for t in eq.left:
		var view := TermView.new()
		view.term = t
		view.position = pos
		add_child(view)

		var label := Label.new()
		label.text = _describe(t)
		label.add_theme_color_override("font_color", Color("#444441"))
		label.position = pos + Vector2(0, 90)
		add_child(label)

		pos.x += maxf(view.get_width(), 90.0) + 60.0
		if pos.x > 1100.0:
			pos = Vector2(80, pos.y + 230)


func _describe(t: EqTerm) -> String:
	var s := "-" if t.negative else "+"
	if not t.is_x() or t.count != 1:
		s += str(t.count)
	if t.is_x():
		s += "x"
	if t.divisor > 1:
		s += "/" + str(t.divisor)
	if not t.is_x():
		s += "  (gruppo)" if t.grouped else "  (sciolte)"
	return s
