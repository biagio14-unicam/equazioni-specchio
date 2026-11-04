extends Control
## Schermata del titolo: EQUALICEY al centro (le lettere di ALICE in un altro colore),
## il pulsante di uscita in alto a destra, Alice in basso a sinistra e la x in basso a destra.
## Tutto è costruito qui nel codice, come nella selezione dei livelli.

const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const W := 1280.0
const H := 720.0

const TITLE := "EQUALICEY"
const ALICE_FROM := 3            # EQU|ALICE|Y: le lettere da 3 a 7 sono "ALICE"
const ALICE_TO := 7
const TITLE_COLOR := Color("#5B4BC9")  # come i dischi
const ALICE_COLOR := Color("#FF8AB8")  # rosa
const TITLE_MAX_SIZE := 190
const TITLE_MAX_WIDTH := 1060.0
const TITLE_BASELINE := 300.0

var _wordmark: Control
var _font_size := TITLE_MAX_SIZE
var _alice: AliceView
var _x_piece: TermView
var _exit_note: Label


func _ready() -> void:
	RenderingServer.set_default_clear_color(UIStyle.LILAC)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# sfondo: i due mondi con la scacchiera, come nei livelli
	var stage := Node2D.new()
	add_child(stage)
	stage.add_child(SceneBackground.new())

	# in basso a sinistra: Alice
	_alice = AliceView.new("sinistra")
	_alice.position = Vector2(150.0, 728.0)
	stage.add_child(_alice)
	_alice.set_mood("felice")

	# in basso a destra: la x (position = bordo sinistro e centro verticale del pezzo)
	var x_term := EqTerm.new()
	x_term.base = EqTerm.Base.X
	x_term.grouped = true
	_x_piece = TermView.new()
	_x_piece.term = x_term
	_x_piece.scale = Vector2(1.5, 1.5)
	_x_piece.position = Vector2(1104.0, 640.0)
	stage.add_child(_x_piece)
	var wobble := _x_piece.create_tween().set_loops()
	wobble.tween_property(_x_piece, "rotation", deg_to_rad(6.0), 1.4).set_trans(Tween.TRANS_SINE)
	wobble.tween_property(_x_piece, "rotation", deg_to_rad(-6.0), 1.4).set_trans(Tween.TRANS_SINE)

	# il titolo
	_wordmark = Control.new()
	_wordmark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wordmark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wordmark.draw.connect(_draw_title)
	add_child(_wordmark)
	while _font_size > 80 and _title_width(_font_size) > TITLE_MAX_WIDTH:
		_font_size -= 4

	var subtitle := UIStyle.label("Aiuta Alice a risolvere le equazioni!", 34, true, UIStyle.MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.size = Vector2(W, 50)
	subtitle.position = Vector2(0, TITLE_BASELINE + 22.0)
	add_child(subtitle)

	# Gioca
	var play := Button.new()
	play.text = "Gioca"
	UIStyle.style_button(play, UIStyle.GOLD, 50, 48)
	play.custom_minimum_size = Vector2(300, 100)
	play.size = play.custom_minimum_size
	play.position = Vector2((W - 300.0) / 2.0, 410.0)
	play.pressed.connect(_play)
	add_child(play)

	# in alto a destra: esci
	var quit := IconButton.new("exit", UIStyle.WHITE, "Esci")
	quit.position = Vector2(W - 24.0 - IconButton.SIZE, 24.0)
	quit.pressed.connect(_quit)
	add_child(quit)

	_exit_note = UIStyle.pill_label("Per uscire, chiudi la scheda del browser", 24)
	_exit_note.visible = false
	add_child(_exit_note)


func _process(_delta: float) -> void:
	_wordmark.queue_redraw() # le lettere ondeggiano


## EQUALICEY: lettere con contorno "adesivo" e ombra, che ondeggiano piano.
## Le lettere di ALICE sono rosa e saltellano un po' di più.
func _draw_title() -> void:
	var font := UIStyle.FONT_TITLE
	var t := Time.get_ticks_msec() / 1000.0
	var x := (W - _title_width(_font_size)) / 2.0
	for i in TITLE.length():
		var ch := TITLE[i]
		var is_alice := i >= ALICE_FROM and i <= ALICE_TO
		var bob := sin(t * 2.2 + i * 0.6) * (9.0 if is_alice else 4.0)
		var pos := Vector2(x, TITLE_BASELINE + bob)
		var fill := ALICE_COLOR if is_alice else TITLE_COLOR
		_wordmark.draw_string_outline(font, pos + Vector2(0, 10), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 30, Color(UIStyle.INK, 0.25))
		_wordmark.draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 30, UIStyle.WHITE)
		_wordmark.draw_string_outline(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, 12, UIStyle.INK)
		_wordmark.draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, fill)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x + _spacing(_font_size)


func _title_width(font_size: int) -> float:
	var w := 0.0
	for ch in TITLE:
		w += UIStyle.FONT_TITLE.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + _spacing(font_size)
	return w - _spacing(font_size)


## Un po' d'aria tra le lettere, per i contorni spessi.
static func _spacing(font_size: int) -> float:
	return font_size * 0.03


## Toccando Alice o la x succede qualcosa (solo per divertimento).
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var p := (make_input_local(mb) as InputEventMouse).position
	if Rect2(_alice.position.x - 100.0, _alice.position.y - 240.0, 200.0, 240.0).has_point(p):
		_alice.react("sorpresa", 0.8)
	elif Rect2(_x_piece.position - Vector2(10, 60), Vector2(120, 120)).has_point(p):
		var spin := _x_piece.create_tween()
		spin.tween_property(_x_piece, "scale", Vector2(1.8, 1.8), 0.12)
		spin.tween_property(_x_piece, "scale", Vector2(1.5, 1.5), 0.25).set_trans(Tween.TRANS_BACK)


func _play() -> void:
	_alice.react("felice", 0.3)
	await get_tree().create_timer(0.25).timeout
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


## Sul computer chiude il gioco. Nel browser una pagina non può chiudersi da sola
## (se non l'ha aperta uno script): torna alla pagina precedente, se c'è,
## altrimenti spiega come uscire.
func _quit() -> void:
	if not OS.has_feature("web"):
		get_tree().quit()
		return
	JavaScriptBridge.eval("if (window.history.length > 1) { window.history.back(); } else { window.close(); }")
	_exit_note.visible = true
	_exit_note.reset_size()
	_exit_note.position = Vector2((W - _exit_note.size.x) / 2.0, 560.0)
	await get_tree().create_timer(3.0).timeout
	_exit_note.visible = false
