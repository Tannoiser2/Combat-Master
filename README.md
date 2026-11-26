# Arcana

Gioco originale di schermaglie fantasy per due combattenti, in Godot 4.7 (GL Compatibility, esportazione web).
Ogni giocatore compone il proprio personaggio con dei **token** che mettono **dadi colorati nel mucchio** e offrono **spazi** su cui piazzarli. I dadi girano in cerchio: per ogni azione si scelgono direttamente dal mucchio entro il budget di **Ritmo** e i limiti cromatici dell'**Attitudine**; sui token restano a occupare lo spazio, lo **sblocco** li sposta in **Attesa** e il **recupero** li riporta nel mucchio.

Le regole complete sono in [`data/regole.md`](data/regole.md) e si leggono anche nel gioco.

## Novità sperimentali (ramo `design/attitudine-mucchio`)
- I dadi liberati dai token entrano in **Attesa**; non tornano automaticamente nel mucchio.
- **Riposo** (1 dado, una volta per scambio) riporta dadi dall'Attesa al mucchio, cedendo l'iniziativa.
- Non esiste una Mano ordinaria: il Ritmo è un budget cumulativo dello scambio e la selezione avviene al momento dell'azione.
- **Attitudine** Aggressiva, Fluida, Guardinga o Concentrata: emerge dai dadi impegnati, dall'Assetto e dalle azioni, ampliando il limite del colore coerente senza aggiungere dadi.
- **Sblocco di emergenza**: spendi un dado disponibile per liberare uno spazio occupato; entrambi i dadi coinvolti finiscono in Attesa.
- La scheda mostra il conteggio dei dadi in Attesa. L'IA valuta le nuove opzioni, ma i pesi e il catalogo richiedono ulteriori playtest.
- I test Godot sono eseguiti sulla pull request con `.github/workflows/test-ciclo.yml`.

## Economia dell'Attesa
Dodici nuovi token di recupero e sblocco (catalogo di 158 token). Il Riposo universale recupera un solo dado; le tecniche specialistiche possono recuperarne fino a tre. Tutti gli sblocchi passano dalla zona Attesa, senza ritorno diretto all'uso.

## Cosa c'è
- **Quasi 150 token**. Quattro caratteristiche obbligatorie (Forza, Destrezza, Tempra, Mente), ognuna con dieci schede fra cui sceglierne una: 2-3 azioni e i dadi del mucchio. Poi armi e strategie (1-2 azioni), equipaggiamento, oggetti, talenti e magie (1 azione), segreti.
- **Chiarezza in battaglia**: toccando un dado si illuminano gli spazi dove può andare, e un messaggio spiega perché non va negli altri (colore, valore, fase o bersaglio).
- **Esagono sui token**: guardie messe prima del colpo su un lato del corpo (pieno, -1, -2, -3 sui lati lontani), colpi mirati che perdono valore se il nemico scarta, token che rafforzano o sfondano le guardie.
- **Movimento**: spinte, lanci contro le colonne, colpi che fanno girare il nemico, colpi pesanti che fanno arretrare, mosse che obbligano chi le usa ad arretrare, incalzare, girare attorno o passare oltre. Produttori e consumatori di dadi, spazi liberi, supporti, reazioni, contatori a soglia, accumuli, segreti che scattano da soli, condizioni su coppie, scale, somme, pari e dispari, effetti che valorizzano i dadi bassi.
- **Officina dei personaggi**: catalogo per categoria, scheda componibile, costo e statistiche in tempo reale, avvisi se manca un attacco, generatore di avventurieri casuali, salvataggio sul dispositivo, codici `CM1-…` da condividere.
- **Arena 3D a esagoni** con colonne e bracieri, orientamento, spinte e urti, animazioni di colpi, schivate, parate e segreti rivelati.
- **Tocco su iPad**: un dito trascina la mappa, due dita pizzicano e ruotano; col mouse tasto destro ruota, rotella zooma.
- **Modalità**: contro l'IA, due giocatori sullo stesso schermo, e **Guarda l'IA combattere** (velocità regolabile, pausa, scontri casuali a ripetizione).
- **IA che impara**: valuta ogni mossa simulandola e usa pesi imparati giocando contro sé stessa (`data/ia_pesi.json`).

## Bilanciamento e allenamento
| Comando | Cosa fa |
|---|---|
| `godot --headless --path . --script tests/regole_test.gd -- partite=60` | test delle regole e partite automatiche |
| `godot --headless --path . --script tests/esagoni_test.gd` | test di guardie, colpi mirati, spinte e movimenti obbligati |
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
Dalla scheda Actions, «Pubblica Arcana» → *Run workflow*, oppure con un commit che contiene `[pubblica]`.
