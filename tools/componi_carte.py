"""Compone le carte illustrate dei token a moduli fissi.

Ogni azione occupa un modulo della stessa altezza, con la stessa illustrazione
quadrata e lo stesso corpo del testo: una carta con un'azione è una fascia del
titolo più un modulo, una con tre azioni è la fascia più tre moduli.

Testi e dadi vengono da data/tokens.json; le illustrazioni delle azioni da
grafica/azioni/<token>__<spazio>.png.

Uso: python3 tools/componi_carte.py [cartella_webp] [cartella_png]
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

RADICE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATI = json.load(open(os.path.join(RADICE, "data/tokens.json"), encoding="utf-8"))
ILL = os.path.join(RADICE, "grafica/azioni")
FONT_T = os.path.join(RADICE, "assets/fonts/Cinzel.ttf")
FONT_C = os.path.join(RADICE, "assets/fonts/Alegreya.ttf")

S = 2  # disegno a doppia risoluzione, poi riduco: bordi più puliti
W = 540
TESTA = 112          # fascia del titolo
NOTA = 34            # riga per "Sempre attivo" o nota del token (solo se serve)
MOD = 232            # altezza di ogni modulo azione
IMG = 204            # lato dell'illustrazione dell'azione
MARG = 12
PERG = (246, 238, 220)
INCH = (43, 33, 24)
ORO = (201, 162, 74)
CORNICE = (92, 64, 40)

CAT_COL = {"base": "#5b5046", "attacco": "#9a4a22", "tecnica": "#2f5f7a", "arma": "#8e3a2c", "mossa": "#a33a3a", "armatura": "#4d6b8a",
           "oggetto": "#6f6534", "talento": "#3f7a55", "magia": "#5b4a9a", "segreto": "#3d3550"}
TIPI = {"azione": ("Azione", "#7a5a2a"), "libera": ("Libera", "#3f7a55"), "reazione": ("Reazione", "#355f93"),
        "supporto_attacco": ("Supporto al colpo", "#a3483a"), "supporto_difesa": ("Supporto alla difesa", "#4d6b8a"),
        "segreto": ("Segreto", "#5a3f7a"), "contatore": ("Contatore", "#6f6534")}
CATN = {c["id"]: c["nome"] for c in DATI["categorie"]}
CATN["base"] = "Azioni di base"
COL = {k: v["hex"] for k, v in DATI["colori"].items()}
NCAR = {k: v["nome"] for k, v in DATI["colori"].items()}
PASSN = {"armatura": "Armatura", "movimento": "Movimento", "iniziativa": "Iniziativa", "vita": "Ferite",
         "ritmo": "Ritmo", "recupero": "Recupero", "conserva": "Conserva"}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def scuro(h, f=0.72):
    return tuple(int(c * f) for c in rgb(h))


def font(path, size, peso=None):
    f = ImageFont.truetype(path, size * S)
    if peso:
        try:
            f.set_variation_by_axes([peso])
        except Exception:
            pass
    return f


F_NOME = font(FONT_T, 25, 700)
F_CAT = font(FONT_C, 14)
F_COSTO = font(FONT_T, 22, 700)
F_AZ = font(FONT_T, 17, 700)
F_TAG = font(FONT_C, 14, 700)
F_TESTO = font(FONT_C, 19)
F_NOTA = font(FONT_C, 16)
F_PIP = font(FONT_C, 17, 700)


def a_capo(dr, testo, f, larg):
    righe, riga = [], ""
    for p in testo.split():
        prova = (riga + " " + p).strip()
        if dr.textlength(prova, font=f) <= larg:
            riga = prova
        else:
            if riga:
                righe.append(riga)
            riga = p
    if riga:
        righe.append(riga)
    return righe


def foro(dr, x, y, lato, cols):
    """Quadratino del dado: un colore, due in diagonale, quattro o più a strisce."""
    x, y, lato = x * S, y * S, lato * S
    if len(cols) >= 4:
        cs = [COL[c] for c in ["rosso", "blu", "verde", "viola"]]
        w = lato / 4
        for i, c in enumerate(cs):
            dr.rectangle([x + i * w, y, x + (i + 1) * w, y + lato], fill=rgb(c))
    elif len(cols) >= 2:
        dr.polygon([(x, y), (x + lato, y), (x, y + lato)], fill=rgb(COL[cols[0]]))
        dr.polygon([(x + lato, y), (x + lato, y + lato), (x, y + lato)], fill=rgb(COL[cols[1]]))
    else:
        dr.rectangle([x, y, x + lato, y + lato], fill=rgb(COL.get(cols[0], "#777")) if cols else (200, 200, 200))
    dr.rectangle([x, y, x + lato, y + lato], outline=INCH, width=2 * S)


def esagono(dr, cx, cy, r):
    import math
    pts = [(cx * S + r * S * math.cos(math.radians(60 * i - 90 + 30)), cy * S + r * S * math.sin(math.radians(60 * i - 90 + 30))) for i in range(6)]
    dr.polygon(pts, fill=(250, 244, 230), outline=INCH)
    # lato di fronte in oro
    dr.line([pts[4], pts[5]], fill=ORO, width=4 * S)


def prodotto(t):
    out = []
    if t.get("colore") and t.get("livelli"):
        out.append((t["colore"], "/".join(str(l["dadi"]) for l in t["livelli"])))
    for k, v in (t.get("produce") or {}).items():
        out.append((k, str(v)))
    if (t.get("passivo") or {}).get("bianco"):
        out.append(("bianco", str(t["passivo"]["bianco"])))
    return out


def nota(t):
    pas = {k: v for k, v in (t.get("passivo") or {}).items() if k in PASSN}
    if t.get("testo"):
        return t["testo"]
    if pas:
        return "Sempre attivo: " + ", ".join(f"{PASSN[k]} {'+' if v > 0 else ''}{v}" for k, v in pas.items())
    return ""


def costo(t):
    return "/".join(str(l["costo"]) for l in t["livelli"]) if t.get("livelli") else str(t.get("costo", 0))


def illustrazione(tid, sid):
    p = os.path.join(ILL, f"{tid}__{sid}.png")
    if os.path.exists(p):
        return Image.open(p).convert("RGB")
    return None


def carta(t):
    n = nota(t)
    h_nota = NOTA if n else 0
    H = TESTA + h_nota + len(t["slot"]) * MOD + MARG
    im = Image.new("RGB", (W * S, H * S), PERG)
    dr = ImageDraw.Draw(im)
    fascia = scuro(COL[t["caratteristica"]]) if t.get("caratteristica") else rgb(CAT_COL.get(t["categoria"], "#555555"))
    # fascia del titolo
    dr.rounded_rectangle([6 * S, 6 * S, (W - 6) * S, (TESTA - 4) * S], 10 * S, fill=fascia)
    cat = CATN[t["categoria"]] + (f" · {NCAR[t['caratteristica']]}" if t.get("caratteristica") else "")
    dr.text((20 * S, 16 * S), cat, font=F_CAT, fill=(245, 230, 205))
    nome = t["nome"]
    fn = F_NOME
    while dr.textlength(nome, font=fn) > (W - 130) * S and fn.size > 16 * S:
        fn = ImageFont.truetype(FONT_T, fn.size - S)
        try:
            fn.set_variation_by_axes([700])
        except Exception:
            pass
    dr.text((20 * S, 40 * S), nome, font=fn, fill=(255, 250, 240))
    # dadi che dà al mucchio
    x = 20
    for c, v in prodotto(t):
        foro(dr, x, 76, 22, [c])
        dr.text(((x + 28) * S, 76 * S), v, font=F_PIP, fill=(255, 246, 230))
        x += 28 + int(dr.textlength(v, font=F_PIP) / S) + 14
    # costo nel cerchio
    cx, cy, r = W - 50, TESTA // 2, 30
    dr.ellipse([(cx - r) * S, (cy - r) * S, (cx + r) * S, (cy + r) * S], fill=(35, 25, 18), outline=ORO, width=3 * S)
    c = costo(t)
    fc = F_COSTO if len(c) <= 2 else font(FONT_T, 15, 700)
    dr.text((cx * S, cy * S), c, font=fc, fill=(255, 245, 225), anchor="mm")
    y = TESTA
    if n:
        righe = a_capo(dr, n, F_NOTA, (W - 40) * S)
        dr.text((20 * S, (y + 6) * S), righe[0] + ("..." if len(righe) > 1 else ""), font=F_NOTA, fill=(90, 70, 50))
        y += NOTA
    for sl in t["slot"]:
        # riquadro del modulo
        dr.rounded_rectangle([MARG * S, (y + 4) * S, (W - MARG) * S, (y + MOD - 4) * S], 8 * S, fill=(252, 247, 236), outline=(190, 170, 135), width=2 * S)
        ix, iy = MARG + 10, y + (MOD - IMG) // 2
        ill = illustrazione(t["id"], sl["id"])
        if ill is not None:
            im.paste(ill.resize((IMG * S, IMG * S), Image.LANCZOS), (ix * S, iy * S))
        else:
            dr.rectangle([ix * S, iy * S, (ix + IMG) * S, (iy + IMG) * S], fill=(225, 214, 190))
        dr.rectangle([ix * S, iy * S, (ix + IMG) * S, (iy + IMG) * S], outline=CORNICE, width=2 * S)
        tx = ix + IMG + 14
        larg = W - MARG - 10 - tx
        # fori dei dadi e nome dell'azione
        dadi = sl.get("dadi") or []
        fx = W - MARG - 10
        es = bool(sl.get("esagono"))
        if es:
            esagono(dr, fx - 13, y + 28, 13)
            fx -= 34
        for cols in reversed(dadi):
            fx -= 26
            foro(dr, fx, y + 16, 24, cols)
            fx -= 4
        righe_n = a_capo(dr, sl["nome"], F_AZ, (fx - tx - 6) * S)
        ny = y + 16
        for rn in righe_n[:2]:
            dr.text((tx * S, ny * S), rn, font=F_AZ, fill=INCH)
            ny += 22
        # etichetta del tipo
        tl, tc = TIPI.get(sl["tipo"], (sl["tipo"], "#666"))
        lw = dr.textlength(tl, font=F_TAG) / S + 14
        ty = max(ny + 4, y + 46)
        dr.rounded_rectangle([tx * S, ty * S, (tx + lw) * S, (ty + 21) * S], 5 * S, fill=rgb(tc))
        dr.text(((tx + 7) * S, (ty + 3) * S), tl, font=F_TAG, fill=(255, 255, 255))
        # testo dell'effetto, sempre allo stesso corpo
        yy = ty + 28
        for riga in a_capo(dr, sl["testo"], F_TESTO, larg * S):
            dr.text((tx * S, yy * S), riga, font=F_TESTO, fill=INCH)
            yy += 22
        if yy > y + MOD - 6:
            print("ATTENZIONE: testo lungo in", t["id"], sl["id"], file=sys.stderr)
        y += MOD
    # cornice della carta
    dr.rounded_rectangle([2 * S, 2 * S, (W - 2) * S, (H - 2) * S], 14 * S, outline=CORNICE, width=4 * S)
    return im.resize((W, H), Image.LANCZOS)


def main():
    out_webp = sys.argv[1] if len(sys.argv) > 1 else os.path.join(RADICE, "assets/carte")
    out_png = sys.argv[2] if len(sys.argv) > 2 else ""  # facoltativo: PNG a piena risoluzione
    os.makedirs(out_webp, exist_ok=True)
    if out_png:
        os.makedirs(out_png, exist_ok=True)
    geo = {"w": W, "testa": TESTA, "mod": MOD, "img": IMG, "marg": MARG, "carte": {}}
    for t in DATI["token"]:
        im = carta(t)
        # dove inizia il primo modulo e quanto è alta la carta: al gioco servono per posare i dadi sulle immagini
        geo["carte"][t["id"]] = {"y0": TESTA + (NOTA if nota(t) else 0), "h": im.height}
        if out_png:
            im.save(os.path.join(out_png, t["id"] + ".png"), optimize=True)
        # per il gioco e il catalogo: 2/3 della larghezza, webp
        w2 = 360
        im.resize((w2, round(im.height * w2 / im.width)), Image.LANCZOS).save(
            os.path.join(out_webp, t["id"] + ".webp"), "WEBP", quality=82, method=6)
    json.dump(geo, open(os.path.join(out_webp, "geometria.json"), "w"), indent=0)
    print(len(DATI["token"]), "carte")


if __name__ == "__main__":
    main()
