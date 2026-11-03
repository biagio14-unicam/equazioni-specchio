extends Node
## Test del modello. Apri tests/test_equation.tscn e premi F6 (o F5: è la scena
## principale finché non creiamo il livello). I risultati compaiono nel pannello Output.

var _failures := 0


func _ready() -> void:
	_test_x_both_sides()
	_test_negative_coefficient()
	_test_fractions()
	_test_impossible()
	_test_identity()
	_test_errors_grouping_undo()
	print("")
	if _failures == 0:
		print("Tutti i test superati.")
	else:
		print("%d controlli falliti." % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(cond: bool, label: String) -> void:
	if not cond:
		print("  FALLITO: ", label)
		_failures += 1


func _new_eq(text: String) -> Equation:
	var eq := Equation.new()
	_check(eq.load_equation(text), "carica " + text)
	var ref: WeakRef = weakref(eq) # weakref: evita un ciclo eq -> segnale -> eq
	eq.state_changed.connect(func(): print("    ", ref.get_ref().to_text()))
	print("    ", eq.to_text())
	return eq


func _test_x_both_sides() -> void:
	print("1) x da entrambi i lati")
	var eq := _new_eq("3x - 4 = x + 6") # id: 1=3x 2=-4 | 3=x 4=6
	_check(eq.move_across(3) == Equation.MoveResult.SUCCESS, "x a sinistra")
	_check(eq.move_across(2) == Equation.MoveResult.SUCCESS, "-4 a destra")
	_check(eq.merge(1, 3) == Equation.MoveResult.SUCCESS, "fondi le x")
	_check(eq.merge(4, 2) == Equation.MoveResult.SUCCESS, "fondi le unità")
	_check(eq.hook_coefficient(1) == Equation.MoveResult.SUCCESS, "gancio")
	_check(eq.simplify(4) == Equation.MoveResult.SUCCESS, "semplifica")
	_check(eq.get_status() == Equation.Status.SOLVED, "risolta")
	_check(eq.get_solution().equals(Fraction.new(5)), "x = 5")
	_check(eq.verify(eq.get_solution()), "verifica")
	_check(eq.move_count == 5, "5 mosse (semplifica non conta)")


func _test_negative_coefficient() -> void:
	print("2) coefficiente negativo")
	var eq := _new_eq("5-2x=11") # 1=5 2=-2x | 3=11
	_check(eq.move_across(1) == Equation.MoveResult.SUCCESS, "5 a destra")
	_check(eq.merge(3, 1) == Equation.MoveResult.SUCCESS, "fondi")
	_check(eq.hook_coefficient(2) == Equation.MoveResult.SUCCESS, "gancio")
	_check(eq.simplify(3) == Equation.MoveResult.SUCCESS, "semplifica")
	_check(eq.get_status() == Equation.Status.IN_PROGRESS, "-x = 3 non è ancora risolta")
	_check(eq.flip_all() == Equation.MoveResult.SUCCESS, "ribalta")
	_check(eq.get_status() == Equation.Status.SOLVED, "risolta")
	_check(eq.get_solution().equals(Fraction.new(-3)), "x = -3")
	_check(eq.verify(eq.get_solution()), "verifica")


func _test_fractions() -> void:
	print("3) frazioni")
	var eq := _new_eq("x/2 + x/3 = 5") # 1=x/2 2=x/3 | 3=5
	_check(eq.merge(1, 2) == Equation.MoveResult.DIFFERENT_DIVISOR, "non si fondono tagli diversi")
	_check(eq.slice_common(1, 2) == Equation.MoveResult.SUCCESS, "affetta")
	_check(eq.merge(1, 2) == Equation.MoveResult.SUCCESS, "fondi")
	_check(eq.hook_divisor(1) == Equation.MoveResult.SUCCESS, "gancio dal divisore")
	_check(eq.hook_coefficient(1) == Equation.MoveResult.SUCCESS, "gancio dal disco della x")
	_check(eq.simplify(3) == Equation.MoveResult.SUCCESS, "semplifica")
	_check(eq.get_status() == Equation.Status.SOLVED, "risolta")
	_check(eq.get_solution().equals(Fraction.new(6)), "x = 6")
	_check(eq.verify(eq.get_solution()), "verifica")

	print("3b) stesso denominatore con un intero, e solo dalla stessa parte")
	var e2 := _new_eq("x/3 + 2 = 4") # 1=x/3 2=2 | 3=4
	_check(e2.slice_common(1, 3) == Equation.MoveResult.DIFFERENT_SIDES, "non attraverso lo specchio")
	_check(e2.slice_common(2, 1) == Equation.MoveResult.SUCCESS, "il 2 diventa 6/3")
	_check(e2.to_text() == "x/3 + 6/3 = 4", "testo dopo l'mcm")

	print("3c) il risolutore trova la mossa successiva")
	var e3 := Equation.new()
	e3.load_equation("x/2 + x/3 = 5")
	_check(Solver.min_moves(e3) == 4, "par 4")
	_check(Solver.next_move(e3).get("type") == "slice", "prima mossa: stesso denominatore")
	var e4 := Equation.new()
	e4.load_equation("4x = 2")
	e4.hook_coefficient(1)
	_check(Solver.next_move(e4).get("type") == "simplify", "dopo il gancio: semplifica")


func _test_impossible() -> void:
	print("4) impossibile")
	var eq := _new_eq("2x+3=2x+5") # 1=2x 2=3 | 3=2x 4=5
	eq.move_across(3)
	eq.move_across(2)
	_check(eq.merge(1, 3) == Equation.MoveResult.SUCCESS, "le x si annullano")
	_check(eq.merge(4, 2) == Equation.MoveResult.SUCCESS, "fondi le unità")
	_check(eq.get_status() == Equation.Status.IMPOSSIBLE, "impossibile")


func _test_identity() -> void:
	print("5) indeterminata")
	var eq := _new_eq("2x+3=2x+3")
	eq.move_across(3)
	eq.move_across(2)
	eq.merge(1, 3)
	eq.merge(4, 2)
	_check(eq.get_status() == Equation.Status.IDENTITY, "indeterminata")


func _test_errors_grouping_undo() -> void:
	print("6) errori, raggruppamento e undo")
	var eq := Equation.new()
	_check(eq.load_equation("2x + 3 = 7"), "carica") # 1=2x 2=3 | 3=7
	_check(eq.merge(2, 3) == Equation.MoveResult.DIFFERENT_SIDES, "lati diversi")
	_check(eq.merge(1, 2) == Equation.MoveResult.DIFFERENT_BASE, "basi diverse")
	_check(eq.merge(1, 1) == Equation.MoveResult.SAME_TERM, "stesso pezzo")
	_check(eq.hook_divisor(1) == Equation.MoveResult.NOTHING_TO_HOOK, "niente da agganciare")
	_check(eq.group(1) == Equation.MoveResult.NOT_GROUPABLE, "le x sono già raggruppate")
	_check(eq.group(3) == Equation.MoveResult.SUCCESS, "raggruppa")
	_check(eq.get_term(3).grouped, "è raggruppato")
	_check(eq.ungroup(3) == Equation.MoveResult.SUCCESS, "sgancia")
	_check(eq.move_count == 0, "raggruppa/sgancia non contano")
	_check(eq.move_across(2) == Equation.MoveResult.SUCCESS, "sposta")
	_check(not eq.is_on_left(2), "ora sta a destra")
	_check(eq.move_count == 1, "una mossa")
	_check(eq.undo(), "annulla")
	_check(eq.move_count == 0, "mosse ripristinate")
	_check(eq.to_text() == "2x + 3 = 7", "stato ripristinato")
	_check(not eq.load_equation("2x + = 7"), "rifiuta 2x + = 7")
	_check(not eq.load_equation("2x + 3"), "rifiuta senza uguale")
	_check(not eq.load_equation("x/0 = 1"), "rifiuta divisore zero")
	print("    ok")
