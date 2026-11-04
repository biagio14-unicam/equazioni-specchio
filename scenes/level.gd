extends Node2D
## Il livello: lo specchio-portale al centro, i due mondi ai lati, le due Alice sul
## pavimento a scacchi. La logica di gioco è la stessa di prima; cambia la scena.
##
## Gesti (mouse, dito o penna della LIM):
##   trascina un pezzo oltre lo specchio              -> specchio (move_across)
##   trascina un pezzo su un altro, stessa parte      -> fondi (merge)
##   trascina un pezzo sul suo gemello oltre lo specchio -> elimina i gemelli (cancel)
##   trascina il disco della x oltre lo specchio      -> gancio (hook_coefficient)
##   trascina il denominatore oltre lo specchio       -> gancio (hook_divisor)
##   trascina il denominatore su un altro termine     -> stesso denominatore, mcm (slice_common)
##   doppio tocco su un pezzo   -> semplifica, oppure raggruppa/sgancia le unità
##   doppio tocco sullo specchio -> ribalta tutto (flip_all)
##   ⌘+Z (Ctrl+Z su Windows) o pulsante Annulla -> annulla
##
## Animazioni: a ogni `state_changed` i pezzi NON vengono ricreati. Ogni pezzo
## sullo schermo è legato all'id del suo EqTerm: se l'id c'è ancora il pezzo
## scivola nella nuova posizione, se è sparito il pezzo svanisce, se è nuovo appare.
##
## Le due Alice: parla solo quella dalla parte in cui si svolge la mossa
## (suggerimento, errore o spiegazione); l'altra reagisce con l'espressione.

## L'equazione del livello (usata se la scena viene aperta direttamente dall'editor).
@export var equation_text := "5 - 2x = 11"

const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

const SCREEN_W := 1280.0
const MIRROR_X := SCREEN_W / 2.0
const ROW_Y := 395.0          # altezza della riga dei pezzi: il centro dello specchio
const TERM_GAP := 40.0        # spazio tra un pezzo e l'altro
const LEFT_AREA := Vector2(36.0, 530.0)    # da x a x: dove stanno i pezzi di sinistra
const RIGHT_AREA := Vector2(750.0, 1244.0) # e quelli di destra
const TOP_LIMIT := 150.0      # i pezzi non salgono oltre (c'è la barra in alto)
const BOTTOM_LIMIT := 520.0   # né scendono oltre (ci sono le Alice e i fumetti)
const DRAG_THRESHOLD := 8.0   # sotto questi pixel non è un trascinamento ma un clic
const ANIM_TIME := 0.25       # durata delle animazioni dei pezzi (secondi)
const DOUBLE_TAP_MS := 400    # due tocchi entro questo tempo...
const DOUBLE_TAP_DIST := 40.0 # ...e entro questa distanza sono un doppio tocco

## Cosa dice Alice per suggerire una mossa (frasi brevi: si leggono anche sul telefono).
const MOVE_TEXT := {
	"across": "Porta il pezzo oltre lo specchio!",
	"cancel": "Porta il pezzo sul suo gemello oltre lo specchio!",
	"merge": "Unisci questi due pezzi!",
	"slice": "Porta il denominatore sull'altro pezzo!",
	"hook_coefficient": "Porta il disco della x oltre lo specchio!",
	"hook_divisor": "Porta il denominatore oltre lo specchio!",
	"flip": "Tocca due volte lo specchio!",
	"simplify": "Tocca due volte la frazione!",
}

## Cosa dice al passaggio del mouse, per parte del pezzo.
const HOVER_TEXT := {
	"body": "Portalo oltre lo specchio, o su un altro pezzo",
	"coefficient": "Oltre lo specchio, il disco divide tutto",
	"divisor": "Oltre lo specchio, il denominatore moltiplica tutto",
	"mirror": "Tocca due volte: si ribalta tutto!",
}

const ERROR_TEXT := {
	Equation.MoveResult.DIFFERENT_SIDES: "Solo pezzi dalla stessa parte!",
	Equation.MoveResult.DIFFERENT_BASE: "Una x e un'unità non si uniscono!",
	Equation.MoveResult.DIFFERENT_DIVISOR: "Prima porta un denominatore sull'altro!",
	Equation.MoveResult.SAME_DIVISOR: "Stesso denominatore: ora uniscili!",
	Equation.MoveResult.NOT_GROUPABLE: "Le x hanno sempre il loro disco",
	Equation.MoveResult.NOTHING_TO_HOOK: "Qui non c'è un disco da agganciare",
	Equation.MoveResult.NOT_REDUCIBLE: "Questa frazione è già ridotta",
	Equation.MoveResult.NOT_TWINS: "Spariscono solo due pezzi identici",
}

