class_name UIStyle
extends RefCounted
## Colori, caratteri e stili comuni dell'interfaccia (direzione "cartoon morbido").
## Cambiando un valore qui si aggiorna tutto il gioco.

const INK := Color("#2B2440")          # contorni e testi
const WHITE := Color("#FFFFFF")
const LILAC := Color("#ECE7FA")        # muro del mondo "di qua"
const LILAC_DOTS := Color("#E1DAF6")
const LILAC_TILE := Color("#D9D0F5")
const MINT := Color("#D6F4EC")         # muro del mondo "oltre lo specchio"
const MINT_DOTS := Color("#BDEADF")
const MINT_TILE := Color("#BDEADF")
const FLOOR_DARK := Color("#3A3160")   # pavimento scuro oltre lo specchio
const GLASS_LEFT := Color("#DCD3FA")
const GLASS_RIGHT := Color("#BFF0E8")
const GOLD := Color("#FFD45C")
const PINK := Color("#FF8AB8")
const X := Color("#FF8A3D")            # incognita
const X_HOLLOW := Color("#E0661B")
const X_HOLLOW_TEXT := Color("#C2530F")
const UNIT := Color("#1FA894")         # unità
const DISC := Color("#5B4BC9")         # dischi (quantità)
const ADVICE := Color("#5B4BC9")       # suggerimento: contorni e frecce
const HOVER := Color("#FF8AB8")        # passaggio del mouse
const MUTED := Color("#6A6388")

const FONT_TITLE: Font = preload("res://assets/fonts/fredoka_semibold.tres")
const FONT_BODY: Font = preload("res://assets/fonts/nunito_extrabold.tres")

const BORDER := 4
const DEPTH := 9 # bordo inferiore più spesso: l'effetto "in rilievo"


## Riquadro arrotondato con contorno e rilievo in basso.
static func box(bg: Color, radius: int, depth := DEPTH, margin_h := 20.0, margin_v := 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = INK
	sb.set_border_width_all(BORDER)
	sb.border_width_bottom = depth
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	sb.anti_aliasing = true
	return sb


## Pulsante nello stile del gioco: rilievo che si abbassa quando lo premi.
static func style_button(b: Button, bg := WHITE, font_size := 28, radius := 40) -> void:
	var normal := box(bg, radius)
	var hover := box(bg.lightened(0.25), radius)
	var pressed := box(bg.darkened(0.08), radius, BORDER)
	pressed.content_margin_top += DEPTH - BORDER # il contenuto scende col tasto
	var disabled := box(Color(bg, 0.55), radius)
	disabled.border_color = Color(INK, 0.35)
	for pair in [["normal", normal], ["hover", hover], ["pressed", pressed], ["disabled", disabled], ["focus", StyleBoxEmpty.new()]]:
		b.add_theme_stylebox_override(pair[0], pair[1])
	b.add_theme_font_override("font", FONT_TITLE)
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.35))
	b.focus_mode = Control.FOCUS_NONE


## Etichetta con il carattere dei titoli o dei testi.
static func label(text: String, font_size: int, title := false, color := INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_TITLE if title else FONT_BODY)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Etichetta dentro una "pillola" bianca (equazione, mosse, livello).
static func pill_label(text: String, font_size: int, radius := 999) -> Label:
	var l := label(text, font_size, true)
	l.add_theme_stylebox_override("normal", box(WHITE, mini(radius, 60), 7, 26.0, 4.0))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
