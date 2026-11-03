extends Node
## Autoload "Game": sempre presente, in tutte le scene.
## Carica i livelli da data/levels.json, ricorda il livello in corso
## e salva le stelle ottenute (su web finiscono nella memoria del browser).

const LEVELS_PATH := "res://data/levels.json"
const SAVE_PATH := "user://progress.json"

var worlds: Array = []        # come nel file: [{name, tutorial?, levels: [...]}]
var levels: Array = []        # tutti i livelli in fila, con i campi del file più world/number/id/title
var current := -1             # indice in `levels` del livello in corso (-1 = nessuno)
var _stars := {}              # id del livello -> stelle migliori (1..3)


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Impossibile leggere " + LEVELS_PATH)
		return
	worlds = data["worlds"]
	for w in worlds.size():
		var world_levels: Array = worlds[w]["levels"]
		for n in world_levels.size():
			var l: Dictionary = world_levels[n].duplicate()
			l["world"] = w
			l["number"] = n + 1
			l["par"] = int(l.get("par", 0))
			# id stabile: "T-1" per il tutorial, "1-1" per il Mondo 1... (aggiungere il
			# tutorial non cambia gli id dei mondi, così i progressi salvati restano validi)
			l["id"] = "%s-%d" % [_world_code(w), n + 1]
			l["title"] = "%s · Livello %d" % [world_short_title(w), n + 1]
			levels.append(l)
	_load_progress()


## "Tutorial", "Mondo 1", "Mondo 2"...
func world_short_title(w: int) -> String:
	if worlds[w].get("tutorial", false):
		return "Tutorial"
	return "Mondo %d" % _world_number(w)


## "Tutorial", "Mondo 1 · Lo specchio"...
func world_title(w: int) -> String:
	if worlds[w].get("tutorial", false):
		return "Tutorial"
	return "Mondo %d · %s" % [_world_number(w), worlds[w]["name"]]


func _world_number(w: int) -> int:
	var n := 0
	for i in w + 1:
		if not worlds[i].get("tutorial", false):
			n += 1
	return n


func _world_code(w: int) -> String:
	return "T" if worlds[w].get("tutorial", false) else str(_world_number(w))


func current_level() -> Dictionary:
	return levels[current] if current >= 0 and current < levels.size() else {}


func has_next() -> bool:
	return current >= 0 and current + 1 < levels.size()


func stars_of(index: int) -> int:
	return _stars.get(levels[index]["id"], 0)


## Giocabile se è il primo, se il precedente è completato o se era già stato completato.
func is_unlocked(index: int) -> bool:
	return index == 0 or stars_of(index - 1) > 0 or stars_of(index) > 0


static func stars_for(moves: int, par: int) -> int:
	if moves <= par:
		return 3
	if moves <= par + 2:
		return 2
	return 1


## Registra il risultato del livello in corso; restituisce le stelle ottenute.
## Con un suggerimento usato, al massimo 2 stelle.
func complete_current(moves: int, used_hint := false) -> int:
	var level := current_level()
	if level.is_empty():
		return 0
	var s := stars_for(moves, level["par"])
	if used_hint:
		s = mini(s, 2)
	if s > _stars.get(level["id"], 0):
		_stars[level["id"]] = s
		_save_progress()
	return s


func reset_progress() -> void:
	_stars.clear()
	_save_progress()


func _load_progress() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) == TYPE_DICTIONARY:
		for k in data:
			_stars[k] = int(data[k])


func _save_progress() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_stars))