@onready var left_side: Node2D = $LeftSide
@onready var right_side: Node2D = $RightSide
@onready var equation_label: Label = $HUD/EquationLabel
@onready var status_label: Label = $HUD/StatusLabel

var eq := Equation.new()
var _views := {}              # id del pezzo -> TermView sullo schermo
var _pending_flip := false    # la prossima `state_changed` arriva da un ribaltamento
var _mirror: MirrorView
var _alice := {}              # "sinistra"/"destra" -> AliceView
var _bubble: SpeechBubble
var _empty_left: Label
var _empty_right: Label
var _level_label: Label       # "Livello 3", accanto al volto del personaggio del mondo
var _level_face: TextureRect  # il personaggio del mondo
var _level_inf: InfinityView  # ∞ accanto alla scritta, nell'allenamento libero
var _right_bar: HBoxContainer # suggerimento e livello, in alto a destra
var _hint_layer: Node2D       # frecce del suggerimento, sopra i pezzi
var _hint_button: Button

# Trascinamento in corso
var _drag_view: TermView = null   # il pezzo afferrato
var _drag_part := ""              # "body", "coefficient" o "divisor"
var _drag_ghost: TermView = null  # il disco fantasma (ganci e denominatori)
var _drag_start := Vector2.ZERO   # dove è iniziato il trascinamento
var _drag_origin := Vector2.ZERO  # posizione originale del pezzo
var _drag_from_left := true
var _drag_twin: TermView = null   # il gemello oltre lo specchio sotto il dito, se c'è

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

# Messaggio temporaneo di Alice (errori, conferme)
var _message := ""
var _message_side := "sinistra"
var _message_serial := 0

# Livello
var _par := 0                 # 0 = nessun par (livello aperto direttamente dall'editor)
var _guided := false          # livello guidato: il suggerimento si vede sempre
var _completed := false       # risolta: l'input sul campo è bloccato
var _endless := false         # allenamento libero: dopo la soluzione arriva un'altra equazione
var _win := {}                # pannello di fine livello (vedi _make_dialog)
var _intro := {}              # pannello di introduzione


func _ready() -> void:
	RenderingServer.set_default_clear_color(UIStyle.LILAC)
	_build_scene()
	_build_hud()
	_win = _make_dialog(640.0, true, [["Livelli", _go_to_levels], ["Ripeti", _restart], ["Nuova", _new_equation], ["Avanti", _go_to_next]])
	_intro = _make_dialog(780.0, false, [["Inizia", _close_intro]])

	# Se arriviamo dalla selezione livelli, l'equazione viene dal file dei livelli.
	var level: Dictionary = Game.current_level()
	if not level.is_empty():
		var instance := Game.new_instance() # equazione fissa o nuova a caso
		if not instance.is_empty():
			equation_text = instance["equation"]
			_par = instance["par"]
		_guided = level.get("guided", false)
		_endless = level.get("endless", false)
		_set_level_badge(level)
		if level.has("intro"):
			_intro["title"].text = level.get("intro_title", "")
			_intro["detail"].text = level["intro"]
			if level["number"] == 1: # primo livello del mondo: si presenta il personaggio
				_intro["face"].texture = Game.character_texture(level["world"])
				_intro["face"].visible = _intro["face"].texture != null
			_intro["root"].visible = true
	else:
		_level_label.get_parent().get_parent().visible = false # il riquadro del livello
	_hint_button.visible = not _guided # nei livelli guidati il suggerimento c'è già

	eq.state_changed.connect(_refresh)
	if not eq.load_equation(equation_text):
		push_error("Equazione non valida: " + equation_text)


func _process(_delta: float) -> void:
	if not _hint_move.is_empty():
		_hint_layer.queue_redraw() # le frecce pulsano e seguono i pezzi che si muovono


# ============================================================ costruzione della scena

