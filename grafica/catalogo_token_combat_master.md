# Combat Master: catalogo dei token per la versione grafica

Questo file descrive **tutti i token** di Combat Master, il gioco di schermaglia fantasy a dadi di Stefano. Serve come base per disegnare le carte dei token. Tutti i testi delle carte sono qui sotto, esatti: vanno riportati così come sono. Ogni token ha anche la descrizione della sua **illustrazione**.

## Istruzioni per la grafica

**Il gioco.** Ogni combattente è una scheda composta da token: piccole carte con uno o più **spazi** in cui si piazzano i dadi. Ogni spazio ha un nome, un tipo (Azione, Reazione...), un foro colorato che dice quali dadi accetta e un breve testo di effetto.

**Stile.** Bottega di un'arena fantasy, sobria e leggibile:
- legno scuro come fondo, oro brunito per i dettagli, carte color pergamena (`#f3ead6`) con inchiostro bruno (`#2b2118`);
- font del gioco: **Cinzel** per i titoli, **Alegreya** per i testi;
- niente simboli speciali o emoji nel testo: usare solo icone disegnate.

**Struttura di ogni carta** (formato consigliato: verticale 63 x 88 mm, come una carta da gioco):
1. **Fascia del titolo** in alto, colorata secondo la caratteristica o la categoria (tabelle sotto). Contiene il nome del token, la categoria in piccolo e il **costo** in punti dentro un cerchio a destra. Se ci sono più costi separati da "/", sono i livelli del token.
2. **Illustrazione** subito sotto la fascia, circa un terzo dell'altezza della carta, a tutta larghezza con bordo sottile oro: una scena che evoca l'azione del token (descrizione sotto ogni token).
3. **Riga "Dà al mucchio"**, solo se il token aggiunge dadi alla riserva del combattente: quadratini colorati con il numero di dadi.
4. **Effetti sempre attivi**, se presenti.
5. **Gli spazi**, uno sotto l'altro. Ogni spazio ha:
   - il nome in grassetto;
   - un'etichetta colorata con il tipo, a destra;
   - a sinistra uno o più **fori quadrati** con i colori ammessi: un foro bicolore se accetta due colori, un foro a strisce dei quattro colori se accetta qualsiasi dado. Più fori significano più dadi nello stesso spazio;
   - il testo dell'effetto;
   - l'icona di un piccolo esagono, se l'effetto lascia una **guardia** o è un **colpo mirato**. L'esagono ha il lato di fronte evidenziato in oro.


### Direzione artistica delle illustrazioni
- **Tecnica:** illustrazione dipinta a mano, inchiostro e acquerello su carta, con tratti di contorno visibili, come nei vecchi manuali fantasy. Niente fotorealismo, niente render 3D.
- **Luce:** calda e morbida, come un pomeriggio in un'arena di sabbia. Niente bianchi bruciati né neon.
- **Ambientazione:** un'arena antica con sabbia, colonne di pietra, spalti in lontananza, fiaccole e bracieri. Il fondo resta semplice e sfocato, il soggetto è in primo piano.
- **Personaggi:** combattenti fantasy vari per età, genere e provenienza, con equipaggiamento credibile e consumato. Nessun personaggio noto o protetto da diritti.
- **Composizione:** una sola azione chiara per illustrazione, colta nel momento culminante, leggibile anche in piccolo.
- **Colore d'accento:** le illustrazioni dei token di caratteristica riprendono nella luce o nei dettagli il colore della caratteristica (rosso Forza, blu Destrezza, verde Tempra, viola Mente). Le magie hanno bagliori coerenti con l'effetto.
- **Nessun testo dentro l'immagine:** niente scritte, lettere, numeri o cornici. Il testo sta solo sulla carta.
- **Formato dell'immagine:** orizzontale circa 3:2, poi ritagliata nella finestra della carta.

### Colori dei dadi (caratteristiche)
| Colore | Caratteristica | Esadecimale |
|---|---|---|
| Rosso | Forza | `#c8372d` |
| Blu | Destrezza | `#2f6fd0` |
| Verde | Tempra | `#2f9a52` |
| Viola | Mente | `#8a4fc4` |
| Bianco | Prodigio | `#ece6d6` |

Il bianco (Prodigio) è un dado speciale concesso da alcuni token. I token di caratteristica hanno la fascia del titolo nel colore della caratteristica, scurito.

### Colori delle fasce per gli altri token
| Categoria | Colore |
|---|---|
| Azioni di base | `#5b5046` |
| Armi | `#8e3a2c` |
| Strategie | `#a33a3a` |
| Equipaggiamento | `#4d6b8a` |
| Oggetti | `#6f6534` |
| Talenti | `#3f7a55` |
| Magie | `#5b4a9a` |
| Segreti | `#3d3550` |

### Etichette dei tipi di spazio
| Tipo | Colore | Significato |
|---|---|---|
| Azione | `#7a5a2a` | si usa nel proprio turno e consuma Ritmo |
| Libera | `#3f7a55` | si usa nel proprio turno senza costo di Ritmo |
| Reazione | `#355f93` | si usa quando si viene attaccati |
| Supporto al colpo | `#a3483a` | rinforza un proprio attacco |
| Supporto alla difesa | `#4d6b8a` | rinforza una propria difesa |
| Segreto | `#5a3f7a` | si piazza coperto e si rivela dopo |
| Contatore | `#6f6534` | accumula dadi nel tempo |

---

## Azioni di base (1)

### Azioni di base
**Categoria:** Azioni di base · **Costo:** 0 · **File:** `base.png`
- **Illustrazione:** Due combattenti si studiano in cerchio sulla sabbia dell'arena; uno sposta il peso per cercare un'apertura, l'altro legge il movimento con lo sguardo fisso sulle spalle dell'avversario.
- **Nota:** Sempre presenti su ogni scheda.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo improvvisato** | Azione | qualsiasi colore | Qualsiasi dado. Portata 2, danno un terzo del dado. Il dado va subito in Attesa: è un gesto fluido disponibile a tutti. |  |
| **Cercare il varco** | Libera | qualsiasi colore | Libera, una volta per scambio, nemico in vista entro 4. Dado 1: prendi 1 svantaggio. 2-3: 1 vantaggio. 4: niente. 5: 1 vantaggio e togli 1 svantaggio. 6: 3 vantaggi. |  |
| **Leggere il colpo** | Reazione | qualsiasi colore | Reazione, una volta per scambio, non se ti attaccano alle spalle. Dado 1: prendi 1 svantaggio. 2-3: l'attaccante perde 1 vantaggio. 4: niente. 5: ne perde 2. 6: ne perde 3 e tu ne guadagni 1. |  |

## Caratteristiche (40)

### Forza del soldato
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 1 · **File:** `forza.png`
- **Illustrazione:** Un fante con corazza semplice spinge con la spalla un avversario sbilanciato, il pugno libero già caricato. Postura solida, piedi ben piantati.
- **Dà al mucchio:** 2 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo a mani nude** | Azione | rosso (Forza) | Portata 1. Danno: metà del dado. |  |
| **Spintone** | Azione | rosso (Forza) | Dado 4+. Danno 1 e spingi il nemico di 1. |  |
| **Forza bruta** | Supporto al colpo | rosso (Forza) | Supporto, dado 4+: +2 danni al tuo colpo. |  |

### Forza del berserker
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 2 · **File:** `furia.png`
- **Illustrazione:** Un guerriero a torso nudo, dipinto di guerra, urla a pieni polmoni con gli occhi stravolti, ferito ma ancora più pericoloso. Polvere e sangue sollevati attorno.
- **Dà al mucchio:** 3 rosso
- **Nota:** Molti dadi, che danno il meglio quando escono bassi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Rancore** | Supporto al colpo | rosso (Forza) | Supporto, dado 1-2: +3 danni al tuo colpo. |  |
| **Urlo di guerra** | Libera | rosso (Forza) | Libera, dado 1: prendi 2 dadi dal mucchio. |  |
| **Colpo cieco** | Azione | rosso (Forza) | Dado 1-3. Portata 1, danno 3. Poi DEVI incalzare di 1. |  |

### Forza del colosso
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 3 · **File:** `potenza.png`
- **Illustrazione:** Un gigante dalle spalle enormi abbatte entrambe le braccia su uno scudo che si incrina; l'avversario piega le ginocchia sotto il colpo.
- **Dà al mucchio:** 2 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Schianto** | Azione | rosso (Forza) | Dado 5+. Portata 1, danno dado +1, spingi di 1. |  |
| **Sfondare la guardia** | Supporto al colpo | rosso (Forza) | Supporto, dado 4+: +1 danno e ogni guardia nemica perde 2. |  |

### Forza del lottatore
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 7 · **File:** `presa.png`
- **Illustrazione:** Un lottatore afferra l'avversario alla vita e lo solleva per rovesciarlo, muscoli in tensione, sabbia che schizza dai piedi.
- **Dà al mucchio:** 2 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Afferrare** | Azione | rosso (Forza) | Dado 1-3, portata 2. Danno 1, lo tiri a te di 1 e gli stordisci il dado più alto. |  |
| **Rovesciare** | Azione | rosso (Forza) | Dado 4+. Portata 1, danno 2 e lo fai girare di 3 lati: ti mostra la schiena. |  |
| **Tenere duro** | Reazione | rosso (Forza) | Reazione in mischia, dado pari o superiore all'attacco: riduci di metà del dado e non puoi essere spinto. |  |

### Forza del boscaiolo
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 4 · **File:** `boscaiolo.png`
- **Illustrazione:** Un uomo barbuto con camicia di lana cala l'ascia dall'alto come su un tronco; la guardia di legno del nemico si spacca in schegge.
- **Dà al mucchio:** 3 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo d'ascia** | Azione | rosso (Forza) | Dado 4+. Portata 1, danno pari al dado +1. |  |
| **Spaccare la guardia** | Supporto al colpo | rosso (Forza) | Supporto, dado 1-3: ogni guardia nemica perde 2. |  |

### Forza del portatore
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 4 · **File:** `portatore.png`
- **Illustrazione:** Un facchino robusto con le cinghie del carico ancora sulle spalle spinge un avversario con il palmo aperto; casse e sacchi abbandonati sullo sfondo.
- **Dà al mucchio:** 4 rosso
- **Nota:** Tanti dadi rossi, poche azioni: serve qualcosa che li consumi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Spinta** | Azione | rosso (Forza) | Portata 1. Danno 1 e spingi il nemico di 2. |  |
| **Riprendere il carico** | Libera | rosso (Forza) | Libera, dado 1-2: prendi 1 dado dal mucchio. |  |

