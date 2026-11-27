"""Catalogo dei token della sfera: tutti i token del vecchio sistema (Combat Master a esagoni)
convertiti per la sfera, più quelli nati con la sfera.

Ogni azione è scritta per componenti (tipo, danno, spinta, svantaggi, trappola...) e il testo
si genera dai componenti, così testo e gioco dicono sempre la stessa cosa. Ogni azione ha la sua
faccia potenziata (pot), che vale quando i dadi sul token sono tutti uguali; i token dell'anello
esterno si potenziano invece con la loro condizione (cond).

Colori del vecchio sistema -> sfera: rosso (Forza) resta rosso; blu (Destrezza) -> giallo (Agilità);
verde (Tempra) -> blu (Percezione, la difesa); viola (Mente) -> viola (Percezione e Forza).

uso: python3 tools/catalogo_sfera.py   (riscrive "esterni" in data/sfera.json, tiene i costi già tarati)
"""
import json
import os

QUI = os.path.dirname(os.path.abspath(__file__))
SFERA = os.path.join(QUI, "..", "data", "sfera.json")

LETTERA = {"rosso": "r", "giallo": "g", "blu": "b"}
DUE = {"arancio": ("r", "g"), "verde": ("g", "b"), "viola": ("b", "r")}
NOMI_COL = {"r": "rosso", "g": "giallo", "b": "blu"}

# ------------------------------------------------------------------ azioni


def _az(tipo, nome, n, **kw):
    a = {"nome": nome, "tipo": tipo, "n": n}
    a.update(kw)
    return a


def colpo(nome, n=1, danno=None, piu=0, **kw):
    return _az("colpo", nome, n, danno=danno or ("somma" if n > 1 else "dado"), piu=piu, **kw)


def presa(nome, n=1, **kw):
    return _az("presa", nome, n, **kw)


def carica(nome, n=2, entra=4, danno=None, piu=0, **kw):
    return _az("colpo", nome, n, danno=danno or ("somma" if n > 1 else "dado"), piu=piu, entra=entra, **kw)


def trappola(nome, n=1, contro="tutto", **kw):
    return _az("trappola", nome, n, contro=contro, **kw)


def effetto(nome, n=1, **kw):
    return _az("effetto", nome, n, **kw)


def guardia(nome, n=1, riduci=2, **kw):
    return _az("guardia", nome, n, riduci=riduci, **kw)


# ------------------------------------------------------------------ testo dai componenti


def _num(n, uno, molti):
    return "%d %s" % (n, uno if n == 1 else molti)


def _danno(a):
    d = a.get("danno", "dado")
    piu = int(a.get("piu", 0))
    if isinstance(d, int):
        return "%d" % (d + piu)
    else:
        base = {"dado": "il dado", "somma": "la somma", "meta": "metà della somma", "quarto": "un quarto della somma"}[d]
    if piu > 0:
        base += " +%d" % piu
    elif piu < 0:
        base += " %d" % piu
    return base


def _seguiti(a, ferendo=False):
    out = []
    if a.get("spinta"):
        out.append("spinta di " + _num(a["spinta"], "esagono", "esagoni"))
    if a.get("proietta"):
        out.append("lo proietti attorno a te di " + _num(a["proietta"], "esagono", "esagoni"))
    if a.get("svant"):
        out.append(_num(a["svant"], "svantaggio", "svantaggi"))
    if a.get("togli"):
        k = int(a.get("ntogli", 1))
        quale = {"alto": "più alto", "basso": "più basso", "caso": "a caso"}[a["togli"]]
        out.append(("perde il dado %s" % quale) if k == 1 else ("perde %d dadi (%s)" % (k, quale.replace("più ", "i più "))))
    if a.get("esposto"):
        out.append("si gira e ti offre il fianco (+1 al tuo prossimo colpo)")
    if a.get("tieni"):
        out.append("lo tieni (non può muoversi)")
    if a.get("a_terra"):
        out.append("resta a terra")
    pre = "; se ferisce, " if ferendo and out else (", " if out else "")
    s = pre + ", ".join(out) if out else ""
    mie = []
    if a.get("vant"):
        mie.append("+%s" % _num(a["vant"], "vantaggio", "vantaggi"))
    if a.get("cura"):
        mie.append("recuperi " + _num(a["cura"], "ferita", "ferite"))
    if a.get("pulisci"):
        mie.append("togli i tuoi svantaggi")
    if a.get("pesca"):
        mie.append("peschi " + _num(a["pesca"], "dado", "dadi"))
    if a.get("ritocca"):
        mie.append("+1 a tutti i dadi che hai in mano")
    if a.get("rovescia"):
        mie.append("il tuo dado più basso in mano si gira sulla faccia opposta")
    if a.get("passo"):
        mie.append(("ti allontani di " if a.get("arretra") else "avanzi fino a ") + _num(a["passo"], "esagono", "esagoni"))
    if a.get("libera"):
        mie.append("ti liberi dalla presa")
    if a.get("disarma"):
        mie.append("disarma i suoi token pronti")
    if a.get("aggira"):
        mie.append("gli giri attorno di " + _num(a["aggira"], "esagono", "esagoni"))
    if a.get("arretra") and not a.get("passo"):
        mie.append("arretri di " + _num(a["arretra"], "esagono", "esagoni"))
    if a.get("iniziativa"):
        mie.append("mantieni l'iniziativa")
    if mie:
        s += ("; " if s else ", ") + ", ".join(mie)
    return s


