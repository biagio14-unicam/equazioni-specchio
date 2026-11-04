class_name Equation
extends RefCounted
## Modello dell'equazione e mosse del gioco.
## Non disegna nulla: la grafica legge `left` e `right` a ogni `state_changed`.
##
## Uso:
##     var eq := Equation.new()
##     eq.state_changed.connect(_ridisegna)
##     eq.load_equation("3x - 4 = x + 6")
##     eq.move_across(id_del_pezzo)

signal state_changed

enum MoveResult {
	SUCCESS,
	UNKNOWN_TERM,      ## id inesistente
	SAME_TERM,         ## stesso pezzo passato due volte
	DIFFERENT_SIDES,   ## fondi: i pezzi stanno da parti diverse dello specchio
	DIFFERENT_BASE,    ## fondi: una x con un'unità
	DIFFERENT_DIVISOR, ## fondi: frazioni con taglio diverso (serve "affetta")
	SAME_DIVISOR,      ## affetta: hanno già lo stesso taglio
	NOT_GROUPABLE,     ## raggruppa/sgancia su un pezzo non adatto
	NOTHING_TO_HOOK,   ## gancio: non c'è un disco da spostare
	NOT_REDUCIBLE,     ## semplifica: la frazione è già ridotta
	NOTHING_TO_FLIP,   ## ribalta: equazione vuota
	SAME_SIDE,         ## elimina: i due pezzi stanno dalla stessa parte
	NOT_TWINS,         ## elimina: i due pezzi non sono identici
}

enum Status {
	IN_PROGRESS,
	SOLVED,     ## x piena con disco 1 da una parte, solo unità dall'altra
	IMPOSSIBLE, ## le x sono sparite e i membri sono diversi (es. 0 = 2)
	IDENTITY,   ## le x sono sparite e i membri sono uguali (es. 0 = 0)
}

const DIGITS := "0123456789"

var left: Array[EqTerm] = []
var right: Array[EqTerm] = []
var move_count: int = 0

var _initial_left: Array[EqTerm] = []
var _initial_right: Array[EqTerm] = []
var _history: Array = [] # elementi: [copia di left, copia di right, move_count]
var keep_history := true  # il risolutore lo spegne sulle sue copie: va molto più veloce
var _next_id: int = 1


# ============================================================ caricamento

## Formato: "3x-4=x+6", "x/2+x/3=5", "5-2x=11". Spazi ignorati.
func load_equation(text: String) -> bool:
	var s := ""
	for c in text.to_lower():
		if c != " " and c != "\t" and c != "\n":
			s += c
	var parts := s.split("=")
	if parts.size() != 2:
		return false
	_next_id = 1
	var new_left: Array[EqTerm] = []
	var new_right: Array[EqTerm] = []
	if not _parse_side(parts[0], new_left) or not _parse_side(parts[1], new_right):
		return false
	left = new_left
	right = new_right
	_initial_left = _copy_side(left)
	_initial_right = _copy_side(right)
	_history.clear()
	move_count = 0
	state_changed.emit()
	return true


func _parse_side(s: String, out: Array[EqTerm]) -> bool:
	if s.is_empty():
		return false
	var i := 0
	var n := s.length()
	while i < n:
		var neg := false
		if s[i] == "+" or s[i] == "-":
			neg = s[i] == "-"
			i += 1
		var start := i
		while i < n and DIGITS.contains(s[i]):
			i += 1
		var amount := -1
		if i > start:
			amount = s.substr(start, i - start).to_int()
		var with_x := false
		if i < n and s[i] == "x":
			with_x = true
			i += 1
		if amount < 0 and not with_x:
			return false # segno senza nulla dopo, o carattere non valido
		if amount < 0:
			amount = 1 # "x" = "1x"
		var div := 1
		if i < n and s[i] == "/":
			i += 1
			var d_start := i
			while i < n and DIGITS.contains(s[i]):
				i += 1
			if i == d_start:
				return false
			div = s.substr(d_start, i - d_start).to_int()
			if div == 0:
				return false
		if i < n and s[i] != "+" and s[i] != "-":
			return false
		if amount == 0:
			continue # "0" = membro vuoto
		var t := EqTerm.new()
		t.id = _next_id
		_next_id += 1
		t.base = EqTerm.Base.X if with_x else EqTerm.Base.UNIT
		t.negative = neg
		t.count = amount
		t.divisor = div
		t.grouped = with_x # le unità partono sciolte
		out.append(t)
	return true


# ============================================================ mosse (contano per il par)

## Specchio: il pezzo cambia lato e la sua base si inverte.
func move_across(id: int) -> MoveResult:
	var f := _find(id)
	if f.is_empty():
		return MoveResult.UNKNOWN_TERM
	_push_history(true)
	var t: EqTerm = f["term"]
	var side: Array = f["side"]
	side.erase(t)
	t.negative = not t.negative
	_other_side(side).append(t)
	return _done()