func _build_scene() -> void:
	var bg := SceneBackground.new()
	bg.z_index = -20
	add_child(bg)
	_mirror = MirrorView.new()
	_mirror.z_index = -10
	add_child(_mirror)
	for side in ["sinistra", "destra"]:
		var a := AliceView.new(side)
		a.position = Vector2(150.0 if side == "sinistra" else SCREEN_W - 150.0, 728.0)
		a.z_index = -5
		add_child(a)
		_alice[side] = a
	_empty_left = _make_empty_label((LEFT_AREA.x + LEFT_AREA.y) / 2.0)
	_empty_right = _make_empty_label((RIGHT_AREA.x + RIGHT_AREA.y) / 2.0)
	_hint_layer = Node2D.new()
	_hint_layer.z_index = 20
	_hint_layer.draw.connect(_draw_hint)
	add_child(_hint_layer)


func _build_hud() -> void:
	var hud: CanvasLayer = $HUD
	# l'equazione scritta, in alto al centro
	_restyle_pill(equation_label, 50)
	equation_label.position.y = 22.0
	# le mosse, in basso al centro
	_restyle_pill(status_label, 28)
	status_label.position.y = 650.0

	# pulsanti a sinistra
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 18)
	bar.add_theme_constant_override("separation", 14)
	hud.add_child(bar)
	for spec in [["levels", _go_to_levels, "Livelli"], ["restart", _restart, "Ricomincia"], ["undo", _undo, "Annulla"]]:
		var b := IconButton.new(spec[0], UIStyle.WHITE, spec[2])
		b.pressed.connect(spec[1])
		bar.add_child(b)

	# a destra: suggerimento e livello
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 14)
	hud.add_child(right)
	_right_bar = right
	_hint_button = IconButton.new("hint", UIStyle.GOLD, "Suggerimento")
	_hint_button.pressed.connect(_on_hint_pressed)
	right.add_child(_hint_button)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.WHITE, 40, 9, 22.0, 6.0))
	badge.custom_minimum_size = Vector2(0, IconButton.SIZE)
	right.add_child(badge)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 8)
	badge.add_child(badge_row)
	_level_face = _face_rect(64.0)
	badge_row.add_child(_level_face)
	_level_label = UIStyle.label("", 26, true)
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_row.add_child(_level_label)
	_level_inf = InfinityView.new()
	_level_inf.custom_minimum_size = Vector2(54, 30)
	_level_inf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_level_inf.visible = false
	badge_row.add_child(_level_inf)
	right.resized.connect(func():
		right.position = Vector2(SCREEN_W - 24.0 - right.size.x, 18)
		_fit_equation())

	_bubble = SpeechBubble.new()
	hud.add_child(_bubble)


func _restyle_pill(l: Label, font_size: int) -> void:
	l.add_theme_font_override("font", UIStyle.FONT_TITLE)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", UIStyle.INK)
	l.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.WHITE, 24, 9, 28.0, 2.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.resized.connect(func(): l.position.x = (SCREEN_W - l.size.x) / 2.0)