def testo(a):
    t = a["tipo"]
    if t in ("colpo", "presa"):
        dove = "A contatto: "
        if a.get("entra"):
            dove = "Da %d esagoni: entri e " % a["entra"]
        elif a.get("alle_spalle"):
            dove = "Da 3 esagoni: salti alle sue spalle e "
        if t == "presa":
            if a.get("danno") is not None:
                s = "%safferri (%s di danno)" % (dove, _danno(a))
            else:
                s = "%safferri" % dove
            s += _seguiti(a)
        else:
            verbo = "colpo" if dove == "A contatto: " else "colpisci"
            s = "%s%s %s %s" % (dove, verbo, "da" if isinstance(a.get("danno"), int) else "con", _danno(a))
            extra = []
            if a.get("non_scarta"):
                extra.append("non si scarta")
            if a.get("non_para"):
                extra.append("non si para")
            if extra:
                s += " (" + ", ".join(extra) + ")"
            s += _seguiti(a, ferendo=True)
        return s + "."
    if t == "trappola":
        contro = {"tutto": "", "colpo": " contro i colpi", "presa": " contro le prese"}[a.get("contro", "tutto")]
        if a.get("riduci"):
            s = "Trappola%s: il colpo fa %d danni in meno" % (contro, a["riduci"])
        elif a.get("schiva"):
            s = "Trappola%s: schivi" % contro
        else:
            s = "Trappola%s: annulli l'attacco" % contro
        if a.get("danno") is not None:
            s += ", l'attaccante prende %s" % _danno(a)
        if a.get("contra"):
            s += ", e lo colpisci con la somma"
        s += _seguiti(a)
        return s + "."
    if t == "guardia":
        return "Guardia: il prossimo colpo che ricevi fa %d %s in meno%s." % (a["riduci"], "danno" if a["riduci"] == 1 else "danni", _seguiti(a))
    s = _seguiti(a).lstrip(", ").lstrip("; ")
    if not s:
        return "Nessun effetto."
    s = s[0].upper() + s[1:] + "."
    if a.get("portata"):
        s = ("A contatto: " if a["portata"] == 1 else "Entro %d esagoni: " % a["portata"]) + s[0].lower() + s[1:]
    return s


def testo_pot(a):
    p = a.get("pot", {})
    b = dict(a)
    b.update(p)
    b.pop("pot", None)
    return testo(b)


# ------------------------------------------------------------------ token


def token(id_, nome, col, azioni, freccia=1, entrambi=False, origine="", note=""):
    """Un token del mediano: una azione (singolo) o due (doppio), tutte del colore del token."""
    out = []
    for k, a in enumerate(azioni):
        a = dict(a)
        a.setdefault("pot", _pot_standard(a))
        req = []
        for i in range(a["n"]):
            if col in LETTERA:
                req.append(LETTERA[col])
            else:
                req.append(DUE[col][i % 2])
        out.append({"nome": a["nome"], "req": req, "freccia": a.get("freccia", freccia), "a": a})
    return {"id": id_, "nome": nome, "col": col, "anello": 2, "azioni": out, "entrambi": entrambi, "origine": origine}


def esterno(id_, nome, coppia, azioni, cond, freccia=1, origine=""):
    """Un token dell'anello esterno: due azioni, la prima del colore base e la seconda del composto."""
    out = []
    for k, a in enumerate(azioni):
        a = dict(a)
        a.setdefault("pot", _pot_standard(a))
        out.append({"nome": a["nome"], "req": ["x"] * a["n"], "freccia": a.get("freccia", freccia), "a": a, "col": coppia[k]})
    return {"id": id_, "nome": nome, "col": coppia[0] + "-" + coppia[1], "coppia": list(coppia), "anello": 3,
            "azioni": out, "cond": cond, "origine": origine}


def _pot_standard(a):
    t = a["tipo"]
    if t in ("colpo", "presa"):
        if isinstance(a.get("danno"), int):
            return {"danno": a["danno"] + 2}
        if a.get("danno") is not None or t == "colpo":
            return {"piu": int(a.get("piu", 0)) + 2}
        return {"svant": int(a.get("svant", 0)) + 1}
    if t == "trappola":
        if a.get("proietta"):
            return {"proietta": a["proietta"] + 1}
        if a.get("riduci"):
            return {"riduci": a["riduci"] + 2}
        return {"svant": int(a.get("svant", 0)) + 1}
    if t == "guardia":
        return {"riduci": a["riduci"] + 1}
    for k in ("cura", "pesca", "svant", "vant"):
        if a.get(k):
            return {k: a[k] + 1}
    return {"vant": int(a.get("vant", 0)) + 1}


# condizioni dei token esterni: chiave -> testo
COND = {
    "uguali": "i due dadi delle sue metà sono uguali",
    "alto": "sei più in alto dell'avversario",
    "a_terra": "l'avversario è a terra",
    "spalle": "sei alle spalle dell'avversario",
    "ferito": "hai metà delle ferite o meno",
    "vantaggi": "hai almeno 3 vantaggi",
    "catena": "le due metà si caricano nello stesso scambio",
    "presa": "l'avversario ti tiene o lo tieni tu",
    "svantaggi": "l'avversario ha almeno 2 svantaggi",
}

# ------------------------------------------------------------------ il catalogo

R, G, B = "rosso", "giallo", "blu"
AR, VE, VI = "arancio", "verde", "viola"

