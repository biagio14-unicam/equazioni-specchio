# Equazioni allo specchio

Puzzle game educativo 2D sulle equazioni di primo grado, fatto con Godot 4.3 in GDScript.
Pensato per il web (GitHub Pages), giocabile con mouse, dito o penna della LIM.

## Struttura

```
equazioni-specchio/
├── project.godot              renderer Compatibility, autoload Game, scena principale
├── data/levels.json           i livelli: mondi, equazioni, par, introduzioni
├── scripts/
│   ├── game.gd                autoload "Game": livelli, livello in corso, salvataggio
│   ├── model/                 la logica, NON disegna nulla
│   │   ├── fraction.gd        Fraction: frazioni esatte
│   │   ├── eq_term.gd         EqTerm: un pezzo del puzzle
│   │   ├── equation.gd        Equation: parser, mosse, annulla, stato
│   │   └── solver.gd          Solver: mossa migliore (suggerimento) e par
│   └── view/
│       ├── term_view.gd       TermView: disegna un pezzo, evidenziazione
│       └── stars_view.gd      StarsView: le tre stelle
├── scenes/
│   ├── level_select.*         selezione dei livelli
│   ├── level.*                il livello: specchio, gesti, animazioni, pannelli
│   └── term_preview.*         anteprima di tutti i tipi di pezzo
├── tests/test_equation.*      test del modello e del risolutore
└── tools/compute_par.gd       calcola il par di ogni livello
```

## Gesti

| gesto | effetto |
|---|---|
| trascina un pezzo oltre lo specchio | cambia lato, base invertita |
| trascina un pezzo su un altro (stessa parte) | si fondono |
| trascina il disco della x oltre lo specchio | gancio: divide tutto il resto |
| trascina il denominatore oltre lo specchio | gancio: moltiplica tutto il resto |
| trascina il denominatore su un altro termine (stessa parte) | stesso denominatore (mcm) |
| doppio clic / doppio tocco su un pezzo | semplifica, oppure raggruppa/sgancia le unità |
| doppio clic / doppio tocco sullo specchio | ribalta tutti i pezzi |

## Livelli

Ogni livello in `data/levels.json`:

```json
{ "equation": "2x + 3 = 7", "par": 3 }
```

Campi facoltativi: `"guided": true` (suggerimento sempre visibile),
`"intro_title"` e `"intro"` (riquadro iniziale che spiega la mossa nuova).
Un mondo con `"tutorial": true` compare come "Tutorial" e non ha numero.

Stelle: 3 entro il par, 2 entro par + 2, 1 altrimenti; con il pulsante
Suggerimento al massimo 2.

Per controllare i par, da terminale nella cartella del progetto:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/compute_par.gd
```

## Test

Apri `tests/test_equation.tscn` ed eseguila con ⌘+R: nel pannello Output
deve comparire `Tutti i test superati.`