## Doppio tocco sullo specchio: si invertono tutte le basi.
func flip_all() -> MoveResult:
	if left.is_empty() and right.is_empty():
		return MoveResult.NOTHING_TO_FLIP
	_push_history(true)
	for t in _all_terms():
		t.negative = not t.negative
	return _done()


## Fondi (anche "assorbi"): stessa parte, stessa base, stesso divisore.
## Il risultato tiene l'id di `a`; pieni e cavi uguali si annullano e spariscono.
func merge(a: int, b: int) -> MoveResult:
	var fa := _find(a)
	var fb := _find(b)
	if fa.is_empty() or fb.is_empty():
		return MoveResult.UNKNOWN_TERM
	if a == b:
		return MoveResult.SAME_TERM
	if not is_same(fa["side"], fb["side"]):
		return MoveResult.DIFFERENT_SIDES
	var ta: EqTerm = fa["term"]
	var tb: EqTerm = fb["term"]
	if ta.base != tb.base:
		return MoveResult.DIFFERENT_BASE
	if ta.divisor != tb.divisor:
		return MoveResult.DIFFERENT_DIVISOR
	_push_history(true)
	var total := ta.signed_count() + tb.signed_count()
	var side: Array = fa["side"]
	side.erase(tb)
	if total == 0:
		side.erase(ta)
	else:
		ta.negative = total < 0
		ta.count = absi(total)
		ta.grouped = ta.grouped or tb.grouped # sciolte su gruppo = assorbi
	return _done()


## Elimina i gemelli: lo stesso pezzo (stessa base, stesso segno, stesso valore)
## da tutte e due le parti dello specchio sparisce da entrambe.
## È come sottrarre (o sommare) lo stesso termine ai due membri.
func cancel(a: int, b: int) -> MoveResult:
	var fa := _find(a)
	var fb := _find(b)
	if fa.is_empty() or fb.is_empty():
		return MoveResult.UNKNOWN_TERM
	if a == b:
		return MoveResult.SAME_TERM
	if is_same(fa["side"], fb["side"]):
		return MoveResult.SAME_SIDE
	if not are_twins(fa["term"], fb["term"]):
		return MoveResult.NOT_TWINS
	_push_history(true)
	fa["side"].erase(fa["term"])
	fb["side"].erase(fb["term"])
	return _done()


## Due pezzi identici: stessa base, stesso segno, stesso valore
## (sciolti o raggruppati non importa: è solo il modo di disegnarli).
static func are_twins(ta: EqTerm, tb: EqTerm) -> bool:
	return ta.base == tb.base and ta.negative == tb.negative \
		and ta.count == tb.count and ta.divisor == tb.divisor


## Affetta: porta due frazioni allo stesso divisore (mcm).
func slice_common(a: int, b: int) -> MoveResult:
	var fa := _find(a)
	var fb := _find(b)
	if fa.is_empty() or fb.is_empty():
		return MoveResult.UNKNOWN_TERM
	if a == b:
		return MoveResult.SAME_TERM
	if not is_same(fa["side"], fb["side"]):
		return MoveResult.DIFFERENT_SIDES
	var ta: EqTerm = fa["term"]
	var tb: EqTerm = fb["term"]
	if ta.divisor == tb.divisor:
		return MoveResult.SAME_DIVISOR
	_push_history(true)
	var l := Fraction.lcm(ta.divisor, tb.divisor)
	@warning_ignore("integer_division")
	ta.count *= l / ta.divisor
	ta.divisor = l
	@warning_ignore("integer_division")
	tb.count *= l / tb.divisor
	tb.divisor = l
	return _done()


## Gancio dal disco della x: sulla x resta il disco da 1 e
## TUTTI gli altri termini, su entrambi i lati, finiscono divisi per quel disco.
func hook_coefficient(id: int) -> MoveResult:
	var f := _find(id)
	if f.is_empty():
		return MoveResult.UNKNOWN_TERM
	var t: EqTerm = f["term"]
	if not t.is_x() or t.count <= 1:
		return MoveResult.NOTHING_TO_HOOK
	_push_history(true)
	var k := t.count
	t.count = 1
	for o in _all_terms():
		if o != t:
			o.divisor *= k
	return _done()


## Gancio dal divisore: il disco sotto la barra moltiplica tutti gli altri termini.
## Se un termine ha già quel divisore sotto la barra, si cancella lì.
func hook_divisor(id: int) -> MoveResult:
	var f := _find(id)
	if f.is_empty():
		return MoveResult.UNKNOWN_TERM
	var t: EqTerm = f["term"]
	if t.divisor <= 1:
		return MoveResult.NOTHING_TO_HOOK
	_push_history(true)
	var d := t.divisor
	t.divisor = 1
	for o in _all_terms():
		if o == t:
			continue
		if o.divisor % d == 0:
			@warning_ignore("integer_division")
			o.divisor /= d
		else:
			o.count *= d
	return _done()


# ============================================================ riordino (NON contano per il par)