MEDIANO = [
    # ---- nati con la sfera
    token("calcio_girato", "Calcio girato", R, [colpo("Calcio girato", piu=2), colpo("Spazzata bassa", danno=1, svant=2, togli="basso", piu=0)]),
    token("raffica", "Raffica di pugni", R, [colpo("Raffica di pugni", n=2, piu=1, iniziativa=True)]),
    token("gomitata", "Gomitata", R, [colpo("Gomitata", piu=1, svant=2, togli="alto", freccia=2), colpo("Ginocchiata", piu=1)]),
    token("spallata_s", "Spallata", R, [colpo("Spallata", spinta=2, svant=1)]),
    token("carica_toro", "Carica del toro", AR, [carica("Carica del toro", n=2, entra=4), colpo("Spinta del toro", n=2, spinta=2, svant=1)]),
    token("calcio_volante", "Calcio volante", AR, [carica("Calcio volante", n=2, entra=4, piu=2)]),
    token("affondo", "Affondo e rientro", AR, [carica("Affondo e rientro", n=2, entra=2, piu=1, arretra=1)]),
    token("sgambetto", "Sgambetto", AR, [colpo("Sgambetto", n=2, danno="quarto", piu=1, svant=2, togli="basso", a_terra=True)]),
    token("balzo", "Balzo", G, [colpo("Balzo", entra=3, piu=-3, vant=1, freccia=2), trappola("Passo indietro", schiva=True, vant=1, danno=1, proietta=1)]),
    token("passi_danza", "Passi di danza", G, [trappola("Passi di danza", n=2, schiva=True, vant=1, danno=2)]),
    token("salto_mortale", "Salto mortale", G, [colpo("Salto mortale", alle_spalle=True, piu=-4, freccia=2)]),
    token("irimi", "Irimi", VE, [trappola("Irimi", n=2, vant=3, danno=1, svant=1, iniziativa=True, aggira=2),
                                  trappola("Irimi nage", n=2, danno="meta", piu=-1, proietta=2, a_terra=True, freccia=2)]),
    token("tenkan", "Tenkan", VE, [trappola("Tenkan", n=2, vant=1, danno=1, svant=1, togli="caso"),
                                    trappola("Tenkan e ukemi", n=2, vant=1, pulisci=True, cura=2)]),
    token("uscire_linea", "Uscire dalla linea", VE, [trappola("Uscire dalla linea", n=2, schiva=True, vant=1, danno=2)]),
    token("ukemi", "Ukemi", VE, [trappola("Ukemi", n=2, vant=1, pulisci=True, cura=2)]),
    token("guardia_ferrea", "Guardia ferrea", B, [guardia("Guardia ferrea", riduci=2)]),
    token("respiro", "Respiro profondo", B, [effetto("Respiro profondo", cura=2, pulisci=True), effetto("Sguardo fermo", svant=2, togli="alto", vant=1)]),
    token("provocazione", "Provocazione", B, [effetto("Provocazione", svant=2, togli="alto", vant=1)]),
    token("calma", "Calma interiore", B, [effetto("Calma interiore", pesca=2)]),
    token("kote_gaeshi", "Kote gaeshi", VI, [trappola("Kote gaeshi", n=2, danno="meta", proietta=2, a_terra=True),
                                              trappola("Kote a terra", n=2, danno="quarto", svant=1, togli="caso")], entrambi=True),
    token("ikkyo", "Ikkyo", VI, [trappola("Ikkyo", n=2, contro="presa", danno="quarto", svant=1, togli="caso", tieni=True)]),
    token("kaiten_nage", "Kaiten nage", VI, [trappola("Kaiten nage", n=2, danno="meta", proietta=2, a_terra=True, freccia=2)], entrambi=True),
    token("contrattacco", "Contrattacco", VI, [trappola("Contrattacco", n=2, contro="colpo", riduci=3, contra=True)]),

    # ---- Forza (rosso): attributi del vecchio sistema, due azioni
    token("forza", "Forza del soldato", R, [colpo("Colpo a mani nude"), colpo("Spintone", danno=1, spinta=1)], origine="forza"),
    token("furia", "Forza del berserker", R, [colpo("Colpo cieco", danno=3), effetto("Urlo di guerra", pesca=1, vant=1)], origine="furia"),
    token("potenza", "Forza del colosso", R, [colpo("Schianto", piu=1, spinta=1, freccia=2), colpo("Sfondare la guardia", piu=1, svant=1)], origine="potenza"),
    token("lottatore", "Forza del lottatore", R, [presa("Afferrare", danno=1, togli="alto", tieni=True), presa("Rovesciare", danno=2, esposto=True)], origine="presa"),
    token("boscaiolo", "Forza del boscaiolo", R, [colpo("Colpo d'ascia", piu=1, freccia=2), colpo("Spaccare la guardia", danno=1, svant=2)], origine="boscaiolo"),
    token("portatore", "Forza del portatore", R, [colpo("Spinta", danno=1, spinta=2), effetto("Riprendere il carico", pesca=1)], origine="portatore"),
    token("pugile", "Forza del pugile", R, [colpo("Diretto", piu=1, iniziativa=True), colpo("Montante", togli="alto", freccia=2)], origine="pugile"),
    token("gladiatore", "Forza del gladiatore", R, [colpo("Colpo da arena", aggira=1), effetto("Ruggito della folla", svant=1, togli="alto")], origine="gladiatore"),
    token("fabbro", "Forza del fabbro", R, [colpo("Martellata", piu=2, freccia=2), effetto("Temprare", ritocca=True)], origine="fabbro"),
    token("toro", "Forza del toro", R, [carica("Carica del toro rosso", n=2, entra=3), colpo("Incornata", danno=2, spinta=2, svant=1)], origine="toro"),
    # Forza: strategie e talenti a una azione
    token("furia_cieca", "Furia cieca", R, [colpo("Furia cieca", n=2, piu=1, freccia=2)], origine="furia_cieca"),
    token("ferocia", "Ferocia", R, [colpo("Ferocia", piu=1, spinta=1)], origine="ferocia"),
    token("ira_ferita", "Ira del ferito", R, [colpo("Ira del ferito", piu=1, svant=1)], origine="ira_ferita"),
    token("colpo_dispari", "Colpo dispari", R, [colpo("Colpo dispari", piu=1)], origine="colpo_dispari"),
    token("rompiguardia", "Rompiguardia", R, [colpo("Sfondare", danno="meta", svant=2)], origine="rompiguardia"),
    token("rabbia", "Rabbia covata", R, [effetto("Covare rabbia", vant=2)], origine="rabbia"),
    token("berserker", "Sangue di berserker", R, [colpo("Sangue agli occhi", piu=2, freccia=2)], origine="berserker"),
    token("temerario", "Temerario", R, [effetto("Provocare", svant=1, togli="alto", portata=2)], origine="temerario"),
    token("att13", "Colpo diretto alla testa", R, [colpo("Colpo diretto alla testa", piu=0, svant=1)], origine="att13"),
    token("att15", "Colpo all'addome", R, [colpo("Colpo all'addome", piu=-1, togli="alto")], origine="att15"),
    token("att18", "Colpo con colpo", R, [colpo("Colpo con colpo", n=2, danno="somma", non_scarta=True)], origine="att18"),

    # ---- Agilità (giallo): dalla vecchia Destrezza
    token("schermidore", "Agilità dello schermidore", G, [effetto("Muoviti", passo=2, vant=1), trappola("Schivata", n=1, schiva=True, vant=1)], origine="agilita"),
    token("ladro", "Agilità del ladro", G, [colpo("Colpo fulmineo", piu=0, iniziativa=True), trappola("Balzo indietro", schiva=True, arretra=1)], origine="velocita"),
    token("danzatore", "Agilità del danzatore", G, [colpo("Taglio girando", danno="meta", aggira=2), effetto("Passo di danza", passo=2, iniziativa=True)], origine="equilibrio"),
    token("gatto", "Agilità del gatto", G, [trappola("Scatto di lato", schiva=True, vant=1), effetto("Riposizionarsi", passo=1, iniziativa=True)], origine="riflessi"),
    token("cecchino", "Agilità del cecchino", G, [colpo("Colpo di gomito", danno=2, non_scarta=True), effetto("Prendere le distanze", passo=2, arretra=2, iniziativa=True)], origine="precisione"),
    token("cacciatore", "Agilità del cacciatore", G, [trappola("Schivata d'istinto", schiva=True, danno=1), colpo("Colpo nel varco", piu=1, non_scarta=True)], origine="istinto"),
    token("giocoliere", "Agilità del giocoliere", G, [effetto("Ritocco", ritocca=True), trappola("Passo svelto", schiva=True, vant=1)], origine="destrezza"),
    token("acrobata", "Agilità dell'acrobata", G, [effetto("Capriola", passo=3, vant=1, iniziativa=True), colpo("Calcio rotante", danno=2, esposto=True)], origine="acrobata"),
    token("borseggiatore", "Agilità del borseggiatore", G, [effetto("Sfilare", togli="alto", portata=1), effetto("Mano lesta", pesca=1)], origine="borseggiatore"),
    token("passo_rapido", "Passo rapido", G, [effetto("Passo rapido", passo=2, iniziativa=True)], origine="passo_rapido"),
    token("riflesso", "Riflesso fortunato", G, [trappola("Riflesso fortunato", schiva=True, vant=2)], origine="riflesso"),
    token("rapido", "Rapido", G, [colpo("Primo colpo", danno=2, iniziativa=True)], origine="rapido"),
    token("colpo_volo", "Colpo in volo", G, [colpo("Colpo in volo", entra=2, piu=1, iniziativa=True)], origine="colpo_volo"),
    token("piccoli_passi", "Piccoli passi", G, [effetto("Piccoli passi", n=2, passo=4, iniziativa=True)], origine="piccoli_passi"),
    token("passo_laterale", "Passo laterale", G, [trappola("Passo laterale", schiva=True, vant=1, aggira=1)], origine="passo_laterale"),
    token("colpo_mirato", "Colpo alle spalle", G, [colpo("Colpo alle spalle", aggira=2, piu=0)], origine="colpo_mirato"),
    token("sgambetto_v", "Sgambetto del cortile", G, [colpo("Sgambetto", danno=1, esposto=True, aggira=1)], origine="sgambetto"),
    token("sesto_senso", "Sesto senso", G, [effetto("Sesto senso", pesca=1)], origine="sesto_senso"),

    # ---- Percezione (blu): dalla vecchia Tempra, la difesa
    token("veterano", "Percezione del veterano", B, [trappola("Incassare", riduci=3), effetto("Rigenerarsi", n=2, cura=3)], origine="tempra"),
    token("legionario", "Percezione del legionario", B, [effetto("Riprendere fiato", pesca=1, pulisci=True), trappola("Respinta", contro="colpo", riduci=2, spinta=1)], origine="resistenza"),
    token("monaco", "Percezione del monaco", B, [effetto("Ostinazione", pulisci=True, vant=1), trappola("Non cedere", riduci=2)], origine="volonta"),
    token("gigante", "Percezione del gigante", B, [guardia("Pelle dura", riduci=1), colpo("Spinta di peso", danno=2, spinta=2, freccia=2)], origine="costituzione"),
    token("montanaro", "Percezione del montanaro", B, [effetto("Fiato di montagna", pesca=1), guardia("Roccia", riduci=2)], origine="montanaro"),
    token("marinaio", "Percezione del marinaio", B, [trappola("Gamba ferma", riduci=2), effetto("Rollio", rovescia=True)], origine="marinaio"),
    token("orso", "Percezione dell'orso", B, [presa("Abbraccio", n=2, danno="somma", togli="alto", tieni=True), guardia("Pelliccia", riduci=1)], origine="orso"),
    token("penitente", "Percezione del penitente", B, [effetto("Sopportare", cura=2), trappola("Carne dura", riduci=2)], origine="penitente"),
    token("guardiano", "Percezione del guardiano", B, [guardia("Muro", riduci=2), trappola("Non passare", contro="colpo", riduci=2, spinta=1)], origine="guardiano"),
    token("corridore", "Percezione del corridore", B, [effetto("Lunga corsa", passo=3), trappola("Reggere il colpo", riduci=2)], origine="corridore"),
    token("cambio_guardia", "Cambio di guardia", B, [trappola("Cambio di guardia", n=2, riduci=4)], origine="cambio_guardia"),
    token("guardia_alta", "Guardia alta", B, [trappola("Guardia alta", riduci=3)], origine="guardia_alta"),
    token("ferro", "Volontà di ferro", B, [trappola("Volontà di ferro", riduci=3, pulisci=True)], origine="ferro"),
    token("riscossa", "Riscossa", B, [effetto("Riscossa", pesca=1, pulisci=True)], origine="riscossa"),
    token("tenacia", "Tenacia", B, [trappola("Stringere i denti", riduci=2, vant=1)], origine="tenacia"),
    token("fiato_lungo", "Fiato lungo", B, [effetto("Respiro", cura=1, pesca=1)], origine="fiato_lungo"),
    token("seconda_aria", "Seconda aria", B, [effetto("Seconda aria", n=2, cura=2, pesca=1)], origine="seconda_aria"),
    token("cuore_leone", "Cuore di leone", B, [trappola("Non arretrare", riduci=2, vant=1)], origine="cuore_leone"),
    token("tenere", "Tenere la guardia", B, [guardia("Rinsalda", riduci=1, vant=1)], origine="tenere"),
    token("respingere", "Respingere", B, [trappola("Respingere", contro="colpo", riduci=2, spinta=1)], origine="respingere"),
    token("respiro_profondo_v", "Respiro del vecchio maestro", B, [effetto("Respiro del maestro", cura=2)], origine="respiro_profondo"),
    token("gestione_fiato", "Gestione del fiato", B, [effetto("Espira", pesca=1)], origine="gestione_del_fiato"),
    token("raccogliere", "Raccogliere le forze", B, [effetto("Raccogliere le forze", pesca=2)], origine="raccogliere_le_forze"),
    token("sopravvivenza", "Istinto di sopravvivenza", B, [effetto("Istinto", cura=1, pesca=1)], origine="istinto_di_sopravvivenza"),

    # ---- Forza e Agilità (arancio)
    token("assalto", "Assalto", AR, [carica("Carica", n=2, entra=4, piu=1)], origine="assalto"),
    token("spallata", "Spallata di corsa", AR, [colpo("Spallata di corsa", n=2, danno=2, spinta=2, iniziativa=True)], origine="spallata"),
    token("tempesta", "Tempesta di colpi", AR, [colpo("Raffica", danno=2, iniziativa=True)], origine="tempesta_colpi"),
    token("doppio_pari", "Doppio pari", AR, [colpo("Doppio pari", n=2, danno="meta", piu=1, iniziativa=True)], origine="doppio_pari"),
    token("calibrato", "Colpo calibrato", AR, [colpo("Colpo calibrato", piu=1, non_scarta=True)], origine="calibrato"),
    token("affondo_v", "Affondo e rientro del duellante", AR, [carica("Affondo", n=1, entra=2, danno="dado", piu=0, arretra=2)], origine="affondo_rientro"),
    token("traverso", "Colpo di traverso", AR, [colpo("Colpo di traverso", danno=2, spinta=2, esposto=True)], origine="traverso"),
    token("danza_guerra", "Danza di guerra", AR, [colpo("Girare attorno", piu=1, aggira=2)], origine="danza_guerra"),
    token("logoramento", "Tecnica del logoramento", AR, [effetto("Sciogli la presa", libera=True, vant=1)], origine="tecnica_del_logoramento"),
    token("att14", "Colpo circolare alla testa", AR, [colpo("Colpo circolare alla testa", piu=-1, esposto=True)], origine="att14"),
    token("att17", "Presa con colpo", AR, [presa("Presa con colpo", n=2, danno="dado", togli="alto", tieni=True)], origine="att17"),

    # ---- Agilità e Percezione (verde)
    token("riposo_tattico", "Riposo tattico", VE, [effetto("Pausa tattica", pesca=1, cura=1)], origine="riposo_tattico"),
    token("disciplina", "Disciplina del duellante", VE, [effetto("Ritrovare il tempo", pesca=1, vant=1)], origine="disciplina_del_duellante"),
    token("preparazione", "Preparazione del ritorno", VE, [effetto("Messa a punto", ritocca=True, vant=1)], origine="preparazione_del_ritorno"),
    token("torsione", "Torsione", VE, [effetto("Torsione", esposto=True, svant=1, portata=1)], origine="torsione"),
    token("pazienza", "Pazienza", VE, [effetto("Attendere", ritocca=True)], origine="pazienza"),
    token("cammino", "Cammino del vento", VE, [trappola("Cammino del vento", n=2, schiva=True, vant=2, aggira=2)]),

    # ---- Percezione e Forza (viola): la vecchia Mente e le immobilizzazioni
    token("tattico", "Mente del tattico", VI, [effetto("Intimidire", svant=1, togli="alto", portata=4), trappola("Leggere la mossa", riduci=3)], origine="mente"),
    token("imbroglione", "Mente dell'imbroglione", VI, [effetto("Finta", togli="alto", iniziativa=True, portata=3), effetto("Rovescio", rovescia=True)], origine="astuzia"),
    token("stratega", "Mente dello stratega", VI, [effetto("Eco della mente", ritocca=True, vant=1), guardia("Anticipare", riduci=2)], origine="intelletto"),
    token("veggente", "Mente del veggente", VI, [trappola("Vedere il colpo", riduci=3, vant=1), effetto("Sogno premonitore", pesca=1)], origine="veggente"),
    token("azzardo", "Mente del giocatore d'azzardo", VI, [effetto("Puntata", rovescia=True), effetto("Bluff", togli="caso", portata=2)], origine="azzardo"),
    token("maestro_armi", "Mente del maestro d'armi", VI, [colpo("Lezione", piu=1, vant=1), effetto("Studio", ritocca=True)], origine="maestro"),
    token("ipnotista", "Mente dell'ipnotista", VI, [effetto("Sguardo fisso", togli="alto", svant=1, portata=2), effetto("Suggestione", esposto=True, portata=2)], origine="ipnotista"),
    token("cacciatore_taglie", "Mente del cacciatore di taglie", VI, [guardia("Prevedere", riduci=2), effetto("Braccare", esposto=True, svant=1, portata=2)], origine="cacciatore_taglie"),
    token("monaco_guerriero", "Mente del monaco guerriero", VI, [effetto("Calma", pesca=1, pulisci=True), colpo("Palmo", danno=2, spinta=1)], origine="monaco_guerriero"),
    token("proiezione_v", "Proiezione", VI, [presa("Proiezione", n=2, danno="meta", proietta=3, a_terra=True, freccia=2)], entrambi=True, origine="proiezione"),
    token("specchio", "Specchio dell'anima", VI, [effetto("Specchio", ritocca=True)], origine="specchio"),
    # i 18 attacchi del libro: prese (viola, contro di loro valgono le trappole contro le prese)
    token("att01", "Presa al polso", VI, [presa("Presa al polso", danno=1, togli="caso")], origine="att01"),
    token("att02", "Presa al polso in diagonale", VI, [presa("Presa al polso in diagonale", danno=1, togli="caso", esposto=True)], origine="att02"),
    token("att03", "Due mani su un braccio", VI, [presa("Due mani su un braccio", n=2, danno=1, togli="caso", ntogli=2)], origine="att03"),
    token("att04", "Presa alle due braccia", VI, [presa("Presa alle due braccia", n=2, danno=1, togli="caso", ntogli=2, svant=1)], entrambi=True, origine="att04"),
    token("att05", "Presa alla spalla", VI, [presa("Presa alla spalla", danno=1, svant=1)], origine="att05"),
    token("att06", "Presa alle due spalle", VI, [presa("Presa alle due spalle", n=2, danno=2, svant=2)], origine="att06"),
    token("att07", "Polsi da dietro", VI, [presa("Polsi da dietro", n=2, danno=1, togli="caso", ntogli=2, tieni=True)], origine="att07"),
    token("att08", "Gomiti da dietro", VI, [presa("Gomiti da dietro", n=2, danno=1, togli="caso", ntogli=2, svant=1)], origine="att08"),
    token("att09", "Spalle da dietro", VI, [presa("Spalle da dietro", danno=1, svant=2)], origine="att09"),
    token("att10", "Strangolamento", VI, [presa("Strangolamento", n=2, danno="dado", svant=1, tieni=True)], entrambi=True, origine="att10"),
    token("att11", "Cintura alta da dietro", VI, [presa("Cintura alta da dietro", n=2, danno=1, togli="caso", ntogli=3)], origine="att11"),
    token("att12", "Cintura bassa da dietro", VI, [presa("Cintura bassa da dietro", n=2, danno=1, togli="caso", ntogli=2, svant=1)], origine="att12"),
    token("att16", "Presa con presa", VI, [presa("Presa con presa", n=2, danno=1, togli="caso", ntogli=2, svant=1)], origine="att16"),
    # le 7 immobilizzazioni (trappole viola)
    token("tec_i1", "Controllo del braccio", VI, [trappola("Controllo del braccio", n=2, danno=1, svant=2, togli="caso", ntogli=2, tieni=True)], origine="tec_i1"),
    token("tec_i2", "Leva del polso piegato", VI, [trappola("Leva del polso piegato", n=2, contro="presa", danno=1, svant=2, togli="caso", ntogli=2)], origine="tec_i2"),
    token("tec_i3", "Torsione del polso in alto", VI, [trappola("Torsione del polso in alto", n=2, contro="presa", danno=2, svant=1, togli="caso")], origine="tec_i3"),
    token("tec_i4", "Pressione sull'avambraccio", VI, [trappola("Pressione sull'avambraccio", n=2, danno=1, svant=2, togli="alto")], origine="tec_i4"),
    token("tec_i5", "Leva del gomito disteso", VI, [trappola("Leva del gomito disteso", contro="colpo", danno=1, svant=2)], origine="tec_i5"),
    token("tec_i6", "Chiave al gomito sul petto", VI, [trappola("Chiave al gomito sul petto", n=2, danno=2, svant=1, togli="caso", tieni=True)], origine="tec_i6"),
    token("tec_i7", "Leva alta ai quattro lati", VI, [trappola("Leva alta ai quattro lati", n=2, contro="presa", danno=1, svant=2, togli="caso", ntogli=2)], origine="tec_i7"),
]