### Forza del pugile
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 5 · **File:** `pugile.png`
- **Illustrazione:** Un pugile con le mani fasciate sferra un montante sotto il mento dell'avversario; l'altro braccio resta alto a proteggere il volto.
- **Dà al mucchio:** 2 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Diretto** | Azione | rosso (Forza) | Dado 1-3. Portata 1, danno pari al dado +1. Mantieni l'iniziativa. |  |
| **Montante** | Azione | rosso (Forza) | Dado 5+. Portata 1, danno pari al dado e stordisci il dado più alto del nemico. |  |
| **Guardia stretta** | Reazione | rosso (Forza) | Reazione in mischia, dado 1-3: riduci il danno di 2. |  |

### Forza del gladiatore
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 4 · **File:** `gladiatore.png`
- **Illustrazione:** Un gladiatore con elmo crestato alza la spada verso gli spalti gremiti che ruggiscono; ai suoi piedi un avversario in ginocchio.
- **Dà al mucchio:** 2 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo da arena** | Azione | rosso (Forza) | Portata 1, danno pari al dado. Poi DEVI girare attorno al nemico di 1. |  |
| **Ruggito della folla** | Azione | rosso (Forza) | Dado 5+, gittata 2: stordisci il dado in mano più alto del nemico che non supera il tuo. |  |

### Forza del fabbro
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 3 · **File:** `fabbro.png`
- **Illustrazione:** Un fabbro con grembiule di cuoio colpisce con il martello da forgia; scintille arancioni volano come sull'incudine.
- **Dà al mucchio:** 1 rosso
- **Nota:** Un solo dado rosso, ma ogni azione rende molto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Martellata** | Azione | rosso (Forza) | Dado 3+. Portata 1, danno pari al dado +2. |  |
| **Temprare** | Libera | rosso (Forza) | Libera: alza o abbassa di 1 un tuo dado in mano. |  |
| **Incudine** | Reazione | rosso (Forza) | Reazione, dado 4+: riduci il danno di 3. |  |

### Forza del toro
**Categoria:** Caratteristiche · **Caratteristica:** Forza (rosso) · **Costo:** 9 · **File:** `toro.png`
- **Illustrazione:** Un guerriero con elmo cornuto carica a testa bassa, le corna puntate contro il petto dell'avversario, polvere sollevata dietro di lui.
- **Dà al mucchio:** 3 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Carica del toro** | Azione | rosso (Forza) + rosso (Forza) | Due rossi. Muovi col primo fino a un nemico davanti a te, poi colpisci: danno pari al secondo. |  |
| **Incornata** | Azione | rosso (Forza) | Dado 4+. Portata 1, danno 2 e lo scagli di 2: se sbatte subisce 3 danni e perde il dado più alto. |  |

### Destrezza dello schermidore
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 5 · **File:** `agilita.png`
- **Illustrazione:** Uno schermidore elegante ruota su un piede schivando una lama per un soffio, il mantello che vortica, la propria spada tesa in linea.
- **Dà al mucchio:** 2 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Muoviti** | Azione | blu (Destrezza) | Punti movimento pari al dado. Avanti 1, di lato o indietro 2, girarsi 1. |  |
| **Schivata** | Reazione | blu (Destrezza) | Reazione. Dado pari o superiore al dado d'attacco: il colpo va a vuoto. |  |
| **Giravolta** | Libera | blu (Destrezza) | Libera: girati verso qualsiasi lato. |  |

### Destrezza del ladro
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 4 · **File:** `velocita.png`
- **Illustrazione:** Una figura incappucciata scatta in avanti e colpisce con un pugnale corto, già pronta a balzare indietro; scia di movimento.
- **Dà al mucchio:** 2 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Scatto** | Libera | blu (Destrezza) | Libera, dado 1-2: prendi 2 dadi dal mucchio. |  |
| **Colpo fulmineo** | Azione | blu (Destrezza) | Dado 1-3. Portata 1, danno pari al dado. Mantieni l'iniziativa. |  |
| **Balzo indietro** | Reazione | blu (Destrezza) | Reazione, dado 4+: salta in un esagono vicino libero. Se il colpo non ti raggiunge più va a vuoto. |  |

### Destrezza del danzatore
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 4 · **File:** `equilibrio.png`
- **Illustrazione:** Un danzatore guerriero in equilibrio perfetto su un piede taglia girando su se stesso, stoffe colorate che seguono la rotazione.
- **Dà al mucchio:** 3 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Baricentro** | Reazione | blu (Destrezza) | Reazione, dado 1-2: riduci il danno di 2, anche alle spalle, e non puoi essere spinto. |  |
| **Taglio girando** | Azione | blu (Destrezza) | Portata 1, danno metà del dado (per eccesso). Poi DEVI girare attorno al nemico di 2. |  |

### Destrezza del gatto
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 4 · **File:** `riflessi.png`
- **Illustrazione:** Un combattente agile atterra di lato a quattro zampe come un gatto, evitando un colpo che si schianta dove era un attimo prima.
- **Dà al mucchio:** 3 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Scatto di lato** | Reazione | blu (Destrezza) | Reazione, dado 1-2: spostati in un esagono vicino libero. Se il colpo non ti raggiunge più va a vuoto. |  |
| **Riposizionarsi** | Azione | blu (Destrezza) | Muovi di 1 e mantieni l'iniziativa. |  |

### Destrezza del cecchino
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 5 · **File:** `precisione.png`
- **Illustrazione:** Una tiratrice socchiude un occhio e prende la mira con una fionda tesa; in lontananza l'avversario, il sasso già in volo.
- **Dà al mucchio:** 2 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Mira** | Supporto al colpo | blu (Destrezza) | Supporto, dado 1-3: il colpo non si schiva e ignora l'armatura. |  |
| **Tiro di sasso** | Azione | blu (Destrezza) | Gittata 2-4, serve la vista libera. Danno 2. |  |

### Destrezza del cacciatore
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 5 · **File:** `istinto.png`
- **Illustrazione:** Un cacciatore in pelli si abbassa d'istinto sotto un fendente e risponde infilando la lancia corta nel varco lasciato aperto.
- **Dà al mucchio:** 2 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Prontezza** | Reazione | blu (Destrezza) | Reazione, dado 1-2: riduci il danno di 3, anche alle spalle. |  |
| **Schivata d'istinto** | Reazione | blu (Destrezza) | Reazione, dado 1-2: spostati in un esagono vicino libero. Se il colpo non ti raggiunge più va a vuoto. |  |
| **Colpo nel varco** | Supporto al colpo | blu (Destrezza) | Supporto, dado 5+: +1 danno e il colpo non si schiva. |  |

### Destrezza del giocoliere
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 2 · **File:** `destrezza.png`
- **Illustrazione:** Un giocoliere fa volteggiare tre pugnali in aria e ne afferra uno al volo per colpire di polso, sorriso beffardo.
- **Dà al mucchio:** 2 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ritocco** | Libera | blu (Destrezza) | Libera: alza o abbassa di 1 un tuo dado in mano. |  |
| **Rapidità di mano** | Libera | blu (Destrezza) | Libera, dado 1: liberi 1 spazio e il suo dado va in Attesa, da recuperare. |  |
| **Colpo di polso** | Azione | blu (Destrezza) | Portata 1. Mira un lato: danno pari al dado meno 1, -1 per ogni lato di scarto se il nemico si sposta. | colpo mirato |

### Destrezza del duellante
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 6 · **File:** `occhio_acuto.png`
- **Illustrazione:** Una duellante con camicia bianca e fioretto vede arrivare il colpo e infila la punta nello spiraglio tra lama e corpo dell'avversario.
- **Dà al mucchio:** 2 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Punta nel varco** | Azione | blu (Destrezza) | Portata 2. Mira un lato: danno metà del dado +1, ignora l'armatura; -1 per ogni lato di scarto. | colpo mirato |
| **Vederlo arrivare** | Reazione | blu (Destrezza) | Reazione, dado pari o superiore all'attacco: riduci il danno di 3. |  |

### Destrezza dell'acrobata
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 6 · **File:** `acrobata.png`
- **Illustrazione:** Un'acrobata in capriola a mezz'aria sferra un calcio rotante; sotto di lei l'avversario guarda in alto, sorpreso.
- **Dà al mucchio:** 3 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Capriola** | Azione | blu (Destrezza) | Dado 4+: punti movimento pari al dado +1. Mantieni l'iniziativa. |  |
| **Calcio rotante** | Azione | blu (Destrezza) | Dado 4+. Portata 1, danno 2 e il nemico si gira di 1 lato. |  |

### Destrezza del borseggiatore
**Categoria:** Caratteristiche · **Caratteristica:** Destrezza (blu) · **Costo:** 1 · **File:** `borseggiatore.png`
- **Illustrazione:** Un ragazzo sgusciante sfila la spada dalla cintura dell'avversario mentre gli passa accanto; l'altro non se ne è ancora accorto.
- **Dà al mucchio:** 1 blu
- **Nota:** Un solo dado blu, ma tre trucchi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sfilare l'arma** | Azione | blu (Destrezza) | Dado 4+, nemico adiacente: il suo attacco migliore è bloccato fino a fine scambio. |  |
| **Mano lesta** | Libera | blu (Destrezza) | Libera, dado 1: prendi 2 dadi dal mucchio. |  |
| **Sgusciare** | Reazione | blu (Destrezza) | Reazione, dado 5+: spostati in un esagono vicino libero. Se il colpo non ti raggiunge più va a vuoto. |  |

### Tempra del veterano
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 6 · **File:** `tempra.png`
- **Illustrazione:** Un veterano coperto di cicatrici incassa un colpo sullo spallaccio senza arretrare di un passo, lo sguardo calmo.
- **Dà al mucchio:** 2 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Incassare** | Reazione | verde (Tempra) | Reazione: riduci il danno di metà del dado, anche alle spalle. |  |
| **Rigenerarsi** | Azione | verde (Tempra) + verde (Tempra) | Due dadi uguali: recuperi 3 ferite. |  |
| **Piantare i piedi** | Azione | verde (Tempra) | Guardia: metti il dado su un lato dell'esagono. I colpi da lì perdono il dado, -1 per ogni lato di distanza; ogni colpo fermato toglie 1. | guardia |

### Tempra del legionario
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 3 · **File:** `resistenza.png`
- **Illustrazione:** Un legionario dietro lo scudo rettangolare riprende fiato e respinge l'avversario con un colpo d'urto.
- **Dà al mucchio:** 3 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riprendere fiato** | Azione | verde (Tempra) | Libera spazi pari a metà del dado (per eccesso): i loro dadi tornano nel mucchio. Mantieni l'iniziativa. |  |
| **Respinta** | Reazione | verde (Tempra) | Reazione in mischia, dado 3+: riduci di 2 e spingi via l'attaccante di 1. |  |

### Tempra del monaco
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 3 · **File:** `volonta.png`
- **Illustrazione:** Un monaco a piedi nudi resta immobile mentre un bastone gli si spezza sul braccio teso; espressione serena.
- **Dà al mucchio:** 2 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ostinazione** | Libera | verde (Tempra) | Libera, dado 1-2: liberi 2 spazi, i loro dadi tornano nel mucchio. |  |
| **Non cedere** | Reazione | verde (Tempra) | Reazione, dado 1-2: riduci il danno di 2 e non puoi essere spinto. |  |
| **Spirito saldo** | Libera | verde (Tempra) | Libera, dado 1-3: +2 al dado di una tua guardia (massimo 6). |  |