## Raggruppa: unità sciolte -> unità + disco.
func group(id: int) -> MoveResult:
	var f := _find(id)
	if f.is_empty():
		return MoveResult.UNKNOWN_TERM
	var t: EqTerm = f["term"]
	if t.is_x() or t.grouped:
		return MoveResult.NOT_GROUPABLE
	_push_history(false)
	t.grouped = true
	return _done()


## Sgancia: unità + disco -> unità sciolte.
func ungroup(id: int) -> MoveResult:
	var f := _find(id)
	if f.is_empty():
		return MoveResult.UNKNOWN_TERM
	var t: EqTerm = f["term"]
	if t.is_x() or not t.grouped:
		return MoveResult.NOT_GROUPABLE
	_push_history(false)
	t.grouped = false
	return _done()


## Semplifica: 10/2 -> 5.
func simplify(id: int) -> MoveResult:
	var f := _find(id)
	if f.is_empty():
		return MoveResult.UNKNOWN_TERM
	var t: EqTerm = f["term"]
	var g := Fraction.gcd(t.count, t.divisor)
	if t.divisor == 1 or g == 1:
		return MoveResult.NOT_REDUCIBLE
	_push_history(false)
	@warning_ignore("integer_division")
	t.count /= g
	@warning_ignore("integer_division")
	t.divisor /= g
	return _done()


func undo() -> bool:
	if _history.is_empty():
		return false
	var h: Array = _history.pop_back()
	left = h[0]
	right = h[1]
	move_count = h[2]
	state_changed.emit()
	return true


# ============================================================ stato

func get_status() -> Status:
	if not _has_x(left) and not _has_x(right):
		if _sum_units(left).equals(_sum_units(right)):
			return Status.IDENTITY
		return Status.IMPOSSIBLE
	if (_is_lone_x(left) and _is_constant(right)) or (_is_lone_x(right) and _is_constant(left)):
		return Status.SOLVED
	return Status.IN_PROGRESS


## Valida solo se get_status() == Status.SOLVED.
func get_solution() -> Fraction:
	return _sum_units(right) if _is_lone_x(left) else _sum_units(left)


## Sostituisce x nell'equazione INIZIALE e controlla che i membri coincidano.
func verify(x: Fraction) -> bool:
	return _eval(_initial_left, x).equals(_eval(_initial_right, x))


## Il pezzo con quell'id, oppure null.
func get_term(id: int) -> EqTerm:
	var f := _find(id)
	return null if f.is_empty() else f["term"]


## true se il pezzo sta a sinistra dello specchio.
func is_on_left(id: int) -> bool:
	var f := _find(id)
	return not f.is_empty() and is_same(f["side"], left)


func to_text() -> String:
	return _side_text(left) + " = " + _side_text(right)


# ============================================================ utilità interne

func _done() -> MoveResult:
	state_changed.emit()
	return MoveResult.SUCCESS


func _push_history(counts_as_move: bool) -> void:
	if keep_history:
		_history.append([_copy_side(left), _copy_side(right), move_count])
	if counts_as_move:
		move_count += 1


func _find(id: int) -> Dictionary:
	for side in [left, right]:
		for t in side:
			if t.id == id:
				return {"term": t, "side": side}
	return {}


func _other_side(side: Array) -> Array[EqTerm]:
	return right if is_same(side, left) else left


func _all_terms() -> Array[EqTerm]:
	var out: Array[EqTerm] = []
	out.append_array(left)
	out.append_array(right)
	return out


static func _copy_side(side: Array[EqTerm]) -> Array[EqTerm]:
	var out: Array[EqTerm] = []
	for t in side:
		out.append(t.copy())
	return out


static func _has_x(side: Array[EqTerm]) -> bool:
	for t in side:
		if t.is_x():
			return true
	return false


static func _sum_units(side: Array[EqTerm]) -> Fraction:
	var s := Fraction.new()
	for t in side:
		if not t.is_x():
			s = s.add(t.value())
	return s


static func _eval(side: Array[EqTerm], x: Fraction) -> Fraction:
	var s := Fraction.new()
	for t in side:
		s = s.add(t.value().mul(x) if t.is_x() else t.value())
	return s


static func _is_lone_x(side: Array[EqTerm]) -> bool:
	if side.size() != 1:
		return false
	var t := side[0]
	return t.is_x() and not t.negative and t.count == 1 and t.divisor == 1


static func _is_constant(side: Array[EqTerm]) -> bool:
	if side.is_empty():
		return true # x = 0
	if side.size() != 1:
		return false
	var t := side[0]
	return not t.is_x() and Fraction.gcd(t.count, t.divisor) == 1


static func _side_text(side: Array[EqTerm]) -> String:
	if side.is_empty():
		return "0"
	var out := ""
	for i in side.size():
		var t := side[i]
		if i == 0:
			if t.negative:
				out += "-"
		else:
			out += " - " if t.negative else " + "
		if t.is_x():
			if t.count != 1:
				out += str(t.count)
			out += "x"
		else:
			out += str(t.count)
		if t.divisor != 1:
			out += "/" + str(t.divisor)
	return out