# le 28 proiezioni del libro (verdi: Agilità e Percezione). Contro chi valgono (prese, colpi o tutto),
# quanto proiettano e quanto fanno male vengono dagli attacchi del vecchio regolamento.
PROIEZIONI = [
    ("tec_p1", "Proiezione a spirale", "tutto", 2, 1, 2), ("tec_p2", "Proiezione ai quattro lati", "presa", 1, 1, 2),
    ("tec_p3", "Proiezione rotatoria", "tutto", 2, 1, 1), ("tec_p4", "Proiezione d'anca", "presa", 1, 2, 2),
    ("tec_p5", "Cielo e terra", "presa", 2, 1, 1), ("tec_p6", "Torsione del polso", "presa", 1, 1, 1),
    ("tec_p7", "Spinta al collo", "presa", 2, 0, 1), ("tec_p8", "Proiezione del respiro", "colpo", 2, 0, 1),
    ("tec_p9", "Proiezione entrando", "presa", 1, 1, 1), ("tec_p10", "Caduta d'angolo", "presa", 1, 1, 1),
    ("tec_p11", "Proiezione dal basso", "tutto", 1, 1, 1), ("tec_p12", "Braccio in alto", "colpo", 1, 1, 1),
    ("tec_p13", "Raccolta delle gambe", "presa", 1, 1, 2), ("tec_p14", "Braccia incrociate", "presa", 2, 1, 1),
    ("tec_p15", "Ruota completa", "presa", 2, 1, 1), ("tec_p16", "Doppia estensione", "presa", 2, 1, 2),
    ("tec_p17", "Trascinamento a terra", "presa", 1, 0, 1), ("tec_p18", "Caduta all'indietro circolare", "tutto", 2, 1, 2),
    ("tec_p19", "Sotto il baricentro", "presa", 1, 1, 1), ("tec_p20", "Taglio orizzontale", "presa", 2, 1, 1),
    ("tec_p21", "Arco sopra la spalla", "presa", 2, 1, 1), ("tec_p22", "Quattro lati da dietro", "presa", 1, 1, 1),
    ("tec_p23", "Sopra la schiena", "presa", 2, 1, 1), ("tec_p24", "Caduta distesa", "presa", 1, 0, 1),
    ("tec_p25", "Proiezione in diagonale", "colpo", 1, 1, 1), ("tec_p26", "Ribaltamento dal basso", "tutto", 1, 1, 2),
    ("tec_p27", "Grande rotazione", "presa", 3, 1, 1), ("tec_p28", "Proiezione universale", "tutto", 2, 1, 2),
]
for pid, nome, contro, pr, piu, n in PROIEZIONI:
    MEDIANO.append(token(pid, nome, VE, [trappola(nome, n=n, contro=contro, danno="meta" if n > 1 else "dado", piu=piu - (2 if n == 1 else 0),
                                                   proietta=pr, a_terra=True, freccia=2 if n > 1 else 1)], origine=pid))

