extends SceneTree
## Controlla i livelli di data/levels.json: per ogni livello genera molte equazioni
## e mostra qualche esempio, il par minimo e massimo e il tempo di generazione.
## Utile dopo aver aggiunto o modificato degli schemi.
##
## Da terminale, nella cartella del progetto (su Mac):
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/check_levels.gd

const SAMPLES := 60


func _init() -> void:
	EquationGenerator.reseed()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	for world: Dictionary in data["worlds"]:
		print("== ", world["name"])
		var n := 0
		for level: Dictionary in world["levels"]:
			n += 1
			if level.has("equation"):
				var eq := Equation.new()
				eq.load_equation(level["equation"])
				print("  %d. fisso: %s   (par %d)" % [n, level["equation"], Solver.min_moves(eq)])
				continue
			var pars := []
			var examples := []
			var worst_ms := 0
			var failed := 0
			var specials := 0
			var start := Time.get_ticks_msec()
			for i in SAMPLES:
				var t0 := Time.get_ticks_msec()
				var g := EquationGenerator.generate(level)
				worst_ms = maxi(worst_ms, Time.get_ticks_msec() - t0)
				if g.is_empty():
					failed += 1
					continue
				pars.append(g["par"])
				if examples.size() < 4 and not examples.has(g["equation"]):
					examples.append(g["equation"])
				var eq := Equation.new()
				eq.load_equation(g["equation"])
				var probe := eq
				for k in g["par"] + 2: # gioca la partita col risolutore fino in fondo
					var m := Solver.next_move(probe)
					if m.is_empty():
						break
					Solver.apply(probe, m)
				if probe.get_status() != Equation.Status.SOLVED:
					specials += 1
			var avg := float(Time.get_ticks_msec() - start) / SAMPLES
			print("  %d. par %s-%s   media %.0f ms, peggiore %d ms%s%s" % [
				n, str(pars.min()), str(pars.max()), avg, worst_ms,
				("   FALLITE: %d" % failed) if failed > 0 else "",
				("   casi speciali: %d/%d" % [specials, SAMPLES]) if specials > 0 else ""])
			print("       es.  ", "   |   ".join(examples))
	quit()
