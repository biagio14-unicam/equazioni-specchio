class_name SpeechBubble
extends PanelContainer
## Il fumetto di Alice. Compare accanto all'Alice del lato indicato,
## con la punta rivolta verso di lei.

const WIDTH := 276.0
const LEFT_X := 262.0           # bordo sinistro del fumetto dell'Alice di sinistra
const TOP := 492.0
const MAX_BOTTOM := 640.0       # sotto c'è la pillola delle mosse
const TAIL_Y := 56.0            # altezza della punta dal bordo superiore

var side := "sinistra"
var _label: Label
var _text := ""


func _init() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.WHITE, 26, 9, 20.0, 10.0))
	custom_minimum_size = Vector2(WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UIStyle.label("", 26)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH - 40.0, 0)
	add_child(_label)
	visible = false
	draw.connect(_draw_tail)


## Mostra `text` dal lato di un'Alice ("sinistra" o "destra"); "" nasconde il fumetto.
func say(text: String, side_: String) -> void:
	if text == "":
		visible = false
		_text = ""
		return
	if text == _text and side_ == side and visible:
		return
	var appearing := not visible or side_ != side
	_text = text
	side = side_
	_label.text = text
	visible = true
	reset_size()
	var x := LEFT_X if side == "sinistra" else 1280.0 - LEFT_X - size.x
	position = Vector2(x, minf(TOP, MAX_BOTTOM - size.y))
	queue_redraw()
	if appearing:
		pivot_offset = Vector2(0.0 if side == "sinistra" else size.x, TAIL_Y)
		scale = Vector2(0.85, 0.85)
		modulate.a = 0.0
		var tw := create_tween().set_parallel(true)
		tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "modulate:a", 1.0, 0.12)


## La punta del fumetto, verso la testa di Alice.
func _draw_tail() -> void:
	var y := clampf(TOP + TAIL_Y - position.y, 24.0, size.y - 24.0)
	var ink := UIStyle.INK
	if side == "sinistra":
		var pts := PackedVector2Array([Vector2(2, y - 14), Vector2(-30, y + 6), Vector2(2, y + 14)])
		draw_colored_polygon(pts, UIStyle.WHITE)
		draw_polyline(pts, ink, 4.0, true)
	else:
		var x := size.x
		var pts := PackedVector2Array([Vector2(x - 2, y - 14), Vector2(x + 30, y + 6), Vector2(x - 2, y + 14)])
		draw_colored_polygon(pts, UIStyle.WHITE)
		draw_polyline(pts, ink, 4.0, true)