ESTERNO = [
    # rosso | arancio
    esterno("assalto_finale", "Assalto finale", ("rosso", "arancio"),
            [colpo("Colpo di grazia", n=1, piu=2, svant=1), carica("Ultima carica", n=1, entra=4, piu=2, spinta=1)], "ferito", origine="ultimo_respiro"),
    esterno("atemi", "Atemi decisivo", ("rosso", "arancio"),
            [colpo("Atemi al plesso", n=1, piu=2, svant=2, togli="alto"), carica("Entrata decisa", n=1, entra=2, piu=1, a_terra=True)], "uguali"),
    esterno("furia_del_toro", "Furia del toro", ("rosso", "arancio"),
            [colpo("Corna basse", n=1, piu=1, spinta=2), carica("Travolgere", n=1, entra=4, piu=1, a_terra=True)], "alto", origine="furia_cieca"),
    # arancio | giallo
    esterno("turbine", "Turbine", ("arancio", "giallo"),
            [colpo("Calcio a turbine", n=1, piu=2, aggira=2), effetto("Danza del turbine", vant=2, iniziativa=True)], "catena"),
    esterno("volo_della_gru", "Volo della gru", ("arancio", "giallo"),
            [carica("Calcio dall'alto", n=1, entra=3, piu=2), colpo("Atterraggio alle spalle", n=1, alle_spalle=True, piu=0)], "alto"),
    esterno("zanshin", "Zanshin", ("arancio", "giallo"),
            [effetto("Mente presente", vant=2, cura=1), effetto("Corpo pronto", pesca=1, iniziativa=True)], "vantaggi"),
    # giallo | verde
    esterno("kokyu_nage", "Kokyu nage", ("giallo", "verde"),
            [trappola("Respiro che svuota", n=1, schiva=True, vant=1), trappola("Kokyu nage", n=1, danno="dado", proietta=2, a_terra=True)], "catena"),
    esterno("fortuna_matto", "Fortuna del matto", ("giallo", "verde"),
            [trappola("Riflesso del matto", n=1, schiva=True, danno=2), effetto("Risata", vant=2, pulisci=True)], "ferito", origine="fortuna_matto"),
    esterno("passo_ombra", "Passo d'ombra", ("giallo", "verde"),
            [effetto("Sparire", passo=3, iniziativa=True), colpo("Riapparire alle spalle", n=1, alle_spalle=True, piu=1)], "spalle"),
    # verde | blu
    esterno("shiho_nage", "Shiho nage", ("verde", "blu"),
            [trappola("Taglio ai quattro lati", n=1, danno="dado", proietta=1, a_terra=True), trappola("Chiusura", n=1, svant=1, togli="caso")], "presa"),
    esterno("ritorno", "Ritorno al centro", ("verde", "blu"),
            [effetto("Ritorno al centro", pesca=2), effetto("Centro calmo", cura=2, pulisci=True)], "ferito"),
    esterno("ultima_risorsa", "Ultima risorsa", ("verde", "blu"),
            [trappola("Ultima risorsa", n=1, riduci=4, cura=1), effetto("Rialzarsi dentro", cura=3)], "ferito", origine="ultima_risorsa"),
    # blu | viola
    esterno("kiai", "Kiai del maestro", ("blu", "viola"),
            [effetto("Kiai", disarma=True, svant=2), effetto("Sguardo del maestro", togli="alto", vant=2, portata=3)], "vantaggi"),
    esterno("juji_nage", "Juji nage", ("blu", "viola"),
            [trappola("Braccia in croce", n=1, contro="presa", danno="dado", togli="caso"), trappola("Juji nage", n=1, danno="dado", proietta=1, a_terra=True)], "presa"),
    esterno("ira_repressa", "Ira repressa", ("blu", "viola"),
            [trappola("Incassare in silenzio", n=1, riduci=3, pesca=1), colpo("Esplodere", n=1, piu=3)], "ferito", origine="ira"),
    # viola | rosso
    esterno("tenchi_nage", "Tenchi nage", ("viola", "rosso"),
            [trappola("Cielo", n=1, contro="presa", svant=1, togli="caso"), colpo("Terra", n=1, danno="dado", proietta=3, a_terra=True)], "svantaggi"),
    esterno("agguato", "Agguato", ("viola", "rosso"),
            [trappola("Attesa nascosta", n=1, contro="colpo", riduci=2, contra=True), colpo("Colpo dall'ombra", n=1, piu=2, non_scarta=True)], "spalle", origine="agguato"),
    esterno("somma_perfetta", "Somma perfetta", ("viola", "rosso"),
            [effetto("Calcolo", ritocca=True, vant=1), colpo("Sette perfetto", n=1, danno=6, non_scarta=True, non_para=True)], "uguali", origine="somma_perfetta"),
]


