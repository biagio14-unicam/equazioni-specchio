class_name TermView
extends Node2D
## Disegna un pezzo del puzzle (un EqTerm) nello stile "cartoon morbido".
## L'origine (0, 0) è il bordo sinistro del pezzo, a metà altezza della riga principale.
## Le misure sono pensate per un dito su uno smartphone; se un membro non ci sta,
## il livello rimpicciolisce i pezzi con `scale`.

const UNIT := 38.0          # lato del quadratino
const UNIT_GAP := 7.0       # spazio tra quadratini sciolti
const LOOSE_COLS := 5       # quadratini sciolti per riga (a gruppi di 5 si contano a colpo d'occhio)
const MAX_LOOSE := 20       # oltre questo numero le unità si disegnano come gruppo con disco
const X_SIZE := 62.0        # lato della x
const DISC_R := 25.0        # raggio del disco
const HINGE := 14.0         # lunghezza del cardine
const LINE := 4.0           # spessore dei contorni
const DEPTH := 5.0          # rilievo sotto i pezzi pieni
const BAR_GAP := 10.0       # distanza tra il pezzo e la barra di frazione
const STEM := 10.0          # gambo tra la barra e il disco divisore

const PIP_STEP := 8.5       # distanza tra i pallini del disco
# Disposizione dei pallini, come sui dadi (in unità di PIP_STEP).
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-0.8, 0), Vector2(0.8, 0)],
	3: [Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0)],
	4: [Vector2(-0.7, -0.7), Vector2(0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.7, 0.7)],
	5: [Vector2(-0.9, -0.9), Vector2(0.9, -0.9), Vector2(0, 0), Vector2(-0.9, 0.9), Vector2(0.9, 0.9)],
	6: [Vector2(-1, -0.7), Vector2(0, -0.7), Vector2(1, -0.7), Vector2(-1, 0.7), Vector2(0, 0.7), Vector2(1, 0.7)],
	7: [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)],
	8: [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)],
	9: [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(0, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)],
}

## Il pezzo da disegnare. Assegnarlo ridisegna automaticamente.
var term: EqTerm:
	set(value):
		term = value
		queue_redraw()

## Se > 0 disegna SOLO un disco con questo numero (il "fantasma" trascinato con il gancio).
var disc_only := 0:
	set(value):
		disc_only = value
		queue_redraw()

## Parte da contornare: "", "body", "coefficient" o "divisor".
var highlight := "":
	set(value):
		if value != highlight:
			highlight = value
			queue_redraw()

## Colore del contorno (cambia tra passaggio del mouse e suggerimento).
var highlight_color := UIStyle.ADVICE:
	set(value):
		highlight_color = value
		queue_redraw()

const HIT_MARGIN := 10.0 # area di presa più grande del disegno: comoda con le dita


## Larghezza totale del pezzo: serve a chi dispone i pezzi in fila.
func get_width() -> float:
	if disc_only > 0:
		return DISC_R * 2.0
	if term == null:
		return 0.0
	var w := _top_width()
	if term.divisor > 1:
		w = maxf(w, DISC_R * 2.0 + 12.0)
	return w


## Quale parte del pezzo c'è nel punto p (coordinate locali):
## "coefficient" = disco della x, "divisor" = disco sotto la barra,
## "body" = il resto del pezzo, "" = niente.
func hit_part(p: Vector2) -> String:
	if term == null:
		return ""
	if term.divisor > 1 and p.distance_to(part_center("divisor")) <= DISC_R + HIT_MARGIN:
		return "divisor"
	if term.is_x() and term.count > 1 and p.distance_to(part_center("coefficient")) <= DISC_R + HIT_MARGIN:
		return "coefficient"
	if get_local_rect().grow(HIT_MARGIN).has_point(p):
		return "body"
	return ""


