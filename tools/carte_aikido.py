"""Genera le carte attacco (1-18) e tecnica (I1-I7, P1-P28) di Combat Master a mani nude.

Fonte della struttura: la tabella "Esempi di tecniche fondamentali di neutralizzazione"
di "Aikido e la sfera dinamica" (attacchi x tecniche), verificata da Stefano il 24/11/2026.
I testi delle carte sono nostri. Uso: python3 tools/carte_aikido.py  (riscrive le carte in data/tokens.json)
"""
import json
import os

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(RADICE, "data/tokens.json")

# attacco -> tecniche che lo neutralizzano (P28 vale contro tutti, a parte)
TABELLA = {
    1: "I2 I3 P1 P2 P3 P9 P10 P11 P22", 2: "I3 P1 P11", 3: "I1 I2 I7 P1 P10 P13 P21",
    4: "I6 P1 P4 P6 P9 P13 P23 P24", 5: "I1 I3 I4 I6 P2 P5 P9 P10", 6: "P1 P2 P7 P18 P19",
    7: "I1 I2 I6 P1 P2 P4 P6 P13 P16 P18", 8: "I7 P1", 9: "I4 P1 P2 P5 P26 P27", 10: "P15",
    11: "P14", 12: "P14", 13: "I1 I2 I3 I4 I6 P1 P3 P11 P12", 14: "I5 I6 I7 P1 P4 P8 P18",
    15: "I1 I4 I7 P3 P25", 16: "I3 P16 P17", 17: "I2 P16 P20 P26", 18: "",
}

TECNICHE = {
    "I1": ("Controllo del braccio", "ikkyo"), "I2": ("Leva del polso piegato", "nikyo"),
    "I3": ("Torsione del polso in alto", "sankyo"), "I4": ("Pressione sull'avambraccio", "yonkyo"),
    "I5": ("Leva del gomito disteso", ""), "I6": ("Chiave al gomito sul petto", ""),
    "I7": ("Leva alta ai quattro lati", ""),
    "P1": ("Proiezione a spirale", ""), "P2": ("Proiezione ai quattro lati", "shiho nage"),
    "P3": ("Proiezione rotatoria", "kaiten nage"), "P4": ("Proiezione d'anca", "koshi nage"),
    "P5": ("Cielo e terra", "tenchi nage"), "P6": ("Torsione del polso", "kote gaeshi"),
    "P7": ("Spinta al collo", ""), "P8": ("Proiezione del respiro", "kokyu nage"),
    "P9": ("Proiezione entrando", "irimi nage"), "P10": ("Caduta d'angolo", "sumi otoshi"),
    "P11": ("Proiezione dal basso", ""), "P12": ("Braccio in alto", ""),
    "P13": ("Raccolta delle gambe", "aiki otoshi"), "P14": ("Braccia incrociate", "juji nage"),
    "P15": ("Ruota completa", ""), "P16": ("Doppia estensione", ""), "P17": ("Trascinamento a terra", ""),
    "P18": ("Caduta all'indietro circolare", ""), "P19": ("Sotto il baricentro", ""),
    "P20": ("Taglio orizzontale", ""), "P21": ("Arco sopra la spalla", ""),
    "P22": ("Quattro lati da dietro", ""), "P23": ("Sopra la schiena", ""), "P24": ("Caduta distesa", ""),
    "P25": ("Proiezione in diagonale", ""), "P26": ("Ribaltamento dal basso", ""),
    "P27": ("Grande rotazione", ""), "P28": ("Proiezione universale", ""),
}