def _costo(t):
    """Stima di partenza del costo (poi il banco la corregge)."""
    v = 0.0
    for az in t["azioni"]:
        a = az["a"]
        n = a["n"]
        p = 1.0
        if a["tipo"] == "trappola":
            p += 1.0 + 0.6 * a.get("proietta", 0) + (0.8 if a.get("a_terra") else 0) + 0.3 * a.get("svant", 0)
            p += 0.3 * a.get("riduci", 0) / 2.0
            if a.get("contro", "tutto") != "tutto":
                p -= 0.6
        elif a["tipo"] in ("colpo", "presa"):
            p += 0.3 * a.get("piu", 0) + 0.4 * a.get("svant", 0) + 0.4 * a.get("ntogli", 1 if a.get("togli") else 0)
            p += 0.4 * a.get("spinta", 0) + (0.8 if a.get("a_terra") else 0) + (0.6 if a.get("iniziativa") else 0)
        else:
            p += 0.5 * (a.get("cura", 0) + a.get("pesca", 0) + a.get("vant", 0) + a.get("svant", 0))
        p *= 1.0 if n == 1 else 1.6
        v += p
    return max(1, int(round(v)))


SETT = {"rosso": "F", "giallo": "A", "blu": "P", "arancio": "FA", "verde": "AP", "viola": "PF"}
ORDINE = ["rosso", "arancio", "giallo", "verde", "blu", "viola"]
COPPIE = [("rosso", "arancio"), ("arancio", "giallo"), ("giallo", "verde"), ("verde", "blu"), ("blu", "viola"), ("viola", "rosso")]


