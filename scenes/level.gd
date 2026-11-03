extends Node2D
## Il livello: lo specchio al centro, i due membri dell'equazione ai lati.
##
## Gesti (mouse, dito o penna della LIM):
##   trascina un pezzo oltre lo specchio              -> specchio (move_across)
##   trascina un pezzo su un altro, stessa parte      -> fondi (merge)
##   trascina il disco della x oltre lo specchio      -> gancio (hook_coefficient)
##   trascina il denominatore oltre lo specchio       -> gancio (hook_divisor)
##   trascina il denominatore su un altro termine     -> stesso denominatore, mcm (slice_common)
##   doppio clic / doppio tocco su un pezzo  -> semplifica, oppure raggruppa/sgancia le unità
##   doppio clic / doppio tocco sullo specchio -> ribalta tutto (flip_all)
##   ⌘+Z (Ctrl+Z su Windows) o pulsante Annulla -> annulla
##
## Animazioni: a ogni `state_changed` i pezzi NON vengono ricreati. Ogni pezzo
## sullo schermo è legato all'id del suo EqTerm: se l'id c'è ancora il pezzo
## scivola nella nuova posizione, se è sparito il pezzo svanisce, se è nuovo appare.

## L'equazione del livello (usata se la scena viene aperta direttamente dall'editor).
@export var equation_text := "5 - 2x = 11"

const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

const SCREEN_W := 1280.0
const MIRROR_X := SCREEN_W / 2.0
const ROW_Y := 340.0          # altezza della riga dei pezzi
const TERM_GAP := 36.0        # spazio tra un pezzo e l'altro
const MIRROR_RECT := Rect2(MIRROR_X - 10.0, 150.0, 20.0, 380.0)
const DRAG_THRESHOLD := 8.0   # sotto questi pixel non è un trascinamento ma un clic
const ANIM_TIME := 0.25       # durata delle animazioni dei pezzi (secondi)
const DOUBLE_TAP_MS := 400    # due tocchi entro questo tempo...
const DOUBLE_TAP_DIST := 40.0 # ...e entro questa distanza sono un doppio tocco

const COL_BG := Color("#F5F3EE")
const COL_MIRROR := Color("#B5D4F4")
const COL_MIRROR_EDGE := Color("#378ADD")
const COL_TEXT := Color("#2C2C2A")
const COL_HINT := Color("#888780")
const COL_WARN := Color("#993C1D")
const COL_HOVER := Color("#378ADD")   # contorno al passaggio del mouse
const COL_ADVICE := Color("#EF9F27")  # contorno e frecce del suggerimento
const COL_ADVICE_TEXT := Color("#854F0B")

## Testo del suggerimento, per tipo di mossa (vedi Solver).
const MOVE_TEXT := {
	"across": "Trascina il pezzo evidenziato oltre lo specchio: uscirà invertito.",
	"merge": "Trascina il pezzo evidenziato sull'altro: si fonderanno.",
	"slice": "Afferra il denominatore evidenziato e lascialo sull'altro termine: avranno lo stesso denominatore.",
	"hook_coefficient": "Afferra il disco della x e portalo oltre lo specchio: dividerà tutto quello che c'è dall'altra parte.",
	"hook_divisor": "Afferra il denominatore e portalo oltre lo specchio: moltiplicherà tutto quello che c'è dall'altra parte.",
	"flip": "Fai doppio clic (o doppio tocco) sullo specchio: tutti i pezzi si ribaltano.",
	"simplify": "Fai doppio clic (o doppio tocco) sulla frazione evidenziata per semplificarla.",
}

## Testo al passaggio del mouse, per parte del pezzo.
const HOVER_TEXT := {
	"body": "Trascinalo oltre lo specchio, oppure sopra un pezzo uguale per fonderli",
	"coefficient": "Trascina il disco oltre lo specchio: dividerà tutto l'altro membro",
	"divisor": "Denominatore: oltre lo specchio moltiplica tutto, su un altro termine dà lo stesso denominatore",
	"mirror": "Doppio clic: ribalta tutti i pezzi",
}

