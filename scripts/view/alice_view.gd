class_name AliceView
extends Node2D
## Una delle due Alice, in piedi sulla scacchiera. L'origine è il centro del bordo
## inferiore dell'immagine. Respira piano e cambia espressione.
##
## Espressioni: "normale", "pensa", "sorpresa", "felice"
## (immagini in assets/alice/alice_<lato>_<espressione>.png).

const EXPRESSIONS := ["normale", "pensa", "sorpresa", "felice"]
const DISPLAY_SCALE := 0.4  # le immagini sono a doppia risoluzione

var side := "sinistra"      # "sinistra" o "destra"
var _sprite := Sprite2D.new()
var _textures := {}
var _base := "normale"      # espressione a cui torna dopo una reazione
var _serial := 0
var _reacting := false      # durante una reazione l'espressione di base aspetta
var _rest_y := 0.0
var _hop_tween: Tween


func _init(side_: String = "sinistra") -> void:
	side = side_
	for e in EXPRESSIONS:
		_textures[e] = load("res://assets/alice/alice_%s_%s.png" % [side, e])
	_sprite.texture = _textures["normale"]
	_sprite.centered = false
	_sprite.scale = Vector2(DISPLAY_SCALE, DISPLAY_SCALE)
	var size: Vector2 = _sprite.texture.get_size() * DISPLAY_SCALE
	_sprite.position = Vector2(-size.x / 2.0, -size.y)
	_rest_y = _sprite.position.y
	add_child(_sprite)


func _ready() -> void:
	# respiro: un'oscillazione leggerissima, sfasata tra le due Alice
	var tw := create_tween().set_loops()
	tw.tween_interval(0.0 if side == "sinistra" else 0.9)
	tw.tween_property(self, "scale", Vector2(1.0, 1.015), 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2.ONE, 1.2).set_trans(Tween.TRANS_SINE)


## Espressione di base (quella che resta).
func set_mood(expression: String) -> void:
	_base = expression
	if not _reacting:
		_show(expression)


## Reazione breve: dopo `seconds` torna all'espressione di base.
func react(expression: String, seconds := 1.2) -> void:
	_serial += 1
	var serial := _serial
	_reacting = true
	_show(expression)
	_hop()
	await get_tree().create_timer(seconds).timeout
	if serial == _serial:
		_reacting = false
		_show(_base)


func _show(expression: String) -> void:
	if _textures.has(expression):
		_sprite.texture = _textures[expression]


func _hop() -> void:
	if _hop_tween != null and _hop_tween.is_valid():
		_hop_tween.kill()
	_hop_tween = create_tween()
	_hop_tween.tween_property(_sprite, "position:y", _rest_y - 12.0, 0.1).set_ease(Tween.EASE_OUT)
	_hop_tween.tween_property(_sprite, "position:y", _rest_y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
