"""Controlla che ogni carattere scritto nell'interfaccia esista nei caratteri tipografici del gioco.
Sul web non c'è un carattere di riserva: un simbolo mancante diventa un quadratino.
Frecce, croci e pallini vanno DISEGNATI (scripts/disegno.gd: icona), non scritti.
uso: python3 tools/controlla_glifi.py   (esce con 1 se trova caratteri mancanti)"""
import glob, json, re, sys
from fontTools.ttLib import TTFont
FONTS = ["assets/fonts/Alegreya.ttf", "assets/fonts/Cinzel.ttf"]
cmaps = {f: set(TTFont(f).getBestCmap().keys()) for f in FONTS}
bad = {}
def check(text, where):
    for ch in str(text):
        if ch in "\n\t":
            continue
        missing = [f.split("/")[-1] for f, cm in cmaps.items() if ord(ch) not in cm]
        if missing:
            bad.setdefault(ch, set()).add(where)
for path in sorted(glob.glob("scripts/*.gd")):
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        if line.strip().startswith("#"):
            continue
        for s in re.findall(r'"((?:[^"\\]|\\.)*)"', line):
            check(s, f"{path}:{n}")
def walk(x, where):
    if isinstance(x, dict):
        for k, v in x.items():
            walk(v, where + "/" + str(k))
    elif isinstance(x, list):
        for i, v in enumerate(x):
            walk(v, where)
    elif isinstance(x, str):
        check(x, where)
walk(json.load(open("data/tokens.json", encoding="utf-8")), "tokens.json")
check(open("data/regole.md", encoding="utf-8").read().replace("#", ""), "regole.md")
if bad:
    for ch, where in sorted(bad.items()):
        print(f"MANCA {ch!r} (U+{ord(ch):04X}) in {len(where)} punti, es. {sorted(where)[:3]}")
    sys.exit(1)
print("OK: tutti i caratteri dell'interfaccia esistono in Alegreya e Cinzel")
