extends Control
## Schermata di selezione dei livelli. Tutta l'interfaccia è costruita qui nel codice:
## la scena contiene solo il nodo radice (un Control) con questo script.

const LEVEL_SCENE := "res://scenes/level.tscn"
const COL_BG := Color("#F5F3EE")
const COL_TEXT := Color("#2C2C2A")
const COL_HINT := Color("#888780")


func _ready() -> void:
	RenderingServer.set_default_clear_color(COL_BG)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # ancoraggi E dimensioni: tutto lo schermo

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)

	column.add_child(_label("Equazioni allo specchio", 40, COL_TEXT))
	column.add_child(_label("Scegli un livello", 18, COL_HINT))

	if Game.levels.is_empty():
		column.add_child(_label("Nessun livello caricato: controlla che il file data/levels.json esista.", 18, Color("#A32D2D")))
		return

	var index := 0
	for w in Game.worlds.size():
		column.add_child(_label(Game.world_title(w), 22, COL_TEXT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		column.add_child(row)
		for n in Game.worlds[w]["levels"].size():
			row.add_child(_level_button(index, n + 1))
			index += 1


func _level_button(index: int, number: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(96, 84)
	b.text = str(number)
	b.add_theme_font_size_override("font_size", 26)
	b.disabled = not Game.is_unlocked(index)
	b.pressed.connect(_open_level.bind(index))

	var stars := StarsView.new()
	stars.radius = 8.0
	stars.stars = Game.stars_of(index)
	stars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -24.0
	stars.offset_bottom = -6.0
	b.add_child(stars)
	return b


func _open_level(index: int) -> void:
	Game.current = index
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l