const ERROR_TEXT := {
	Equation.MoveResult.DIFFERENT_SIDES: "Si fondono solo pezzi dalla stessa parte dello specchio",
	Equation.MoveResult.DIFFERENT_BASE: "Una x e un'unità non si possono fondere",
	Equation.MoveResult.DIFFERENT_DIVISOR: "Denominatori diversi: trascina un denominatore sull'altro termine per renderli uguali",
	Equation.MoveResult.SAME_DIVISOR: "Hanno già lo stesso denominatore: ora puoi fonderli",
	Equation.MoveResult.NOT_GROUPABLE: "Le x hanno sempre il loro disco",
	Equation.MoveResult.NOTHING_TO_HOOK: "Qui non c'è un disco da agganciare",
	Equation.MoveResult.NOT_REDUCIBLE: "Questa frazione è già ridotta",
}

@onready var left_side: Node2D = $LeftSide
@onready var right_side: Node2D = $RightSide
@onready var equation_label: Label = $HUD/EquationLabel
@onready var status_label: Label = $HUD/StatusLabel

var eq := Equation.new()
var _views := {}              # id del pezzo -> TermView sullo schermo
var _pending_flip := false    # la prossima `state_changed` arriva da un ribaltamento
var _flash := 0.0             # 1 = specchio illuminato, 0 = normale
var _empty_left: Label
var _empty_right: Label
var _title_label: Label       # "Mondo 1 · Livello 1"
var _tip_label: Label         # suggerimento o spiegazione al passaggio del mouse
var _hint_layer: Node2D       # frecce del suggerimento, sopra i pezzi
var _hint_button: Button

# Trascinamento in corso
var _drag_view: TermView = null   # il pezzo afferrato
var _drag_part := ""              # "body", "coefficient" o "divisor"
var _drag_ghost: TermView = null  # il disco fantasma (ganci e denominatori)
var _drag_start := Vector2.ZERO   # dove è iniziato il trascinamento
var _drag_origin := Vector2.ZERO  # posizione originale del pezzo
var _drag_from_left := true

# Doppio clic / doppio tocco (riconosciuto qui: sul web il tocco non lo segnala)
var _last_press_ms := -100000
var _last_press_pos := Vector2.ZERO

# Passaggio del mouse
var _hover_view: TermView = null
var _hover_part := ""
var _mirror_hover := false

# Suggerimento
var _hint_move := {}          # la mossa suggerita ({} = nessuna)
var _used_hint := false

# Messaggio temporaneo nella riga di stato
var _message := ""
var _message_serial := 0

# Livello
var _par := 0                 # 0 = nessun par (livello aperto direttamente dall'editor)
var _guided := false          # livello guidato: il suggerimento si vede sempre
var _completed := false       # risolta: l'input sul campo è bloccato
var _endless := false         # allenamento libero: dopo la soluzione arriva un'altra equazione
var _win := {}                # pannello di fine livello (vedi _make_dialog)
var _intro := {}              # pannello di introduzione