### Tempra del gigante
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 5 · **File:** `costituzione.png`
- **Illustrazione:** Un gigante dalla pelle dura come corteccia avanza spingendo con tutto il suo peso un avversario che slitta all'indietro.
- **Dà al mucchio:** 3 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Pelle dura** | Supporto alla difesa | verde (Tempra) | Supporto in difesa, dado 4+: riduci il danno di 2. |  |
| **Spinta di peso** | Azione | verde (Tempra) | Dado 5+. Portata 1, danno 2 e spingi il nemico di 2. |  |

### Tempra del montanaro
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 4 · **File:** `montanaro.png`
- **Illustrazione:** Un montanaro con mantello di lana pesante, piantato come una roccia sul terreno, il vento della montagna che gli scompiglia la barba.
- **Dà al mucchio:** 2 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Fiato di montagna** | Libera | verde (Tempra) | Libera, dado 1: libera 1 spazio, il suo dado torna nel mucchio. |  |
| **Roccia** | Azione | verde (Tempra) | Dado 3+. Guardia sul lato scelto: i colpi da lì perdono il dado +1, -1 per ogni lato di distanza; ogni colpo fermato toglie 1. | guardia |

### Tempra del marinaio
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 4 · **File:** `marinaio.png`
- **Illustrazione:** Un marinaio a gambe larghe, come sul ponte in tempesta, lancia un gancio d'abbordaggio verso l'avversario.
- **Dà al mucchio:** 3 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Gamba ferma** | Reazione | verde (Tempra) | Reazione: riduci il danno di 1 e non puoi essere spinto. |  |
| **Rollio** | Libera | verde (Tempra) | Libera: scambia i valori di due tuoi dadi in mano. |  |
| **Gancio d'abbordaggio** | Azione | verde (Tempra) | Portata 2. Danno 1 e lo tiri a te di 1. |  |

### Tempra dell'orso
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 4 · **File:** `orso.png`
- **Illustrazione:** Un guerriero avvolto in una pelliccia d'orso stringe l'avversario in un abbraccio soffocante, la testa d'orso a fargli da cappuccio.
- **Dà al mucchio:** 4 verde
- **Nota:** Molti dadi verdi e solo due azioni.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Abbraccio** | Azione | verde (Tempra) + verde (Tempra) | Due verdi uguali. Portata 1, danno pari al dado e stordisci il dado più alto del nemico. |  |
| **Pelliccia** | Supporto alla difesa | verde (Tempra) | Supporto in difesa: riduci il danno di 1. |  |

### Tempra del penitente
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 3 · **File:** `penitente.png`
- **Illustrazione:** Un penitente con il saio lacero e catene ai polsi sopporta un colpo a occhi chiusi, quasi traendone forza.
- **Dà al mucchio:** 2 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sopportare** | Azione | verde (Tempra) | Dado 1-2: recuperi 2 ferite. |  |
| **Dolore che nutre** | Libera | verde (Tempra) | Libera, dado 1: prendi 1 dado dal mucchio. |  |

### Tempra del guardiano
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 6 · **File:** `guardiano.png`
- **Illustrazione:** Un guardiano dietro un grande scudo sbarra un passaggio tra due colonne: nessuno passa.
- **Dà al mucchio:** 1 verde
- **Nota:** Un solo dado verde, per chi tiene la posizione.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Muro** | Azione | verde (Tempra) | Guardia sul lato scelto: i colpi da lì perdono il dado, -1 per ogni lato di distanza; ogni colpo fermato toglie 1. | guardia |
| **Rinsaldare** | Libera | verde (Tempra) | Libera, dado 1-3: +2 al dado di una tua guardia (massimo 6). |  |
| **Non passare** | Reazione | verde (Tempra) | Reazione in mischia, dado 4+: riduci di 2 e spingi via l'attaccante di 1. |  |

### Tempra del corridore
**Categoria:** Caratteristiche · **Caratteristica:** Tempra (verde) · **Costo:** 6 · **File:** `corridore.png`
- **Illustrazione:** Una corritrice snella ancora in movimento, il petto che si alza per il secondo fiato, la polvere dell'arena alle spalle.
- **Dà al mucchio:** 3 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Lunga corsa** | Azione | verde (Tempra) | Punti movimento pari al dado. Avanti 1, di lato o indietro 2, girarsi 1. |  |
| **Secondo fiato** | Azione | verde (Tempra) | Dado 5+: libera spazi pari a metà del dado (per eccesso). Mantieni l'iniziativa. |  |

### Mente del tattico
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 3 · **File:** `mente.png`
- **Illustrazione:** Un comandante con il mantello dei gradi fissa l'avversario con uno sguardo che lo fa esitare; dietro di lui, una mappa schizzata nella sabbia.
- **Dà al mucchio:** 2 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Intimidire** | Azione | viola (Mente) | Gittata 4, dado 2+. Stordisci il dado in mano più alto del nemico che non supera il tuo. |  |
| **Concentrazione** | Libera | viola (Mente) | Libera: ritira senza rischio i tuoi dadi in mano più bassi (metà del dado). |  |
| **Leggere la mossa** | Reazione | viola (Mente) | Reazione, dado pari o superiore all'attacco: riduci il danno del dado meno 2. |  |