RB = ["rosso", "blu"]
# n: (nome, giapponese, genere, dadi, parametri, testo)
ATTACCHI = {
    1: ("Presa al polso", "katate tori", "presa", [RB], {"fisso": 1, "blocca": 1},
        "Presa al polso sullo stesso lato. Danno 1 e stordisci un dado."),
    2: ("Presa al polso in diagonale", "katate tori", "presa", [RB], {"fisso": 1, "blocca": 1, "gira": 1},
        "Presa in diagonale: danno 1, stordisci un dado e lo fai girare di un lato."),
    3: ("Due mani su un braccio", "katate tori ryote mochi", "presa", [["rosso"], RB], {"fisso": 1, "blocca": 2},
        "Due mani su un braccio: danno 1 e stordisci due dadi."),
    4: ("Presa alle due braccia", "ryote tori", "presa", [["rosso"], ["blu"]], {"fisso": 1, "blocca": 2, "svantaggi": 1},
        "Presa a entrambe le braccia: danno 1, stordisci due dadi, 1 svantaggio."),
    5: ("Presa alla spalla", "kata tori", "presa", [RB], {"fisso": 1, "svantaggi": 1},
        "Presa singola alta: danno 1 e 1 svantaggio."),
    6: ("Presa alle due spalle", "ryokata tori", "presa", [["rosso"], ["rosso", "verde"]], {"fisso": 2, "svantaggi": 2},
        "Presa doppia alta: danno 2 e 2 svantaggi."),
    7: ("Polsi da dietro", "ushiro tekubi tori", "presa", [["blu"], RB], {"fisso": 1, "blocca": 2, "dorsale": True},
        "Solo da dietro. Presa dei due polsi: danno 1 e stordisci due dadi."),
    8: ("Gomiti da dietro", "ushiro hiji tori", "presa", [["blu"], ["rosso"]], {"fisso": 1, "blocca": 2, "dorsale": True, "imparabile": True},
        "Solo da dietro. Presa ai gomiti: danno 1, stordisci due dadi, non si para."),
    9: ("Spalle da dietro", "ushiro kata tori", "presa", [["blu"]], {"fisso": 1, "svantaggi": 2, "dorsale": True},
        "Solo da dietro. Presa alle spalle: danno 1 e 2 svantaggi."),
    10: ("Strangolamento", "ushiro kubi shime", "presa", [["rosso"], ["rosso", "verde"]], {"valore": "primo", "dorsale": True, "svantaggi": 1},
         "Solo da dietro. Danno pari al primo dado e 1 svantaggio."),
    11: ("Cintura alta da dietro", "ushiro tori", "presa", [["rosso"], ["blu"]], {"fisso": 1, "blocca": 3, "dorsale": True},
         "Solo da dietro. Immobilizzazione alta: danno 1 e stordisci tre dadi."),
    12: ("Cintura bassa da dietro", "ushiro tori", "presa", [["rosso"], ["verde"]], {"fisso": 1, "blocca": 2, "svantaggi": 1, "dorsale": True},
         "Solo da dietro. Immobilizzazione bassa: danno 1, stordisci due dadi, 1 svantaggio."),
    13: ("Colpo diretto alla testa", "shomen uchi", "colpo", [["rosso"]], {"valore": "primo", "bonus": -1},
         "Colpo dall'alto: danno pari al dado -1."),
    14: ("Colpo circolare alla testa", "yokomen uchi", "colpo", [RB], {"valore": "primo", "bonus": -1, "gira": 1},
         "Colpo circolare: danno pari al dado -1 e lo fai girare di un lato."),
    15: ("Colpo all'addome", "mune tsuki", "colpo", [["rosso"]], {"valore": "primo", "bonus": -1, "blocca": 1, "cond": {"min": 3}},
         "Dado 3+. Pugno all'addome: danno pari al dado -1 e gli togli il fiato (stordisci un dado)."),
    16: ("Presa con presa", "", "combinazione", [RB, RB], {"fisso": 1, "blocca": 2, "svantaggi": 1},
         "Due prese di fila: danno 1, stordisci due dadi, 1 svantaggio."),
    17: ("Presa con colpo", "", "combinazione", [RB, ["rosso"]], {"valore": "secondo", "blocca": 1},
         "Lo tieni e colpisci: danno pari al secondo dado, stordisci un dado."),
    18: ("Colpo con colpo", "", "combinazione", [["rosso"], ["rosso"]], {"valore": "somma", "div": 2, "non_schivabile": True},
         "Due colpi rapidi: danno metà della somma, non si schiva."),
}


def coperture():
    cop = {k: [] for k in TECNICHE}
    for a, s in TABELLA.items():
        for t in s.split():
            cop[t].append(a)
    return cop


def carte():
    out = []
    for n, (nome, jp, genere, dadi, par, testo) in ATTACCHI.items():
        sl = {"id": "colpo", "nome": nome, "tipo": "azione", "dadi": dadi, "cond": par.pop("cond", {}),
              "effetto": "attacco", "portata": 1, "attacco_n": n, "genere": genere, "testo": testo}
        sl.update(par)
        prese = genere == "presa"
        costo = 1 + (1 if len(dadi) == 1 else 0) + (1 if par.get("dorsale") else 0) + (1 if genere == "combinazione" else 0)
        out.append({"id": "att%02d" % n, "nome": "%d. %s" % (n, nome), "categoria": "attacco", "costo": costo,
                    "testo": (jp + ". " if jp else "") + ("Presa: tiene e toglie risorse." if prese else ""),
                    "slot": [sl]})
    cop = coperture()
    for k, (nome, jp) in TECNICHE.items():
        imm = k.startswith("I")
        contro = "tutti" if k == "P28" else cop[k]
        n = 18 if contro == "tutti" else len(contro)
        if contro == "tutti":
            elenco = "tutti gli attacchi"
            cond = {"min": 5}
        else:
            elenco = "attacchi " + ", ".join(str(x) for x in contro)
            # più attacchi copre, più alto deve essere il dado
            cond = {"min": 4} if n >= 9 else ({"min": 3} if n >= 6 else {})
        effetto_txt = ("immobilizzi: 1 ferita (2 con un 5+), 2 svantaggi e due dadi storditi"
                       if imm else "proietti: 1 ferita + un terzo del dado, lo lanci di 1 (2 con 5+); con un dado verde rotola e dimezza")
        soglia = (" Dado %d+." % cond["min"]) if cond else ""
        sl = {"id": "tecnica", "nome": nome, "tipo": "reazione", "dadi": [["verde", "viola"] if imm else ["blu", "viola"]],
              "cond": cond, "effetto": "tecnica", "genere": "immobilizzazione" if imm else "proiezione",
              "contro": contro, "quando": "mischia",
              "testo": "Reazione contro %s.%s Annulli l'attacco e %s. Dado dispari: irimi, pari: tenkan." % (elenco, soglia, effetto_txt)}
        costo = 1 + (n + 2) // 4
        out.append({"id": "tec_" + k.lower(), "nome": "%s %s" % (k, nome), "categoria": "tecnica", "costo": costo,
                    "testo": jp, "slot": [sl]})
    return out


def main():
    d = json.load(open(P, encoding="utf-8"))
    d["token"] = [t for t in d["token"] if t["categoria"] not in ("attacco", "tecnica")] + carte()
    cats = [c for c in d["categorie"] if c["id"] not in ("attacco", "tecnica")]
    cats.insert(1, {"id": "attacco", "nome": "Attacchi"})
    cats.insert(2, {"id": "tecnica", "nome": "Tecniche"})
    d["categorie"] = cats
    json.dump(d, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    cop = coperture()
    print("carte:", sum(1 for t in d["token"] if t["categoria"] in ("attacco", "tecnica")))
    print("copertura:", {k: len(v) for k, v in cop.items()})


if __name__ == "__main__":
    main()