func _ready() -> void:
	RenderingServer.set_default_clear_color(COL_BG)
	_style_label(equation_label, 78.0, 34, COL_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_style_label(status_label, 650.0, 18, COL_HINT, HORIZONTAL_ALIGNMENT_CENTER)
	_title_label = Label.new()
	$HUD.add_child(_title_label)
	_style_label(_title_label, 26.0, 18, COL_HINT, HORIZONTAL_ALIGNMENT_RIGHT)
	_title_label.size.x = SCREEN_W - 28.0
	_tip_label = Label.new()
	$HUD.add_child(_tip_label)
	_style_label(_tip_label, 600.0, 18, COL_HINT, HORIZONTAL_ALIGNMENT_CENTER)
	_empty_left = _make_empty_label(MIRROR_X * 0.5)
	_empty_right = _make_empty_label(MIRROR_X * 1.5)

	_hint_layer = Node2D.new()
	_hint_layer.z_index = 20
	_hint_layer.draw.connect(_draw_hint)
	add_child(_hint_layer)

	_build_buttons()
	_win = _make_dialog(460.0, true, [["Livelli", _go_to_levels], ["Ripeti", _restart], ["Nuova equazione", _new_equation], ["Avanti", _go_to_next]])
	_intro = _make_dialog(540.0, false, [["Inizia", _close_intro]])

	# Se arriviamo dalla selezione livelli, l'equazione viene dal file dei livelli.
	var level: Dictionary = Game.current_level()
	if not level.is_empty():
		var instance := Game.new_instance() # equazione fissa (tutorial) o nuova a caso
		if not instance.is_empty():
			equation_text = instance["equation"]
			_par = instance["par"]
		_guided = level.get("guided", false)
		_endless = level.get("endless", false)
		_title_label.text = level["title"]
		if level.has("intro"):
			_intro["title"].text = level.get("intro_title", "")
			_intro["detail"].text = level["intro"]
			_intro["root"].visible = true
	_hint_button.visible = not _guided # nei livelli guidati il suggerimento c'è già

	eq.state_changed.connect(_refresh)
	if not eq.load_equation(equation_text):
		push_error("Equazione non valida: " + equation_text)


func _process(_delta: float) -> void:
	if not _hint_move.is_empty():
		_hint_layer.queue_redraw() # le frecce pulsano e seguono i pezzi che si muovono


# ============================================================ disegno e animazioni

func _refresh() -> void:
	_message = "" # una mossa valida cancella un eventuale messaggio di errore
	_message_serial += 1
	var flip := _pending_flip
	_pending_flip = false

	var seen := {}
	_layout_side(eq.left, left_side, MIRROR_X * 0.5, flip, seen)
	_layout_side(eq.right, right_side, MIRROR_X * 1.5, flip, seen)
	for id in _views.keys(): # i pezzi che non esistono più svaniscono
		if not seen.has(id):
			_vanish(_views[id])
			_views.erase(id)

	_empty_left.visible = eq.left.is_empty()
	_empty_right.visible = eq.right.is_empty()
	equation_label.text = eq.to_text()
	_update_status()

	_hover_view = null
	_hover_part = ""
	_hint_move = {}
	if not _completed and eq.get_status() != Equation.Status.IN_PROGRESS:
		_completed = true
		_on_completed()
	elif _guided:
		_show_hint()
	_apply_highlights()


## Calcola dove va ogni pezzo di un membro (centrati nella sua metà) e ce lo porta.
func _layout_side(terms: Array[EqTerm], container: Node2D, center_x: float, flip: bool, seen: Dictionary) -> void:
	var views: Array[TermView] = []
	var olds: Array = [] # com'era ogni pezzo prima della mossa (null se è nuovo)
	var total := 0.0
	for t in terms:
		seen[t.id] = true
		var v: TermView = _views.get(t.id)
		if v == null:
			v = TermView.new()
			v.modulate.a = 0.0
			container.add_child(v)
			_views[t.id] = v
			olds.append(null)
		else:
			olds.append(v.term)
		v.term = t.copy() # una copia: il modello modifica i suoi termini sul posto
		views.append(v)
		total += v.get_width()
	total += TERM_GAP * maxi(views.size() - 1, 0)

	var x := center_x - total / 2.0
	for i in views.size():
		_animate_to(views[i], olds[i], container, Vector2(x, ROW_Y), flip)
		x += views[i].get_width() + TERM_GAP


func _animate_to(v: TermView, old: EqTerm, container: Node2D, target: Vector2, flip: bool) -> void:
	v.z_index = 0
	var tw := _tween_of(v)
	tw.set_parallel(true)

	if old == null: # pezzo nuovo (inizio livello, o tornato con annulla): appare
		v.position = target
		tw.tween_property(v, "modulate:a", 1.0, ANIM_TIME)
		return

	var t := v.term
	var crossed := v.get_parent() != container
	if crossed:
		v.reparent(container) # mantiene la posizione sullo schermo

	# Il disco è diventato 1: lo mostriamo per un istante prima che sparisca.
	if (t.is_x() or t.grouped) and old.count > 1 and t.count == 1:
		_ghost_disc(v)

	tw.tween_property(v, "position", target, ANIM_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "modulate:a", 1.0, ANIM_TIME)
	if crossed or (flip and old.negative != t.negative):
		v.scale = Vector2(0.0, 1.0) # si "apre" come un foglio girato
	elif old.count != t.count or old.divisor != t.divisor or old.grouped != t.grouped:
		v.scale = Vector2(1.2, 1.2) # pop: il pezzo è cambiato
	tw.tween_property(v, "scale", Vector2.ONE, ANIM_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un pezzo che non esiste più (assorbito o annullato) si rimpicciolisce e svanisce.
func _vanish(v: TermView) -> void:
	v.reparent(self) # fuori dai membri: non si può più afferrare
	v.highlight = ""
	var tw := _tween_of(v)
	tw.set_parallel(true)
	tw.tween_property(v, "scale", Vector2(0.3, 0.3), ANIM_TIME)
	tw.tween_property(v, "modulate:a", 0.0, ANIM_TIME)
	tw.chain().tween_callback(v.queue_free)


## Il disco da 1 che resta sulla x: è figlio del pezzo, quindi si muove con lui;
## compare alla sua sinistra, sale un poco e svanisce.
func _ghost_disc(v: TermView) -> void:
	var g := TermView.new()
	g.disc_only = 1
	v.add_child(g)
	g.position = Vector2(-(TermView.DISC_R * 2.0 + TermView.HINGE), 0)
	var tw := g.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(g, "modulate:a", 0.0, 0.5)
	tw.parallel().tween_property(g, "position:y", g.position.y - 16.0, 0.5)
	tw.tween_callback(g.queue_free)


## Un solo tween per pezzo: se ne parte uno nuovo, il precedente viene fermato.
## Il tween è creato DAL pezzo, così si ferma da solo se il pezzo viene eliminato.
func _tween_of(v: Node2D) -> Tween:
	if v.has_meta("tween"):
		var old: Tween = v.get_meta("tween")
		if old != null and old.is_valid():
			old.kill()
	var tw := v.create_tween()
	v.set_meta("tween", tw)
	return tw


func _draw() -> void:
	# Lo specchio: una lastra azzurra che si illumina quando viene usata.
	var glow := COL_MIRROR.lerp(Color.WHITE, _flash * 0.8)
	draw_rect(MIRROR_RECT, glow)
	draw_rect(MIRROR_RECT, COL_MIRROR_EDGE, false, 2.0)
	var r := MIRROR_RECT
	draw_line(r.position + Vector2(4, 40), r.position + Vector2(r.size.x - 4, 20), Color(1, 1, 1, 0.7), 2.0)
	draw_line(r.position + Vector2(4, 70), r.position + Vector2(r.size.x - 4, 50), Color(1, 1, 1, 0.5), 2.0)
	if _mirror_hover:
		var h := MIRROR_RECT.grow(7.0)
		draw_rect(h, Color(COL_HOVER, 0.15))
		draw_rect(h, COL_HOVER, false, 2.5)


func _update_status() -> void:
	if _message != "":
		status_label.text = _message
		status_label.add_theme_color_override("font_color", COL_WARN)
		return
	status_label.add_theme_color_override("font_color", COL_HINT)
	match eq.get_status():
		Equation.Status.SOLVED:
			status_label.text = "Risolta! x = %s   in %d mosse" % [eq.get_solution(), eq.move_count]
		Equation.Status.IMPOSSIBLE:
			status_label.text = "Le x sono sparite e i membri sono diversi: equazione impossibile"
		Equation.Status.IDENTITY:
			status_label.text = "Le x sono sparite e i membri sono uguali: equazione indeterminata"
		_:
			status_label.text = "Mosse: %d" % eq.move_count + (("   ·   par %d" % _par) if _par > 0 else "")


func _show_message(text: String) -> void:
	_message = text
	_message_serial += 1
	var serial := _message_serial
	_update_status()
	await get_tree().create_timer(2.5).timeout
	if serial == _message_serial: # nel frattempo non è arrivato un altro messaggio
		_message = ""
		_update_status()


func _style_label(label: Label, y: float, font_size: int, color: Color, align: HorizontalAlignment) -> void:
	label.position = Vector2(0, y)
	label.size = Vector2(SCREEN_W, font_size + 16)
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


func _make_empty_label(center_x: float) -> Label:
	var l := Label.new()
	l.text = "vuoto"
	l.add_theme_color_override("font_color", COL_HINT)
	l.position = Vector2(center_x - 20.0, ROW_Y - 12.0)
	l.visible = false
	add_child(l)
	return l


# ============================================================ evidenziazione e suggerimento

## Contorni sui pezzi: arancio per il suggerimento, azzurro per il passaggio del mouse.
func _apply_highlights() -> void:
	for v in _views.values():
		v.highlight = ""
	var hint := _hint_geometry()
	if not hint.is_empty():
		if hint["view"] != null:
			hint["view"].highlight_color = COL_ADVICE
			hint["view"].highlight = hint["part"]
		if hint["target_view"] != null:
			hint["target_view"].highlight_color = COL_ADVICE
			hint["target_view"].highlight = "body"
	if _hover_view != null and is_instance_valid(_hover_view) and _hover_view.highlight == "":
		_hover_view.highlight_color = COL_HOVER
		_hover_view.highlight = _hover_part
	_update_tip()


func _update_tip() -> void:
	if not _hint_move.is_empty():
		_tip_label.text = MOVE_TEXT[_hint_move["type"]]
		_tip_label.add_theme_color_override("font_color", COL_ADVICE_TEXT)
	elif _mirror_hover:
		_tip_label.text = HOVER_TEXT["mirror"]
		_tip_label.add_theme_color_override("font_color", COL_HINT)
	elif _hover_part != "":
		_tip_label.text = HOVER_TEXT[_hover_part]
		_tip_label.add_theme_color_override("font_color", COL_HINT)
	else:
		_tip_label.text = ""


## Pulsante Suggerimento: chiede al risolutore la mossa migliore.
func _on_hint_pressed() -> void:
	if _completed:
		return
	if _show_hint():
		_used_hint = true
		_apply_highlights()
	else:
		_show_message("Nessun suggerimento: prova ad annullare qualche mossa")


func _show_hint() -> bool:
	_hint_move = Solver.next_move(eq)
	_hint_layer.queue_redraw()
	return not _hint_move.is_empty()


## Dove disegnare il suggerimento: quale pezzo, quale parte, da dove a dove.
func _hint_geometry() -> Dictionary:
	if _hint_move.is_empty():
		return {}
	var m := _hint_move
	var g := {"view": _views.get(m.get("a", -1)), "part": "body", "target_view": null, "to": null}
	match m["type"]:
		"flip":
			g["view"] = null
		"simplify":
			pass
		"merge": # si trascina b sopra a
			g["view"] = _views.get(m["b"])
			g["target_view"] = _views.get(m["a"])
		"slice": # si trascina il denominatore di a sopra b
			g["part"] = "divisor"
			g["target_view"] = _views.get(m["b"])
		"hook_coefficient":
			g["part"] = "coefficient"
		"hook_divisor":
			g["part"] = "divisor"
	var v: TermView = g["view"]
	if v != null:
		g["from"] = v.to_global(v.part_center(g["part"]))
		if g["target_view"] != null:
			var tv: TermView = g["target_view"]
			g["to"] = tv.to_global(tv.part_center("body"))
		elif m["type"] in ["across", "hook_coefficient", "hook_divisor"]:
			# un punto oltre lo specchio, simmetrico rispetto a dove si trova il pezzo
			var dist := maxf(absf(g["from"].x - MIRROR_X), 220.0)
			var dir := 1.0 if g["from"].x < MIRROR_X else -1.0
			g["to"] = Vector2(MIRROR_X + dir * dist, ROW_Y - 90.0)
	return g


## Disegnato sul livello _hint_layer, sopra i pezzi: freccia tratteggiata che pulsa.
func _draw_hint() -> void:
	var g := _hint_geometry()
	if g.is_empty():
		return
	var pulse := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	var col := Color(COL_ADVICE, pulse)
	if _hint_move["type"] == "flip":
		_hint_layer.draw_rect(MIRROR_RECT.grow(10.0), col, false, 3.0)
		return
	if g["to"] == null:
		return
	var a: Vector2 = g["from"]
	var b: Vector2 = g["to"]
	if g["target_view"] == null: # verso un punto vuoto: una curva che scavalca lo specchio
		_draw_dashed_curve(a, b, Vector2((a.x + b.x) / 2.0, minf(a.y, b.y) - 120.0), col)
	else:
		_draw_dashed_curve(a, b, (a + b) / 2.0 + Vector2(0, -70.0), col)


## Curva tratteggiata (Bézier quadratica) con la punta di freccia in fondo.
func _draw_dashed_curve(a: Vector2, b: Vector2, ctrl: Vector2, col: Color) -> void:
	var steps := 28
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		if i % 2 == 0:
			_hint_layer.draw_line(prev, p, col, 4.0, true)
		prev = p
	var before := a.lerp(ctrl, 0.92).lerp(ctrl.lerp(b, 0.92), 0.92)
	var dir := (b - before).normalized()
	var side := Vector2(-dir.y, dir.x)
	_hint_layer.draw_colored_polygon(PackedVector2Array([b, b - dir * 18.0 + side * 10.0, b - dir * 18.0 - side * 10.0]), col)


# ============================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if _completed or _intro["root"].visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var pos := _event_position(mb)
		if mb.pressed:
			var now := Time.get_ticks_msec()
			if now - _last_press_ms <= DOUBLE_TAP_MS and pos.distance_to(_last_press_pos) <= DOUBLE_TAP_DIST:
				_last_press_ms = -100000 # il terzo tocco non conta come un altro doppio
				_on_double_click(pos)
			else:
				_last_press_ms = now
				_last_press_pos = pos
				_start_drag(pos)
		else:
			_end_drag(pos)
	elif event is InputEventMouseMotion:
		var pos := _event_position(event as InputEventMouseMotion)
		if _drag_view != null:
			_update_drag(pos)
		else:
			_update_hover(pos)
	elif event.is_action_pressed("ui_undo"):
		_undo()


## Posizione dell'evento nelle coordinate del livello (vale per mouse e tocco).
func _event_position(event: InputEventMouse) -> Vector2:
	return (make_input_local(event) as InputEventMouse).position


## Il pezzo (e la sua parte) sotto il punto, escludendo eventualmente un pezzo.
func _term_at(point: Vector2, exclude: TermView = null) -> Dictionary:
	for container in [left_side, right_side]:
		for child in container.get_children():
			var v := child as TermView
			if v == null or v == exclude or v.is_queued_for_deletion():
				continue
			var part := v.hit_part(v.to_local(point))
			if part != "":
				return {"view": v, "part": part}
	return {}


func _update_hover(pos: Vector2) -> void:
	var hit := _term_at(pos)
	var view: TermView = hit.get("view")
	var part: String = hit.get("part", "")
	var on_mirror := hit.is_empty() and MIRROR_RECT.grow(16.0).has_point(pos)
	if view == _hover_view and part == _hover_part and on_mirror == _mirror_hover:
		return
	_hover_view = view
	_hover_part = part
	if on_mirror != _mirror_hover:
		_mirror_hover = on_mirror
		queue_redraw()
	var hand := view != null or on_mirror
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW)
	_apply_highlights()


func _start_drag(pos: Vector2) -> void:
	var hit := _term_at(pos)
	if hit.is_empty():
		return
	_drag_view = hit["view"]
	_drag_part = hit["part"]
	_drag_start = pos
	_drag_origin = _drag_view.global_position
	_drag_from_left = eq.is_on_left(_drag_view.term.id)
	_hover_view = _drag_view # anche col dito si vede cosa si è afferrato
	_hover_part = _drag_part
	_apply_highlights()
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	if _drag_part == "body":
		_tween_of(_drag_view).kill() # ferma un'eventuale animazione in corso
		_drag_view.z_index = 10 # sopra gli altri pezzi mentre lo trascini
	else:
		_drag_ghost = TermView.new()
		var t := _drag_view.term
		_drag_ghost.disc_only = t.count if _drag_part == "coefficient" else t.divisor
		_drag_ghost.z_index = 10
		_drag_ghost.modulate.a = 0.85
		add_child(_drag_ghost)
		_update_drag(pos)


func _update_drag(pos: Vector2) -> void:
	if _drag_ghost != null:
		_drag_ghost.global_position = pos - Vector2(TermView.DISC_R, 0)
	else:
		_drag_view.global_position = _drag_origin + (pos - _drag_start)


func _end_drag(pos: Vector2) -> void:
	if _drag_view == null:
		return
	var view := _drag_view
	var part := _drag_part
	var origin := _drag_origin
	if _drag_ghost != null:
		_drag_ghost.queue_free()
	_drag_ghost = null
	_drag_view = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	if pos.distance_to(_drag_start) < DRAG_THRESHOLD:
		_snap_back(view, origin) # era solo un clic
		_update_hover(pos)
		return

	var id := view.term.id
	var crossed := (pos.x < MIRROR_X) != _drag_from_left
	# Il pezzo su cui è stato lasciato, dalla stessa parte dello specchio.
	var target := {} if crossed else _term_at(pos, view)

	match part:
		"coefficient": # gancio dal disco della x
			if crossed:
				_report(eq.hook_coefficient(id), view, origin)
			else:
				_snap_back(view, origin)
				_show_message("Porta il disco oltre lo specchio")
		"divisor": # denominatore: gancio oltre lo specchio, mcm su un altro termine
			if crossed:
				_report(eq.hook_divisor(id), view, origin)
			elif not target.is_empty():
				_report(eq.slice_common(target["view"].term.id, id), view, origin)
			else:
				_snap_back(view, origin)
		_: # il pezzo intero
			if crossed:
				_report(eq.move_across(id), view, origin)
			elif not target.is_empty():
				_report(eq.merge(target["view"].term.id, id), view, origin) # il risultato resta al posto del bersaglio
			else:
				_snap_back(view, origin)


func _on_double_click(pos: Vector2) -> void:
	if MIRROR_RECT.grow(16.0).has_point(pos):
		_pending_flip = true
		if eq.flip_all() == Equation.MoveResult.SUCCESS:
			_flash_mirror()
		_pending_flip = false
		return
	var hit := _term_at(pos)
	if hit.is_empty():
		return
	var view: TermView = hit["view"]
	var t := view.term
	if t.divisor > 1 and Fraction.gcd(t.count, t.divisor) > 1:
		_report(eq.simplify(t.id), view, view.global_position)
	elif t.grouped and not t.is_x():
		_report(eq.ungroup(t.id), view, view.global_position)
	else:
		_report(eq.group(t.id), view, view.global_position)


## Mossa riuscita: il modello ha già avviato le animazioni.
## Mossa rifiutata: il pezzo torna al suo posto e compare il motivo.
func _report(result: Equation.MoveResult, view: TermView, origin: Vector2) -> void:
	if result == Equation.MoveResult.SUCCESS:
		return
	_snap_back(view, origin)
	if ERROR_TEXT.has(result):
		_show_message(ERROR_TEXT[result])


func _snap_back(view: TermView, origin: Vector2) -> void:
	if not is_instance_valid(view) or view.is_queued_for_deletion():
		return
	view.z_index = 0
	var tw := _tween_of(view)
	tw.tween_property(view, "global_position", origin, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash_mirror() -> void:
	var tween := create_tween()
	tween.tween_method(_set_flash, 1.0, 0.0, 0.4)


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


# ============================================================ pulsanti e pannelli

## Pulsanti in alto a sinistra: grandi abbastanza da premere con un dito.
func _build_buttons() -> void:
	var bar := HBoxContainer.new()
	bar.position = Vector2(20, 18)
	bar.add_theme_constant_override("separation", 8)
	$HUD.add_child(bar)
	for spec in [["Livelli", _go_to_levels], ["Ricomincia", _restart], ["Annulla", _undo], ["Suggerimento", _on_hint_pressed]]:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE # così lo spazio/invio non li ripremono
		b.pressed.connect(spec[1])
		bar.add_child(b)
		if spec[0] == "Suggerimento":
			_hint_button = b


## Un pannello centrale con titolo, testo, stelle (facoltative) e pulsanti.
## Restituisce {root, title, detail, stars, buttons: {testo: Button}}. Parte nascosto.
func _make_dialog(width: float, with_stars: bool, buttons: Array) -> Dictionary:
	var shade := ColorRect.new() # velo sul campo: blocca i clic sui pezzi
	shade.color = Color(0.96, 0.95, 0.93, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	$HUD.add_child(shade)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28)
	style.border_color = Color("#D3D1C7")
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)
	shade.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	panel.add_child(col)

	var title := Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COL_TEXT)
	col.add_child(title)

	var detail := Label.new()
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(width - 56.0, 0) # serve per andare a capo
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color("#5F5E5A"))
	col.add_child(detail)

	var stars := StarsView.new()
	stars.radius = 20.0
	stars.visible = with_stars
	col.add_child(stars)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var by_text := {}
	for spec in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(120, 48)
		b.add_theme_font_size_override("font_size", 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)
		by_text[spec[0]] = b
	return {"root": shade, "title": title, "detail": detail, "stars": stars, "buttons": by_text}