def personaggi(d):
    """Ricompone le collezioni dei personaggi pronti: il mediano pieno secondo le loro caratteristiche,
    qualche token di ricambio e i token esterni delle coppie più affini."""
    import random
    r = d["regole"]
    tok = {t["id"]: t for t in d["esterni"]}
    for pg in d["personaggi"]:
        rnd = random.Random(pg["nome"])
        forza = {k: pg.get(k, 1) for k in "FAP"}
        aff = {c: sum(forza[k] for k in SETT[c]) / len(SETT[c]) for c in ORDINE}
        budget = r["budget"] - (r["ritmo3_budget"] if pg.get("R", 2) == 3 else 0)
        coll = []
        per_col = {c: [t for t in d["esterni"] if t["anello"] == 2 and t["col"] == c] for c in ORDINE}
        # i posti più affini scelgono per primi, con i token migliori per costo
        for c in sorted(ORDINE, key=lambda c: -aff[c]):
            lista = per_col[c][:]
            rnd.shuffle(lista)
            lista.sort(key=lambda t: -(t["costo"] / len(t["azioni"])) if aff[c] >= 2.5 else t["costo"] / len(t["azioni"]))
            resto = len([x for x in ORDINE if x not in [tok[i]["col"] for i in coll]]) - 1
            pz = 0
            for t in lista:
                n = len(t["azioni"])
                if pz + n <= 2 and t["costo"] <= budget - resto * 2:
                    coll.append(t["id"]); budget -= t["costo"]; pz += n
                if pz >= 2:
                    break
        for c in sorted(ORDINE, key=lambda c: -aff[c])[:2]:
            for t in sorted(per_col[c], key=lambda t: t["costo"]):
                if t["id"] not in coll and t["costo"] <= budget:
                    coll.append(t["id"]); budget -= t["costo"]
                    break
        b3 = r["budget_esterno"]
        coppie = sorted(range(6), key=lambda k: -(aff[COPPIE[k][0]] + aff[COPPIE[k][1]]))
        for k in coppie:
            cand = [t for t in d["esterni"] if t["anello"] == 3 and tuple(sorted(t["coppia"])) == tuple(sorted(COPPIE[k])) and t["costo"] <= b3]
            if cand:
                t = rnd.choice(cand)
                coll.append(t["id"]); b3 -= t["costo"]
        pg["coll"] = coll
        pg["raro"] = ""


