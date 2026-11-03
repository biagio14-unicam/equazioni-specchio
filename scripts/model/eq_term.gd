class_name EqTerm
extends RefCounted
## Un pezzo del puzzle.
##
## - base:     UNIT (quadratino) oppure X (incognita)
## - negative: il segno vive SULLA BASE (base cava = negativo)
## - count:    quantità, sempre >= 1. Per X è il disco agganciato (anche da 1);
##             per UNIT sciolte è il numero di quadratini, per UNIT raggruppate
##             è il disco agganciato all'unità.
## - divisor:  disco sotto la barra di frazione (1 = nessuna frazione)
## - grouped:  solo per UNIT: sciolte (false) o raggruppate (true). X sempre true.
## - id:       identificativo stabile: resta lo stesso dopo spostamenti e fusioni,
##             così la grafica può animare il pezzo invece di ridisegnarlo.

enum Base { UNIT, X }

var id: int = 0
var base: Base = Base.UNIT
var negative: bool = false
var count: int = 1
var divisor: int = 1
var grouped: bool = false


func is_x() -> bool:
	return base == Base.X


func signed_count() -> int:
	return -count if negative else count


func value() -> Fraction:
	return Fraction.new(signed_count(), divisor)


func copy() -> EqTerm:
	var t := EqTerm.new()
	t.id = id
	t.base = base
	t.negative = negative
	t.count = count
	t.divisor = divisor
	t.grouped = grouped
	return t


func _to_string() -> String:
	return "[%d %s%s%s%s%s]" % [
		id,
		"-" if negative else "+",
		str(count),
		"x" if is_x() else "",
		("/" + str(divisor)) if divisor != 1 else "",
		" gruppo" if grouped and not is_x() else "",
	]
