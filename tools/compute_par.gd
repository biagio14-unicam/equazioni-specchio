extends SceneTree
## Calcola il par (numero minimo di mosse) di ogni livello in data/levels.json
## e segnala quelli in cui il valore nel file è diverso.
##
## Da terminale, nella cartella del progetto (su Mac):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/compute_par.gd


func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for world: Dictionary in data["worlds"]:
		print("== ", world["name"])
		for level: Dictionary in world["levels"]:
			var eq := Equation.new()
			var best := Solver.min_moves(eq) if eq.load_equation(level["equation"]) else -1
			var flag := "" if best == int(level["par"]) else "   <-- nel file: %d" % int(level["par"])
			print("  %-20s par %s%s" % [level["equation"], str(best) if best >= 0 else "?", flag])
	quit()
