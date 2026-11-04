class_name MirrorView
extends Node2D
## Lo specchio-portale: cornice dorata arrotondata, vetro diviso nei colori dei
## due mondi, riflessi, piedini sul pavimento. Si illumina quando viene usato e
## si increspa nel punto in cui un pezzo lo attraversa.

const RECT := Rect2(555, 150, 170, 470)  # cornice esterna
const INSET := 18.0                       # spessore della cornice

var _flash := 0.0
var _hover := false
var _ripples: Array = [] # ciascuna: [altezza, avanzamento 0..1]


## Il rettangolo sensibile al doppio tocco.
func hit_rect() -> Rect2:
	return RECT.grow(10.0)


func set_hover(on: bool) -> void:
	if on != _hover:
		_hover = on
		queue_redraw()


func flash() -> void:
	var tw := create_tween()
	tw.tween_method(func(v: float): _flash = v; queue_redraw(), 1.0, 0.0, 0.45)


## Un'increspatura sul vetro all'altezza y (un pezzo è appena passato di lì).
func ripple(y: float) -> void:
	var r := [clampf(y, RECT.position.y + 60.0, RECT.end.y - 60.0), 0.0]
	_ripples.append(r)
	var tw := create_tween()
	tw.tween_method(func(v: float): r[1] = v; queue_redraw(), 0.0, 1.0, 0.6)
	tw.tween_callback(func(): _ripples.erase(r); queue_redraw())


func _draw() -> void:
	var ink := UIStyle.INK
	var r := RECT
	var cx := r.get_center().x
	# ombra sul pavimento e piedini
	draw_set_transform(Vector2(cx, r.end.y + 14.0), 0.0, Vector2(1.0, 0.12))
	draw_circle(Vector2.ZERO, 118.0, Color(ink, 0.25))
	draw_set_transform(Vector2.ZERO)
	for fx in [r.position.x + 20.0, r.end.x - 46.0]:
		_round_box(Rect2(fx, r.end.y - 4.0, 26, 18), UIStyle.GOLD, 6, 3)

	# cornice
	_round_box(r, UIStyle.GOLD, int(r.size.x / 2.0), 4)
	# vetro: due metà, una per mondo
	var g := r.grow(-INSET)
	var rad := int(g.size.x / 2.0)
	var half := g.size.x / 2.0
	var left := StyleBoxFlat.new()
	left.bg_color = UIStyle.GLASS_LEFT.lerp(Color.WHITE, _flash * 0.7)
	left.corner_radius_top_left = rad
	left.corner_radius_bottom_left = rad
	left.anti_aliasing = true
	left.draw(get_canvas_item(), Rect2(g.position, Vector2(half, g.size.y)))
	var right := left.duplicate() as StyleBoxFlat
	right.bg_color = UIStyle.GLASS_RIGHT.lerp(Color.WHITE, _flash * 0.7)
	right.corner_radius_top_left = 0
	right.corner_radius_bottom_left = 0
	right.corner_radius_top_right = rad
	right.corner_radius_bottom_right = rad
	right.draw(get_canvas_item(), Rect2(g.position + Vector2(half, 0), Vector2(half, g.size.y)))
	# riflessi
	draw_line(Vector2(g.position.x + 26, g.end.y - 90), Vector2(g.end.x - 22, g.position.y + 90), Color(1, 1, 1, 0.55), 16.0, true)
	draw_line(Vector2(g.position.x + 50, g.end.y - 50), Vector2(g.end.x - 10, g.position.y + 150), Color(1, 1, 1, 0.45), 6.0, true)
	_sparkle(Vector2(g.end.x - 30, g.position.y + 130), 14.0)
	_sparkle(Vector2(g.position.x + 26, g.position.y + 330), 9.0)
	# increspature
	for rp in _ripples:
		var t: float = rp[1]
		draw_set_transform(Vector2(cx, rp[0]), 0.0, Vector2(1.0, 0.35))
		draw_arc(Vector2.ZERO, 10.0 + 55.0 * t, 0.0, TAU, 40, Color(1, 1, 1, 1.0 - t), 4.0, true)
		draw_set_transform(Vector2.ZERO)
	# bordo del vetro, bottoni rosa della cornice
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = ink
	edge.set_border_width_all(3)
	edge.set_corner_radius_all(rad)
	edge.anti_aliasing = true
	edge.draw(get_canvas_item(), g)
	for p in [Vector2(cx, r.position.y + 2), Vector2(r.position.x + 8, r.position.y + 50), Vector2(r.end.x - 8, r.position.y + 50)]:
		var rr := 12.0 if p.x == cx else 9.0
		draw_circle(p, rr, UIStyle.PINK)
		draw_arc(p, rr, 0.0, TAU, 24, ink, 3.0, true)
	# passaggio del mouse
	if _hover:
		var h := StyleBoxFlat.new()
		h.bg_color = Color(UIStyle.HOVER, 0.12)
		h.border_color = UIStyle.HOVER
		h.set_border_width_all(4)
		h.set_corner_radius_all(int(r.size.x / 2.0) + 10)
		h.anti_aliasing = true
		h.draw(get_canvas_item(), r.grow(10.0))


func _round_box(rect: Rect2, color: Color, radius: int, border: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = UIStyle.INK
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.draw(get_canvas_item(), rect)


func _sparkle(c: Vector2, s: float) -> void:
	var k := s * 0.3
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -s), c + Vector2(k, -k), c + Vector2(s, 0), c + Vector2(k, k),
		c + Vector2(0, s), c + Vector2(-k, k), c + Vector2(-s, 0), c + Vector2(-k, -k)]), Color.WHITE)