## Il centro di una parte del pezzo, in coordinate locali.
func part_center(part: String) -> Vector2:
	match part:
		"divisor":
			return _divisor_center()
		"coefficient":
			return Vector2((get_width() - _top_width()) / 2.0 + DISC_R, 0)
	return get_local_rect().get_center()


## Il rettangolo occupato dal pezzo, in coordinate locali.
func get_local_rect() -> Rect2:
	var top := _top_half_height()
	var bottom := top + DEPTH
	if term.divisor > 1:
		bottom = top + BAR_GAP + STEM + DISC_R * 2.0 + 4.0
	return Rect2(0, -top, get_width(), top + bottom)


func _divisor_center() -> Vector2:
	return Vector2(get_width() / 2.0, _top_half_height() + BAR_GAP + STEM + DISC_R)


func _draw() -> void:
	if disc_only > 0:
		_draw_disc(Vector2(DISC_R, 0), disc_only)
		return
	if term == null:
		return
	_draw_highlight()
	var w := get_width()
	var x := (w - _top_width()) / 2.0

	# --- riga principale: disco + cardine + base, oppure quadratini sciolti
	if term.is_x() or _as_group():
		var base_x := x
		if _has_disc(): # il disco da 1 non si disegna: resta solo la base
			_draw_hinge(Vector2(x + DISC_R * 2.0 - 4.0, 0))
			_draw_disc(Vector2(x + DISC_R, 0), term.count)
			base_x = x + DISC_R * 2.0 + HINGE
		if term.is_x():
			_draw_x(Vector2(base_x, -X_SIZE / 2.0))
		else:
			_draw_unit(Vector2(base_x, -UNIT / 2.0))
	else:
		var h := _loose_height()
		for i in term.count:
			@warning_ignore("integer_division")
			var row := i / LOOSE_COLS
			var col := i % LOOSE_COLS
			_draw_unit(Vector2(x + col * (UNIT + UNIT_GAP), -h / 2.0 + row * (UNIT + UNIT_GAP)))

	# --- frazione: barra sotto tutta la riga, gambo, disco divisore
	if term.divisor > 1:
		var bar_y := _top_half_height() + BAR_GAP
		draw_line(Vector2(2, bar_y), Vector2(w - 2, bar_y), UIStyle.INK, 6.0, true)
		draw_line(Vector2(w / 2.0, bar_y), Vector2(w / 2.0, bar_y + STEM + 2.0), UIStyle.INK, 5.0, true)
		_draw_disc(_divisor_center(), term.divisor)


# ============================================================ misure

## true se il pezzo mostra un disco agganciato (x o unità raggruppate, con disco > 1).
func _has_disc() -> bool:
	return (term.is_x() or _as_group()) and term.count > 1


## Unità disegnate come gruppo (unità + disco): se raggruppate dal giocatore,
## oppure se sono troppe per stare sciolte sullo schermo.
func _as_group() -> bool:
	return not term.is_x() and (term.grouped or term.count > MAX_LOOSE)


func _top_width() -> float:
	var disc := DISC_R * 2.0 + HINGE if _has_disc() else 0.0
	if term.is_x():
		return disc + X_SIZE
	if _as_group():
		return disc + UNIT
	var cols := mini(term.count, LOOSE_COLS)
	return cols * UNIT + (cols - 1) * UNIT_GAP


func _loose_height() -> float:
	var rows := ceili(term.count / float(LOOSE_COLS))
	return rows * UNIT + (rows - 1) * UNIT_GAP


func _top_half_height() -> float:
	if term.is_x():
		return X_SIZE / 2.0
	if _as_group():
		return DISC_R if _has_disc() else UNIT / 2.0
	return _loose_height() / 2.0


# ============================================================ forme

## Il segno sta sulla base: pieno = positivo, vuoto (tratteggiato) = negativo.
func _draw_unit(top_left: Vector2) -> void:
	var r := Rect2(top_left, Vector2(UNIT, UNIT))
	if term.negative:
		_box(r, UIStyle.WHITE, 10, 0.0, Color(0, 0, 0, 0))
		_dashed_round_rect(r.grow(-LINE / 2.0), 9.0, UIStyle.UNIT, LINE)
	else:
		_box(r, UIStyle.UNIT, 10, DEPTH, UIStyle.INK)