func _close_intro() -> void:
	_intro["root"].visible = false


## Ricomincia da capo: i pezzi attuali svaniscono e quelli iniziali riappaiono.
func _restart() -> void:
	for id in _views:
		_vanish(_views[id])
	_views.clear()
	_completed = false
	_used_hint = false
	_win["root"].visible = false
	eq.load_equation(equation_text)


func _undo() -> void:
	if not _completed:
		eq.undo()


func _on_completed() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_mirror_hover = false
	queue_redraw()
	match eq.get_status():
		Equation.Status.SOLVED:
			_win["title"].text = "x = %s" % eq.get_solution()
		Equation.Status.IMPOSSIBLE:
			_win["title"].text = "Equazione impossibile"
		Equation.Status.IDENTITY:
			_win["title"].text = "Equazione indeterminata"

	var detail := "%d mosse" % eq.move_count + (("  ·  par %d" % _par) if _par > 0 else "")
	if _endless:
		Game.endless_solved += 1
		detail += "\nEquazioni risolte in questo allenamento: %d" % Game.endless_solved
		_win["stars"].visible = false
	else:
		var got := Game.complete_current(eq.move_count, _par, _used_hint) if _par > 0 else 0
		_win["stars"].stars = got
		_win["stars"].visible = _par > 0
		if _par > 0 and _used_hint:
			detail += "\nHai usato un suggerimento: al massimo 2 stelle."
		elif _par > 0 and got < 3:
			detail += "\nSi può fare con meno mosse: riprova!"
	_win["detail"].text = detail
	_win["buttons"]["Ripeti"].visible = not _endless
	_win["buttons"]["Nuova equazione"].visible = _endless
	_win["buttons"]["Avanti"].visible = Game.has_next()

	await get_tree().create_timer(0.6).timeout # il tempo di vedere l'ultima animazione
	if _completed: # nel frattempo il giocatore potrebbe aver premuto Ricomincia
		_win["root"].visible = true


func _go_to_levels() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


## Allenamento libero: un'altra equazione dello stesso tipo, senza uscire dal livello.
func _new_equation() -> void:
	var instance := Game.new_instance()
	if instance.is_empty():
		return
	equation_text = instance["equation"]
	_par = instance["par"]
	_restart()


func _go_to_next() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Game.endless_solved = 0
	Game.current += 1
	get_tree().reload_current_scene()