## L'equazione scritta sta tra i pulsanti di sinistra e quelli di destra:
## se è troppo lunga, il carattere si rimpicciolisce.
func _fit_equation() -> void:
	if _right_bar == null:
		return
	var room_left := MIRROR_X - (24.0 + 3.0 * IconButton.SIZE + 2.0 * 14.0) - 16.0
	var room_right := _right_bar.position.x - 16.0 - MIRROR_X
	if not _right_bar.visible or _right_bar.size.x <= 0.0:
		room_right = room_left
	var max_w := 2.0 * minf(room_left, room_right) - 56.0 # 56 = margini della pillola
	var font_size := 50
	while font_size > 26 and UIStyle.FONT_TITLE.get_string_size(equation_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
		font_size -= 2
	equation_label.add_theme_font_size_override("font_size", font_size)
	equation_label.reset_size()
	equation_label.position.y = 22.0 + (50 - font_size) * 0.5 # resta centrata rispetto ai pulsanti


## In alto a destra: il volto del personaggio del mondo e il numero del livello.
func _set_level_badge(level: Dictionary) -> void:
	var w: int = level["world"]
	_level_face.texture = Game.character_texture(w)
	_level_face.visible = _level_face.texture != null
	_level_face.get_parent().get_parent().tooltip_text = "%s · %s" % [Game.character_name(w), Game.worlds[w]["name"]]
	var endless: bool = level.get("endless", false)
	_level_label.text = "Allenamento" if endless else "Livello %d" % level["number"]
	_level_inf.visible = endless
	if not _level_face.visible: # mondo senza personaggio: resta il nome
		_level_label.text = "%s · %s" % [Game.world_short_title(w), _level_label.text]


## Un riquadro per l'immagine di un personaggio, di lato `side` pixel.
static func _face_rect(side: float) -> TextureRect:
	var r := TextureRect.new()
	r.custom_minimum_size = Vector2(side, side)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _make_empty_label(center_x: float) -> Label:
	var l := UIStyle.label("vuoto", 28, true, Color(UIStyle.INK, 0.45))
	l.position = Vector2(center_x - 40.0, ROW_Y - 20.0)
	l.visible = false
	add_child(l)
	return l


# ============================================================ disegno e animazioni

func _refresh() -> void:
	_message = "" # una mossa valida cancella un eventuale messaggio di errore
	_message_serial += 1
	var flip := _pending_flip
	_pending_flip = false

	var seen := {}
	_layout_side(eq.left, left_side, LEFT_AREA, flip, seen)
	_layout_side(eq.right, right_side, RIGHT_AREA, flip, seen)
	for id in _views.keys(): # i pezzi che non esistono più svaniscono
		if not seen.has(id):
			_vanish(_views[id])
			_views.erase(id)

	_empty_left.visible = eq.left.is_empty()
	_empty_right.visible = eq.right.is_empty()
	equation_label.text = eq.to_text()
	_fit_equation()
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


## Dispone i pezzi di un membro, centrati nella loro area. Se non ci stanno
## (equazioni lunghe, frazioni alte) li rimpicciolisce tutti insieme.
func _layout_side(terms: Array[EqTerm], container: Node2D, area: Vector2, flip: bool, seen: Dictionary) -> void:
	var views: Array[TermView] = []
	var olds: Array = [] # com'era ogni pezzo prima della mossa (null se è nuovo)
	var total := 0.0
	var top := 0.0
	var bottom := 0.0
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
		var r := v.get_local_rect()
		top = maxf(top, -r.position.y)
		bottom = maxf(bottom, r.end.y)
	total += TERM_GAP * maxi(views.size() - 1, 0)

	var k := 1.0 # fattore di scala comune a tutto il membro
	if total > 0.0:
		k = minf(k, (area.y - area.x) / total)
	if top > 0.0:
		k = minf(k, (ROW_Y - TOP_LIMIT) / top)
	if bottom > 0.0:
		k = minf(k, (BOTTOM_LIMIT - ROW_Y) / bottom)

	var x := (area.x + area.y) / 2.0 - total * k / 2.0
	for i in views.size():
		views[i].set_meta("base_scale", k)
		_animate_to(views[i], olds[i], container, Vector2(x, ROW_Y), flip)
		x += (views[i].get_width() + TERM_GAP) * k


func _animate_to(v: TermView, old: EqTerm, container: Node2D, target: Vector2, flip: bool) -> void:
	var k: float = v.get_meta("base_scale", 1.0)
	v.z_index = 0
	var tw := _tween_of(v)
	tw.set_parallel(true)

	if old == null: # pezzo nuovo (inizio livello, o tornato con annulla): appare
		v.position = target
		v.scale = Vector2(k, k)
		tw.tween_property(v, "modulate:a", 1.0, ANIM_TIME)
		return

	var t := v.term
	var crossed := v.get_parent() != container
	if crossed:
		v.reparent(container) # mantiene la posizione sullo schermo
		_mirror.ripple(v.global_position.y)
		_alice["sinistra" if container == left_side else "destra"].react("felice", 0.8)

	# Il disco è diventato 1: lo mostriamo per un istante prima che sparisca.
	if (t.is_x() or t.grouped) and old.count > 1 and t.count == 1:
		_ghost_disc(v)

	tw.tween_property(v, "position", target, ANIM_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(v, "modulate:a", 1.0, ANIM_TIME)
	if crossed or (flip and old.negative != t.negative):
		v.scale = Vector2(0.0, k) # si "apre" come un foglio girato
	elif old.count != t.count or old.divisor != t.divisor or old.grouped != t.grouped:
		v.scale = Vector2(1.2, 1.2) * k # pop: il pezzo è cambiato
	tw.tween_property(v, "scale", Vector2(k, k), ANIM_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Un pezzo che non esiste più (assorbito o annullato) si rimpicciolisce e svanisce.
func _vanish(v: TermView) -> void:
	v.reparent(self) # fuori dai membri: non si può più afferrare
	v.highlight = ""
	var tw := _tween_of(v)
	tw.set_parallel(true)
	tw.tween_property(v, "scale", v.scale * 0.3, ANIM_TIME)
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


func _update_status() -> void:
	match eq.get_status():
		Equation.Status.SOLVED:
			status_label.text = "Risolta in " + _moves_text(eq.move_count)
		Equation.Status.IMPOSSIBLE:
			status_label.text = "Impossibile!"
		Equation.Status.IDENTITY:
			status_label.text = "Indeterminata!"
		_:
			status_label.text = "Mosse %d" % eq.move_count + ((" · par %d" % _par) if _par > 0 else "")


## "1 mossa", "3 mosse".
static func _moves_text(n: int) -> String:
	return "1 mossa" if n == 1 else "%d mosse" % n


## Alice dice qualcosa per un po' (errori e conferme), dal lato indicato.
func _show_message(text: String, side := "") -> void:
	_message = text
	_message_side = side if side != "" else ("sinistra" if _drag_from_left else "destra")
	_message_serial += 1
	var serial := _message_serial
	_alice[_message_side].react("sorpresa", 1.6)
	_update_bubble()
	await get_tree().create_timer(2.5).timeout
	if serial == _message_serial: # nel frattempo non è arrivato un altro messaggio
		_message = ""
		_update_bubble()


## Chi parla e cosa dice: prima i messaggi, poi il suggerimento, poi il passaggio del mouse.
func _update_bubble() -> void:
	var text := ""
	var side := "sinistra"
	if _completed:
		text = ""
	elif _message != "":
		text = _message
		side = _message_side
	elif not _hint_move.is_empty():
		text = MOVE_TEXT[_hint_move["type"]]
		side = _hint_side()
	elif _mirror_hover:
		text = HOVER_TEXT["mirror"]
	elif _hover_view != null and is_instance_valid(_hover_view) and _hover_part != "":
		text = HOVER_TEXT[_hover_part]
		side = "sinistra" if _hover_view.get_parent() == left_side else "destra"
	_bubble.say(text, side)
	# chi non parla, pensa (solo quando c'è un suggerimento in corso)
	if not _completed:
		var other := "destra" if side == "sinistra" else "sinistra"
		_alice[side].set_mood("normale")
		_alice[other].set_mood("pensa" if text != "" and not _hint_move.is_empty() else "normale")


## Il lato in cui si svolge la mossa suggerita.
func _hint_side() -> String:
	if _hint_move["type"] == "flip": # parla l'Alice dalla parte della x negativa
		for t in eq.right:
			if t.is_x() and t.negative:
				return "destra"
		return "sinistra"
	var g := _hint_geometry()
	if g.is_empty() or g["view"] == null:
		return "sinistra"
	return "sinistra" if g["view"].get_parent() == left_side else "destra"


# ============================================================ evidenziazione e suggerimento

## Contorni sui pezzi: viola per il suggerimento, rosa per il passaggio del mouse.
func _apply_highlights() -> void:
	for v in _views.values():
		v.highlight = ""
	var hint := _hint_geometry()
	if not hint.is_empty():
		if hint["view"] != null:
			hint["view"].highlight_color = UIStyle.ADVICE
			hint["view"].highlight = hint["part"]
		if hint["target_view"] != null:
			hint["target_view"].highlight_color = UIStyle.ADVICE
			hint["target_view"].highlight = "body"
	if _hover_view != null and is_instance_valid(_hover_view) and _hover_view.highlight == "":
		_hover_view.highlight_color = UIStyle.HOVER
		_hover_view.highlight = _hover_part
	_update_bubble()


## Pulsante Suggerimento: chiede al risolutore la mossa migliore.
func _on_hint_pressed() -> void:
	if _completed:
		return
	if _show_hint():
		_used_hint = true
		_apply_highlights()
	else:
		_show_message("Prova ad annullare qualche mossa", "sinistra")


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
		"cancel": # si trascina a sul suo gemello b, oltre lo specchio
			g["target_view"] = _views.get(m["b"])
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
			g["to"] = Vector2(MIRROR_X + dir * dist, ROW_Y - 60.0)
	return g


## Disegnato sul livello _hint_layer, sopra i pezzi: freccia tratteggiata che pulsa.
func _draw_hint() -> void:
	var g := _hint_geometry()
	if g.is_empty():
		return
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	var col := Color(UIStyle.ADVICE, pulse)
	if _hint_move["type"] == "flip":
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = col
		sb.set_border_width_all(6)
		sb.set_corner_radius_all(100)
		sb.anti_aliasing = true
		sb.draw(_hint_layer.get_canvas_item(), _mirror.hit_rect().grow(8.0))
		return
	if g["to"] == null:
		return
	var a: Vector2 = g["from"]
	var b: Vector2 = g["to"]
	if g["target_view"] == null: # verso un punto vuoto: una curva che scavalca lo specchio
		_draw_dashed_curve(a, b, Vector2((a.x + b.x) / 2.0, minf(a.y, b.y) - 170.0), col)
	else:
		_draw_dashed_curve(a, b, (a + b) / 2.0 + Vector2(0, -80.0), col)


## Curva tratteggiata (Bézier quadratica) con la punta di freccia in fondo.
func _draw_dashed_curve(a: Vector2, b: Vector2, ctrl: Vector2, col: Color) -> void:
	var steps := 30
	var prev := a
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var p := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
		if i % 2 == 0:
			_hint_layer.draw_line(prev, p, col, 6.0, true)
		prev = p
	var before := a.lerp(ctrl, 0.92).lerp(ctrl.lerp(b, 0.92), 0.92)
	var dir := (b - before).normalized()
	var side := Vector2(-dir.y, dir.x)
	_hint_layer.draw_colored_polygon(PackedVector2Array([b, b - dir * 24.0 + side * 13.0, b - dir * 24.0 - side * 13.0]), col)


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
	var on_mirror := hit.is_empty() and _mirror.hit_rect().has_point(pos)
	if view == _hover_view and part == _hover_part and on_mirror == _mirror_hover:
		return
	_hover_view = view
	_hover_part = part
	_mirror_hover = on_mirror
	_mirror.set_hover(on_mirror)
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
		return
	_drag_view.global_position = _drag_origin + (pos - _drag_start)
	# il gemello oltre lo specchio si illumina: lasciando lì il pezzo, spariscono tutti e due
	var twin := _twin_at(pos, _drag_view)
	if twin == _drag_twin:
		return
	if _drag_twin != null and is_instance_valid(_drag_twin):
		_drag_twin.highlight = ""
	_drag_twin = twin
	if twin != null:
		twin.highlight_color = UIStyle.HOVER
		twin.highlight = "body"


## Il gemello di `view` sotto il punto, dall'altra parte dello specchio (oppure null).
func _twin_at(pos: Vector2, view: TermView) -> TermView:
	if (pos.x < MIRROR_X) == _drag_from_left:
		return null
	var hit := _term_at(pos, view)
	if hit.is_empty() or not Equation.are_twins(view.term, hit["view"].term):
		return null
	return hit["view"]


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
	if _drag_twin != null and is_instance_valid(_drag_twin):
		_drag_twin.highlight = ""
	_drag_twin = null
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
				_show_message("Porta il disco oltre lo specchio!")
		"divisor": # denominatore: gancio oltre lo specchio, mcm su un altro termine
			if crossed:
				_report(eq.hook_divisor(id), view, origin)
			elif not target.is_empty():
				_report(eq.slice_common(target["view"].term.id, id), view, origin)
			else:
				_snap_back(view, origin)
		_: # il pezzo intero
			var twin := _twin_at(pos, view)
			if twin != null: # sul gemello oltre lo specchio: spariscono entrambi
				_mirror.ripple(pos.y)
				_report(eq.cancel(id, twin.term.id), view, origin)
				for a in _alice.values():
					a.react("felice", 0.8)
			elif crossed:
				_report(eq.move_across(id), view, origin)
			elif not target.is_empty():
				_report(eq.merge(target["view"].term.id, id), view, origin) # il risultato resta al posto del bersaglio
			else:
				_snap_back(view, origin)


func _on_double_click(pos: Vector2) -> void:
	if _mirror.hit_rect().has_point(pos) and _term_at(pos).is_empty():
		_pending_flip = true
		if eq.flip_all() == Equation.MoveResult.SUCCESS:
			_mirror.flash()
		_pending_flip = false
		return
	var hit := _term_at(pos)
	if hit.is_empty():
		return
	var view: TermView = hit["view"]
	var t := view.term
	_drag_from_left = eq.is_on_left(t.id)
	if t.divisor > 1 and Fraction.gcd(t.count, t.divisor) > 1:
		_report(eq.simplify(t.id), view, view.global_position)
	elif t.grouped and not t.is_x():
		_report(eq.ungroup(t.id), view, view.global_position)
	else:
		_report(eq.group(t.id), view, view.global_position)


## Mossa riuscita: il modello ha già avviato le animazioni.
## Mossa rifiutata: il pezzo torna al suo posto e Alice spiega perché.
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


# ============================================================ pannelli

## Un pannello centrale con titolo, testo, stelle (facoltative) e pulsanti.
## Restituisce {root, title, detail, stars, buttons: {testo: Button}}. Parte nascosto.
func _make_dialog(width: float, with_stars: bool, buttons: Array) -> Dictionary:
	var shade := ColorRect.new() # velo sul campo: blocca i tocchi sui pezzi
	shade.color = Color(UIStyle.LILAC, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.visible = false
	$HUD.add_child(shade)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.WHITE, 32, 12, 40.0, 32.0))
	shade.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	panel.add_child(col)

	var head := HBoxContainer.new() # volto del personaggio (facoltativo) e titolo
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 18)
	col.add_child(head)
	var face := _face_rect(96.0)
	face.visible = false
	head.add_child(face)
	var title := UIStyle.label("", 46, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(title)

	var detail := UIStyle.label("", 28, false, UIStyle.MUTED)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(width - 80.0, 0) # serve per andare a capo
	col.add_child(detail)

	var stars := StarsView.new()
	stars.radius = 30.0
	stars.visible = with_stars
	col.add_child(stars)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	col.add_child(row)
	var by_text := {}
	for spec in buttons:
		var b := Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(150, 80)
		UIStyle.style_button(b, UIStyle.GOLD if spec[0] in ["Avanti", "Inizia", "Nuova"] else UIStyle.WHITE, 30)
		b.pressed.connect(spec[1])
		row.add_child(b)
		by_text[spec[0]] = b
	return {"root": shade, "title": title, "face": face, "detail": detail, "stars": stars, "buttons": by_text}


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
	for a in _alice.values():
		a.set_mood("normale")
	eq.load_equation(equation_text)


func _undo() -> void:
	if not _completed:
		eq.undo()


func _on_completed() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	_mirror_hover = false
	_mirror.set_hover(false)
	_bubble.say("", "sinistra")
	for a in _alice.values():
		a.set_mood("felice")
		a.react("felice", 0.1)
	match eq.get_status():
		Equation.Status.SOLVED:
			_win["title"].text = "x = %s" % eq.get_solution()
		Equation.Status.IMPOSSIBLE:
			_win["title"].text = "Impossibile!"
		Equation.Status.IDENTITY:
			_win["title"].text = "Indeterminata!"

	var detail := _moves_text(eq.move_count) + (("  ·  par %d" % _par) if _par > 0 else "")
	if _endless:
		Game.endless_solved += 1
		detail += "\nRisolte in questo allenamento: %d" % Game.endless_solved
		_win["stars"].visible = false
	else:
		var got := Game.complete_current(eq.move_count, _par, _used_hint) if _par > 0 else 0
		_win["stars"].stars = got
		_win["stars"].visible = _par > 0
		if _par > 0 and _used_hint:
			detail += "\nCon un suggerimento: al massimo 2 stelle."
		elif _par > 0 and got < 3:
			detail += "\nSi può fare con meno mosse!"
	_win["detail"].text = detail
	_win["buttons"]["Ripeti"].visible = not _endless
	_win["buttons"]["Nuova"].visible = _endless
	_win["buttons"]["Avanti"].visible = Game.has_next()

	await get_tree().create_timer(0.8).timeout # il tempo di vedere l'ultima animazione
	if _completed: # nel frattempo il giocatore potrebbe aver premuto Ricomincia
		_win["root"].visible = true


## Allenamento libero: un'altra equazione dello stesso tipo, senza uscire dal livello.
func _new_equation() -> void:
	var instance := Game.new_instance()
	if instance.is_empty():
		return
	equation_text = instance["equation"]
	_par = instance["par"]
	_restart()


func _go_to_levels() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _go_to_next() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	Game.endless_solved = 0
	Game.current += 1
	get_tree().reload_current_scene()
