# Combat Master

Gioco originale di schermaglie fantasy per due combattenti, in Godot 4.7 (GL Compatibility, esportazione web).
Ogni giocatore compone il proprio personaggio con dei **token** (caratteristiche, armi, armature, mosse, talenti) entro il budget dello scenario; in combattimento si **piazzano i dadi** sugli spazi dei token, si **spinge la fortuna**, si bloccano i dadi dell'avversario e l'**iniziativa salta** da un combattente all'altro secondo azioni, combo e reazioni.

Le regole complete sono in [`data/regole.md`](data/regole.md) e si leggono anche nel gioco.

## Cosa c'è in questa prova
- **Officina dei personaggi**: catalogo dei token per categoria, scheda componibile con livelli delle caratteristiche, costo e statistiche in tempo reale, salvataggio sul dispositivo, codice `CM1-…` da esportare e importare. Otto combattenti pronti (30, 45 e 60 punti).
- **Arena 3D a esagoni** con colonne e bracieri, combattenti con l'arma della loro scheda, orientamento (fronte, fianco, spalle), spinte e urti, animazioni di colpi, schivate e parate.
- **Comandi al tocco su iPad**: un dito trascina la mappa, due dita pizzicano per lo zoom e ruotano la vista; col mouse tasto destro ruota, rotella zooma, trascinare sposta. Ci sono anche i pulsanti Ruota, Avvicina, Allontana, Centra.
- **Contro l'IA** oppure **due giocatori sullo stesso schermo**.

## Struttura
| Cartella | Contenuto |
|---|---|
| `data/tokens.json` | catalogo dei token, scenari, arene, personaggi pronti |
| `data/regole.md` | regolamento |
| `scripts/motore.gd` | regole: dadi, ritmo, iniziativa, reazioni, azzardo, movimento sugli esagoni |
| `scripts/ia.gd` | avversario automatico (simula ogni opzione e la reazione migliore dell'avversario) |
| `scripts/arena3d.gd` | mappa 3D, figure, animazioni, telecamera con tocco |
| `scripts/carta_token.gd`, `vassoio.gd`, `stato_giocatore.gd`, `disegno.gd` | interfaccia disegnata a mano (niente simboli Unicode) |
| `scripts/main.gd` | menu, officina, preparazione e battaglia |
| `tests/` | test delle regole con partite automatiche, schermate, copertina |
| `ludoteca/` | scheda e copertina per la ludoteca |

## Verifiche
```
godot --headless --path . --script tests/regole_test.gd -- partite=60
python3 tools/controlla_glifi.py
xvfb-run godot --path . --resolution 1180x820 --script tests/screenshots.gd -- out=/tmp/shots/ipad
```

## Pubblicazione
Solo su richiesta: dalla scheda Actions, «Pubblica Combat Master» → *Run workflow*, oppure con un commit che contiene `[pubblica]`. Il sito va attivato in Settings → Pages con sorgente «GitHub Actions».

## Prossimi passi possibili
Multigiocatore online con Firebase, più combattenti per lato, editor delle arene, nuovi token, miniature 3D vere al posto delle figure geometriche.