### Mente dell'imbroglione
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 5 · **File:** `astuzia.png`
- **Illustrazione:** Un imbroglione accenna un colpo a destra mentre la vera lama arriva da sinistra; il suo sorriso tradisce la finta.
- **Dà al mucchio:** 2 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Finta** | Azione | viola (Mente) | Gittata 3, dado 1-2: stordisci il dado in mano più alto del nemico. Mantieni l'iniziativa. |  |
| **Rovescio** | Libera | viola (Mente) | Libera: gira un tuo dado in mano sulla faccia opposta (l'1 diventa 6). |  |
| **Depistare** | Libera | viola (Mente) | Libera, dado 1-3, nemico entro 2: fallo girare di un lato a tua scelta. |  |

### Mente del mago
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 3 · **File:** `arcano.png`
- **Illustrazione:** Una maga concentra una luce viola tra le mani a coppa, gli occhi socchiusi, sottili rune che si affinano nell'aria.
- **Dà al mucchio:** 3 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Affinare** | Libera | viola (Mente) | Libera: elimini per sempre dal mucchio un dado del colore che scegli, poi peschi 1 dado. |  |
| **Canalizzare** | Supporto al colpo | viola (Mente) | Supporto: +metà del dado ai danni e il colpo ignora l'armatura. |  |

### Mente dello stratega
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 5 · **File:** `intelletto.png`
- **Illustrazione:** Uno stratega anziano osserva il duello da vicino; attorno alla sua testa, sagome trasparenti delle prossime mosse dell'avversario.
- **Dà al mucchio:** 2 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Eco della mente** | Libera | viola (Mente) | Libera: un tuo dado in mano prende il valore di questo dado viola. |  |
| **Anticipare** | Azione | viola (Mente) | Guardia: metti il dado su un lato dell'esagono, da dove prevedi il colpo. I colpi da lì perdono il dado, -1 per ogni lato di distanza. | guardia |
| **Leggere la guardia** | Supporto al colpo | viola (Mente) | Supporto, dado 3+: ogni guardia nemica perde 3. |  |

### Mente del veggente
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 5 · **File:** `veggente.png`
- **Illustrazione:** Un veggente bendato alza la mano e ferma in anticipo un colpo che vede solo in sogno; un'eco luminosa della lama lo precede.
- **Dà al mucchio:** 2 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Vedere il colpo** | Reazione | viola (Mente) | Reazione, dado pari o superiore all'attacco: riduci il danno di 3. |  |
| **Sogno premonitore** | Libera | viola (Mente) | Libera, dado 1-2: prendi 1 dado dal mucchio. |  |

### Mente del giocatore d'azzardo
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 3 · **File:** `azzardo.png`
- **Illustrazione:** Un giocatore d'azzardo con il cappello di sbieco lancia due dadi sul palmo mentre para con il pugnale; posta e rischio nello sguardo.
- **Dà al mucchio:** 3 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Puntata** | Libera | viola (Mente) | Libera: gira un tuo dado in mano sulla faccia opposta (l'1 diventa 6). |  |
| **Raddoppio** | Supporto al colpo | viola (Mente) | Supporto, dado dispari: +2 danni. |  |
| **Bluff** | Azione | viola (Mente) | Dado 1-2, gittata 2: stordisci un dado in mano del nemico che non supera il tuo. |  |

### Mente del maestro d'armi
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 3 · **File:** `maestro.png`
- **Illustrazione:** Un maestro d'armi con i capelli grigi corregge con il bastone la guardia di un allievo, gesto preciso e paziente.
- **Dà al mucchio:** 1 viola
- **Nota:** Un solo dado viola, che aggiusta tutto il resto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Lezione** | Supporto al colpo | viola (Mente) | Supporto: +1 danno. |  |
| **Correggere la guardia** | Reazione | viola (Mente) | Reazione: sposta una tua guardia sul lato vicino, verso il colpo. |  |
| **Studio** | Libera | viola (Mente) | Libera: ritira senza rischio i tuoi dadi in mano più bassi (metà del dado). |  |

### Mente dell'ipnotista
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 4 · **File:** `ipnotista.png`
- **Illustrazione:** Un'ipnotista fissa l'avversario negli occhi; spirali viola sottili si irradiano dal suo sguardo e l'altro abbassa l'arma, intontito.
- **Dà al mucchio:** 3 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sguardo fisso** | Azione | viola (Mente) | Dado 4+, gittata 2: stordisci il dado in mano più alto del nemico che non supera il tuo. |  |
| **Suggestione** | Libera | viola (Mente) | Libera, dado 1-2, nemico entro 2: fallo girare di un lato a tua scelta. |  |

### Mente del cacciatore di taglie
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 6 · **File:** `cacciatore_taglie.png`
- **Illustrazione:** Un cacciatore di taglie con il manifesto di un ricercato alla cintura si posiziona nel punto cieco della preda, che guarda altrove.
- **Dà al mucchio:** 2 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Prevedere** | Azione | viola (Mente) | Guardia sul lato da cui prevedi il colpo: i colpi da lì perdono il dado, -1 per ogni lato di distanza. | guardia |
| **Punto cieco** | Supporto al colpo | viola (Mente) | Supporto, dado 4+: +1 danno e il colpo non si schiva. |  |

### Mente del monaco guerriero
**Categoria:** Caratteristiche · **Caratteristica:** Mente (viola) · **Costo:** 4 · **File:** `monaco_guerriero.png`
- **Illustrazione:** Un monaco guerriero in posizione calma colpisce con il palmo aperto il petto dell'avversario; un'onda d'aria si propaga dall'impatto.
- **Dà al mucchio:** 4 viola
- **Nota:** Molti dadi viola e due sole azioni.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Calma** | Libera | viola (Mente) | Libera, dado 1-2: liberi 2 spazi, i loro dadi tornano nel mucchio. |  |
| **Palmo** | Azione | viola (Mente) | Portata 1. Danno 2 e spingi il nemico di 1. |  |

## Armi (10)

### Spada
**Categoria:** Armi · **Costo:** 5 · **File:** `spada.png`
- **Illustrazione:** Una spada lunga cala in un fendente diagonale; dettaglio della lama e della mano guantata, con un avversario che para all'ultimo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Fendente** | Azione | rosso (Forza) | Portata 1. Mira un lato dell'esagono: danno pari al dado, -1 per ogni lato di scarto se il nemico si sposta prima del colpo. | colpo mirato |
| **Parata** | Reazione | rosso (Forza) o verde (Tempra) o blu (Destrezza) | Reazione in mischia, non alle spalle: riduci il danno del dado meno 1. |  |

### Pugnali gemelli
**Categoria:** Armi · **Costo:** 5 · **File:** `pugnali.png`
- **Illustrazione:** Due pugnali identici, uno in mano per la stoccata rapida e l'altro che vola verso il bersaglio lanciato di punta.
- **Dà al mucchio:** 1 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Stoccata rapida** | Azione | rosso (Forza) o blu (Destrezza) | Dado 1-3. Portata 1, danno dado +1. Mantieni l'iniziativa. |  |
| **Lancio del pugnale** | Azione | blu (Destrezza) | Dado 3+. Gittata 2-3, danno 2. |  |

### Ascia da guerra
**Categoria:** Armi · **Costo:** 11 · **File:** `ascia.png`
- **Illustrazione:** Un'ascia bipenne pesante si abbatte su una guardia di legno e la spezza in due.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo d'ascia** | Azione | rosso (Forza) | Dado 3+. Portata 1, danno dado +2. |  |
| **Spezzaguardia** | Azione | rosso (Forza) + rosso (Forza) | Due rossi uguali. Danno pari al dado, non si schiva, stordisce 2 dadi del nemico. |  |

### Lancia
**Categoria:** Armi · **Costo:** 10 · **File:** `lancia.png`
- **Illustrazione:** Una lancia in affondo lungo tiene a distanza un avversario; la punta ferma a un palmo dal suo petto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Affondo lungo** | Azione | rosso (Forza) | Portata 2. Danno pari al dado. Poi DEVI arretrare di 1. |  |
| **Punta ferma** | Reazione | rosso (Forza) | Reazione in mischia, dado pari o superiore all'attacco: colpisci per metà del dado e prendi l'iniziativa. |  |

### Arco lungo
**Categoria:** Armi · **Costo:** 16 · **File:** `arco.png`
- **Illustrazione:** Un arciere tende l'arco lungo fino all'orecchio, la freccia incoccata puntata verso l'arena.
- **Dà al mucchio:** 1 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Tiro** | Azione | blu (Destrezza) | Dado 2+. Gittata 2-6, serve la linea di vista. Danno dado -1. |  |
| **Tiro mirato** | Azione | blu (Destrezza) + viola (Mente) | Blu + viola, somma 8+. Gittata 2-6, danno metà della somma, ignora l'armatura. |  |

### Bastone arcano
**Categoria:** Armi · **Costo:** 8 · **File:** `bastone.png`
- **Illustrazione:** Un bastone nodoso con un cristallo in cima sprigiona un dardo luminoso e un'onda di forza che solleva la sabbia.
- **Dà al mucchio:** 1 viola

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Dardo arcano** | Azione | viola (Mente) | Gittata 1-4. Danno metà del dado (per eccesso), ignora l'armatura. |  |
| **Onda di forza** | Azione | viola (Mente) + viola (Mente) | Due viola uguali. Nemico adiacente: danno 1, spinto di 2, non si schiva. |  |

### Scudo
**Categoria:** Armi · **Costo:** 9 · **File:** `scudo.png`
- **Illustrazione:** Uno scudo rotondo rinforzato regge un colpo violento; schegge e scintille sul bordo di ferro.
- **Dà al mucchio:** 1 verde

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Parata con lo scudo** | Reazione | verde (Tempra) | Reazione, non alle spalle: riduci il danno pari al dado. |  |
| **Muro di scudo** | Azione | verde (Tempra) | Guardia: metti il dado su un lato. I colpi da quel lato perdono dado +1, -1 per ogni lato di distanza. Ogni colpo fermato toglie 1 al dado. | guardia |

### Martello da guerra
**Categoria:** Armi · **Costo:** 7 · **File:** `martello.png`
- **Illustrazione:** Un martello da guerra colpisce un elmo; il rintocco metallico si vede come cerchi concentrici nell'aria.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo di martello** | Azione | rosso (Forza) | Dado 4+. Portata 1, danno dado +1, stordisce 1 dado del nemico. |  |
| **Rintocco** | Supporto al colpo | rosso (Forza) | Supporto, dado 1-2: +2 danni e spingi di 1. |  |

### Frusta
**Categoria:** Armi · **Costo:** 4 · **File:** `frusta.png`
- **Illustrazione:** Una frusta di cuoio schiocca nell'aria e si avvolge come un laccio attorno al polso dell'avversario.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Schiocco** | Azione | blu (Destrezza) | Portata 2. Danno 2 e attiri il nemico di 1 verso di te. |  |
| **Laccio** | Azione | blu (Destrezza) | Gittata 2, dado 1-2: stordisci il dado in mano più alto del nemico. |  |

### Lama e brocchiero
**Categoria:** Armi · **Costo:** 5 · **File:** `lama_scudo.png`
- **Illustrazione:** Uno spadaccino con spada nella destra e piccolo scudo nella sinistra taglia e copre nello stesso tempo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Taglia e copri** | Azione | rosso (Forza) o verde (Tempra) | Portata 1, danno dado -1. Scegli un lato: il dado resta come guardia per metà del suo valore. | guardia |

## Strategie (44)

### Doppio fendente
**Categoria:** Strategie · **Costo:** 1 · **File:** `doppio_fendente.png`
- **Illustrazione:** Un guerriero colpisce due volte in rapida successione, a destra e a sinistra; due scie di lama si incrociano a X.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Doppio fendente** | Azione | rosso (Forza) + rosso (Forza) | Due rossi uguali. Portata 1, danno dado +3. Mantieni l'iniziativa. |  |

### Assalto
**Categoria:** Strategie · **Costo:** 14 · **File:** `assalto.png`
- **Illustrazione:** Un guerriero lancia la carica a testa bassa con l'arma in avanti; la polvere si solleva dietro i suoi passi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Carica** | Azione | blu (Destrezza) + rosso (Forza) | Blu + rosso. Muovi col blu fino a un nemico davanti a te, poi colpisci: danno rosso +1. |  |

### Turbine d'acciaio
**Categoria:** Strategie · **Costo:** 1 · **File:** `turbine.png`
- **Illustrazione:** Un combattente ruota su se stesso con la spada tesa, creando un cerchio d'acciaio scintillante attorno al corpo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Turbine** | Azione | rosso (Forza) o blu (Destrezza) + rosso (Forza) o blu (Destrezza) + rosso (Forza) o blu (Destrezza) | Tre dadi in scala. Colpisci il nemico attorno a te da ogni lato: danno pari al dado più alto. |  |

### Passo d'ombra
**Categoria:** Strategie · **Costo:** 1 · **File:** `passo_ombra.png`
- **Illustrazione:** Un'assassina compare dietro l'avversario uscendo da un'ombra; il punto da cui è partita svanisce in fumo nero.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Passo d'ombra** | Azione | blu (Destrezza) + viola (Mente) | Blu + viola, somma 7+. Riappari accanto a un nemico entro 4, rivolto verso di lui. Mantieni l'iniziativa. |  |

### Furia cieca
**Categoria:** Strategie · **Costo:** 6 · **File:** `furia_cieca.png`
- **Illustrazione:** Un guerriero con gli occhi chiusi dalla rabbia mena colpi a raffica, senza difese, i capelli scarmigliati.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Furia cieca** | Azione | rosso (Forza) | Azzardo. Colpo pari al dado; poi peschi e tiri altri dadi rossi e li sommi. Con un 1 il colpo fallisce e quei dadi restano storditi. |  |

### Contrattacco
**Categoria:** Strategie · **Costo:** 4 · **File:** `contrattacco.png`
- **Illustrazione:** Uno spadaccino para il colpo e nello stesso movimento risponde con una riposta al petto dell'avversario.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riposta** | Reazione | rosso (Forza) + blu (Destrezza) | Reazione in mischia. Rosso + blu, somma 7+: il colpo va a vuoto, colpisci col rosso e prendi l'iniziativa. |  |

### Spallata
**Categoria:** Strategie · **Costo:** 1 · **File:** `spallata.png`
- **Illustrazione:** Un combattente colpisce con tutta la spalla il busto dell'avversario, che vola all'indietro.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Spallata** | Azione | rosso (Forza) o verde (Tempra) | Dado 5+. Danno 2, spingi il nemico di 2; se sbatte contro un ostacolo subisce 3 danni e perde il dado più alto. Mantieni l'iniziativa. |  |

### Combinazione del novizio
**Categoria:** Strategie · **Costo:** 1 · **File:** `novizio.png`
- **Illustrazione:** Un giovane apprendista esegue con impegno tre colpi in sequenza, uno, due, tre, ancora un po' goffo ma deciso.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Uno, due, tre** | Azione | qualsiasi colore + qualsiasi colore + qualsiasi colore | Tre dadi di valore 1, 2 e 3. Portata 1, danno 6, non si schiva. Mantieni l'iniziativa. |  |

### Colpi in serie
**Categoria:** Strategie · **Costo:** 2 · **File:** `in_serie.png`
- **Illustrazione:** Una sequenza di colpi rapidi mostrata come più braccia sovrapposte in movimento, ciascuno più veloce del precedente.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **In serie** | Supporto al colpo | qualsiasi colore | Supporto, dado 1: +1 danno e dopo il colpo mantieni l'iniziativa. |  |

### Sacrificio
**Categoria:** Strategie · **Costo:** 1 · **File:** `sacrificio.png`
- **Illustrazione:** Un guerriero lascia scoperto il proprio fianco a un colpo pur di affondare la lama nel cuore della guardia nemica.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sacrificio** | Libera | qualsiasi colore | Libera: il dado usato è eliminato per sempre. Liberi 2 spazi e recuperi 2 ferite. |  |

### Ritmo di battaglia
**Categoria:** Strategie · **Costo:** 5 · **File:** `ritmo_battaglia.png`
- **Illustrazione:** Un combattente danza al ritmo di un tamburo da guerra che risuona sugli spalti, i colpi scanditi a tempo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Cadenza** | Libera | qualsiasi colore + qualsiasi colore | Libera, due dadi uguali: peschi 3 dadi dal mucchio. |  |

### Cambio di guardia
**Categoria:** Strategie · **Costo:** 2 · **File:** `cambio_guardia.png`
- **Illustrazione:** Uno spadaccino passa la spada dall'alto al basso cambiando guardia di scatto, confondendo l'avversario.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Cambio di guardia** | Reazione | qualsiasi colore + qualsiasi colore | Reazione: sacrifica due dadi qualsiasi e riduci il danno della loro somma divisa per 2. |  |

### Passo rapido
**Categoria:** Strategie · **Costo:** 2 · **File:** `passo_rapido.png`
- **Illustrazione:** Piedi leggeri che si spostano in un lampo sulla sabbia, lasciando impronte ravvicinate e una scia di polvere.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Passo rapido** | Azione | blu (Destrezza) | Muovi della metà del dado (per eccesso). Mantieni l'iniziativa. |  |

### Ferocia
**Categoria:** Strategie · **Costo:** 2 · **File:** `ferocia.png`
- **Illustrazione:** Un guerriero digrigna i denti come una belva e si getta sull'avversario con le mani artigliate sull'arma.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ferocia** | Supporto al colpo | rosso (Forza) | Supporto: +metà del dado ai danni e spingi di 1. |  |

### Danza delle lame
**Categoria:** Strategie · **Costo:** 5 · **File:** `danza_lame.png`
- **Illustrazione:** Una danzatrice con due spade corte salta e taglia volteggiando, nastri di stoffa e riflessi di metallo attorno a lei.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Taglio danzante** | Azione | blu (Destrezza) | Portata 1. Danno pari al dado meno 1. Poi DEVI girare attorno al nemico di 1 esagono. |  |
| **Taglio volante** | Azione | blu (Destrezza) + blu (Destrezza) | Due blu uguali. Portata 1, danno dado +1, non si schiva. |  |

### Colpo caricato
**Categoria:** Strategie · **Costo:** 1 · **File:** `colpo_caricato.png`
- **Illustrazione:** Un guerriero porta l'arma indietro sopra la spalla, i muscoli tesi al massimo, accumulando forza per un unico colpo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo caricato** | Contatore | rosso (Forza) o verde (Tempra) | Contatore: aggiungi dadi uno alla volta. A 12 è carico: scaricalo in mischia per 8 danni. |  |

### Esecuzione
**Categoria:** Strategie · **Costo:** 2 · **File:** `esecuzione.png`
- **Illustrazione:** Un guerriero alza la spada a due mani sopra un avversario a terra, pronto al colpo finale.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Esecuzione** | Azione | qualsiasi colore + qualsiasi colore | Due dadi uguali da 5 o 6. Nemico adiacente con un quarto delle ferite o meno, colpito sul fianco o alle spalle: è a terra. |  |

### Ultimo respiro
**Categoria:** Strategie · **Costo:** 11 · **File:** `ultimo_respiro.png`
- **Illustrazione:** Un combattente morente usa l'ultimo respiro per un colpo disperato; il suo sguardo è fermo nonostante tutto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ultimo respiro** | Azione | qualsiasi colore + qualsiasi colore | Due dadi qualsiasi, eliminati per sempre. Portata 1, danno 7, non si schiva e non si para. |  |

### Disarmare
**Categoria:** Strategie · **Costo:** 1 · **File:** `disarmare.png`
- **Illustrazione:** Una lama aggancia l'elsa nemica e fa volare via la spada dell'avversario, che ruota in aria.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Disarmare** | Azione | blu (Destrezza) o rosso (Forza) | Dado 4+, nemico adiacente: il suo attacco migliore è bloccato fino a fine scambio. |  |

### Tocco di gelo
**Categoria:** Strategie · **Costo:** 4 · **File:** `gelo.png`
- **Illustrazione:** Una mano coperta di brina sfiora il braccio dell'avversario, che si ricopre di cristalli di ghiaccio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Tocco di gelo** | Azione | viola (Mente) o blu (Destrezza) | Gittata 3: il dado in mano più alto del nemico diventa 1. Mantieni l'iniziativa. |  |

### Colpo alle spalle
**Categoria:** Strategie · **Costo:** 4 · **File:** `colpo_mirato.png`
- **Illustrazione:** Un combattente colpisce alle spalle un avversario che guarda nella direzione sbagliata.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo alle spalle** | Azione | blu (Destrezza) | Portata 1, danno pari al dado; +2 se colpisci sul fianco o alle spalle. |  |

### Ira del ferito
**Categoria:** Strategie · **Costo:** 2 · **File:** `ira_ferita.png`
- **Illustrazione:** Un guerriero appena colpito si volta con occhi di fuoco e restituisce il colpo con il doppio della forza.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ira del ferito** | Azione | rosso (Forza) | Portata 1, danno pari al dado; +3 se hai metà delle ferite o meno. |  |

### Tempesta di colpi
**Categoria:** Strategie · **Costo:** 6 · **File:** `tempesta_colpi.png`
- **Illustrazione:** Una raffica di colpi rapidissimi, rappresentata come decine di lame sovrapposte in un vortice di metallo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Raffica** | Azione | rosso (Forza) o blu (Destrezza) | Dado 1-3. Portata 1, danno 2. Se il dado è 1 va direttamente in Attesa, senza occupare il token. Mantieni l'iniziativa. |  |

### Rabbia covata
**Categoria:** Strategie · **Costo:** 1 · **File:** `rabbia.png`
- **Illustrazione:** Un combattente seduto in un angolo, testa bassa, stringe l'impugnatura della spada fino a sbiancare le nocche.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Covare rabbia** | Libera | rosso (Forza) | Libera: lascia qui fino a 3 dadi rossi. Ogni dado sopra dà +1 a tutti i tuoi colpi finché non lo liberi. |  |

### Guardia ferrea
**Categoria:** Strategie · **Costo:** 2 · **File:** `guardia_ferrea.png`
- **Illustrazione:** Un guerriero con braccia e spada incrociate davanti al corpo forma una barriera impenetrabile.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Guardia ferrea** | Libera | verde (Tempra) | Libera: lascia qui fino a 2 dadi verdi. Ogni dado sopra riduce di 1 ogni colpo subito. |  |

### Somma perfetta
**Categoria:** Strategie · **Costo:** 8 · **File:** `somma_perfetta.png`
- **Illustrazione:** Due dadi che sommano sette brillano su una lama sollevata; il colpo parte nel momento perfetto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sette perfetto** | Azione | qualsiasi colore + qualsiasi colore | Due dadi con somma esattamente 7. Portata 2, danno 6, non si schiva. |  |

### Piccoli passi
**Categoria:** Strategie · **Costo:** 1 · **File:** `piccoli_passi.png`
- **Illustrazione:** Piedi che avanzano con passi brevi e misurati, guadagnando terreno senza mai perdere l'equilibrio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Piccoli passi** | Azione | blu (Destrezza) + blu (Destrezza) | Due dadi con somma 4 o meno: 4 punti movimento. Mantieni l'iniziativa. |  |

### Doppio pari
**Categoria:** Strategie · **Costo:** 3 · **File:** `doppio_pari.png`
- **Illustrazione:** Due spade gemelle colpiscono in perfetta simmetria, come uno specchio, dai due lati dell'avversario.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Doppio pari** | Azione | rosso (Forza) o blu (Destrezza) + rosso (Forza) o blu (Destrezza) | Due dadi pari. Portata 1, danno metà della somma +1. Mantieni l'iniziativa. |  |

### Colpo dispari
**Categoria:** Strategie · **Costo:** 2 · **File:** `colpo_dispari.png`
- **Illustrazione:** Un colpo storto e imprevedibile arriva da un'angolazione strana, cogliendo l'avversario di sorpresa.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo dispari** | Azione | rosso (Forza) | Dado dispari. Portata 1, danno dado +1. |  |

### Colpo in volo
**Categoria:** Strategie · **Costo:** 2 · **File:** `colpo_volo.png`
- **Illustrazione:** Un guerriero salta in alto e colpisce dall'alto verso il basso, l'arma sopra la testa, il mantello aperto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo in volo** | Supporto al colpo | blu (Destrezza) | Supporto, dado 5+: +2 danni e dopo il colpo mantieni l'iniziativa. |  |

### Postura di difesa
**Categoria:** Strategie · **Costo:** 8 · **File:** `postura.png`
- **Illustrazione:** Un combattente in posizione bassa e raccolta, arma davanti al corpo, pronto a ricevere l'attacco.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **In guardia** | Azione | verde (Tempra) o rosso (Forza) o blu (Destrezza) | Guardia: metti il dado su un lato. I colpi da quel lato perdono il valore del dado, -1 per ogni lato di distanza. Ogni colpo fermato toglie 1 al dado. | guardia |

### Colpo calibrato
**Categoria:** Strategie · **Costo:** 4 · **File:** `calibrato.png`
- **Illustrazione:** Una lama si ferma con precisione millimetrica su un punto preciso dell'armatura avversaria.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo calibrato** | Azione | rosso (Forza) o blu (Destrezza) | Portata 1. Mira un lato: danno dado +1, -1 per ogni lato di scarto se il nemico si sposta. | colpo mirato |

### Affondo e rientro
**Categoria:** Strategie · **Costo:** 2 · **File:** `affondo_rientro.png`
- **Illustrazione:** Uno schermidore affonda in avanti e in un attimo è già due passi indietro, fuori portata.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Affondo e rientro** | Azione | rosso (Forza) o blu (Destrezza) | Portata 1, danno metà del dado +1. Poi DEVI arretrare di 2. |  |

### Taglio di passaggio
**Categoria:** Strategie · **Costo:** 3 · **File:** `taglio_passaggio.png`
- **Illustrazione:** Un combattente taglia di lato mentre scivola oltre l'avversario, senza fermarsi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Taglio di passaggio** | Azione | blu (Destrezza) + rosso (Forza) | Blu + rosso. Portata 1, danno metà della somma. Poi DEVI passare oltre il nemico e voltarti verso le sue spalle. |  |

### Sgambetto
**Categoria:** Strategie · **Costo:** 1 · **File:** `sgambetto.png`
- **Illustrazione:** Un piede aggancia la caviglia dell'avversario, che perde l'equilibrio e cade all'indietro.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sgambetto** | Azione | blu (Destrezza) | Dado 1-3. Danno 1, il nemico si gira di 2 lati e ti offre il fianco. Poi DEVI spostarti di lato di 1. |  |

### Proiezione
**Categoria:** Strategie · **Costo:** 3 · **File:** `proiezione.png`
- **Illustrazione:** Un lottatore scaglia l'avversario contro una colonna di pietra dell'arena, che si crepa nell'urto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Proiezione** | Azione | rosso (Forza) + verde (Tempra) | Rosso + verde, somma 8+. Danno metà del rosso, lo scagli di 3 e gli giri la schiena. Se sbatte subisce 3 danni e perde il dado più alto. |  |

### Rompiguardia
**Categoria:** Strategie · **Costo:** 2 · **File:** `rompiguardia.png`
- **Illustrazione:** Un colpo potente sfonda la guardia incrociata dell'avversario, che allarga le braccia sbilanciato.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sfondare** | Azione | rosso (Forza) | Dado 4+. Danno metà del dado, ogni guardia nemica perde 3. Poi DEVI incalzare di 1. |  |

### Torsione
**Categoria:** Strategie · **Costo:** 1 · **File:** `torsione.png`
- **Illustrazione:** Un combattente ruota il busto e torce il braccio armato dell'avversario, costringendolo a girarsi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Torsione** | Libera | viola (Mente) o blu (Destrezza) | Libera, dado 1-2, nemico vicino: giralo di un lato a tua scelta. |  |

### Colpo di traverso
**Categoria:** Strategie · **Costo:** 5 · **File:** `traverso.png`
- **Illustrazione:** Un fendente orizzontale arriva di traverso, dal fianco, dove la guardia dell'avversario non arriva.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo di traverso** | Azione | rosso (Forza) o verde (Tempra) | Dado 3+. Danno 2 e spingi il nemico di lato di 2; se sbatte subisce 3 danni e perde il dado più alto. |  |

### Riposo tattico
**Categoria:** Strategie · **Costo:** 1 · **File:** `riposo_tattico.png`
- **Illustrazione:** Un combattente si ritira un passo dietro una colonna e riprende fiato, senza perdere d'occhio l'avversario.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Pausa tattica** | Azione | blu (Destrezza) o verde (Tempra) | Dado 1-3: cedi l'iniziativa e recupera 1 dado dall'Attesa. |  |

### Raccogliere le forze
**Categoria:** Strategie · **Costo:** 2 · **File:** `raccogliere_le_forze.png`
- **Illustrazione:** Un guerriero si ricompone, raddrizza la schiena e rimette in ordine la guardia, raccogliendo le energie.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riordina la guardia** | Azione | verde (Tempra) | Dado 1-3: libera 2 spazi occupati trasferendo i dadi in Attesa; cedi l'iniziativa. |  |

### Disciplina del duellante
**Categoria:** Strategie · **Costo:** 3 · **File:** `disciplina_del_duellante.png`
- **Illustrazione:** Una duellante si ferma un istante, ritrova la propria postura perfetta e il proprio tempo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ritrovare il tempo** | Azione | blu (Destrezza) | Dado 1-2: libera 2 spazi e manda i dadi in Attesa. Cedi l'iniziativa. |  |

### Tecnica del logoramento
**Categoria:** Strategie · **Costo:** 3 · **File:** `tecnica_del_logoramento.png`
- **Illustrazione:** Un combattente scioglie con pazienza la presa dell'avversario, dita contro dita, stancandolo poco a poco.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sciogli la presa** | Libera | rosso (Forza) o blu (Destrezza) | Libera, dado rosso o blu 1-2: sblocca 1 spazio in Attesa; il dado speso resta sul token. |  |

### Preparazione del ritorno
**Categoria:** Strategie · **Costo:** 2 · **File:** `preparazione_del_ritorno.png`
- **Illustrazione:** Un combattente controlla lacci, cinghie e lama, mettendo tutto a punto prima di tornare nella mischia.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Messa a punto** | Azione | blu (Destrezza) o viola (Mente) | Dado blu o viola 1-3. Prepara un dado nell'Attesa: quando verra recuperato, il suo nuovo valore sara almeno 4. Cedi l'iniziativa. |  |

## Equipaggiamento (5)

### Corpetto di cuoio
**Categoria:** Equipaggiamento · **Costo:** 7 · **File:** `cuoio.png`
- **Illustrazione:** Un combattente con un corpetto di cuoio leggero rotola via a terra sotto un colpo che va a vuoto.
- **Sempre attivo:** Armatura +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Rotolare via** | Reazione | blu (Destrezza) o verde (Tempra) | Armatura 1. Reazione, dado 5+: riduci il danno di 2. |  |

### Cotta di maglia
**Categoria:** Equipaggiamento · **Costo:** 11 · **File:** `maglia.png`
- **Illustrazione:** Primo piano di una cotta di maglia che ferma una lama; gli anelli si tendono ma reggono.
- **Sempre attivo:** Armatura +2

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Assorbire** | Reazione | verde (Tempra) | Armatura 2. Reazione, dado 3+: riduci il danno di 2, anche alle spalle. |  |

### Armatura a piastre
**Categoria:** Equipaggiamento · **Costo:** 12 · **File:** `piastre.png`
- **Illustrazione:** Un cavaliere in armatura a piastre completa resta in piedi come un muro d'acciaio mentre una spada gli rimbalza sulla corazza.
- **Sempre attivo:** Armatura +3, Movimento -1, Iniziativa -2

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Muro d'acciaio** | Reazione | verde (Tempra) | Armatura 3, movimento -1, iniziativa -2. Reazione: riduci il danno pari al dado. |  |

### Mantello d'ombra
**Categoria:** Equipaggiamento · **Costo:** 3 · **File:** `mantello.png`
- **Illustrazione:** Un mantello scuro si dissolve in fumo dove un attimo prima c'era il combattente; la lama nemica attraversa solo ombra.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Dissolversi** | Reazione | blu (Destrezza) o viola (Mente) | Reazione, dado pari o superiore all'attacco: il colpo va a vuoto. |  |

### Rotella
**Categoria:** Equipaggiamento · **Costo:** 6 · **File:** `rotella.png`
- **Illustrazione:** Un piccolo scudo rotondo da pugno devia un colpo di lato con un movimento secco del polso.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Guardia di rotella** | Azione | blu (Destrezza) | Guardia: il dado protegge il lato scelto, -1 per ogni lato di distanza. Ogni colpo fermato toglie 1. | guardia |

## Oggetti (11)

### Cintura del gigante
**Categoria:** Oggetti · **Costo:** 4 · **File:** `cintura_gigante.png`
- **Illustrazione:** Una cintura borchiata enorme con una fibbia a forma di pugno; chi la indossa sferra un colpo da gigante.
- **Dà al mucchio:** 1 rosso
- **Nota:** Un dado rosso in più nel mucchio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Colpo da gigante** | Supporto al colpo | rosso (Forza) | Supporto, dado 5+: +2 danni. |  |

### Stivali alati
**Categoria:** Oggetti · **Costo:** 8 · **File:** `stivali_alati.png`
- **Illustrazione:** Stivali di cuoio con piccole ali piumate alle caviglie, sollevati in un balzo sopra la sabbia.
- **Dà al mucchio:** 1 blu
- **Nota:** Un dado blu e +1 punto movimento.
- **Sempre attivo:** Movimento +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Balzo alato** | Azione | blu (Destrezza) | Dado 5+: 3 punti movimento. |  |

### Amuleto di quarzo
**Categoria:** Oggetti · **Costo:** 4 · **File:** `amuleto_quarzo.png`
- **Illustrazione:** Un amuleto di quarzo viola appeso a una catenina emana una luce soffusa sul petto del combattente.
- **Dà al mucchio:** 1 viola
- **Nota:** Un dado viola in più nel mucchio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Luce del quarzo** | Libera | viola (Mente) | Libera: alza o abbassa di 1 un tuo dado in mano. |  |

### Borraccia del pellegrino
**Categoria:** Oggetti · **Costo:** 2 · **File:** `borraccia.png`
- **Illustrazione:** Un combattente beve un sorso da una borraccia di zucca consumata, la conchiglia del pellegrino legata alla cinghia.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sorso** | Libera | verde (Tempra) | Libera, dado 1-3: recuperi 1 ferita. |  |

### Talismano del gatto
**Categoria:** Oggetti · **Costo:** 1 · **File:** `talismano_gatto.png`
- **Illustrazione:** Un talismano a forma di gatto nero con occhi di giada, appeso al collo di un combattente che scivola via illeso.
- **Dà al mucchio:** 1 blu
- **Nota:** Un dado blu e +1 all'iniziativa.
- **Sempre attivo:** Iniziativa +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sette vite** | Reazione | blu (Destrezza) | Reazione, solo con il 6: spostati in un esagono vicino libero; se il colpo non ti raggiunge più va a vuoto. |  |

### Pietra di luna
**Categoria:** Oggetti · **Costo:** 9 · **File:** `pietra_luna.png`
- **Illustrazione:** Una pietra lattiginosa che riflette la luce lunare, tenuta nel palmo aperto, con un alone argenteo.
- **Dà al mucchio:** 1 bianco
- **Nota:** Un dado bianco, vale come qualsiasi colore.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riflesso lunare** | Libera | bianco (Prodigio) | Libera, solo dado bianco: gira un tuo dado in mano sulla faccia opposta. |  |

### Sacca dei trucchi
**Categoria:** Oggetti · **Costo:** 1 · **File:** `sacca_trucchi.png`
- **Illustrazione:** Un combattente lancia una manciata di polvere dalla sacca negli occhi dell'avversario, che si copre il volto.
- **Dà al mucchio:** 1 blu

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Polvere negli occhi** | Libera | blu (Destrezza) | Libera, gittata 2: il dado in mano più alto del nemico diventa 1. |  |

### Corno di guerra
**Categoria:** Oggetti · **Costo:** 3 · **File:** `corno_guerra.png`
- **Illustrazione:** Un guerriero suona un grande corno ricurvo; le onde sonore fanno vibrare la sabbia dell'arena.
- **Dà al mucchio:** 1 rosso

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Squillo** | Libera | rosso (Forza) | Libera, dado 1: liberi 1 spazio. |  |

### Clessidra
**Categoria:** Oggetti · **Costo:** 4 · **File:** `clessidra.png`
- **Illustrazione:** Una clessidra di ottone girata da una mano guantata; la sabbia scende lenta e il tempo sembra sospeso.
- **Nota:** Puoi conservare due dadi in più per lo scambio seguente.
- **Sempre attivo:** Conserva +2

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Girare la clessidra** | Libera | qualsiasi colore | Libera, dado 1 di qualsiasi colore: libera 1 spazio, il suo dado torna nel mucchio. |  |

### Cristallo della tempesta
**Categoria:** Oggetti · **Costo:** 1 · **File:** `cristallo.png`
- **Illustrazione:** Un cristallo azzurro tenuto in alto sprigiona fulmini e vento che fanno turbinare il mantello del combattente.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Tempesta** | Contatore | viola (Mente) o blu (Destrezza) | Contatore: aggiungi un dado alla volta. A 14 è carico: scaricalo per un fulmine a gittata 4, danno 6, ignora l'armatura. |  |

### Secondo respiro
**Categoria:** Oggetti · **Costo:** 1 · **File:** `secondo_respiro.png`
- **Illustrazione:** Una fiaschetta d'argento con un liquido ambrato, stappata da un combattente che si riprende dopo un colpo duro.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Fiaschetta** | Azione | qualsiasi colore | Dado di qualsiasi colore da 1: recupera 1 dado dall'Attesa con +1 al tiro; cedi l'iniziativa. |  |

## Talenti (26)

### Guardia alta
**Categoria:** Talenti · **Costo:** 1 · **File:** `guardia_alta.png`
- **Illustrazione:** Un combattente tiene la spada alta sopra la testa, pronto a calarla, lo sguardo vigile sotto la lama.
- **Nota:** Usa i dadi blu senza produrne.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Guardia alta** | Supporto alla difesa | blu (Destrezza) | Supporto in difesa: riduci il danno di metà del dado blu (per eccesso). |  |

### Riflesso fortunato
**Categoria:** Talenti · **Costo:** 4 · **File:** `riflesso.png`
- **Illustrazione:** Un combattente inciampa per caso e proprio così evita un colpo che gli sfiora i capelli; espressione di sorpresa.
- **Nota:** Un 1 blu diventa una schivata sicura.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riflesso fortunato** | Reazione | blu (Destrezza) | Reazione, dado 1: schivi qualsiasi colpo schivabile. |  |

### Mira istintiva
**Categoria:** Talenti · **Costo:** 1 · **File:** `mira_istintiva.png`
- **Illustrazione:** Un arciere scocca senza quasi guardare, d'istinto, e la freccia trova il bersaglio.
- **Nota:** Usa i dadi blu senza produrne.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Mira istintiva** | Supporto al colpo | blu (Destrezza) | Supporto: +metà del dado blu ai danni. |  |

### Volontà di ferro
**Categoria:** Talenti · **Costo:** 1 · **File:** `ferro.png`
- **Illustrazione:** Un guerriero stremato, in ginocchio, si rialza puntando la spada a terra, mascella serrata.
- **Nota:** Usa i dadi verdi bassi senza produrne.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Volontà di ferro** | Supporto alla difesa | verde (Tempra) | Supporto in difesa, dado 1-2: riduci il danno di 3. |  |

### Sesto senso
**Categoria:** Talenti · **Costo:** 2 · **File:** `sesto_senso.png`
- **Illustrazione:** Un combattente si volta all'improvviso verso un pericolo alle sue spalle, avvertito da un brivido luminoso dietro la nuca.
- **Nota:** Trasforma un dado blu in un dado del mucchio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sesto senso** | Libera | blu (Destrezza) | Libera: prendi 1 dado dal mucchio. |  |

### Riscossa
**Categoria:** Talenti · **Costo:** 1 · **File:** `riscossa.png`
- **Illustrazione:** Un guerriero ferito si rialza dalla polvere e contrattacca con rinnovata energia, la luce che lo colpisce dall'alto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riscossa** | Libera | verde (Tempra) | Libera: i tuoi dadi storditi tornano in mano, ritirati. |  |

### Tenacia
**Categoria:** Talenti · **Costo:** 2 · **File:** `tenacia.png`
- **Illustrazione:** Un combattente con bende insanguinate stringe i denti e resta in piedi oltre ogni limite.
- **Nota:** +3 ferite massime.
- **Sempre attivo:** Vita +3

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Stringere i denti** | Reazione | verde (Tempra) | Reazione, dado 1-2: riduci il danno di 1. |  |

### Ritmo serrato
**Categoria:** Talenti · **Costo:** 9 · **File:** `ritmo.png`
- **Illustrazione:** Un combattente cambia tempo di colpo, rapidissimo, mentre l'avversario resta un passo indietro.
- **Nota:** Peschi un dado in più a ogni scambio.
- **Sempre attivo:** Ritmo +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Cambio di tempo** | Libera | blu (Destrezza) | Libera, dado 1: prendi 1 dado dal mucchio. |  |

### Fiato lungo
**Categoria:** Talenti · **Costo:** 6 · **File:** `fiato_lungo.png`
- **Illustrazione:** Un combattente espira lentamente, una nuvola di vapore nell'aria fredda, rilassando le spalle tra uno scambio e l'altro.
- **Nota:** Quando passi liberi uno spazio in più.
- **Sempre attivo:** Recupero +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Respiro** | Libera | verde (Tempra) | Libera, dado 1: libera 1 spazio, il suo dado torna nel mucchio. |  |

### Pazienza
**Categoria:** Talenti · **Costo:** 2 · **File:** `pazienza.png`
- **Illustrazione:** Un guerriero aspetta immobile con la spada abbassata, mentre l'avversario si agita e si stanca.
- **Nota:** Puoi conservare in mano un dado in più per lo scambio seguente.
- **Sempre attivo:** Conserva +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Attendere** | Libera | viola (Mente) o verde (Tempra) | Libera: alza o abbassa di 1 un tuo dado in mano. |  |

### Temerario
**Categoria:** Talenti · **Costo:** 2 · **File:** `temerario.png`
- **Illustrazione:** Un combattente provoca l'avversario a braccia aperte, petto in fuori, con un sorriso sfrontato.
- **Nota:** Il primo 1 di ogni scambio uscito spingendo la fortuna non stordisce il dado.
- **Sempre attivo:** Temerario

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Provocare** | Azione | rosso (Forza) | Dado 5+, gittata 2: stordisci il dado in mano più alto del nemico che non supera il tuo. |  |

### Niente si spreca
**Categoria:** Talenti · **Costo:** 5 · **File:** `niente_spreco.png`
- **Illustrazione:** Un combattente raccoglie al volo un'arma caduta a terra e la rimette subito in gioco.
- **Nota:** Una volta per scambio, un 1 che usi torna subito nel mucchio invece di restare sul token. Un dado da 1 entra in Attesa invece di rimanere bloccato sul token (una volta per scambio).
- **Sempre attivo:** Riciclo

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Recuperare** | Libera | qualsiasi colore | Libera, dado 1-2 di qualsiasi colore: i tuoi dadi storditi tornano in mano, ritirati. |  |

### Prodigio
**Categoria:** Talenti · **Costo:** 7 · **File:** `prodigio.png`
- **Illustrazione:** Un giovane combattente avvolto da un lampo di luce bianca, come se il talento puro gli guidasse la mano.
- **Dà al mucchio:** 1 bianco
- **Nota:** Ottieni un dado bianco: vale come qualsiasi colore.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Lampo** | Azione | bianco (Prodigio) | Solo dado bianco. Gittata 2, danno pari al dado, ignora l'armatura. |  |

### Rapido
**Categoria:** Talenti · **Costo:** 4 · **File:** `rapido.png`
- **Illustrazione:** Un combattente colpisce per primo, prima ancora che l'avversario abbia sguainato l'arma.
- **Nota:** +3 all'iniziativa e +1 punto movimento.
- **Sempre attivo:** Iniziativa +3, Movimento +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Primo colpo** | Azione | blu (Destrezza) | Dado 1-2. Portata 1, danno 2. Mantieni l'iniziativa. |  |

### Sangue di berserker
**Categoria:** Talenti · **Costo:** 3 · **File:** `berserker.png`
- **Illustrazione:** Un guerriero coperto di ferite ride mentre il sangue gli cola sul volto, i colpi sempre più violenti.
- **Nota:** Con metà delle ferite o meno, +1 danno a ogni colpo.
- **Sempre attivo:** Berserker

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Sangue agli occhi** | Supporto al colpo | rosso (Forza) | Supporto, dado 1-2: +2 danni. |  |

### Occhio di falco
**Categoria:** Talenti · **Costo:** 2 · **File:** `occhio.png`
- **Illustrazione:** Un arciere con un falco sulla spalla; i due guardano lo stesso bersaglio lontano con la stessa intensità.
- **Nota:** +1 danno agli attacchi a distanza (gittata 2 o più).
- **Sempre attivo:** Tiro +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Occhio di falco** | Supporto al colpo | blu (Destrezza) | Supporto, dado 5+: +1 danno. |  |

### Seconda aria
**Categoria:** Talenti · **Costo:** 1 · **File:** `seconda_aria.png`
- **Illustrazione:** Un combattente esausto alza lo sguardo, respira a fondo e ritrova le forze; la luce gli torna negli occhi.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Seconda aria** | Libera | verde (Tempra) + verde (Tempra) | Libera, due verdi uguali: liberi 3 spazi. |  |

### Cuore di leone
**Categoria:** Talenti · **Costo:** 3 · **File:** `cuore_leone.png`
- **Illustrazione:** Un guerriero con un leone ruggente dipinto sullo scudo avanza senza arretrare di un passo.
- **Nota:** +2 ferite massime e +1 all'iniziativa.
- **Sempre attivo:** Vita +2, Iniziativa +1

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Non arretrare** | Reazione | verde (Tempra) | Reazione, dado 4+: riduci il danno di 2 e non puoi essere spinto. |  |

### Specchio dell'anima
**Categoria:** Talenti · **Costo:** 2 · **File:** `specchio.png`
- **Illustrazione:** Un combattente guarda in uno specchio rotondo e il suo riflesso compie la stessa mossa dell'avversario.
- **Nota:** Copia un valore: coppie e scale su richiesta.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Specchio** | Libera | qualsiasi colore | Libera: un tuo dado in mano prende il valore di questo dado. |  |

### Tenere la guardia
**Categoria:** Talenti · **Costo:** 1 · **File:** `tenere.png`
- **Illustrazione:** Un combattente rinsalda la presa sull'arma e rimette a posto la guardia dopo un colpo violento.
- **Nota:** Usa i dadi verdi senza produrne.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Rinsalda** | Libera | verde (Tempra) | Libera, dado 1-3: +2 al dado di una tua guardia (massimo 6). |  |

### Passo laterale
**Categoria:** Talenti · **Costo:** 6 · **File:** `passo_laterale.png`
- **Illustrazione:** Un combattente fa un passo deciso di lato e l'attacco dell'avversario gli passa accanto senza toccarlo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Passo laterale** | Reazione | blu (Destrezza) | Reazione, dado 3+: spostati in un esagono vicino libero. Se il colpo non ti raggiunge più va a vuoto; se era mirato perde valore. |  |

### Respingere
**Categoria:** Talenti · **Costo:** 3 · **File:** `respingere.png`
- **Illustrazione:** Un combattente allontana l'avversario con una spinta decisa dello scudo, guadagnando spazio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Respingere** | Reazione | verde (Tempra) | Reazione in mischia, dado 4+: riduci di 2 e spingi via l'attaccante di 1. |  |

### Danza di guerra
**Categoria:** Talenti · **Costo:** 3 · **File:** `danza_guerra.png`
- **Illustrazione:** Un guerriero gira attorno all'avversario con passi di danza tribale, cercando l'angolo giusto per colpire.
- **Nota:** Usa i dadi blu senza produrne.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Girare attorno** | Supporto al colpo | blu (Destrezza) | Supporto: +1 danno. Poi DEVI girare attorno al nemico di 2 esagoni. |  |

### Respiro profondo
**Categoria:** Talenti · **Costo:** 2 · **File:** `respiro_profondo.png`
- **Illustrazione:** Un combattente a occhi chiusi inspira profondamente, il petto che si gonfia, l'aria attorno immobile.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Respiro profondo** | Azione | verde (Tempra) | Cedi l'iniziativa: scegli fino a 2 dadi dall'Attesa e riportali nel mucchio, ritirandoli. |  |

### Gestione del fiato
**Categoria:** Talenti · **Costo:** 2 · **File:** `gestione_del_fiato.png`
- **Illustrazione:** Un combattente espira lentamente mentre para con calma, ogni gesto misurato per non sprecare energia.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Espira** | Libera | verde (Tempra) | Libera, dado 1-2: recupera 1 dado dall'Attesa; il dado speso resta sul token. |  |

### Istinto di sopravvivenza
**Categoria:** Talenti · **Costo:** 3 · **File:** `istinto_di_sopravvivenza.png`
- **Illustrazione:** Un combattente all'angolo, ferito, con gli occhi accesi come quelli di un animale braccato, pronto a tutto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Istinto** | Azione | verde (Tempra) o blu (Destrezza) | Dado 1-2: recupera fino a 2 dadi dall'Attesa e cura 1 ferita. Cedi l'iniziativa. |  |

## Magie (12)

### Dardo arcano
**Categoria:** Magie · **Costo:** 3 · **File:** `dardo_arcano.png`
- **Illustrazione:** Un mago punta l'indice e scaglia un dardo di luce viola che sibila verso il bersaglio.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Dardo arcano** | Azione | viola (Mente) | Gittata 3, serve la vista libera. Danno metà del dado +1. |  |

### Spinta arcana
**Categoria:** Magie · **Costo:** 3 · **File:** `spinta_arcana.png`
- **Illustrazione:** Un'onda di forza invisibile, resa come aria distorta, scaglia indietro un combattente sollevando polvere.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Spinta arcana** | Azione | viola (Mente) | Gittata 3, serve la vista libera. Danno 1 e spingi il nemico di 2. |  |

### Scudo arcano
**Categoria:** Magie · **Costo:** 6 · **File:** `scudo_arcano.png`
- **Illustrazione:** Una cupola esagonale di luce azzurra si materializza attorno al mago e ferma una lama.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Scudo arcano** | Azione | viola (Mente) | Guardia sul lato scelto: i colpi da lì perdono il dado +1, -1 per ogni lato di distanza; ogni colpo fermato toglie 1. | guardia |

### Passo nella nebbia
**Categoria:** Magie · **Costo:** 5 · **File:** `passo_nebbia.png`
- **Illustrazione:** Un mago si dissolve in nebbia argentata e ricompare poco lontano, la sagoma ancora sfumata.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Passo nella nebbia** | Azione | viola (Mente) + viola (Mente) | Due viola, somma 7+. Riappari accanto a un nemico entro 4, rivolto verso di lui. Mantieni l'iniziativa. |  |

### Morsa di gelo
**Categoria:** Magie · **Costo:** 3 · **File:** `morsa_gelo.png`
- **Illustrazione:** Ghiaccio blu sale dal terreno e imprigiona le gambe dell'avversario fino alle ginocchia.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Morsa di gelo** | Libera | viola (Mente) | Libera, dado 4+, gittata 3: il dado in mano più alto del nemico diventa 1. |  |

### Catene mentali
**Categoria:** Magie · **Costo:** 3 · **File:** `catene.png`
- **Illustrazione:** Catene viola trasparenti si avvolgono attorno alla testa e alle braccia di un combattente, che si irrigidisce.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Catene mentali** | Azione | viola (Mente) | Dado 4+, gittata 3: stordisci il dado in mano più alto del nemico che non supera il tuo. |  |

### Fiammata
**Categoria:** Magie · **Costo:** 3 · **File:** `fiamma.png`
- **Illustrazione:** Un getto di fiamme arancioni esce dalle mani di un mago e investe l'avversario dietro lo scudo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Fiammata** | Azione | viola (Mente) + viola (Mente) | Due viola uguali. Gittata 2, danno 3 che ignora l'armatura. |  |

### Vortice
**Categoria:** Magie · **Costo:** 4 · **File:** `vortice.png`
- **Illustrazione:** Un turbine di vento e sabbia solleva e fa girare su se stesso un combattente al centro dell'arena.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Vortice** | Azione | viola (Mente) | Dado 5+, gittata 2. Danno 1 e il nemico si gira di 3 lati: ti mostra la schiena. |  |

### Meditazione rituale
**Categoria:** Magie · **Costo:** 3 · **File:** `meditazione_rituale.png`
- **Illustrazione:** Un mago seduto a gambe incrociate sulla sabbia, cerchi di rune luminose che ruotano lenti attorno a lui.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Meditazione** | Azione | viola (Mente) | Dado 4+: cedi l'iniziativa e recupera fino a 2 dadi dall'Attesa; +1 alle facce ottenute. |  |

### Riciclo arcano
**Categoria:** Magie · **Costo:** 4 · **File:** `riciclo_arcano.png`
- **Illustrazione:** Frammenti di un incantesimo esaurito vengono riassorbiti nelle mani del mago come scintille che tornano a lui.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Riciclo arcano** | Azione | viola (Mente) | Cedi l'iniziativa: recupera fino a 3 dadi dall'Attesa; il dado viola resta impegnato. |  |

### Cerchio della vita
**Categoria:** Magie · **Costo:** 4 · **File:** `cerchio_della_vita.png`
- **Illustrazione:** Un cerchio di luce verde si accende sotto i piedi di una sacerdotessa; foglie e germogli spuntano nella sabbia.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Cerchio della vita** | Azione | viola (Mente) + verde (Tempra) | Due dadi viola e verde, somma 7+: recupera 3 dadi dall'Attesa e cura 2 ferite; cedi l'iniziativa. |  |

### Preghiera del rientro
**Categoria:** Magie · **Costo:** 2 · **File:** `preghiera_del_rientro.png`
- **Illustrazione:** Un guerriero inginocchiato prega a mani giunte; una luce dorata scende dall'alto e lo rinvigorisce.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Preghiera del rientro** | Azione | viola (Mente) | Dado 1-3: recupera 2 dadi dall'Attesa e cedi l'iniziativa. |  |

## Segreti (10)

### Trappola a molla
**Categoria:** Segreti · **Costo:** 7 · **File:** `trappola.png`
- **Illustrazione:** Una tagliola nascosta nella sabbia scatta sulla caviglia di un combattente che avanzava ignaro.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Trappola a molla** | Segreto | rosso (Forza) o verde (Tempra) o blu (Destrezza) | Segreto. Quando ti attaccano in mischia, prima del colpo l'attaccante subisce danni pari al dado. |  |

### Agguato
**Categoria:** Segreti · **Costo:** 6 · **File:** `agguato.png`
- **Illustrazione:** Una figura acquattata dietro una colonna dell'arena attende con il pugnale pronto mentre l'avversario le passa accanto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Agguato** | Segreto | rosso (Forza) o blu (Destrezza) | Segreto. Quando il nemico finisce un movimento accanto a te, lo colpisci per il dado +1. |  |

### Pelle di pietra
**Categoria:** Segreti · **Costo:** 3 · **File:** `pelle_pietra.png`
- **Illustrazione:** La pelle di un guerriero si trasforma in pietra grigia nel punto esatto in cui una lama lo colpisce.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Pelle di pietra** | Segreto | verde (Tempra) | Segreto. Quando un colpo ti raggiunge, riduci il danno pari al dado. |  |

### Rito notturno
**Categoria:** Segreti · **Costo:** 4 · **File:** `rito.png`
- **Illustrazione:** Una figura incappucciata traccia un cerchio di simboli sotto la luna, candele attorno, preparando un rito segreto.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Rito notturno** | Segreto | viola (Mente) o verde (Tempra) | Segreto. A fine scambio liberi 2 spazi e nello scambio seguente prendi un dado in più. |  |

### Fortuna del matto
**Categoria:** Segreti · **Costo:** 9 · **File:** `fortuna_matto.png`
- **Illustrazione:** Un buffone di corte con il cappello a sonagli schiva tutto per pura fortuna, ridendo, mentre i colpi lo mancano da ogni lato.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Fortuna del matto** | Segreto | qualsiasi colore | Segreto. Quando ti attaccano si rivela e si tira un dado: 1-2 niente, 3-4 riduci il danno di 3, 5-6 il colpo va a vuoto e l'attaccante subisce 2. |  |

### Ira repressa
**Categoria:** Segreti · **Costo:** 1 · **File:** `ira.png`
- **Illustrazione:** Un guerriero dall'aria calma stringe i pugni tremanti; sotto la pelle si intravede un bagliore rosso pronto a esplodere.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ira repressa** | Segreto | rosso (Forza) | Segreto. Quando subisci danni prendi dal mucchio i 2 dadi più alti. |  |

### Bomba di fumo
**Categoria:** Segreti · **Costo:** 1 · **File:** `fumo.png`
- **Illustrazione:** Una sfera di terracotta esplode a terra in una nuvola di fumo grigio; il combattente scompare.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Bomba di fumo** | Segreto | blu (Destrezza) | Segreto. Quando ti attaccano, se il dado caricato è pari o superiore al dado d'attacco il colpo va a vuoto. |  |

### Rete nascosta
**Categoria:** Segreti · **Costo:** 6 · **File:** `rete.png`
- **Illustrazione:** Una rete coperta di sabbia si solleva di scatto e intrappola le gambe di un combattente.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Rete nascosta** | Segreto | blu (Destrezza) o verde (Tempra) | Segreto. Quando il nemico finisce un movimento accanto a te, stordisci i suoi 2 dadi in mano più alti. |  |

### Ultima risorsa
**Categoria:** Segreti · **Costo:** 5 · **File:** `ultima_risorsa.png`
- **Illustrazione:** Un combattente con le spalle al muro estrae un pugnale nascosto nello stivale, l'ultima carta da giocare.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Ultima risorsa** | Segreto | verde (Tempra) | Segreto. Quando subisci danni recuperi ferite pari al dado. |  |

### Veleno lento
**Categoria:** Segreti · **Costo:** 8 · **File:** `veleno.png`
- **Illustrazione:** Una goccia verde scivola lungo la lama di un pugnale sottile; fumo pallido si alza dal filo.

| Spazio | Tipo | Dadi | Effetto | Esagono |
|---|---|---|---|---|
| **Veleno lento** | Segreto | viola (Mente) o verde (Tempra) | Segreto. A fine scambio il nemico subisce danni pari al dado, armatura compresa. |  |
