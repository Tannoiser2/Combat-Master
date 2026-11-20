# Combat Master

Gioco originale di schermaglie fantasy per due combattenti, in Godot 4.7 (GL Compatibility, esportazione web).
Ogni giocatore compone il proprio personaggio con dei **token** che mettono **dadi colorati nel mucchio** e offrono **spazi** su cui piazzarli. I dadi girano in cerchio: si scelgono dal mucchio visibile tanti quanto il Ritmo, si piazzano sui token dove restano a occupare lo spazio, e tornano nel mucchio (ritirati) solo quando qualcosa li sblocca. L'iniziativa salta da un combattente all'altro secondo azioni, combo e reazioni.

Le regole complete sono in [`data/regole.md`](data/regole.md) e si leggono anche nel gioco.

## Cosa c'è
- **Oltre 100 token** in sette categorie: caratteristiche, oggetti, armi, armature, mosse, talenti e segreti. Produttori e consumatori di dadi, spazi liberi, supporti, reazioni, contatori a soglia, accumuli, segreti che scattano da soli, condizioni su coppie, scale, somme, pari e dispari, effetti che valorizzano i dadi bassi.
- **Officina dei personaggi**: catalogo per categoria, scheda componibile, costo e statistiche in tempo reale, avvisi se manca un attacco, generatore di avventurieri casuali, salvataggio sul dispositivo, codici `CM1-…` da condividere.
- **Arena 3D a esagoni** con colonne e bracieri, orientamento, spinte e urti, animazioni di colpi, schivate, parate e segreti rivelati.
- **Tocco su iPad**: un dito trascina la mappa, due dita pizzicano e ruotano; col mouse tasto destro ruota, rotella zooma.
- **Modalità**: contro l'IA, due giocatori sullo stesso schermo, e **Guarda l'IA combattere** (velocità regolabile, pausa, scontri casuali a ripetizione).
- **IA che impara**: valuta ogni mossa simulandola e usa pesi imparati giocando contro sé stessa (`data/ia_pesi.json`).

## Bilanciamento e allenamento
| Comando | Cosa fa |
|---|---|
| `godot --headless --path . --script tests/regole_test.gd -- partite=60` | test delle regole e partite automatiche |
| `godot --headless --path . --script tests/bilancia.gd -- partite=400 iterazioni=4 applica=1 rapporto=res://docs/bilanciamento.md` | avventurieri casuali, centinaia di partite, ritocco automatico dei costi e rapporto |
| `godot --headless --path . --script tests/allena_ia.gd -- generazioni=40 partite=40` | l'IA prova varianti dei suoi pesi contro sé stessa e tiene quelle che vincono |
| `python3 tools/controlla_glifi.py` | controlla che ogni carattere dell'interfaccia esista nei font |
| `xvfb-run godot --path . --resolution 1180x820 --script tests/screenshots.gd -- out=/tmp/shots/ipad` | schermate di controllo |

I rapporti dell'ultimo giro sono in `docs/bilanciamento.md` e `docs/allenamento_ia.md`.

## Struttura
| Cartella | Contenuto |
|---|---|
| `data/tokens.json` | catalogo dei token, regole di base, scenari, arene, combattenti pronti |
| `data/ia_pesi.json` | pesi imparati dall'IA |
| `scripts/motore.gd` | regole: mucchio, scelta dei dadi, spazi occupati, sblocchi, reazioni, supporti, segreti, contatori |
| `scripts/ia.gd` | avversario automatico a pesi |
| `scripts/generatore.gd` | avventurieri casuali |
| `scripts/arena3d.gd` | mappa 3D, figure, animazioni, telecamera con tocco |
| `scripts/carta_token.gd`, `vassoio.gd`, `stato_giocatore.gd`, `disegno.gd` | interfaccia disegnata a mano (niente simboli Unicode) |
| `scripts/main.gd` | menu, officina, preparazione, battaglia, spettatore |
| `tests/` | test, bilanciamento, allenamento, schermate |

## Pubblicazione
Dalla scheda Actions, «Pubblica Combat Master» → *Run workflow*, oppure con un commit che contiene `[pubblica]`.
