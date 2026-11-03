class_name TermView
extends Node2D
## Disegna un pezzo del puzzle (un EqTerm).
## L'origine (0, 0) è il bordo sinistro del pezzo, a metà altezza della riga principale.

const UNIT := 26.0          # lato del quadratino
const UNIT_GAP := 4.0       # spazio tra quadratini sciolti
const LOOSE_COLS := 5       # quadratini sciolti per riga (a gruppi di 5 si contano a colpo d'occhio)
const X_SIZE := 40.0        # lato della x
const DISC_R := 17.0        # raggio del disco
const HINGE := 14.0         # lunghezza del cardine
const OUTLINE := 3.0        # spessore del contorno dei pezzi cavi

const COL_X := Color("#D85A30")
const COL_UNIT := Color("#1D9E75")
const COL_DISC := Color("#7F77DD")
const COL_DISC_FILL := Color("#EEEDFE")
const COL_LINE := Color("#5F5E5A")

# Disposizione dei pallini nel disco, come sui dadi (fino a 9).
const PIPS := {
	1: [Vector2(0, 0)],
	2: [Vector2(-6, 0), Vector2(6, 0)],
	3: [Vector2(-7, 0), Vector2(0, 0), Vector2(7, 0)],
	4: [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)],
	5: [Vector2(-6, -6), Vector2(6, -6), Vector2(0, 0), Vector2(-6, 6), Vector2(6, 6)],
	6: [Vector2(-6, -5), Vector2(0, -5), Vector2(6, -5), Vector2(-6, 5), Vector2(0, 5), Vector2(6, 5)],
	7: [Vector2(-6, -6), Vector2(0, -6), Vector2(6, -6), Vector2(0, 0), Vector2(-6, 6), Vector2(0, 6), Vector2(6, 6)],
	8: [Vector2(-6, -6), Vector2(0, -6), Vector2(6, -6), Vector2(-6, 0), Vector2(6, 0), Vector2(-6, 6), Vector2(0, 6), Vector2(6, 6)],
	9: [Vector2(-6, -6), Vector2(0, -6), Vector2(6, -6), Vector2(-6, 0), Vector2(0, 0), Vector2(6, 0), Vector2(-6, 6), Vector2(0, 6), Vector2(6, 6)],
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
var highlight_color := Color("#EF9F27"):
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
		w = maxf(w, DISC_R * 2.0 + 8.0)
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
	var bottom := top
	if term.divisor > 1:
		bottom = top + 16.0 + DISC_R * 2.0
	return Rect2(0, -top, get_width(), top + bottom)


func _divisor_center() -> Vector2:
	return Vector2(get_width() / 2.0, _top_half_height() + 16.0 + DISC_R)


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
	if term.is_x() or term.grouped:
		var base_x := x
		if _has_disc(): # il disco da 1 non si disegna: resta solo la base
			_draw_disc(Vector2(x + DISC_R, 0), term.count)
			_draw_hinge(Vector2(x + DISC_R * 2.0, 0))
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

	# --- frazione: barra sotto tutta la riga, cardine verticale, disco divisore
	if term.divisor > 1:
		var bar_y := _top_half_height() + 8.0
		draw_line(Vector2(0, bar_y), Vector2(w, bar_y), COL_LINE, 3.0)
		draw_line(Vector2(w / 2.0, bar_y), Vector2(w / 2.0, bar_y + 8.0), COL_LINE, 2.0)
		_draw_disc(Vector2(w / 2.0, bar_y + 8.0 + DISC_R), term.divisor)


# ============================================================ misure

## true se il pezzo mostra un disco agganciato (x o unità raggruppate, con disco > 1).
func _has_disc() -> bool:
	return (term.is_x() or term.grouped) and term.count > 1


func _top_width() -> float:
	var disc := DISC_R * 2.0 + HINGE if _has_disc() else 0.0
	if term.is_x():
		return disc + X_SIZE
	if term.grouped:
		return disc + UNIT
	var cols := mini(term.count, LOOSE_COLS)
	return cols * UNIT + (cols - 1) * UNIT_GAP


func _loose_height() -> float:
	var rows := ceili(term.count / float(LOOSE_COLS))
	return rows * UNIT + (rows - 1) * UNIT_GAP


func _top_half_height() -> float:
	if term.is_x():
		return X_SIZE / 2.0
	if term.grouped:
		return DISC_R if _has_disc() else UNIT / 2.0
	return _loose_height() / 2.0


# ============================================================ forme

## Il segno sta sulla base: pieno = positivo, cavo = negativo.
func _draw_unit(top_left: Vector2) -> void:
	var r := Rect2(top_left, Vector2(UNIT, UNIT))
	if term.negative:
		draw_rect(r.grow(-OUTLINE / 2.0), COL_UNIT, false, OUTLINE)
	else:
		draw_rect(r, COL_UNIT)


func _draw_x(top_left: Vector2) -> void:
	var r := Rect2(top_left, Vector2(X_SIZE, X_SIZE))
	var text_color := COL_X
	if term.negative:
		draw_rect(r.grow(-OUTLINE / 2.0), COL_X, false, OUTLINE)
	else:
		draw_rect(r, COL_X)
		text_color = Color.WHITE
	_draw_centered_text("?", r.get_center(), 26, text_color)


## Il disco porta solo la quantità: è sempre pieno.
func _draw_disc(center: Vector2, n: int) -> void:
	draw_circle(center, DISC_R, COL_DISC_FILL)
	draw_arc(center, DISC_R, 0.0, TAU, 48, COL_DISC, 2.0, true)
	if PIPS.has(n):
		for p: Vector2 in PIPS[n]:
			draw_circle(center + p, 3.0, COL_DISC)
	else:
		_draw_centered_text(str(n), center, 16, COL_DISC)


func _draw_hinge(left: Vector2) -> void:
	draw_line(left, left + Vector2(HINGE, 0), COL_LINE, 3.0)
	draw_circle(left + Vector2(HINGE / 2.0, 0), 4.5, COL_LINE)


func _draw_centered_text(text: String, center: Vector2, size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := center + Vector2(-text_size.x / 2.0, font.get_ascent(size) - text_size.y / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Contorno morbido attorno alla parte evidenziata (disegnato sotto il pezzo).
func _draw_highlight() -> void:
	if highlight == "":
		return
	var soft := Color(highlight_color, 0.18)
	if highlight == "body":
		var r := get_local_rect().grow(7.0)
		draw_rect(r, soft)
		draw_rect(r, highlight_color, false, 2.5)
	else:
		var c := part_center(highlight)
		draw_circle(c, DISC_R + 7.0, soft)
		draw_arc(c, DISC_R + 7.0, 0.0, TAU, 48, highlight_color, 2.5, true)
