# Allenamento dell'IA

L'IA prova varianti dei pesi della sua valutazione e le fa combattere contro i pesi in uso, con avventurieri casuali e ogni coppia giocata due volte a lati invertiti. Una variante è adottata se vince almeno il 56% delle partite.

- Generazioni totali: 60 (questo giro: 20, 30 partite ciascuna)
- Varianti adottate in questo giro: 4
- Partite al limite di tempo: 2 su 600
- Opzioni rifiutate dal motore: 0

## Pesi attuali

| Peso | Valore | Valore iniziale |
| --- | --- | --- |
| vita | 4.00 | 4.00 |
| vita_bassa | 3.00 | 3.00 |
| mano_base | 0.55 | 0.55 |
| mano_val | 0.10 | 0.10 |
| conservato | 1.42 | 0.90 |
| mucchio_base | 0.74 | 0.40 |
| mucchio_val | 0.07 | 0.04 |
| stordito | 0.40 | 0.40 |
| eliminato | 0.62 | 0.90 |
| occupato | 0.65 | 1.00 |
| armato | 1.58 | 1.50 |
| distanza | 0.70 | 0.70 |
| fronte | 1.47 | 1.20 |
| fianco | 0.72 | 0.80 |
| retro | 2.16 | 1.60 |
| pericolo | 3.00 | 3.00 |
| iniziativa | 0.30 | 0.80 |
| azzardo | 7.11 | 7.00 |
| pesca_spazio | 0.50 | 0.50 |
| pesca_val | 0.10 | 0.10 |
| minaccia | 1.20 | 1.20 |
| pericolo_subito | 0.94 | 1.00 |
| cede | 0.66 | 0.60 |

## Varianti adottate

- vince il 57%: { "mucchio_val": [0.04, 0.07], "iniziativa": [0.8, 0.65] }
- vince il 57%: { "mucchio_val": [0.07, 0.06], "fianco": [0.8, 0.72], "retro": [1.6, 2.4], "iniziativa": [0.65, 0.3] }
- vince il 57%: { "mucchio_val": [0.06, 0.07], "armato": [1.5, 1.58], "fronte": [2.13, 1.47], "pericolo_subito": [1.0, 0.94], "cede": [0.6, 0.66] }
- vince il 60%: { "eliminato": [0.9, 0.62], "retro": [2.4, 2.16] }
