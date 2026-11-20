# Allenamento dell'IA

L'IA prova varianti dei pesi della sua valutazione e le fa combattere contro i pesi in uso, con avventurieri casuali e ogni coppia giocata due volte a lati invertiti. Una variante è adottata se vince almeno il 56% delle partite.

- Generazioni totali: 75 (questo giro: 15, 30 partite ciascuna)
- Varianti adottate in questo giro: 5
- Partite al limite di tempo: 1 su 450
- Opzioni rifiutate dal motore: 0

## Pesi attuali

| Peso | Valore | Valore iniziale |
| --- | --- | --- |
| vita | 4.00 | 4.00 |
| vita_bassa | 2.14 | 3.00 |
| mano_base | 0.47 | 0.55 |
| mano_val | 0.19 | 0.10 |
| conservato | 1.24 | 0.90 |
| mucchio_base | 0.74 | 0.40 |
| mucchio_val | 0.10 | 0.04 |
| stordito | 0.40 | 0.40 |
| eliminato | 0.35 | 0.90 |
| occupato | 0.41 | 1.00 |
| armato | 1.15 | 1.50 |
| distanza | 0.67 | 0.70 |
| fronte | 1.66 | 1.20 |
| fianco | 0.72 | 0.80 |
| retro | 1.86 | 1.60 |
| pericolo | 3.44 | 3.00 |
| iniziativa | 0.17 | 0.80 |
| azzardo | 7.11 | 7.00 |
| pesca_spazio | 0.50 | 0.50 |
| pesca_val | 0.10 | 0.10 |
| minaccia | 0.69 | 1.20 |
| pericolo_subito | 1.04 | 1.00 |
| cede | 0.66 | 0.60 |
| guardia | 1.66 | 1.00 |

## Varianti adottate

- vince il 57%: { "mano_val": [0.1, 0.19], "pesca_val": [0.1, 0.1] }
- vince il 60%: { "mucchio_val": [0.07, 0.07], "eliminato": [0.62, 0.35], "distanza": [0.7, 0.67], "retro": [2.16, 1.86], "iniziativa": [0.3, 0.17] }
- vince il 57%: { "mucchio_val": [0.07, 0.09], "armato": [1.59, 1.15], "pericolo": [3.0, 3.43], "pericolo_subito": [0.94, 1.04], "guardia": [1.0, 1.65] }
- vince il 60%: { "mano_base": [0.55, 0.81], "conservato": [1.42, 1.24], "fronte": [1.47, 1.66], "minaccia": [1.2, 1.39] }
- vince il 60%: { "vita_bassa": [3.0, 2.14], "mano_base": [0.81, 0.47], "occupato": [0.65, 0.41], "minaccia": [1.39, 0.69] }
