class_name EquationGenerator
extends RefCounted
## Genera equazioni casuali a partire da uno SCHEMA con lettere al posto dei numeri.
##
##   "x + A = B"      "Ax + B = C"      "B - Ax = C/D"      "x/A + x/B = C"
##
## Ogni lettera maiuscola è un numero intero positivo; il segno lo dà lo schema.
## Una lettera ripetuta vale lo stesso numero ovunque ("Ax + B = Ax + C" è impossibile).
## Il valore dipende dal ruolo della lettera:
##   coefficiente della x  ->  da 2 a max_coef   (default 6)
##   termine noto          ->  da 1 a max_const  (default 12)
##   denominatore          ->  da 2 a max_den    (default 6)
##
## Come funziona: si sceglie PRIMA la soluzione, poi si estraggono tutte le lettere
## tranne l'ultimo termine noto, che viene ricavato perché l'equazione abbia proprio
## quella soluzione. Se i numeri non vanno bene (non interi, troppo grandi...) si riprova.
##
## Le opzioni (tutte facoltative) arrivano dal livello in data/levels.json:
##   "solution": [min, max]   intervallo della soluzione (default [-9, 9], mai 0)
##   "fraction": true         soluzione anche frazionaria (es. 7/3)
##   "distinct": ["A", "B"]   lettere che devono avere valori diversi
##   "min_par": 3             scarta le equazioni che si risolvono in meno mosse
##   "max_coef", "max_const", "max_den"   gli intervalli qui sopra

const MAX_TRIES := 400
const MAX_FREE := 24        # valore massimo della lettera ricavata
const SEARCH_DEPTH := 7     # oltre questo numero di mosse l'equazione è troppo lunga

static var _rng := RandomNumberGenerator.new()


## Nuovo seme dall'orologio: ogni partita è diversa.
static func reseed() -> void:
	_rng.seed = hash(Time.get_unix_time_from_system() * 1000003.0 + Time.get_ticks_usec())


## Restituisce {"equation": testo, "par": mosse minime}, oppure {} se lo schema non funziona.
## `level` è il dizionario del livello: "patterns" (lista di schemi) più le opzioni.
static func generate(level: Dictionary) -> Dictionary:
	var patterns: Array = level.get("patterns", [])
	if patterns.is_empty():
		return {}
	for attempt in MAX_TRIES:
		var pattern: String = patterns[_rng.randi() % patterns.size()]
		var text := _try(pattern, level)
		if text == "":
			continue
		var eq := Equation.new()
		if not eq.load_equation(text) or eq.get_status() != Equation.Status.IN_PROGRESS:
			continue
		var par := Solver.min_moves(eq, SEARCH_DEPTH)
		if par < int(level.get("min_par", 1)):
			continue
		return {"equation": text, "par": par}
	push_error("Nessuna equazione valida per gli schemi " + str(patterns))
	return {}


## Un tentativo: testo dell'equazione, oppure "" se i numeri estratti non vanno bene.
static func _try(pattern: String, level: Dictionary) -> String:
	var terms := _parse(pattern)
	if terms.is_empty():
		return ""
	var roles := _roles(terms)
	var free := _free_letter(terms)

	# 1. valori casuali per tutte le lettere tranne quella da ricavare
	var values := {}
	for letter in roles:
		if letter == free:
			continue
		match roles[letter]:
			"coef": values[letter] = _rng.randi_range(2, int(level.get("max_coef", 6)))
			"den": values[letter] = _rng.randi_range(2, int(level.get("max_den", 6)))
			_: values[letter] = _rng.randi_range(1, int(level.get("max_const", 12)))

	# 2. la soluzione
	var x0 := _random_solution(level)

	# 3. la lettera libera: (sinistra - destra) deve fare zero
	if free != "":
		var rest := Fraction.new(0)
		var free_term: Dictionary = {}
		for t in terms:
			if t["num"] == free:
				free_term = t
				continue
			rest = rest.add(_value(t, values, x0))
		# il termine libero vale side*sign*F/den: deve essere -rest
		var s: int = free_term["side"] * free_term["sign"]
		var den := _resolve(free_term["den"], values)
		var f := Fraction.new(-rest.num * den * s, rest.den)
		if f.den != 1 or f.num < 1 or f.num > MAX_FREE:
			return ""
		values[free] = f.num

	# 4. lettere che devono essere diverse
	var distinct: Array = level.get("distinct", [])
	for i in distinct.size():
		for j in range(i + 1, distinct.size()):
			if values.get(distinct[i]) == values.get(distinct[j]):
				return ""

	# 5. niente frazioni finte (12/2, 4x/2): il numeratore non deve essere un multiplo del denominatore
	var x_coef := Fraction.new(0)
	for t in terms:
		var den := _resolve(t["den"], values)
		if den > 1 and _resolve(t["num"], values) % den == 0:
			return ""
		if t["x"]:
			x_coef = x_coef.add(_value(t, values, Fraction.new(1)))
	# 6. se lo schema prevede una soluzione, la x non deve sparire per caso (A = C in Ax + B = Cx + D)
	if free != "" and x_coef.num == 0:
		return ""

	# 7. il testo, controllando che la soluzione sia proprio x0 (se c'è la x)
	var text := _substitute(terms, values)
	if free != "":
		var eq := Equation.new()
		if not eq.load_equation(text) or not eq.verify(x0):
			return ""
	return text


