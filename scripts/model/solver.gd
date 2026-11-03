class_name Solver
extends RefCounted
## Trova la strada più corta verso la soluzione, esplorando in ampiezza
## tutte le mosse possibili. Serve al pulsante Suggerimento, ai livelli guidati
## e al calcolo del par (tools/compute_par.gd).
##
## Una mossa è un dizionario: {"type": ..., "a": id, "b": id}
##   type = "across", "flip", "merge", "slice", "hook_coefficient",
##          "hook_divisor", "simplify"
## Le mosse gratuite (semplifica) non contano: nella ricerca si applicano da sole.

const MAX_DEPTH := 8


## La mossa successiva consigliata, oppure {} se l'equazione è già finita
## o la soluzione è troppo lontana.
static func next_move(eq: Equation) -> Dictionary:
	if eq.get_status() != Equation.Status.IN_PROGRESS:
		return {}
	var first: Dictionary = _search(eq).get("first", {})
	if first.get("type") == "simplify_all":
		# la strada migliore comincia semplificando: indichiamo la prima frazione riducibile
		for t in eq.left + eq.right:
			if t.divisor > 1 and Fraction.gcd(t.count, t.divisor) > 1:
				return {"type": "simplify", "a": t.id}
	return first


## Il numero minimo di mosse che contano per il par (-1 se non trovato).
static func min_moves(eq: Equation) -> int:
	return _search(eq).get("depth", -1)


## Applica una mossa a un'equazione.
static func apply(eq: Equation, move: Dictionary) -> Equation.MoveResult:
	var a: int = move.get("a", 0)
	var b: int = move.get("b", 0)
	match move["type"]:
		"across": return eq.move_across(a)
		"flip": return eq.flip_all()
		"merge": return eq.merge(a, b)
		"slice": return eq.slice_common(a, b)
		"hook_coefficient": return eq.hook_coefficient(a)
		"hook_divisor": return eq.hook_divisor(a)
		"simplify": return eq.simplify(a)
	return Equation.MoveResult.UNKNOWN_TERM


## Ricerca in ampiezza. Semplificare è gratis ma NON obbligatorio (altrimenti
## 3x/6 tornerebbe subito x/2 e l'mcm non servirebbe mai): ogni stato viene
## esplorato sia così com'è sia semplificato, alla stessa profondità.
static func _search(eq: Equation) -> Dictionary:
	var start := _clone(eq)
	# Ogni elemento della frontiera: [equazione, prima mossa fatta per arrivarci]
	var frontier: Array = [[start, {}]]
	var seen := {start.to_text(): true}
	var simple := _simplified(start)
	if simple != null:
		frontier.append([simple, {"type": "simplify_all"}])
		seen[simple.to_text()] = true
	for depth in MAX_DEPTH + 1:
		var next: Array = []
		for node in frontier:
			var e: Equation = node[0]
			if e.get_status() != Equation.Status.IN_PROGRESS:
				return {"depth": depth, "first": node[1]}
			for move in _moves(e):
				var c := _clone(e)
				if apply(c, move) != Equation.MoveResult.SUCCESS:
					continue
				var first: Dictionary = node[1] if not node[1].is_empty() else move
				for variant in [c, _simplified(c)]:
					if variant == null:
						continue
					var key: String = variant.to_text()
					if not seen.has(key):
						seen[key] = true
						next.append([variant, first])
		frontier = next
	return {}


## Una copia con tutte le frazioni semplificate, oppure null se non c'era niente da semplificare.
static func _simplified(eq: Equation) -> Equation:
	var c := _clone(eq)
	var changed := false
	for t in c.left + c.right:
		if c.simplify(t.id) == Equation.MoveResult.SUCCESS:
			changed = true
	return c if changed else null


## Tutte le mosse da provare (quelle non valide vengono scartate da `apply`).
## L'ordine conta: a parità di mosse, il suggerimento preferisce le prime della lista
## (prima fondere e affettare, poi spostare, poi agganciare, per ultimo ribaltare).
static func _moves(eq: Equation) -> Array:
	var out: Array = []
	var all := eq.left + eq.right
	for ta in all:
		for tb in all:
			if ta.id == tb.id:
				continue
			if ta.base == tb.base and ta.divisor == tb.divisor:
				out.append({"type": "merge", "a": ta.id, "b": tb.id})
			# mcm: si trascina un denominatore (a) su un altro termine (b)
			if ta.divisor > 1 and ta.divisor != tb.divisor:
				out.append({"type": "slice", "a": ta.id, "b": tb.id})
	for ta in all:
		out.append({"type": "across", "a": ta.id})
	for ta in all:
		if ta.is_x() and ta.count > 1:
			out.append({"type": "hook_coefficient", "a": ta.id})
		if ta.divisor > 1:
			out.append({"type": "hook_divisor", "a": ta.id})
	out.append({"type": "flip"})
	return out


static func _clone(eq: Equation) -> Equation:
	var c := Equation.new()
	c.left = Equation._copy_side(eq.left)
	c.right = Equation._copy_side(eq.right)
	return c
