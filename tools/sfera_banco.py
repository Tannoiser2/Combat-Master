#!/usr/bin/env python3
"""Banco della sfera: N duelli sulla mappa e resoconto per anello (base, esterni, rari, scena).

uso: python3 tools/sfera_banco.py [partite=10000] [seme=1] [json=uscita.json]
"""
import json
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sfera_sim as S  # noqa: E402

BASE = [
    ("colpo", "Colpo"), ("gira_colpo", "Colpo pesante (faccia)"),
    ("presa", "Presa"), ("gira_presa", "Presa forte (faccia)"),
    ("passo", "Passo (avvicinarsi)"), ("passo_via", "Passo (allontanarsi)"), ("aggira", "Aggirare"), ("gira_passo", "Balzo (faccia del Passo)"),
    ("scarto", "Scarto (reazione)"), ("gira_scarto", "Scarto e riposizionamento (faccia)"),
    ("parata", "Parata (reazione)"), ("gira_parata", "Parata ferrea (faccia)"),
    ("leggi", "Leggere il colpo"), ("gira_leggi", "Lettura profonda (faccia)"),
    ("sali", "Salire da un dado fermo"), ("scatta", "Far scattare un token pronto"), ("raro", "Usare il raro"),
]


def analizza(r):
    n = r["n"]
    st = r["st"]
    uv, up = r.get("uso_vinc", {}), r.get("uso_perd", {})
    tot = sum(st["azioni"].values()) + sum(st["reazioni"].values())
    base = []
    for k, nome in BASE:
        a, b = uv.get(k, 0), up.get(k, 0)
        base.append({"id": k, "nome": nome, "per_duello": round((a + b) / n, 2), "quota": round(100 * (a + b) / tot, 1),
                     "vincitore_su_perdente": round(a / b, 2) if b else None})
    est = []
    for t in S.tabella_token(r):
        disp = st["disponibile"].get(t["id"], 0)
        t["piazzato_pct"] = round(100 * t["piazzato"] / disp, 1) if disp else 0
        t["scatti_per_duello_posseduto"] = round(t["scatti"] / t["presenze"], 2) if t["presenze"] else 0
        est.append(t)
    rari = []
    for rid, t in S.RARI.items():
        w, m = r["raro"].get(rid, [0, 0])
        rari.append({"id": rid, "nome": t["nome"], "costo": t["costo"], "presenze": m, "vittorie_pct": round(100 * w / m, 1) if m else 0,
                     "scatta_pct": round(100 * st["raro_scatti"].get(rid, 0) / m, 1) if m else 0})
    scena = []
    for o, t in S.SCENA.items():
        k = "scena_" + o
        scena.append({"id": k, "nome": t["nome"], "piazzati_per_duello": round(st["piazzati"].get(k, 0) / n, 2),
                      "scatti_per_duello": round(st["scatti"].get(k, 0) / n, 2), "danni_per_duello": round(st["danni"].get(k, 0) / n, 2)})
    mappa = {k: round(st[k] / n, 2) for k in ["urti", "cadute", "pericoli", "spinte", "colpi_dall_alto", "colpi_alle_spalle", "aggirati_dietro", "rialzo_token", "cambi_al_muro"]}
    arene = {k: {"duelli": v[0], "scambi_medi": round(v[1] / v[0], 2), "primo_vince_pct": round(100 * v[2] / v[0], 1)} for k, v in st["arena_esito"].items()}
    return {"riassunto": S.riassunto(r), "base": base, "esterni": est, "rari": rari, "scena": scena, "mappa": mappa, "arene": arene,
            "dominante": {k: round(100 * w / m, 1) for k, (w, m) in r["dom"].items()},
            "ritmo": {str(k): round(100 * w / m, 1) for k, (w, m) in r["ritmo"].items()},
            "danni": {k: round(v / n, 2) for k, v in sorted(st["danni"].items(), key=lambda x: -x[1])}}


def main():
    arg = {"partite": "10000", "seme": "1", "json": ""}
    for a in sys.argv[1:]:
        k, v = a.split("=", 1)
        arg[k] = v
    r = S.giro(int(arg["partite"]), int(arg["seme"]))
    out = analizza(r)
    print(json.dumps(out["riassunto"]))
    if arg["json"]:
        with open(arg["json"], "w") as f:
            json.dump(out, f, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