func _draw_x(top_left: Vector2) -> void:
	var r := Rect2(top_left, Vector2(X_SIZE, X_SIZE))
	if term.negative:
		_box(r, UIStyle.WHITE, 16, 0.0, Color(0, 0, 0, 0))
		_dashed_round_rect(r.grow(-LINE / 2.0), 14.0, UIStyle.X_HOLLOW, LINE)
		_draw_centered_text("?", r.get_center(), 38, UIStyle.X_HOLLOW_TEXT)
	else:
		_box(r, UIStyle.X, 16, DEPTH + 1.0, UIStyle.INK)
		_draw_centered_text("?", r.get_center() + Vector2(0, -2), 38, UIStyle.INK)


## Il disco porta solo la quantità: bianco con i pallini, o con la cifra oltre il 9.
func _draw_disc(center: Vector2, n: int) -> void:
	draw_circle(center, DISC_R, UIStyle.WHITE)
	draw_arc(center, DISC_R - LINE / 2.0, 0.0, TAU, 48, UIStyle.INK, LINE, true)
	if PIPS.has(n):
		var r := 4.6 if n <= 6 else 3.8
		for p: Vector2 in PIPS[n]:
			draw_circle(center + p * PIP_STEP, r, UIStyle.DISC)
	else:
		_draw_centered_text(str(n), center, 24, UIStyle.DISC)


func _draw_hinge(left: Vector2) -> void:
	draw_line(left, left + Vector2(HINGE + 8.0, 0), UIStyle.INK, 7.0, true)


## Riquadro arrotondato pieno, con contorno e rilievo in basso.
func _box(r: Rect2, fill: Color, radius: int, depth: float, border: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(int(LINE))
		sb.border_width_bottom = int(LINE + depth)
	sb.draw(get_canvas_item(), r)


## Contorno tratteggiato di un rettangolo arrotondato: il pezzo "vuoto".
func _dashed_round_rect(r: Rect2, radius: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - radius, r.position.y + radius), -PI / 2.0],
		[Vector2(r.end.x - radius, r.end.y - radius), 0.0],
		[Vector2(r.position.x + radius, r.end.y - radius), PI / 2.0],
		[Vector2(r.position.x + radius, r.position.y + radius), PI],
	]
	for c in corners:
		for i in 7:
			var a: float = c[1] + (PI / 2.0) * i / 6.0
			pts.append(c[0] + Vector2(cos(a), sin(a)) * radius)
	pts.append(pts[0])
	var dash := 7.0
	var gap := 5.0
	var on := true
	var left := dash
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step := minf(left, seg - pos)
			if on:
				draw_line(a.lerp(b, pos / seg), a.lerp(b, (pos + step) / seg), color, width, true)
			pos += step
			left -= step
			if left <= 0.001:
				on = not on
				left = dash if on else gap


func _draw_centered_text(text: String, center: Vector2, font_size: int, color: Color) -> void:
	var font := UIStyle.FONT_TITLE
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Contorno morbido attorno alla parte evidenziata (disegnato sotto il pezzo).
func _draw_highlight() -> void:
	if highlight == "":
		return
	var soft := Color(highlight_color, 0.16)
	if highlight == "body":
		var sb := StyleBoxFlat.new()
		sb.bg_color = soft
		sb.border_color = highlight_color
		sb.set_border_width_all(4)
		sb.set_corner_radius_all(18)
		sb.anti_aliasing = true
		sb.draw(get_canvas_item(), get_local_rect().grow(10.0))
	else:
		var c := part_center(highlight)
		draw_circle(c, DISC_R + 9.0, soft)
		draw_arc(c, DISC_R + 9.0, 0.0, TAU, 48, highlight_color, 4.0, true)
