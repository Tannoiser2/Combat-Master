# Combat Master — Ciclo dei dadi v2 (proposta di regole)

Stato: specifica progettuale, **non ancora implementata**. Base: `data/regole.md`. Obiettivo: 70% costruzione del motore, 30% gestione tattica; nessun motore deve essere automaticamente infinito, e nessun combattente deve rimanere senza una scelta utile.

## 1. Tre zone distinte
Ogni dado appartiene in ogni momento a una e una sola zona:
- **Mucchio**: dadi pronti, con faccia visibile, disponibili per la selezione fino al Ritmo.
- **In mano**: dadi selezionati per lo scambio, in attesa di essere piazzati.
- **Azioni**: dadi piazzati in spazi token, che restano occupati finché un effetto non li libera.
- **Attesa**: dadi liberati ma non ancora nuovamente disponibili.
- **Conservati / storditi / eliminati**: stati speciali mutuamente esclusivi rispetto alle altre zone, come da regole esistenti.

Invarianti: la somma dei dadi nelle zone coincide con il totale generato, meno i dadi eliminati. Nessun trasferimento crea duplicati. Le azioni che muovono dadi indicano sempre **zona sorgente, zona destinazione e momento del tiro**.

## 2. Transizioni
- **Piazzare**: Mano → Azioni, occupa lo spazio e ne risolve l'effetto.
- **Sbloccare**: Azioni → Attesa, libera lo spazio ma NON ritira il dado.
- **Recuperare**: Attesa → Mucchio, ritira ciascun dado al momento del rientro. Non libera spazi.
- **Recupero naturale**: al passaggio, il combattente può sbloccare fino a `Recupero` spazi (Azioni → Attesa); non riporta direttamente dadi nel mucchio.
- **Fine scambio**: i dadi non utilizzati in mano rientrano nel mucchio con le regole attuali; i dadi in Attesa non tornano automaticamente nel mucchio.
- **Riposo** (azione universale di sicurezza, proposta): se il combattente non riesce o non vuole agire, cede l'iniziativa e trasferisce fino a **2 dadi** da Attesa a Mucchio ritirandoli. Non infligge danno. Si può usare anche con mano vuota. Se non possiede dadi in Attesa, equivale a Passare.
- **Sblocco di emergenza** (proposta): scarta dalla mano un dado per liberare uno spazio occupato; il dado liberato passa ad Attesa e quello speso passa ad Attesa. Per compensare il vantaggio, non si può usare più di una volta per scambio.
- **Stanchezza** (da testare, NON regola fissa): un dado basso può liberare un dado alto; il dado liberato rientra in Attesa con penalità temporanea di valore, rimossa al ritiro successivo. Evitare doppia contabilità finché non è chiaro l'impatto sull'IA.

## 3. Token ed effetti
Ogni token che oggi dice «sblocca e ritira» va classificato esplicitamente:
1. **Sblocco**: sposta un dado da Azioni ad Attesa.
2. **Recupero**: sposta uno o più dadi da Attesa a Mucchio.
3. **Riciclo completo** (raro/costoso): sposta Azioni → Attesa → Mucchio in un effetto.
4. **Conversione**: altera colore/faccia/stato, ma non deve saltare zone implicitamente.
5. **Sacrificio**: sposta un dado in Eliminati, irreversibilmente se non specificato.

I token con riciclo completo sono candidati a loop: introdurre un costo, un limite per scambio o una condizione esterna.

## 4. Costruzione del personaggio
Tre assi diversi, non da sommare come statistiche di combattimento:
- **Potenza**: rendimento di una combo attivata.
- **Affidabilità**: probabilità di attivare un piano principale con dadi e vincoli reali.
- **Resilienza**: capacità di restare operativo quando gli spazi sono occupati, i dadi sono in Attesa o l'avversario interrompe il piano.

Ogni build dovrebbe possedere una **combo principale** e almeno una **combo di emergenza**. Un 1 può essere utile per sblocco, supporti, condizioni esatte, effetti di scarto e preparazione; non deve necessariamente essere un fallimento.

## 5. Regole anti-stallo e anti-loop
- **Mai duplicare dadi** durante il transito fra zone.
- Non consentire una catena di azioni gratuite capace di riciclare indefinitamente gli stessi dadi senza costo.
- La scelta Riposo deve essere visibile e spiegata nell'interfaccia, con numero di dadi in Attesa.
- Una build casuale deve avere almeno un attacco praticabile e una via ragionevole di recupero.
- Se un giocatore non infligge danni, deve poter almeno recuperare, preparare una guardia o riposizionarsi.

## 6. Interfaccia
Mostrare separatamente Mucchio, Mano, Azioni occupate e Attesa, con contatori per colore; animare il percorso del dado. Tooltip: «Sblocca: Azioni → Attesa» vs «Recupera: Attesa → Mucchio». Disabilitare e spiegare azioni non disponibili.

## 7. Test obbligatori prima della pubblicazione
1. Conservazione del numero di dadi su 10.000 transizioni casuali.
2. Nessun dado presente in due zone contemporaneamente.
3. Sblocco non concede un dado immediatamente spendibile.
4. Recupero non libera automaticamente uno spazio occupato.
5. Riposo funziona con mano vuota e non genera dadi.
6. Loop delle azioni gratuite troncati e segnalati.
7. IA in grado di scegliere Riposo e nuovi effetti di recupero.
8. Matrice incrociata di archetipi, su 30/45/60 punti e iniziativa invertita; registrare zero-attacchi, durata, stalli, scarti e uso delle combo.
9. Regressione per esagoni, guardie, segreti e salvataggi personaggi.
10. Solo dopo test verdi: aggiornare `data/regole.md`, `scripts/motore.gd`, `scripts/ia.gd`, UI e pubblicazione.

## Decisione di bilanciamento
Il 70/30 è un **obiettivo di design**, non una percentuale di vittoria da imporre. Va misurato confrontando prestazioni di build diverse con IA uguale e di decision maker diversi con build uguali, non dedotto da una sola percentuale di successi.
