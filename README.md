# Equalicey · Equazioni allo specchio

Puzzle game educativo 2D sulle equazioni di primo grado, fatto con Godot 4.3 in GDScript.
Pensato per il web (GitHub Pages), giocabile con mouse, dito o penna della LIM.

## Struttura

```
equazioni-specchio/
├── project.godot              renderer Compatibility, autoload Game, scena principale
├── data/levels.json           i livelli: mondi, schemi delle equazioni, introduzioni
├── assets/
│   ├── fonts/                 Fredoka (titoli) e Nunito (testi), licenza SIL OFL
│   ├── alice/                 le due Alice, 4 espressioni ciascuna (PNG a doppia risoluzione)
│   └── characters/            i volti dei personaggi dei mondi (un PNG per mondo)
├── scripts/
│   ├── game.gd                autoload "Game": livelli, livello in corso, salvataggio
│   ├── model/                 la logica, NON disegna nulla
│   │   ├── fraction.gd        Fraction: frazioni esatte
│   │   ├── eq_term.gd         EqTerm: un pezzo del puzzle
│   │   ├── equation.gd        Equation: parser, mosse, annulla, stato
│   │   ├── solver.gd          Solver: mossa migliore (suggerimento) e par
│   │   └── generator.gd       EquationGenerator: equazioni casuali dagli schemi
│   ├── ui/
│   │   ├── ui_style.gd        UIStyle: colori, caratteri, stili di pulsanti e riquadri
│   │   ├── icon_button.gd     IconButton: pulsanti tondi con icona
│   │   └── speech_bubble.gd   SpeechBubble: il fumetto di Alice
│   └── view/
│       ├── scene_background.gd  i due mondi e la scacchiera in prospettiva
│       ├── mirror_view.gd     lo specchio-portale (bagliore, increspature)
│       ├── alice_view.gd      un'Alice: espressioni, respiro, saltello
│       ├── term_view.gd       TermView: disegna un pezzo, evidenziazione
│       ├── stars_view.gd      StarsView: le tre stelle
│       └── infinity_view.gd   InfinityView: il simbolo ∞
├── scenes/
│   ├── title.*                schermata del titolo (scena principale)
│   ├── level_select.*         selezione dei livelli
│   ├── level.*                il livello: specchio, gesti, animazioni, pannelli
│   └── term_preview.*         anteprima di tutti i tipi di pezzo
├── tests/test_equation.*      test del modello e del risolutore
└── tools/check_levels.gd      prova gli schemi di ogni livello
```

## Grafica

Direzione "cartoon morbido": tutto è disegnato da codice tranne le Alice e i font.
Colori e caratteri si cambiano in `scripts/ui/ui_style.gd`. I pezzi sono dimensionati
per il tocco su smartphone in orizzontale; se un membro non ci sta, si rimpiccioliscono.
Le Alice sono un disegno originale ispirato alle incisioni di Tenniel (pubblico dominio).

## Gesti

| gesto | effetto |
|---|---|
| trascina un pezzo oltre lo specchio | cambia lato, base invertita |
| trascina un pezzo su un altro (stessa parte) | si fondono |
| trascina un pezzo sul suo gemello identico oltre lo specchio | spariscono entrambi |
| trascina il disco della x oltre lo specchio | gancio: divide tutto il resto |
| trascina il denominatore oltre lo specchio | gancio: moltiplica tutto il resto |
| trascina il denominatore su un altro termine (stessa parte) | stesso denominatore (mcm) |
| doppio clic / doppio tocco su un pezzo | semplifica, oppure raggruppa/sgancia le unità |
| doppio clic / doppio tocco sullo specchio | ribalta tutti i pezzi |

## Livelli

I livelli sono in `data/levels.json`. Ogni livello ha uno o più **schemi**, scritti come
equazioni con lettere maiuscole al posto dei numeri; a ogni partita il gioco estrae numeri
nuovi (seme preso dall'orologio):

```json
{ "patterns": ["Ax + B = C", "B + Ax = C"], "solution": [1, 6] }
```

- Ruolo delle lettere: coefficiente della x da 2 a 6, termine noto da 1 a 12,
  denominatore da 2 a 6. Una lettera ripetuta vale lo stesso numero ovunque
  (`Ax + B = Ax + C` è impossibile, `Ax + B = B + Ax` è indeterminata).
- La soluzione viene scelta per prima; l'ultimo termine noto viene ricavato di conseguenza.
- Opzioni: `"solution": [min, max]`, `"fraction": true` (soluzioni anche frazionarie),
  `"distinct": ["A", "B"]` (lettere con valori diversi), `"min_par": 3` (scarta le
  equazioni troppo facili), `"max_coef"`, `"max_const"`, `"max_den"`.
- Il par (mosse minime) è calcolato dal risolutore su ogni equazione generata.
- Livelli a equazione fissa (il tutorial): `{ "equation": "x + 2 = 5" }`.
- Ogni mondo ha un personaggio: `"character": "bianconiglio"` (il file
  `assets/characters/bianconiglio.png`) e `"character_name": "Il Bianconiglio"`.
  Il volto compare nella selezione livelli, nel riquadro in alto a destra del livello
  e nell'introduzione del primo livello del mondo.
- Altri campi: `"guided": true` (suggerimento sempre visibile), `"intro_title"` e
  `"intro"` (riquadro iniziale). Un mondo con `"tutorial": true` non ha numero né allenamento.
- Dopo l'ultimo livello di ogni mondo c'è l'**allenamento libero** (∞): stessi schemi
  dell'ultimo livello, equazioni infinite, nessuna stella. Il mondo successivo si apre
  completando l'ultimo livello normale.

Stelle: 3 entro il par, 2 entro par + 2, 1 altrimenti; con il pulsante Suggerimento al massimo 2.

Per controllare gli schemi dopo una modifica (genera 60 equazioni per livello e mostra
esempi, par e tempi), da terminale nella cartella del progetto:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --script res://tools/check_levels.gd
```

## Test

Apri `tests/test_equation.tscn` ed eseguila con ⌘+R: nel pannello Output
deve comparire `Tutti i test superati.`
