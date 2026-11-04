extends Control
## Schermata di selezione dei livelli. Tutta l'interfaccia è costruita qui nel codice:
## la scena contiene solo il nodo radice (un Control) con questo script.
##
## Una riga per mondo: il volto del personaggio, i livelli, l'allenamento (∞) e i nomi.

const LEVEL_SCENE := "res://scenes/level.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
const BUTTON_SIZE := Vector2(104, 100)
const FACE_SIZE := 100.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(UIStyle.LILAC)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # ancoraggi E dimensioni: tutto lo schermo

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 28)
	scroll.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	# in alto: torna al titolo, e il titolo della schermata
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	column.add_child(header)
	var home := IconButton.new("home", UIStyle.WHITE, "Titolo")
	home.pressed.connect(func(): get_tree().change_scene_to_file(TITLE_SCENE))
	header.add_child(home)
	var heading := UIStyle.label("Scegli un livello", 50, true)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(heading)

	if Game.levels.is_empty():
		column.add_child(UIStyle.label("Nessun livello caricato: controlla che il file data/levels.json esista.", 26, false, Color("#A32D2D")))
		return

	var row: HBoxContainer = null
	var last_world := -1
	for index in Game.levels.size():
		var level: Dictionary = Game.levels[index]
		if level["world"] != last_world: # nuovo mondo: nuova riga, che comincia col personaggio
			if row != null:
				row.add_child(_world_names(last_world))
			last_world = level["world"]
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			column.add_child(row)
			row.add_child(_world_face(last_world))
		row.add_child(_level_button(index, level["number"]))
	if row != null:
		row.add_child(_world_names(last_world))


## Il volto del personaggio del mondo (grigio se il mondo è ancora chiuso).
func _world_face(w: int) -> Control:
	var face := TextureRect.new()
	face.texture = Game.character_texture(w)
	face.custom_minimum_size = Vector2(FACE_SIZE, FACE_SIZE)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.tooltip_text = Game.character_name(w)
	if not Game.is_world_unlocked(w):
		face.modulate = Color(0.75, 0.72, 0.85, 0.55)
	# un po' di spazio tra il personaggio e il primo livello
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_right", 6)
	box.add_child(face)
	return box


## A destra della riga: il nome del personaggio e quello del mondo.
func _world_names(w: int) -> Control:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	var who := UIStyle.label(Game.character_name(w), 24, true)
	who.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	who.custom_minimum_size = Vector2(300, 0)
	col.add_child(who)
	col.add_child(UIStyle.label(Game.worlds[w]["name"], 20, false, UIStyle.MUTED))
	var box := MarginContainer.new()
	box.add_theme_constant_override("margin_left", 10)
	box.add_child(col)
	return box


func _level_button(index: int, number: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = BUTTON_SIZE
	var unlocked := Game.is_unlocked(index)
	var endless := Game.is_endless(index)
	UIStyle.style_button(b, UIStyle.GOLD if endless else UIStyle.WHITE, 40, 28)
	b.disabled = not unlocked
	b.pressed.connect(_open_level.bind(index))

	if endless: # allenamento libero: il simbolo ∞, niente stelle
		b.tooltip_text = "Allenamento libero"
		var inf := InfinityView.new()
		inf.color = UIStyle.INK if unlocked else Color(UIStyle.INK, 0.35)
		inf.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inf.offset_bottom = -6.0
		b.add_child(inf)
		return b

	b.text = str(number)
	var stars := StarsView.new()
	stars.radius = 11.0
	stars.stars = Game.stars_of(index)
	stars.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stars.offset_top = -38.0
	stars.offset_bottom = -14.0
	b.add_child(stars)
	# il numero un po' più in alto, per fare posto alle stelle
	for s in ["normal", "hover", "pressed", "disabled"]:
		var sb: StyleBoxFlat = b.get_theme_stylebox(s)
		sb.content_margin_bottom += 24.0
	return b


func _open_level(index: int) -> void:
	Game.current = index
	Game.endless_solved = 0
	# un frame di attesa: con il tocco, la lista scorrevole sta ancora finendo il suo gesto
	await get_tree().process_frame
	get_tree().change_scene_to_file(LEVEL_SCENE)
