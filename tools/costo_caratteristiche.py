"""Costo di partenza delle carte caratteristica: dadi portati nel mucchio + forza delle azioni.

Il costo nasce da una formula trasparente e poi si corregge con il banco
(tests/bilancia.gd). Uso: python3 tools/costo_caratteristiche.py [applica]
"""
import json
import os
import sys

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(RADICE, "data/tokens.json")

VAL_DADO = 1.3       # ogni dado nel mucchio
SCONTO = 2.5         # le caratteristiche sono obbligatorie: si parte da qui
BASE = {"attacco": 2.0, "assalto": 2.4, "movimento": 1.2, "schiva": 1.2, "scarta": 1.2, "para": 1.0,
        "guardia": 1.2, "stordisci": 1.4, "gira_nemico": 0.9, "pesca": 1.2, "sblocca": 1.2,
        "supp_danno": 0.9, "supp_difesa": 0.9, "cura": 1.1, "ritocca": 0.8, "ritocca_guardia": 0.8,
        "elimina": 1.2, "rovescia": 1.0, "concentrazione": 1.0, "eco": 1.0, "ruota": 0.6,
        "scambia": 0.8, "gira_guardia": 0.8, "disarma": 1.4}


def forza_azione(s):
    v = BASE.get(s.get("effetto"), 0.7)
    if s.get("effetto") in ("attacco", "assalto"):
        if int(s.get("portata", 1)) >= 2:
            v += 0.4
        if s.get("ignora_armatura"):
            v += 0.3
        if s.get("fisso") is not None and s.get("valore") is None:
            v += 0.1 * (int(s["fisso"]) - 2)
        if s.get("div"):
            v -= 0.3
    if s.get("catena"):
        v += 0.3
    if s.get("anche_retro"):
        v += 0.2
    cond = s.get("cond") or {}
    ammessi = 6
    if "max" in cond:
        ammessi = int(cond["max"])
    if "min" in cond:
        ammessi = min(ammessi, 7 - int(cond["min"]))
    f = 0.45 + 0.55 * ammessi / 6.0
    if cond.get("coppia") or len(s.get("dadi", [])) >= 2:
        f *= 0.65
    return v * f


# Correzioni dal banco (300 duelli, 24/11): +1 a chi vince 60% o più, -1 a chi vince 41% o meno.
CORREZIONI = {"equilibrio": 1, "toro": 1, "volonta": 1, "potenza": 1,
              "gladiatore": -1, "penitente": -1, "precisione": -1, "furia": -1, "portatore": -1, "veggente": -1}


def costo(t):
    lv = t["livelli"][0]
    extra = 0.4 * int(lv.get("vita", 0))
    base = round(VAL_DADO * int(lv["dadi"]) + sum(forza_azione(s) for s in t["slot"]) + extra - SCONTO)
    return max(1, base + CORREZIONI.get(t["id"], 0))


def main():
    d = json.load(open(P, encoding="utf-8"))
    righe = []
    for t in d["token"]:
        if t["categoria"] != "attributo":
            continue
        nuovo = costo(t)
        vecchio = t["livelli"][0]["costo"]
        righe.append((t["caratteristica"], t["nome"], t["livelli"][0]["dadi"], vecchio, nuovo))
        if len(sys.argv) > 1 and sys.argv[1] == "applica":
            t["livelli"][0]["costo"] = nuovo
    for r in sorted(righe):
        print("%-6s %-32s dadi %d  costo %d -> %d" % r)
    if len(sys.argv) > 1 and sys.argv[1] == "applica":
        json.dump(d, open(P, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print("costi applicati")


if __name__ == "__main__":
    main()