def costruisci():
    d = json.load(open(SFERA))
    vecchi = {t["id"]: t for t in d.get("esterni", [])}
    tutti = []
    for t in MEDIANO + ESTERNO:
        for az in t["azioni"]:
            az["testo"] = testo(az["a"])
            az["testo_pot"] = testo_pot(az["a"])
        if t["anello"] == 3:
            t["testo_cond"] = "Si potenzia se " + COND[t["cond"]] + "."
        # i costi già tarati dal banco restano; i nuovi partono dalla stima
        t["costo"] = int(vecchi[t["id"]]["costo"]) if t["id"] in vecchi and vecchi[t["id"]].get("azioni") else _costo(t)
        tutti.append(t)
    ids = [t["id"] for t in tutti]
    assert len(ids) == len(set(ids)), "id doppi: %s" % [i for i in ids if ids.count(i) > 1]
    d["esterni"] = tutti
    personaggi(d)
    json.dump(d, open(SFERA, "w"), ensure_ascii=False, indent=1)
    m = [t for t in tutti if t["anello"] == 2]
    print("token: %d nel mediano (%d doppi), %d nell'esterno" % (len(m), sum(len(t["azioni"]) == 2 for t in m), len(tutti) - len(m)))
    from collections import Counter
    print(Counter(t["col"] for t in m))


if __name__ == "__main__":
    costruisci()
