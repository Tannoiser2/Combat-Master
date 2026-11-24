# Combat Master a mani nude: illustrazioni delle carte attacco e tecnica

> **Per Codex.** Servono le illustrazioni delle nuove carte del gioco a mani nude: 18 attacchi e 35 tecniche, una illustrazione per carta. Lavora su un ramo tuo e apri una pull request. Si comincia con una **prova da approvare** (fase 1), poi tutto il resto (fase 2).

## Cosa disegnare
- Ogni carta ha **una sola azione**, quindi **una sola illustrazione quadrata**: la scena dell'attacco o della tecnica, due figure a mani nude (chi attacca e chi difende), in un'arena di sabbia come nelle altre carte.
- **Stile:** lo stesso delle 159 carte già fatte (tempera e inchiostro, luce calda e morbida, niente testo dentro l'immagine). Vedi `grafica/azioni/` per i riferimenti.
- **Abiti:** keikogi bianco e hakama scura per chi difende (tori), keikogi chiaro per chi attacca (uke). Nessuna arma.
- **Originali:** le figure del libro "Aikido e la sfera dinamica" sono solo l'ispirazione: non vanno ricalcate né copiate.

## Elenco
I nomi e i testi esatti sono in `data/tokens.json` (categorie `attacco` e `tecnica`) e nel catalogo. In breve:

| File | Carta | Cosa mostra |
|---|---|---|
| `att01__colpo.png` … `att18__colpo.png` | Attacchi 1-18 | La presa o il colpo nel momento in cui arriva: 1-6 prese frontali (polso, due mani su un braccio, due braccia, spalla, due spalle), 7-12 prese da dietro (polsi, gomiti, spalle, strangolamento, cintura alta e bassa), 13 colpo dall'alto alla testa, 14 colpo circolare alla tempia, 15 pugno all'addome, 16 presa con presa, 17 presa con colpo, 18 colpo con colpo |
| `tec_i1__tecnica.png` … `tec_i7__tecnica.png` | Immobilizzazioni I1-I7 | Uke portato a terra e controllato con una leva (braccio, polso piegato, polso torto in alto, avambraccio, gomito disteso, gomito sul petto, braccio alzato sopra la testa) |
| `tec_p1__tecnica.png` … `tec_p28__tecnica.png` | Proiezioni P1-P28 | Uke in volo o in caduta, tori che guida il movimento circolare; il nome della carta dice la proiezione (spirale, quattro lati, rotatoria, d'anca, cielo e terra, torsione del polso, entrando, caduta d'angolo…) |

## Formato e cartella
- PNG quadrato, almeno 800 x 800 pixel, senza testo, cornici o bordi.
- Salva in `grafica/azioni/` con esattamente i nomi della tabella: da lì lo script `tools/componi_carte.py` le monta sulle carte.

## Fasi
1. **Prova:** solo `att01__colpo.png`, `att13__colpo.png`, `tec_i1__tecnica.png`, `tec_p3__tecnica.png`, `tec_p28__tecnica.png`. Apri la pull request e **fermati** finché Stefano non approva.
2. **Tutto il resto**, dopo l'approvazione: le altre 48, poi controlla che ci siano tutte le 53.

## Cosa non toccare
Niente fuori da `grafica/azioni/` e niente pubblicazione del sito.