## Soluzione casuale: intera e diversa da zero, oppure una frazione p/q non intera.
static func _random_solution(level: Dictionary) -> Fraction:
	var range_: Array = level.get("solution", [-9, 9])
	var lo := int(range_[0])
	var hi := int(range_[1])
	if level.get("fraction", false) and _rng.randf() < 0.6:
		var q := _rng.randi_range(2, 4)
		var p := 0
		while p == 0 or p % q == 0:
			p = _rng.randi_range(lo, hi)
		return Fraction.new(p, q)
	var x := 0
	while x == 0:
		x = _rng.randi_range(lo, hi)
	return Fraction.new(x)


## Valore di un termine (con il segno del suo lato) per x = x0.
static func _value(t: Dictionary, values: Dictionary, x0: Fraction) -> Fraction:
	var v := Fraction.new(t["side"] * t["sign"] * _resolve(t["num"], values), _resolve(t["den"], values))
	return v.mul(x0) if t["x"] else v


## Una lettera diventa il suo valore, un numero resta com'è.
static func _resolve(token: String, values: Dictionary) -> int:
	return int(values[token]) if values.has(token) else token.to_int()


## Lo schema diviso in termini: {side: +1 sinistra / -1 destra, sign, num, x, den}.
## num e den sono testi: una lettera, delle cifre, oppure "1".
static func _parse(pattern: String) -> Array:
	var s := pattern.replace(" ", "")
	var halves := s.split("=")
	if halves.size() != 2:
		return []
	var out: Array = []
	for h in 2:
		var part: String = halves[h]
		var i := 0
		while i < part.length():
			var t := {"side": 1 if h == 0 else -1, "sign": 1, "num": "1", "x": false, "den": "1"}
			if part[i] == "+" or part[i] == "-":
				t["sign"] = -1 if part[i] == "-" else 1
				i += 1
			var tok := _read_token(part, i)
			if tok != "":
				t["num"] = tok
				i += tok.length()
			if i < part.length() and part[i] == "x":
				t["x"] = true
				i += 1
			if i < part.length() and part[i] == "/":
				var d := _read_token(part, i + 1)
				t["den"] = d
				i += 1 + d.length()
			out.append(t)
	return out


## Una lettera maiuscola oppure una sequenza di cifre, a partire da i.
static func _read_token(s: String, i: int) -> String:
	if i >= s.length():
		return ""
	if s[i] >= "A" and s[i] <= "Z":
		return s[i]
	var j := i
	while j < s.length() and s[j] >= "0" and s[j] <= "9":
		j += 1
	return s.substr(i, j - i)


static func _is_letter(token: String) -> bool:
	return token.length() == 1 and token >= "A" and token <= "Z"


## Il ruolo di ogni lettera: "coef" (moltiplica la x), "const" (termine noto), "den".
static func _roles(terms: Array) -> Dictionary:
	var roles := {}
	for t in terms:
		if _is_letter(t["num"]) and not roles.has(t["num"]):
			roles[t["num"]] = "coef" if t["x"] else "const"
		if _is_letter(t["den"]) and not roles.has(t["den"]):
			roles[t["den"]] = "den"
	return roles


## La lettera da ricavare: l'ultimo termine noto (senza x) la cui lettera compare una volta sola.
## "" se non c'è (per esempio nei casi speciali, dove la x sparisce).
static func _free_letter(terms: Array) -> String:
	var count := {}
	for t in terms:
		for token in [t["num"], t["den"]]:
			if _is_letter(token):
				count[token] = count.get(token, 0) + 1
	if _x_cancels(terms): # le x spariscono: non c'è una soluzione da imporre
		return ""
	for i in range(terms.size() - 1, -1, -1):
		var t: Dictionary = terms[i]
		if not t["x"] and _is_letter(t["num"]) and count[t["num"]] == 1:
			return t["num"]
	return ""


## true se le x si annullano per costruzione (stessa lettera dalle due parti, es. Ax ... = Ax ...).
static func _x_cancels(terms: Array) -> bool:
	var balance := {}
	for t in terms:
		if t["x"]:
			var key: String = t["num"] + "/" + t["den"]
			balance[key] = balance.get(key, 0) + t["side"] * t["sign"]
	for k in balance:
		if balance[k] != 0:
			return false
	return true


static func _substitute(terms: Array, values: Dictionary) -> String:
	var sides := ["", ""]
	for t in terms:
		var h := 0 if t["side"] == 1 else 1
		var piece := ""
		var num := _resolve(t["num"], values)
		if sides[h] == "":
			piece = "-" if t["sign"] < 0 else ""
		else:
			piece = " - " if t["sign"] < 0 else " + "
		if t["x"]:
			piece += ("" if num == 1 else str(num)) + "x"
		else:
			piece += str(num)
		var den := _resolve(t["den"], values)
		if den != 1:
			piece += "/" + str(den)
		sides[h] += piece
	return sides[0] + " = " + sides[1]
