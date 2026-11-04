class_name SceneBackground
extends Node2D
## Lo sfondo: due mondi speculari divisi dallo specchio.
## A sinistra il mondo lilla, a destra quello menta. In basso una scacchiera in
## prospettiva, con il punto di fuga sotto il centro dello specchio; dall'altra
## parte dello specchio i colori del pavimento sono invertiti.

const W := 1280.0
const H := 720.0
const HORIZON := 480.0    # linea dell'orizzonte = altezza del punto di fuga
const VANISH_X := 640.0   # il punto di fuga è sull'asse dello specchio
const TILE := 165.0       # larghezza di una casella sul bordo inferiore dello schermo
const ROWS := 12          # file di caselle verso l'orizzonte
const DEPTH_STEP := 0.55  # quanto si stringono le file allontanandosi

const DOTS := [Vector2(110, 150), Vector2(260, 250), Vector2(430, 160), Vector2(80, 370), Vector2(470, 450)]


func _draw() -> void:
	var mid := W / 2.0
	# muri
	draw_rect(Rect2(0, 0, mid, HORIZON), UIStyle.LILAC)
	draw_rect(Rect2(mid, 0, mid, HORIZON), UIStyle.MINT)
	for p: Vector2 in DOTS: # pois, simmetrici rispetto allo specchio
		draw_circle(p, 6.0, UIStyle.LILAC_DOTS)
		draw_circle(Vector2(W - p.x, p.y), 6.0, UIStyle.MINT_DOTS)

	# pavimento: base e caselle
	draw_rect(Rect2(0, HORIZON, mid, H - HORIZON), UIStyle.WHITE)
	draw_rect(Rect2(mid, HORIZON, mid, H - HORIZON), UIStyle.FLOOR_DARK)
	var depth := H - HORIZON
	var rows: Array[float] = []
	for n in ROWS + 1:
		rows.append(HORIZON + depth / (1.0 + n * DEPTH_STEP))
	for n in ROWS:
		var y0 := rows[n]
		var y1 := rows[n + 1]
		for k in range(-40, 40):
			if (n + k) % 2 != 0:
				continue
			var cell := PackedVector2Array([
				Vector2(_x(k, y0), y0), Vector2(_x(k + 1, y0), y0),
				Vector2(_x(k + 1, y1), y1), Vector2(_x(k, y1), y1)])
			if cell[1].x < -10.0 or cell[0].x > W + 10.0:
				continue
			draw_colored_polygon(cell, UIStyle.LILAC_TILE if k < 0 else UIStyle.MINT_TILE)

	# foschia vicino all'orizzonte e linea dell'orizzonte
	draw_rect(Rect2(0, HORIZON, mid, 40), Color(UIStyle.LILAC, 0.7))
	draw_rect(Rect2(mid, HORIZON, mid, 40), Color(UIStyle.MINT_TILE, 0.22))
	draw_line(Vector2(0, HORIZON), Vector2(W, HORIZON), UIStyle.INK, 3.0)


## Ascissa della linea di casella k all'altezza y: tutte convergono nel punto di fuga.
func _x(k: int, y: float) -> float:
	return VANISH_X + k * TILE * (y - HORIZON) / (H - HORIZON)
