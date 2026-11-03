class_name Fraction
extends RefCounted
## Frazione esatta: niente float, quindi niente 0.3333...
## Viene sempre ridotta ai minimi termini, con il denominatore positivo.

var num: int = 0
var den: int = 1


func _init(n: int = 0, d: int = 1) -> void:
	num = n
	den = d
	if den == 0:
		push_error("Fraction: denominatore zero")
		num = 0
		den = 1
	if den < 0:
		num = -num
		den = -den
	var g := gcd(num, den)
	if g > 1:
		@warning_ignore("integer_division")
		num /= g
		@warning_ignore("integer_division")
		den /= g


static func gcd(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := a % b
		a = b
		b = t
	return a


static func lcm(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	return absi(a) / gcd(a, b) * absi(b)


func add(other: Fraction) -> Fraction:
	return Fraction.new(num * other.den + other.num * den, den * other.den)


func mul(other: Fraction) -> Fraction:
	return Fraction.new(num * other.num, den * other.den)


func equals(other: Fraction) -> bool:
	return num == other.num and den == other.den


func _to_string() -> String:
	return str(num) if den == 1 else "%d/%d" % [num, den]
