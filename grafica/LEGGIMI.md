# Combat Master: pacchetto per la grafica dei token

> **Per Codex.** Questa cartella è `grafica/` nel repository. Lavora su un ramo tuo e apri una pull request. Le immagini vanno salvate **solo** in `grafica/token/`, perché da lì verranno prese per inserirle nel gioco. Si comincia con una **prova da approvare**: vedi *Fasi di lavoro*.

Questo pacchetto serve a realizzare la **versione grafica dei token** di Combat Master, il gioco originale di Stefano. È una schermaglia fantasy a dadi: ogni combattente è una scheda composta da token, piccole carte con degli spazi in cui si piazzano i dadi colorati. Il gioco digitale (Godot 4) è pubblico su https://github.com/Tannoiser2/Combat-Master e giocabile su https://tannoiser2.github.io/Combat-Master/.

## Cosa contiene

| File | A cosa serve |
|---|---|
| `catalogo_token_combat_master.md` | **Il documento principale.** Direzione artistica, struttura della carta, colori, e poi i 159 token con testi esatti, spazi, costi, dadi e descrizione dell'illustrazione. |
| `illustrazioni.csv` | Le stesse 159 illustrazioni in tabella: nome del file da produrre, nome del token, categoria, caratteristica, descrizione. Comodo per lavorare a lotti. |
| `dati/tokens.json` | Copia dei dati del gioco da cui è generato tutto, per verifiche. Non va modificata. |
| `dati/regole.md` | Il regolamento, per capire che cosa fanno le azioni. |
| `font/` | Cinzel (titoli) e Alegreya (testi), i font del gioco, licenza SIL OFL. |
| `riferimenti/` | Schermate del gioco e del catalogo attuale, più il catalogo interattivo (`catalogo_interattivo.html`, si apre nel browser), per vedere la palette e lo stile già in uso. |

## Fasi di lavoro

### Fase 1: prova da approvare (prima di tutto il resto)
Realizza **solo queste 6 illustrazioni**. Coprono categorie e situazioni diverse, così da giudicare lo stile:

| File | Token | Perché |
|---|---|---|
| `forza.png` | Forza del soldato | caratteristica, accento rosso |
| `agilita.png` | Destrezza dello schermidore | caratteristica, accento blu, movimento |
| `spada.png` | Spada | arma, primo piano su un oggetto |
| `mantello.png` | Mantello d'ombra | equipaggiamento con effetto visivo |
| `dardo_arcano.png` | Dardo arcano | magia, bagliore |
| `trappola.png` | Trappola a molla | segreto, scena d'insidia |

Se il modello della carta è nelle tue possibilità, aggiungi **una carta completa** di esempio (Forza del soldato) come `grafica/token/prova/carta_forza.png`.

Salva tutto in `grafica/token/prova/`, apri la pull request e **fermati**. Nella descrizione della pull request scrivi lo stile scelto, la tecnica e il prompt di base usato, così si potrà rifarlo uguale. Si prosegue solo dopo l'approvazione di Stefano. Se chiede modifiche, rifai la prova.

### Fase 2: tutti i token (solo dopo l'approvazione)
- Una illustrazione per token, **159 in tutto**, seguendo la descrizione di ciascun token, la *Direzione artistica* del catalogo e lo stile approvato nella prova.
- **Dove:** `grafica/token/<id>.png`, tutte nella stessa cartella, senza sottocartelle. La cartella `prova/` resta com'è.
- **Nome del file:** quello indicato nel catalogo alla voce **File** (ad esempio `forza.png`, `spada.png`), che corrisponde all'id del token nel gioco. Non cambiarlo: serve a reinserire le immagini in automatico.
- **Formato:** PNG orizzontale 3:2, almeno 1200 x 800 pixel, senza testo, cornici o bordi.
- Lavora per categoria (prima le 40 caratteristiche, poi armi, strategie e così via), così lo stile resta coerente in ogni gruppo. Puoi fare un commit per categoria.
- Alla fine controlla che in `grafica/token/` ci siano esattamente i 159 file elencati in `illustrazioni.csv` e scrivi l'esito nella pull request.

### Modello della carta (facoltativo, dopo la fase 2)
Un modello di carta 63 x 88 mm secondo la *Struttura di ogni carta* del catalogo, con alcune carte di esempio complete, una per categoria, salvate in `grafica/carte/`.

## Regole da rispettare
- **Testi:** riportarli esattamente come nel catalogo, in italiano. Non riassumere e non tradurre.
- **Nessun simbolo speciale o emoji:** sulle carte vanno solo lettere, numeri e icone disegnate.
- **Luce morbida:** niente bianchi bruciati o colori saturi al neon.
- **Nessun personaggio, logo o marchio esistente:** solo figure originali.
- **I dati non si modificano:** se un testo sembra sbagliato, segnalarlo invece di correggerlo.

## Cosa non toccare
- Non modificare nulla fuori da `grafica/`: il codice del gioco (`scripts/`, `scenes/`, `data/`) lo gestisce Claude.
- Non pubblicare il sito: niente `[pubblica]` nei commit e nessun avvio del workflow delle Pages.
- `grafica/dati/` è una copia di consultazione: i dati veri sono in `data/`.

## Consegna
Con le immagini in `grafica/token/`, Claude le inserirà nel gioco digitale e nel catalogo.
