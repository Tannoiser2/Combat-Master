#!/usr/bin/env python3
"""Prototipo del sistema "La sfera" per Combat Master: duelli astratti IA contro IA.

Non usa la mappa a esagoni: la distanza e' un numero (1 = contatto). Serve solo a
misurare ritmo, durata e bilanciamento delle mosse prima di toccare il gioco.

uso: python3 tools/sfera_sim.py [partite=600] [seme=1] [variante=base] [iterazioni=0] [json=out.json]
"""
import json
import random
import sys
from collections import defaultdict

# ---------------------------------------------------------------------------
# Regole regolabili (le varianti le cambiano)
REGOLE = {
    "pesca": 4,            # dadi pescati dal mucchio a ogni pausa
    "dist0": 3,            # distanza iniziale (1 = contatto)
    "dist_max": 5,
    "vita_base": 18,        # ferite = vita_base + 2 * Costituzione
    "vita_per_cos": 1,
    "max_vant": 5,
    "vant_per_colpo": 3,   # vantaggi spendibili su un colpo (+1 danno l'uno)
    "soglia_delta": 0,     # sommato alla soglia di ogni token
    "ritiro": True,        # tiro di passaggio
    "ridotto": True,       # sotto soglia si puo' salire a effetto ridotto (perdendo l'iniziativa)
    "flusso": True,
    "flusso_per_scambio": 1,
    "doppia_faccia": True,
    "combo": True,         # facce potenziate dei token esterni con dadi uguali
    "raro": True,
    "max_scambi": 40,
    "recupero": 0,         # ferite recuperate a ogni pausa
    "parata_piena": True,  # True: la parata riduce del valore; False: valore - 1
    "presa_toglie": True,
    "vant_ritiro": True,   # ritiro riuscito: continui e prendi 1 vantaggio
    "senza_potenziamenti": True, # Kime, Sen no sen e Zanshin come token a se' non convengono
    "cavalieri": True,     # i loro effetti stanno su Tenkan, Occhio del falco e Uscire dalla linea
    "persistenti": True,   # alla pausa i token caricati restano con i loro dadi
    "aggirare": True,      # Passo a contatto: aggiri e prendi 1 vantaggio
    "vant_in_parata": True,# i vantaggi si spendono anche per parare (+1 l'uno)
    "raro_da_tutti": True, # il raro si carica dallo scatto di qualsiasi token esterno
    "soglia_raro": 4,
    "vant_reazione": True, # parata che azzera il colpo o scarto riuscito: +1 vantaggio
    "scarto_tolleranza": 2, # lo scarto riesce con un dado >= dado d'attacco - tolleranza
    "passaggio": "freccia", # "soglia" (prima stesura) o "freccia": scali il dado e perdi l'iniziativa, o ritiri e continui
    "fallisce_fino": 2,    # nel ritiro, con questo valore o meno il dado va in Attesa
    "catena_max": 99,      # quante volte per scambio si puo' continuare dopo un ritiro riuscito (99 = senza limite)
    "ia_rischio": 3,       # l'IA ritira se il dado scalato varrebbe meno di questo
    "reazione_continua": False, # ritiro riuscito salendo da una reazione: prendi l'iniziativa
    "mappa": True,         # duelli sulle arene del gioco (esagoni, alture, ostacoli, oggetti)
    "arene": "cortile,rovine,fossa",
    "danno_alto": 1,       # colpo dall'alto: +1 danno
    "danno_spalle": 2,     # colpo alle spalle: +1 danno, niente scarto
    "danno_urto": 1,       # spinto contro un ostacolo
    "danno_pericolo": 1,
    "token_scena": True,   # accanto a un oggetto di scena si piazza il suo token oltre al Ritmo
    "assetto_posizione": True, # rialzo: un token in piu'; spalle a colonna o albero: cambio gratis
    "danno_div": 2,        # 2 = i danni dei colpi sono la meta' del valore (arrotondata per eccesso)
}


def D(x):
    """Danno effettivo di un valore di colpo."""
    if REGOLE["danno_div"] <= 1:
        return x
    return (x + REGOLE["danno_div"] - 1) // REGOLE["danno_div"]

DADI = {"r": "rosso", "g": "giallo", "b": "blu", "n": "bianco"}
SETTORE_DI = {"r": "F", "g": "A", "b": "P"}
# token esterni adiacenti a ciascun settore
ADIACENTI = {"F": ["rosso", "arancio", "viola"], "A": ["giallo", "arancio", "verde"], "P": ["blu", "verde", "viola"]}
PRIMARI = {"rosso": "r", "giallo": "g", "blu": "b"}
AZIONE_SETTORE = {"colpo": "F", "presa": "F", "passo": "A", "scarto": "A", "parata": "P", "leggi": "P"}

# ---------------------------------------------------------------------------
# Catalogo dei token esterni (prima stesura; il banco li equilibra)
# req: colori richiesti per ogni posto ("n" = anche un dado neutro, solo nei primari)
# modo: "subito" (scatta quando e' pieno, se serve il contatto aspetta) o "armato" (al prossimo attacco nemico)
CATALOGO = {
    # rosso
    "calcio_girato":  {"nome": "Calcio girato", "col": "rosso", "req": ["r"], "soglia": 3, "modo": "subito", "eff": "colpo", "bonus": 2, "costo": 2},
    "raffica":        {"nome": "Raffica di pugni", "col": "rosso", "req": ["r", "n"], "soglia": 2, "modo": "subito", "eff": "colpo", "bonus": 1, "costo": 1},
    "gomitata":       {"nome": "Gomitata", "col": "rosso", "req": ["r"], "soglia": 4, "modo": "subito", "eff": "colpo_stordente", "bonus": 1, "costo": 3},
    "spallata":       {"nome": "Spallata", "col": "rosso", "req": ["r"], "soglia": 3, "modo": "subito", "eff": "spinta", "bonus": 0, "costo": 4},
    # arancio
    "carica_toro":    {"nome": "Carica del toro", "col": "arancio", "req": ["r", "g"], "soglia": 3, "modo": "subito", "eff": "carica", "bonus": 0, "costo": 1},
    "calcio_volante": {"nome": "Calcio volante", "col": "arancio", "req": ["g", "r"], "soglia": 3, "modo": "subito", "eff": "carica", "bonus": 2, "costo": 2},
    "affondo":        {"nome": "Affondo e rientro", "col": "arancio", "req": ["r", "g"], "soglia": 3, "modo": "subito", "eff": "affondo", "bonus": 1, "costo": 2},
    # giallo
    "balzo":          {"nome": "Balzo", "col": "giallo", "req": ["g"], "soglia": 4, "modo": "subito", "eff": "balzo", "bonus": -3, "costo": 3},
    "passi_danza":    {"nome": "Passi di danza", "col": "giallo", "req": ["g", "g"], "soglia": 2, "modo": "armato", "eff": "schivata", "bonus": 1, "costo": 1},
    "salto_mortale":  {"nome": "Salto mortale", "col": "giallo", "req": ["g"], "soglia": 5, "modo": "subito", "eff": "alle_spalle", "bonus": -6, "costo": 8},
    # verde
    "irimi":          {"nome": "Irimi", "col": "verde", "req": ["g", "b"], "soglia": 3, "modo": "armato", "eff": "irimi", "bonus": 0, "costo": 1},
    "tenkan":         {"nome": "Tenkan", "col": "verde", "req": ["b", "g"], "soglia": 3, "modo": "armato", "eff": "tenkan", "bonus": 0, "costo": 3},
    "uscire_linea":   {"nome": "Uscire dalla linea", "col": "verde", "req": ["g", "b"], "soglia": 2, "modo": "armato", "eff": "schivata", "bonus": 1, "costo": 1},
    # blu
    "guardia_ferrea": {"nome": "Guardia ferrea", "col": "blu", "req": ["b"], "soglia": 3, "modo": "armato", "eff": "guardia", "bonus": 0, "costo": 4},
    "respiro":        {"nome": "Respiro profondo", "col": "blu", "req": ["b"], "soglia": 2, "modo": "subito", "eff": "respiro", "bonus": 0, "costo": 1},
    "occhio_falco":   {"nome": "Occhio del falco", "col": "blu", "req": ["b"], "soglia": 2, "modo": "subito", "eff": "lettura", "bonus": 0, "costo": 1},
    "provocazione":   {"nome": "Provocazione", "col": "blu", "req": ["b"], "soglia": 2, "modo": "subito", "eff": "provoca", "bonus": 0, "costo": 1},
    # viola
    "kote_gaeshi":    {"nome": "Kote gaeshi", "col": "viola", "req": ["b", "r"], "soglia": 3, "modo": "armato", "eff": "proiezione", "bonus": 0, "costo": 5},
    "ikkyo":          {"nome": "Ikkyo", "col": "viola", "req": ["r", "b"], "soglia": 3, "modo": "armato", "eff": "immobilizza", "bonus": 0, "costo": 2},
    "kaiten_nage":    {"nome": "Kaiten nage", "col": "viola", "req": ["b", "r"], "soglia": 4, "modo": "armato", "eff": "proiezione", "bonus": 0, "costo": 4},
    "contrattacco":   {"nome": "Contrattacco", "col": "viola", "req": ["b", "r"], "soglia": 3, "modo": "armato", "eff": "contrattacco", "bonus": 0, "costo": 1},
    # aggiunti
    "ukemi":          {"nome": "Ukemi", "col": "verde", "req": ["g", "b"], "soglia": 2, "modo": "armato", "eff": "ukemi", "bonus": 0, "costo": 1},
    "sgambetto":      {"nome": "Sgambetto", "col": "arancio", "req": ["g", "r"], "soglia": 3, "modo": "subito", "eff": "sgambetto", "bonus": 0, "costo": 2},
    "calma":          {"nome": "Calma interiore", "col": "blu", "req": ["b"], "soglia": 3, "modo": "subito", "eff": "calma", "bonus": 0, "costo": 7},
    # potenziare i dadi, tenere o prendere l'iniziativa
    "kime":           {"nome": "Kime", "col": "rosso", "req": ["r"], "soglia": 3, "modo": "subito", "eff": "kime", "bonus": 0, "costo": 1},
    "sen_no_sen":     {"nome": "Sen no sen", "col": "blu", "req": ["b"], "soglia": 3, "modo": "subito", "eff": "sen", "bonus": 0, "costo": 1},
    "zanshin":        {"nome": "Zanshin", "col": "verde", "req": ["g", "b"], "soglia": 2, "modo": "subito", "eff": "zanshin", "bonus": 0, "costo": 1},
}
RARI = {
    "tenchi_nage":    {"nome": "Tenchi nage", "req": ["x", "x"], "soglia": 3, "eff": "tenchi", "bonus": 0, "costo": 8},
    "kiai":           {"nome": "Kiai del maestro", "req": ["x"], "soglia": 3, "eff": "kiai", "bonus": 0, "costo": 4},
    "ritorno":        {"nome": "Ritorno al centro", "req": ["x", "x"], "soglia": 3, "eff": "ritorno", "bonus": 0, "costo": 5},
}

TRAPPOLE = {"schivata", "irimi", "tenkan", "guardia", "proiezione", "immobilizza", "contrattacco", "ukemi"}
COLPI = {"colpo", "colpo_stordente", "spinta", "carica", "affondo"}


def freccia(t):
    """Di quanto si scala il dado per salire senza rischio: 1 per le mosse semplici, 2 per le forti."""
    return t.get("freccia", 1 if t["soglia"] <= 3 else 2)


import math
import os

DIRS = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]
_ARENE = None


def arene():
    global _ARENE
    if _ARENE is None:
        qui = os.path.dirname(os.path.abspath(__file__))
        with open(os.path.join(qui, "..", "data", "tokens.json")) as f:
            _ARENE = json.load(f)["arene"]
    return _ARENE


def hdist(a, b):
    dq, dr = a[0] - b[0], a[1] - b[1]
    return (abs(dq) + abs(dr) + abs(dq + dr)) // 2


def xy(h):
    return (h[0] + h[1] / 2.0, h[1] * 0.8660254)


def dir_verso(a, b):
    ax, ay = xy(a)
    bx, by = xy(b)
    vx, vy = bx - ax, by - ay
    best, bi = -1e9, 0
    for i, d in enumerate(DIRS):
        dx, dy = xy(d)
        v = dx * vx + dy * vy
        if v > best:
            best, bi = v, i
    return bi


def piu(a, d, k=1):
    return (a[0] + d[0] * k, a[1] + d[1] * k)


# token di scena: si caricano con qualsiasi dado e si piazzano oltre al Ritmo vicino all'oggetto
SCENA = {
    "pietre":   {"nome": "Lancio di pietra", "col": "scena", "req": ["x"], "soglia": 3, "modo": "subito", "eff": "lancio", "bonus": 0, "costo": 0, "portata": 4},
    "braciere": {"nome": "Tizzone ardente", "col": "scena", "req": ["x"], "soglia": 3, "modo": "subito", "eff": "tizzone", "bonus": 1, "costo": 0, "portata": 3},
    "fontana":  {"nome": "Acqua negli occhi", "col": "scena", "req": ["x"], "soglia": 3, "modo": "subito", "eff": "acqua", "bonus": 0, "costo": 0, "portata": 3},
    "sabbia":   {"nome": "Sabbia negli occhi", "col": "scena", "req": ["x"], "soglia": 3, "modo": "subito", "eff": "sabbia", "bonus": 0, "costo": 0, "portata": 2},
    "cassa":    {"nome": "Spingi la cassa", "col": "scena", "req": ["x"], "soglia": 3, "modo": "subito", "eff": "cassa", "bonus": 0, "costo": 0, "portata": 2},
}


def tok(tid):
    if tid in CATALOGO:
        return CATALOGO[tid]
    return SCENA[tid[6:]]


def colori_token(col):
    return {"rosso": "F", "giallo": "A", "blu": "P", "arancio": "FA", "verde": "AP", "viola": "PF", "scena": "FAP"}[col]


# ---------------------------------------------------------------------------
class Pg:
    def __init__(self, nome, F, A, P, C, R, coll, raro=None):
        self.nome, self.F, self.A, self.P, self.C, self.R = nome, F, A, P, C, R
        self.coll = list(coll)
        self.raro_id = raro
        self.vita_max = REGOLE["vita_base"] + REGOLE["vita_per_cos"] * C
        self.vita = self.vita_max
        self.vant = 0
        self.svant = 0
        self.raro = None
        self.raro_usato = False
        self.esterni = []
        self.mucchio = ["r"] * F + ["g"] * A + ["b"] * P + ["n"] * C

    def dominante(self):
        d = {"Forza": self.F, "Agilita": self.A, "Percezione": self.P, "Costituzione": self.C}
        m = max(d.values())
        top = [k for k, v in d.items() if v == m]
        return top[0] if len(top) == 1 else "equilibrato"


class Duello:
    def __init__(self, a, b, rng, st):
        self.g = [a, b]
        self.rng = rng
        self.st = st
        self._dist = REGOLE["dist0"]
        self.mappa = None
        if REGOLE["mappa"]:
            self.prepara_mappa(rng.choice(REGOLE["arene"].split(",")))
        self.scambi = 0
        self.azioni = 0
        self.primo = rng.randrange(2)
        self.iniziativa_a = None
        self.log = []
        self.uso = [defaultdict(int), defaultdict(int)]

    # ----------------------------------------------------------- mappa
    def prepara_mappa(self, nome):
        ar = arene()[nome]
        m = {"nome": nome, "R": int(ar["raggio"]), "ost": set(), "per": set(), "ogg": {}, "alt": {}, "sabbia": set(), "bassi": set()}
        for o in ar["ostacoli"]:
            m["ost"].add((o[0], o[1]))
        for o in ar.get("pericoli", []):
            m["per"].add((o[0], o[1]))
        for o in ar.get("bassi", []):
            m["bassi"].add((o[0], o[1]))
        for o in ar.get("oggetti", []):
            m["ogg"][(o[0], o[1])] = o[2]
        for o in ar.get("sabbia", []):
            m["sabbia"].add((o[0], o[1]))
        for o in ar.get("alture", []):
            m["alt"][(o[0], o[1])] = int(o[2])
        for o in ar.get("alberi_grandi", []):
            c = (o[0], o[1])
            m["ogg"][c] = "albero"
            for d in DIRS:
                m["alt"][piu(c, d)] = 1
        for h, t in m["ogg"].items():
            if t == "cassa":
                m["alt"][h] = m["alt"].get(h, 0) + 1
        CARICHE = {"pietre": 3, "braciere": 2, "fontana": 2, "cassa": 1}
        m["cariche"] = {h: CARICHE[t] for h, t in m["ogg"].items() if t in CARICHE}
        for h in m["sabbia"]:
            m["cariche"][h] = 1
        self.mappa = m
        Rr = m["R"]
        self.pos = [(-(Rr - 3), 0), (Rr - 3, 0)]
        self.dir = [0, 3]
        self.st["arene"][nome] += 1

    def alt(self, h):
        return self.mappa["alt"].get(h, 0)

    def dentro(self, h):
        return hdist(h, (0, 0)) <= self.mappa["R"]

    def bloccato(self, h):
        m = self.mappa
        return (not self.dentro(h)) or h in m["ost"] or h in m["bassi"] or m["ogg"].get(h) in ("fontana", "braciere", "albero", "pietre")

    def libero(self, h, chi=None):
        return not self.bloccato(h) and all(self.pos[i] != h for i in range(2) if i != chi)

    @property
    def dist(self):
        if self.mappa:
            return hdist(self.pos[0], self.pos[1])
        return self._dist

    def contatto(self):
        if self.mappa:
            return hdist(self.pos[0], self.pos[1]) == 1 and abs(self.alt(self.pos[0]) - self.alt(self.pos[1])) <= 1
        return self._dist <= 1

    def contatto_da(self, h, p):
        o = self.pos[1 - p]
        return hdist(h, o) == 1 and abs(self.alt(h) - self.alt(o)) <= 1

    def raggiungibili(self, p, k):
        """Esagoni raggiungibili camminando con k passi (un livello di dislivello per passo)."""
        start = self.pos[p]
        visti = {start: 0}
        coda = [start]
        while coda:
            h = coda.pop(0)
            if visti[h] >= k:
                continue
            for d in DIRS:
                nh = piu(h, d)
                if nh in visti or not self.libero(nh, p):
                    continue
                if abs(self.alt(nh) - self.alt(h)) > 1:
                    continue
                visti[nh] = visti[h] + 1
                coda.append(nh)
        return visti

    def lato(self, dif, h):
        """0 davanti ... 3 dietro, rispetto allo sguardo del difensore."""
        d = dir_verso(self.pos[dif], h)
        return (d - self.dir[dif]) % 6

    def alle_spalle_di(self, dif, h):
        return self.lato(dif, h) in (2, 3, 4)

    def valuta_casella(self, p, h):
        """Punteggio di una casella per chi si avvicina: contatto, dietro al nemico, in alto, vicino agli oggetti."""
        o = 1 - p
        v = 0.0
        if self.contatto_da(h, p):
            v += 10
            if self.alle_spalle_di(o, h):
                v += 3
        v -= hdist(h, self.pos[o]) * 1.5
        v += 0.8 * self.alt(h) + (0.6 if self.alt(h) > self.alt(self.pos[o]) else 0)
        if h in self.mappa["per"]:
            v -= 4
        if REGOLE["token_scena"] and self.oggetto_vicino(h):
            v += 0.4
        return v

    def gira_verso(self, p):
        if self.mappa:
            self.dir[p] = dir_verso(self.pos[p], self.pos[1 - p])

    def avvicina(self, p, k):
        if not self.mappa:
            self._dist = max(1, self._dist - k)
            return
        rag = self.raggiungibili(p, k)
        best = max(rag, key=lambda h: self.valuta_casella(p, h) + self.rng.random() * 0.3)
        self.pos[p] = best
        self.gira_verso(p)

    def allontana(self, p, k):
        if not self.mappa:
            self._dist = min(REGOLE["dist_max"], self._dist + k)
            return
        rag = self.raggiungibili(p, k)
        o = self.pos[1 - p]
        best = max(rag, key=lambda h: hdist(h, o) + 0.3 * self.alt(h) - (4 if h in self.mappa["per"] else 0) + self.rng.random() * 0.2)
        self.pos[p] = best
        self.gira_verso(p)

    def porta_contatto(self, p, k, dritto=False):
        """Salto o carica: arrivi a contatto se entro k esagoni, scavalcando. Dritto: atterri davanti, non sul fianco."""
        if not self.mappa:
            if self._dist <= k:
                self._dist = 1
            return
        o = self.pos[1 - p]
        cand = [piu(o, d) for d in DIRS]
        cand = [h for h in cand if self.libero(h, p) and abs(self.alt(h) - self.alt(o)) <= 1 and hdist(h, self.pos[p]) <= k]
        if not cand:
            self.avvicina(p, k)
            return
        if dritto:
            self.pos[p] = min(cand, key=lambda h: (hdist(h, self.pos[p]), -self.alt(h)))
        else:
            self.pos[p] = max(cand, key=lambda h: self.valuta_casella(p, h) + self.rng.random() * 0.3)
        self.gira_verso(p)

    def alle_spalle(self, p):
        if not self.mappa:
            self._dist = 1
            return True
        o = 1 - p
        cand = [piu(self.pos[o], d) for d in DIRS]
        cand = [h for h in cand if self.libero(h, p) and abs(self.alt(h) - self.alt(self.pos[o])) <= 1]
        if not cand:
            return False
        cand.sort(key=lambda h: (-(abs(self.lato(o, h) - 3) == 0), abs(self.lato(o, h) - 3), -self.alt(h)))
        self.pos[p] = cand[0]
        self.gira_verso(p)
        return self.alle_spalle_di(o, cand[0])

    def aggira(self, p, k):
        """A contatto: giri attorno al nemico di k esagoni verso le sue spalle. Ritorna True se arrivi dietro."""
        if not self.mappa:
            return False
        o = 1 - p
        visti = {self.pos[p]: 0}
        coda = [self.pos[p]]
        while coda:
            h = coda.pop(0)
            if visti[h] >= k:
                continue
            for d in DIRS:
                nh = piu(h, d)
                if nh in visti or hdist(nh, self.pos[o]) != 1 or not self.libero(nh, p):
                    continue
                if abs(self.alt(nh) - self.alt(h)) > 1 or abs(self.alt(nh) - self.alt(self.pos[o])) > 1:
                    continue
                visti[nh] = visti[h] + 1
                coda.append(nh)
        best = min(visti, key=lambda h: (abs(self.lato(o, h) - 3), -self.alt(h)))
        self.pos[p] = best
        self.gira_verso(p)
        return self.alle_spalle_di(o, best)

    def spingi(self, att, dif, k):
        """Spinta o proiezione: dif vola di k esagoni; urta, cade dalle alture, finisce nei pericoli."""
        if not self.mappa:
            self._dist = min(REGOLE["dist_max"], self._dist + k)
            return
        d = DIRS[dir_verso(self.pos[att], self.pos[dif])]
        for _ in range(k):
            cur = self.pos[dif]
            nh = piu(cur, d)
            if not self.libero(nh, dif) or self.alt(nh) > self.alt(cur):
                self.ferisci(dif, REGOLE["danno_urto"], "urto")
                self.st["urti"] += 1
                break
            calo = self.alt(cur) - self.alt(nh)
            self.pos[dif] = nh
            if calo > 0:
                self.ferisci(dif, calo, "caduta")
                self.st["cadute"] += 1
            if nh in self.mappa["per"]:
                self.ferisci(dif, REGOLE["danno_pericolo"], "pericolo")
                self.st["pericoli"] += 1
        self.st["spinte"] += 1

    def spinta_utile(self, p):
        """Spingere il nemico di un esagono lo manderebbe contro qualcosa o giu' da un'altura?"""
        if not self.mappa or not REGOLE.get("presa_sbilancia", True):
            return False
        o = 1 - p
        d = DIRS[dir_verso(self.pos[p], self.pos[o])]
        nh = piu(self.pos[o], d)
        return (not self.libero(nh, o)) or self.alt(nh) < self.alt(self.pos[o]) or nh in self.mappa["per"]

    def oggetto_vicino(self, h, con_casella=False):
        """Oggetto di scena usabile da h (con cariche rimaste): sabbia sotto i piedi o un oggetto accanto."""
        if not self.mappa:
            return None
        m = self.mappa
        if h in m["sabbia"] and m["cariche"].get(h, 0) > 0:
            return ("sabbia", h) if con_casella else "sabbia"
        for d in DIRS:
            nh = piu(h, d)
            t = m["ogg"].get(nh)
            if t in SCENA and m["cariche"].get(nh, 0) > 0:
                return (t, nh) if con_casella else t
        return None

    def spalle_al_muro(self, p):
        if not self.mappa:
            return False
        h = self.pos[p]
        for d in DIRS:
            nh = piu(h, d)
            if nh in self.mappa["ost"] or self.mappa["ogg"].get(nh) == "albero":
                return True
        return False

    def mod_posizione(self, p):
        """Danno in piu' per altezza e spalle; e se il difensore puo' scartare."""
        if not self.mappa or not self.contatto():
            return 0, True
        d = 1 - p
        extra = 0
        if self.alt(self.pos[p]) > self.alt(self.pos[d]):
            extra += REGOLE["danno_alto"]
            self.st["colpi_dall_alto"] += 1
        dietro = self.alle_spalle_di(d, self.pos[p])
        if dietro:
            extra += REGOLE["danno_spalle"]
            self.st["colpi_alle_spalle"] += 1
        return extra, not dietro

    # ----------------------------------------------------------- dadi e stato
    def tira(self):
        return self.rng.randint(1, 6)

    def pausa(self):
        self.scambi += 1
        for p, g in enumerate(self.g):
            if REGOLE["recupero"]:
                g.vita = min(g.vita_max, g.vita + REGOLE["recupero"])
            tenuti = []
            slot = g.R
            if self.mappa and REGOLE["assetto_posizione"] and self.alt(self.pos[p]) >= 1:
                slot += 1
                self.st["rialzo_token"] += 1
            if REGOLE["persistenti"] and self.scambi > 1:
                tenuti = [e for e in getattr(g, "esterni", []) if e["dadi"] and not e.get("scattato") and not e["id"].startswith("scena_")]
                tenuti.sort(key=lambda e: -len(e["dadi"]))
                tenuti = tenuti[: slot]
                if self.mappa and REGOLE["assetto_posizione"] and self.spalle_al_muro(p) and tenuti:
                    # spalle a colonna o albero: cambi gratis il token tenuto meno carico che non e' pronto
                    cand = [e for e in tenuti if not e["pronto"]]
                    if cand and self.rng.random() < 0.5:
                        tenuti.remove(min(cand, key=lambda e: len(e["dadi"])))
                        self.st["cambi_al_muro"] += 1
                for e in tenuti:
                    e["bloccato"] = False
            impegnati = [c for e in tenuti for c, _ in e["dadi"]]
            pool = list(g.mucchio)
            for c in impegnati:
                if c in pool:
                    pool.remove(c)
            pesc = self.rng.sample(pool, min(REGOLE["pesca"], len(pool)))
            g.mano = [[c, self.tira()] for c in pesc]
            g.fermi = []            # [colore, azione] dadi fermi sui token base
            g.girate = set()        # azioni base gia' girate in questo scambio
            g.svant = 0
            g.flussi = 0
            g.zanshin = max(0, getattr(g, "zanshin", 0) - 1)
            g.kime = False
            g.occhio = False
            g.passo_libero = REGOLE.get("passo_libero", 0)
            g.catena_extra = 0
            g.tenuto = False
            g.esterni = list(tenuti)
            gia = {e["id"] for e in tenuti}
            for tid in g.coll:
                self.st["disponibile"][tid] += 1
            for tid in self.scegli_token(p, len(tenuti), gia, slot):
                g.esterni.append({"id": tid, "dadi": [], "pronto": False, "bloccato": False, "pot": False})
                self.st["piazzati"][tid] += 1
            ogg = self.oggetto_vicino(self.pos[p], True) if (self.mappa and REGOLE["token_scena"]) else None
            if ogg:
                tid = "scena_" + ogg[0]
                g.esterni.append({"id": tid, "dadi": [], "pronto": False, "bloccato": False, "pot": False, "ogg_h": ogg[1]})
                self.st["piazzati"][tid] += 1
            if getattr(g, "raro", None) and REGOLE["persistenti"]:
                pass
            elif g.raro_id and REGOLE["raro"] and not getattr(g, "raro_usato", False):
                g.raro = {"id": g.raro_id, "dadi": [], "pronto": False}
        self.attivo = (self.primo + self.scambi) % 2
        self.finito = [False, False]
        if self.mappa:
            self.gira_verso(0)
            self.gira_verso(1)

    def scegli_token(self, p, gia_n=0, gia=(), slot=None):
        g = self.g[p]
        slot = g.R if slot is None else slot
        forze = {"F": g.F + g.C * 0.3, "A": g.A + g.C * 0.3, "P": g.P + g.C * 0.3}
        punt = []
        for tid in g.coll:
            if tid in gia:
                continue
            t = CATALOGO[tid]
            s = sum(forze[c] for c in colori_token(t["col"])) / len(colori_token(t["col"]))
            s += self.rng.random() * 1.5
            if t["eff"] in COLPI and self.dist > 2:
                s += 0.5
            punt.append((s, tid))
        punt.sort(reverse=True)
        if REGOLE.get("potenziamenti_fuori_ritmo"):
            pot = [tid for _, tid in punt if CATALOGO[tid]["eff"] in ("kime", "sen", "zanshin")][:1]
            altri = [tid for _, tid in punt if tid not in pot]
            return pot + altri[: max(0, slot - gia_n)]
        return [tid for _, tid in punt[: max(0, slot - gia_n)]]

    def nemico(self, p):
        return self.g[1 - p]

    def valore(self, g, v):
        if g.svant > 0:
            g.svant -= 1
            return max(1, v - 1)
        return v

    def ferisci(self, p, n, fonte):
        if n <= 0:
            return
        g = self.g[p]
        g.vita -= n
        self.st["danni"][fonte] += n

    def puo_agire(self, p):
        g = self.g[p]
        if self.finito[p]:
            return False
        return bool(g.mano) or bool(g.fermi) or any(e["pronto"] and not e["bloccato"] and tok(e["id"])["modo"] == "subito" and self.in_portata(e) for e in g.esterni)

    # ----------------------------------------------------------- token esterni
    def posti_liberi(self, e):
        t = tok(e["id"])
        usati = [c for c, _ in e["dadi"]]
        liberi = list(t["req"])
        for c in usati:
            if c in liberi:
                liberi.remove(c)
            elif "n" in liberi:
                liberi.remove("n")
            elif "x" in liberi:
                liberi.remove("x")
        return liberi

    def puo_caricare(self, e, colore, settore):
        if e["pronto"] or e["bloccato"]:
            return False
        t = tok(e["id"])
        if settore not in colori_token(t["col"]):
            return False
        liberi = self.posti_liberi(e)
        if not liberi:
            return False
        if "x" in liberi:
            return True
        primario = PRIMARI.get(t["col"])
        if colore == "n":
            # neutri: solo nei token primari
            return primario is not None and (primario in liberi or "n" in liberi)
        return colore in liberi or ("n" in liberi and colore == primario)

    def bersagli_salita(self, p, colore, settore):
        g = self.g[p]
        return [e for e in g.esterni if self.puo_caricare(e, colore, settore)]

    def sali(self, p, colore, settore, mia_azione, valore=4):
        """Passaggio verso l'esterno. Ritorna (salito, scattato, continua/perso)."""
        g = self.g[p]
        cand = self.bersagli_salita(p, colore, settore)
        if not cand:
            return False, False, False
        # preferisce il token piu' vicino a riempirsi
        cand.sort(key=lambda e: len(self.posti_liberi(e)))
        e = cand[0]
        t = tok(e["id"])
        if REGOLE["passaggio"] == "freccia":
            return self.sali_freccia(p, e, t, colore, mia_azione, valore)
        soglia = t["soglia"] + REGOLE["soglia_delta"]
        v = self.tira() if REGOLE["ritiro"] else 4
        ridotto = False
        self.st["passaggi"] += 1
        if REGOLE["ritiro"] and v < soglia:
            self.st["passaggi_falliti"] += 1
            completa = len(self.posti_liberi(e)) == 1
            if REGOLE["ridotto"] and completa and self.rng.random() < 0.8:
                v = max(1, v // 2)
                ridotto = True
                self.st["ridotti"] += 1
            else:
                return False, False, False
        e["dadi"].append((colore, v))
        if self.posti_liberi(e):
            return True, False, ridotto
        e["pronto"] = True
        if REGOLE["combo"] and len(e["dadi"]) >= 2 and len({x for _, x in e["dadi"]}) == 1:
            e["pot"] = True
            self.st["combo"] += 1
        if t["modo"] == "subito":
            scattato = self.scatta(p, e)
            return True, scattato, ridotto
        self.st["armati"][e["id"]] += 1
        return True, False, ridotto

    def sali_freccia(self, p, e, t, colore, mia_azione, valore):
        g = self.g[p]
        k = 0 if getattr(g, "kime", False) else freccia(t)
        scalato = max(1, valore - k)
        self.st["passaggi"] += 1
        puo_continuare = mia_azione or REGOLE["reazione_continua"]
        soglia_ia = getattr(g, "rischio", REGOLE["ia_rischio"]) + (2 if getattr(g, "zanshin", 0) else 0)
        caso = 0 if hasattr(g, "rischio") else (0.6 if getattr(g, "zanshin", 0) else 0.25)
        rischia = scalato < soglia_ia or (puo_continuare and self.rng.random() < caso)
        continua = False
        if rischia:
            self.st["ritiri"] += 1
            v = self.tira()
            soglia_fallo = 1 if getattr(g, "zanshin", 0) else REGOLE["fallisce_fino"]
            if v <= soglia_fallo:
                self.st["passaggi_falliti"] += 1
                return False, False, False   # il dado va in Attesa
            continua = puo_continuare
            if REGOLE.get("vant_ritiro"):
                g.vant = min(REGOLE["max_vant"], g.vant + 1)
        else:
            v = scalato
            self.st["scalati"] += 1
        e["dadi"].append((colore, v))
        if self.posti_liberi(e):
            return True, False, continua
        e["pronto"] = True
        if REGOLE["combo"] and len(e["dadi"]) >= 2 and len({x for _, x in e["dadi"]}) == 1:
            e["pot"] = True
            self.st["combo"] += 1
        if t["modo"] == "subito":
            self.scatta(p, e)
            return True, True, continua
        self.st["armati"][e["id"]] += 1
        return True, False, continua

    def somma(self, e):
        return sum(v for _, v in e["dadi"])

    def in_portata(self, e):
        eff = tok(e["id"])["eff"]
        if eff in ("colpo", "colpo_stordente", "spinta", "sgambetto"):
            return self.contatto()
        if eff == "affondo":
            return self.dist <= 2
        if eff == "carica":
            return self.dist <= 4
        if eff == "alle_spalle":
            return self.dist <= 3
        t = tok(e["id"])
        if "portata" in t:
            return self.dist <= t["portata"]
        return True

    def scatta(self, p, e):
        """Effetti dei token 'subito'. Ritorna True se e' scattato."""
        g, n = self.g[p], self.nemico(p)
        t = tok(e["id"])
        eff = t["eff"]
        s = self.somma(e) + t["bonus"] + (2 if e["pot"] else 0)
        if not self.in_portata(e):
            return False
        self.st["scatti"][e["id"]] += 1
        g.esterni.remove(e)
        if "ogg_h" in e and self.mappa:
            self.mappa["cariche"][e["ogg_h"]] = self.mappa["cariche"].get(e["ogg_h"], 1) - 1
        if eff in COLPI:
            if eff == "carica":
                self.porta_contatto(p, 4, dritto=True)
            if eff == "affondo":
                self.porta_contatto(p, 2, dritto=True)
            dmg = self.attacco(p, s, max(v for _, v in e["dadi"]), fonte=e["id"])
            if eff == "colpo_stordente" and dmg > 0:
                n.svant += 2
                if n.mano:
                    n.mano.sort(key=lambda d: d[1])
                    n.mano.pop()
            if eff == "spinta" and dmg >= 0:
                self.spingi(p, 1 - p, 2)
                n.svant += 1
            if eff == "affondo":
                self.allontana(p, 1)
        elif eff == "balzo":
            if self.vuole_contatto(p):
                self.porta_contatto(p, 3, dritto=True)
            else:
                self.allontana(p, 2)
            g.vant = min(REGOLE["max_vant"], g.vant + 1 + (1 if e["pot"] else 0))
            if self.contatto():
                self.attacco(p, self.somma(e) + t["bonus"], max(v for _, v in e["dadi"]), fonte=e["id"])
        elif eff == "alle_spalle":
            self.alle_spalle(p)
            if REGOLE.get("salto_senza_colpo"):
                g.vant = min(REGOLE["max_vant"], g.vant + 1)
                self.iniziativa_a = p   # atterri alle spalle: il colpo lo dai con l'azione che segue
            else:
                self.attacco(p, self.somma(e) + 2 + t["bonus"], 6, fonte=e["id"])  # alle spalle: si scarta solo con 5-6
        elif eff in ("lancio", "tizzone"):
            dmg = self.attacco(p, s, max(v for _, v in e["dadi"]), fonte=e["id"])
            if eff == "tizzone" and dmg > 0:
                n.svant += 1
        elif eff == "acqua":
            n.svant += 2
            if n.mano:
                n.mano.sort(key=lambda d: d[1])
                n.mano.pop()
        elif eff == "sabbia":
            n.svant += 2
            best = [d for d in n.mano if d[0] in ("b", "g", "n")]
            if best:
                max(best, key=lambda d: d[1])[1] = 1
        elif eff == "cassa":
            self.ferisci(1 - p, 1, e["id"])
            self.spingi(p, 1 - p, 1)
        elif eff == "respiro":
            cura = min(3, (self.somma(e) + 1) // 2 + (1 if e["pot"] else 0))
            g.vita = min(g.vita_max, g.vita + cura)
            g.svant = 0
            self.st["cure"] += cura
        elif eff == "lettura":
            g.vant = min(REGOLE["max_vant"], g.vant + 2 + (1 if e["pot"] else 0))
            n.vant = max(0, n.vant - 2)   # leggi le sue intenzioni: perde 2 vantaggi
            g.occhio = True               # e per lo scambio i suoi colpi fanno 1 danno in meno
            if REGOLE.get("cavalieri"):
                self.iniziativa_a = p   # leggi e anticipi: l'iniziativa resta tua
            n.svant += 2
            # vedi il prossimo dado: il nemico perde la reazione migliore
            best = [d for d in n.mano if d[0] in ("b", "g", "n")]
            if best:
                best.sort(key=lambda d: -d[1])
                best[0][1] = max(1, best[0][1] - 2)
        elif eff == "sgambetto":
            self.ferisci(1 - p, 1 + D(self.somma(e)) // 2 + t["bonus"] + (1 if e["pot"] else 0), e["id"])
            n.svant += 2
            if n.mano:
                n.mano.sort(key=lambda d: d[1])
                n.mano.pop(0)
        elif eff == "kime":
            # dadi potenziati: +1 a quelli in mano, e per lo scambio salire non scala il dado
            k = 2 if REGOLE.get("potenziamenti_forti", True) else 1
            for d in g.mano:
                d[1] = min(6, d[1] + k + (1 if e["pot"] else 0))
            g.fermi = [(c, az, min(6, v + k)) for c, az, v in g.fermi]
            g.kime = True
        elif eff == "sen":
            # prendi l'iniziativa ora e, per lo scambio, una catena in piu'
            self.iniziativa_a = p
            g.catena_extra = getattr(g, "catena_extra", 0) + (99 if REGOLE.get("potenziamenti_forti", True) else 1)
            if REGOLE.get("potenziamenti_forti", True):
                g.vant = min(REGOLE["max_vant"], g.vant + 1)
        elif eff == "zanshin":
            g.zanshin = 2   # vale per questo scambio e il prossimo
            g.vant = min(REGOLE["max_vant"], g.vant + (2 if REGOLE.get("potenziamenti_forti", True) else 1))
            if REGOLE.get("potenziamenti_forti", True):
                g.svant = 0
        elif eff == "calma":
            for _ in range(2 + (1 if e["pot"] else 0)):
                g.mano.append([self.rng.choice(g.mucchio), self.tira()])
        elif eff == "provoca":
            n.svant += 2 + (1 if e["pot"] else 0)
            g.vant = min(REGOLE["max_vant"], g.vant + 1)
            if n.mano:
                n.mano.sort(key=lambda d: d[1])
                n.mano.pop()
        self.caricare_raro(p, e)
        return True

    def caricare_raro(self, p, e):
        g = self.g[p]
        r = getattr(g, "raro", None)
        if not r or r["pronto"] or len(e["dadi"]) == 0:
            return
        if not REGOLE["raro_da_tutti"] and tok(e["id"])["col"] not in ("viola", "verde", "arancio"):
            return
        t = RARI[r["id"]]
        soglia = REGOLE["soglia_raro"] + REGOLE["soglia_delta"]
        v = self.tira()
        if v < soglia:
            return
        r["dadi"].append(("x", v))
        if len(r["dadi"]) >= len(t["req"]):
            r["pronto"] = True
            self.st["raro_pronto"][r["id"]] += 1
            if t["eff"] in ("kiai", "ritorno") or (t["eff"] == "tenchi" and self.contatto()):
                self.scatta_raro(p)

    def scatta_raro(self, p):
        g, n = self.g[p], self.nemico(p)
        r = g.raro
        t = RARI[r["id"]]
        s = D(sum(v for _, v in r["dadi"])) + t["bonus"]
        self.st["raro_scatti"][r["id"]] += 1
        if t["eff"] == "tenchi":
            self.ferisci(1 - p, s, r["id"])
            self.spingi(p, 1 - p, 3)
            for _ in range(2):
                if n.mano:
                    n.mano.pop(self.rng.randrange(len(n.mano)))
        elif t["eff"] == "kiai":
            for x in n.esterni:
                if x["pronto"]:
                    x["pronto"] = False
                    x["dadi"] = []
            n.svant += 2
            g.vant = min(REGOLE["max_vant"], g.vant + 2)
        elif t["eff"] == "ritorno":
            for _ in range(2):
                g.mano.append([self.rng.choice(g.mucchio), self.tira()])
        g.raro = None
        g.raro_usato = True

    # ----------------------------------------------------------- attacco e reazioni
    def attacco(self, p, danno, dado_max, fonte):
        """Risolve un attacco di p; ritorna il danno inflitto (-1 se annullato da trappola)."""
        g, d = self.g[p], 1 - p
        n = self.g[d]
        danno = D(danno)
        extra, puo_scartare = self.mod_posizione(p)
        danno += extra
        if getattr(n, "occhio", False):
            danno = max(0, danno - 1)
        spesa = min(g.vant, REGOLE["vant_per_colpo"])
        danno += spesa
        g.vant -= spesa
        self.st["attacchi"] += 1
        # 0. guardia ferrea: riduzione passiva per tutto lo scambio, poi si reagisce normalmente
        for e in n.esterni:
            if e["pronto"] and not e["bloccato"] and tok(e["id"])["eff"] == "guardia":
                danno = max(0, danno - 2 - (1 if e["pot"] else 0))
                self.st["scatti"][e["id"]] += 1
                if not e.get("respinto"):
                    self.ferisci(p, 1, e["id"])
                    e["respinto"] = True
                if danno == 0:
                    return 0
                break
        # 1. trappole armate del difensore
        trap = [e for e in n.esterni if e["pronto"] and not e["bloccato"] and tok(e["id"])["eff"] in TRAPPOLE - {"guardia"}]
        if trap:
            trap.sort(key=lambda e: -self.valore_trappola(e))
            e = trap[0]
            return self.risolvi_trappola(d, e, danno, p)
        # 2. reazioni con un dado: parata o scarto
        best = None
        for i, (c, v) in enumerate(n.mano):
            if c in ("b", "n"):
                rid = D(v) if REGOLE["parata_piena"] else max(0, D(v) - 1)
                resto = max(0, danno - rid)
                pot = REGOLE["doppia_faccia"] and n.vant >= 1 and "parata" not in n.girate
                cand = (resto, 0, i, "parata")
                if best is None or cand < best:
                    best = cand
            if puo_scartare and c in ("g", "n") and v >= dado_max - REGOLE["scarto_tolleranza"]:
                cand = (0, 1, i, "scarto")
                if best is None or cand < best:
                    best = cand
        if best is not None and danno - best[0] >= REGOLE.get("soglia_reazione_ia", 1):
            resto, _, i, tipo = best
            c, v = n.mano.pop(i)
            v = self.valore(n, v)
            self.st["reazioni"][tipo] += 1
            self.uso[d][tipo] += 1
            if tipo == "parata":
                ferrea = REGOLE["doppia_faccia"] and n.vant >= 1 and "parata" not in n.girate and danno - v > 0
                rid = D(v) if REGOLE["parata_piena"] else max(0, D(v) - 1)
                if ferrea:
                    n.vant -= 1
                    n.girate.add("parata")
                    rid += 1
                    self.ferisci(p, 1, "parata_ferrea")
                    self.st["girate"]["parata"] += 1
                    self.uso[d]["gira_parata"] += 1
                if REGOLE["vant_in_parata"]:
                    k = min(n.vant, 2, max(0, danno - rid))
                    n.vant -= k
                    rid += k
                resto = max(0, danno - rid)
                self.ferisci(d, resto, fonte)
                if resto == 0 and REGOLE["vant_reazione"]:
                    n.vant = min(REGOLE["max_vant"], n.vant + 1)
                if REGOLE.get("parata_respinge", True) and rid - danno >= REGOLE.get("respinge_margine", 2):
                    self.ferisci(p, 1, "parata_respinge")
                self.sali(d, c, "P", False, v)
                return resto
            else:
                self.allontana(d, 1)
                if REGOLE["vant_reazione"]:
                    n.vant = min(REGOLE["max_vant"], n.vant + 1)
                if REGOLE["doppia_faccia"] and n.vant >= 1 and "scarto" not in n.girate:
                    n.vant -= 1
                    n.girate.add("scarto")
                    n.vant = min(REGOLE["max_vant"], n.vant + 2)
                    self.st["girate"]["scarto"] += 1
                    self.uso[d]["gira_scarto"] += 1
                self.sali(d, c, "A", False, v)
                return 0
        self.ferisci(d, danno, fonte)
        return danno

    def valore_trappola(self, e):
        return {"proiezione": 5, "immobilizza": 4, "contrattacco": 4, "irimi": 3, "tenkan": 3, "guardia": 1, "schivata": 2, "ukemi": 2}[tok(e["id"])["eff"]]

    def risolvi_trappola(self, d, e, danno, att):
        n, a = self.g[d], self.g[att]
        t = tok(e["id"])
        eff = t["eff"]
        s = D(self.somma(e)) + t["bonus"] + (2 if e["pot"] else 0)
        n.esterni.remove(e)
        e["usato"] = True
        self.st["scatti"][e["id"]] += 1
        inflitto = 0
        if eff == "schivata":
            n.vant = min(REGOLE["max_vant"], n.vant + 1)
            if REGOLE.get("cavalieri") and t["col"] == "verde":
                n.zanshin = 2   # uscire dalla linea: per due scambi i ritiri falliscono solo con 1
            self.ferisci(att, 1 + t["bonus"] + (1 if e["pot"] else 0), e["id"])
        elif eff == "irimi":
            n.vant = min(REGOLE["max_vant"], n.vant + 3 + (1 if e["pot"] else 0))
            a.svant += 1
            self.ferisci(att, 1, e["id"])
            self.iniziativa_a = d   # entri sul fianco: l'iniziativa e' tua
            if self.mappa:
                self.alle_spalle(d)  # e finisci al suo fianco o alle sue spalle
        elif eff == "tenkan":
            n.vant = min(REGOLE["max_vant"], n.vant + 1)
            a.svant += 1
            if not self.mappa:
                self._dist = 1
            self.ferisci(att, 1 + (1 if e["pot"] else 0), e["id"])
            if REGOLE.get("cavalieri"):
                for x in n.mano:   # la rotazione carica i tuoi dadi
                    x[1] = min(6, x[1] + 1)
            if a.mano:
                a.mano.pop(self.rng.randrange(len(a.mano)))
        elif eff == "guardia":
            inflitto = max(0, danno - 2 - (1 if e["pot"] else 0))
            self.ferisci(d, inflitto, "guardia_passata")
            if not e.get("respinto"):
                self.ferisci(att, 1, e["id"])
                e["respinto"] = True
        elif eff == "proiezione":
            self.ferisci(att, s, e["id"])
            self.spingi(d, att, 2)
        elif eff == "immobilizza":
            self.ferisci(att, (s + 1) // 2, e["id"])
            a.svant += 1
            for _ in range(1):
                if a.mano:
                    a.mano.pop(self.rng.randrange(len(a.mano)))
        elif eff == "ukemi":
            n.vant = min(REGOLE["max_vant"], n.vant + 1)
            n.svant = 0
            n.vita = min(n.vita_max, n.vita + 2 + (1 if e["pot"] else 0))
        elif eff == "contrattacco":
            inflitto = max(0, danno - 3)
            self.ferisci(d, inflitto, "contrattacco_subito")
            self.ferisci(att, s, e["id"])
        self.caricare_raro(d, e)
        if n.raro and n.raro["pronto"] and RARI[n.raro["id"]]["eff"] == "tenchi":
            self.scatta_raro(d)
        return inflitto if inflitto else -1

    # ----------------------------------------------------------- intelligenza
    def vuole_contatto(self, p):
        return True

    def trappole_nemiche(self, p):
        return [e for e in self.nemico(p).esterni if e["pronto"] and not e["bloccato"] and tok(e["id"])["eff"] in TRAPPOLE - {"guardia"}]

    def opzioni(self, p):
        g, n = self.g[p], self.nemico(p)
        op = []
        trap = self.trappole_nemiche(p)
        cont = self.contatto()
        # token pronti in attesa del contatto
        for e in g.esterni:
            if e["pronto"] and not e["bloccato"] and tok(e["id"])["modo"] == "subito" and self.in_portata(e):
                op.append((9, "scatta", e))
        if g.raro and g.raro["pronto"] and RARI[g.raro["id"]]["eff"] == "tenchi" and cont:
            op.append((10, "raro", None))
        blu_in_mano = sum(1 for c, _ in g.mano if c == "b")
        if self.mappa and getattr(g, "passo_libero", 0) and not cont and g.mano:
            op.append((5.5, "passo_libero", None))
        for i, (c, v) in enumerate(g.mano):
            if c in ("r", "n") and cont:
                if trap:
                    # esca: si attacca con il dado peggiore per far scattare la trappola
                    op.append((3 + (6 - v) * 0.3, "colpo", i))
                else:
                    sc = v + min(g.vant, REGOLE["vant_per_colpo"]) + 0.6 * len(self.bersagli_salita(p, c if c != "n" else "r", "F"))
                    if c == "n":
                        sc -= 0.8
                    op.append((sc, "colpo", i))
                op.append((1.5 + (2 if not g.tenuto and n.mano else 0) * 0.4 + (1 if v >= 5 else 0) + (2.5 if v >= REGOLE.get("presa_soglia_spinta", 5) and self.spinta_utile(p) else 0), "presa", i))
            if c in ("g", "n") and not g.tenuto:
                if not cont:
                    op.append((5 + v * 0.2, "passo", i))
                elif trap and not self.bersagli_salita(p, c, "A"):
                    op.append((1.0, "passo_via", i))
                elif REGOLE["aggirare"]:
                    op.append((2.2 + 0.5 * len(self.bersagli_salita(p, c, "A")) - (0.8 if c == "n" else 0), "aggira", i))
            if c in ("b", "n"):
                minaccia = any(cc in ("r", "n") for cc, _ in n.mano) and self.dist <= 2
                riserva = 2 if blu_in_mano <= 1 and c == "b" and minaccia else 0
                op.append((1.8 - riserva + 0.5 * len(self.bersagli_salita(p, c, "P")), "leggi", i))
        for j, (c, az, vf) in enumerate(g.fermi):
            sett = AZIONE_SETTORE[az]
            if self.bersagli_salita(p, c, sett):
                op.append((4.0, "sali", j))
            if REGOLE["doppia_faccia"] and az not in g.girate:
                if az == "presa" and cont:
                    op.append((3.0, "gira", j))
                elif az == "passo" and (not cont):
                    op.append((4.5, "gira", j))
                elif az == "leggi":
                    op.append((2.5, "gira", j))
        return op

    def agisci(self, p):
        g, n = self.g[p], self.nemico(p)
        op = self.opzioni(p)
        op = [o for o in op if o[0] > 0]
        if not op:
            return False, False
        if self.rng.random() < 0.12:
            sc, tipo, x = self.rng.choice(op)
        else:
            sc, tipo, x = max(op, key=lambda o: o[0] + self.rng.random() * 0.8)
        self.azioni += 1
        self.st["azioni"][tipo] += 1
        self.uso[p][tipo] += 1
        flusso = False
        if tipo == "scatta":
            self.scatta(p, x)
            if x in g.esterni:  # non e' riuscito a scattare
                pass
        elif tipo == "raro":
            self.scatta_raro(p)
        elif tipo == "colpo":
            c, v = g.mano.pop(x)
            v = self.valore(g, v)
            pesante = REGOLE["doppia_faccia"] and g.vant >= 3 and "colpo" not in g.girate
            dmg = v
            if pesante:
                g.vant -= REGOLE.get("costo_colpo_pesante", 1)
                g.girate.add("colpo")
                dmg += 2
                self.st["girate"]["colpo"] += 1
                self.uso[p]["gira_colpo"] += 1
            self.attacco(p, dmg, v, "colpo")
            if g.vita > 0 and n.vita > 0:
                sal, sca, perso = self.sali(p, c if c != "n" else "n", "F", True, v)
                if REGOLE["passaggio"] == "freccia":
                    if perso and REGOLE["flusso"] and g.flussi < REGOLE["catena_max"] + getattr(g, "catena_extra", 0):
                        flusso = True
                elif sca and REGOLE["flusso"] and g.flussi < REGOLE["flusso_per_scambio"] and not perso:
                    flusso = True
        elif tipo == "presa":
            c, v = g.mano.pop(x)
            v = self.valore(g, v)
            n.svant += 1
            if REGOLE.get("presa_toglie") and n.mano:
                n.mano.sort(key=lambda d: d[1])
                n.mano.pop()
            if v >= 5:
                n.tenuto = True
            if self.mappa and v >= REGOLE.get("presa_soglia_spinta", 5) and REGOLE.get("presa_sbilancia", True):
                self.spingi(p, 1 - p, 1)   # lo sbilanci: un esagono, contro muri e giu' dalle alture
                self.st["prese_sbilancia"] += 1
            g.fermi.append((c, "presa", v))
        elif tipo == "passo_libero":
            g.passo_libero = 0
            self.avvicina(p, REGOLE["passo_libero"])
        elif tipo in ("passo", "passo_via"):
            c, v = g.mano.pop(x)
            v = self.valore(g, v)
            k = (2 if v >= 5 else 1) + REGOLE.get("passo_extra", 0)
            if tipo == "passo":
                self.avvicina(p, k)
            else:
                self.allontana(p, k)
            g.fermi.append((c, "passo", v))
        elif tipo == "aggira":
            c, v = g.mano.pop(x)
            v = self.valore(g, v)
            dietro = self.aggira(p, 2 if v >= REGOLE.get("aggira_due", 4) else 1)
            g.vant = min(REGOLE["max_vant"], g.vant + (2 if dietro else 1))
            if v >= 5 or dietro:
                n.svant += 1
            if dietro:
                self.st["aggirati_dietro"] += 1
            g.fermi.append((c, "passo", v))
        elif tipo == "leggi":
            c, v = g.mano.pop(x)
            v = self.valore(g, v)
            g.vant = min(REGOLE["max_vant"], g.vant + (2 if v >= 5 and REGOLE.get("leggi_forte", True) else 1))
            if v >= REGOLE.get("leggi_soglia_svant", 4) and REGOLE.get("leggi_svant", True):
                n.svant += 1
            g.fermi.append((c, "leggi", v))
        elif tipo == "sali":
            c, az, vf = g.fermi.pop(x)
            sal, sca, perso = self.sali(p, c, AZIONE_SETTORE[az], True, vf)
            if REGOLE["passaggio"] == "freccia":
                if perso and REGOLE["flusso"] and g.flussi < REGOLE["catena_max"] + getattr(g, "catena_extra", 0):
                    flusso = True
            elif sca and REGOLE["flusso"] and REGOLE.get("flusso_da_sali") and g.flussi < REGOLE["flusso_per_scambio"] and not perso:
                flusso = True
        elif tipo == "gira":
            c, az, vf = g.fermi.pop(x)
            g.girate.add(az)
            self.st["girate"][az] += 1
            self.uso[p]["gira_" + az] += 1
            if az == "presa":
                n.svant += 2
                cand = [e for e in n.esterni if not e["bloccato"]]
                if cand:
                    cand.sort(key=lambda e: -len(e["dadi"]) - (5 if e["pronto"] else 0))
                    cand[0]["bloccato"] = True
                    self.st["blocchi"] += 1
            elif az == "passo":
                self.porta_contatto(p, 3)
                g.vant = min(REGOLE["max_vant"], g.vant + 1)
            elif az == "leggi":
                g.vant = min(REGOLE["max_vant"], g.vant + 2)
                if REGOLE.get("occhio_in_lettura", True):
                    # Lettura profonda assorbe l'Occhio del falco: il nemico perde 2 vantaggi e per lo scambio colpisce 1 in meno
                    n.vant = max(0, n.vant - 2)
                    g.occhio = True
        g.tenuto = False if tipo != "presa" else g.tenuto
        if self.mappa and tipo not in ("aggira",):
            self.gira_verso(p)
        if flusso:
            g.flussi += 1
            self.st["flussi"] += 1
        return True, flusso

    # ----------------------------------------------------------- partita
    def gioca(self):
        self.pausa()
        guardia = 0
        while self.scambi <= REGOLE["max_scambi"]:
            guardia += 1
            if guardia > 20000:
                raise RuntimeError("ciclo infinito")
            p = self.attivo
            if not self.puo_agire(0) and not self.puo_agire(1):
                self.pausa()
                continue
            if not self.puo_agire(p):
                self.attivo = 1 - p
                continue
            fatto, flusso = self.agisci(p)
            if self.g[0].vita <= 0 or self.g[1].vita <= 0:
                break
            if not fatto:
                # chi non ha niente di utile si ferma fino alla pausa (le trappole armate restano)
                self.finito[p] = True
                self.attivo = 1 - p
                continue
            if self.iniziativa_a is not None:
                self.attivo = self.iniziativa_a
                self.iniziativa_a = None
                self.st["iniziative_rubate"] += 1
            elif not flusso:
                self.attivo = 1 - p
        a, b = self.g
        if a.vita <= 0 and b.vita <= 0:
            return -1
        if a.vita <= 0:
            return 1
        if b.vita <= 0:
            return 0
        return -1


# ---------------------------------------------------------------------------
def genera(rng, nome):
    R = rng.choice([2, 2, 3])
    punti = 10 if R == 2 else 10 - REGOLE.get("costo_ritmo3", 2)
    while True:
        v = [1, 1, 1, 1]
        for _ in range(punti - 4):
            v[rng.randrange(4)] += 1
        if max(v) <= 4:
            break
    F, A, P, C = v
    budget = 12 - (REGOLE.get("ritmo3_budget", 3) if R == 3 else 0)
    raro = None
    if rng.random() < 0.3:
        raro = rng.choice(list(RARI))
        budget -= RARI[raro]["costo"] if REGOLE.get("raro_a_pagamento", True) else 0
    coll = []
    ids = [t for t in CATALOGO if not (REGOLE.get("senza_potenziamenti") and CATALOGO[t]["eff"] in ("kime", "sen", "zanshin"))
           and not (REGOLE.get("occhio_in_lettura", True) and t == "occhio_falco")]
    rng.shuffle(ids)
    for tid in ids:
        if len(coll) >= 6:
            break
        if CATALOGO[tid]["costo"] <= budget:
            coll.append(tid)
            budget -= CATALOGO[tid]["costo"]
    return Pg(nome, F, A, P, C, R, coll, raro)


def giro(n, seme):
    rng = random.Random(seme)
    st = {k: defaultdict(int) for k in ["piazzati", "scatti", "armati", "danni", "azioni", "reazioni", "girate", "raro_pronto", "raro_scatti"]}
    st["arene"] = defaultdict(int)
    st["disponibile"] = defaultdict(int)
    st["arena_esito"] = defaultdict(lambda: [0, 0, 0])
    for k in ["prese_sbilancia", "urti", "cadute", "pericoli", "spinte", "colpi_dall_alto", "colpi_alle_spalle", "aggirati_dietro", "rialzo_token", "cambi_al_muro", "ritiri", "scalati", "iniziative_rubate", "passaggi", "passaggi_falliti", "ridotti", "combo", "attacchi", "flussi", "blocchi", "cure"]:
        st[k] = 0
    ris = {"vinti_primo": 0, "patte": 0, "scambi": [], "azioni": [], "pres": defaultdict(lambda: [0, 0]),
           "dom": defaultdict(lambda: [0, 0]), "ritmo": defaultdict(lambda: [0, 0]), "raro": defaultdict(lambda: [0, 0]), "n": n}
    for i in range(n):
        a, b = genera(rng, "A"), genera(rng, "B")
        d = Duello(a, b, rng, st)
        v = d.gioca()
        ris.setdefault("rec", []).append((a, b, v))
        if v >= 0:
            for k, c in d.uso[v].items():
                ris.setdefault("uso_vinc", defaultdict(int))[k] += c
            for k, c in d.uso[1 - v].items():
                ris.setdefault("uso_perd", defaultdict(int))[k] += c
        ris["scambi"].append(d.scambi)
        if d.mappa:
            ae = st["arena_esito"][d.mappa["nome"]]
            ae[0] += 1
            ae[1] += d.scambi
            ae[2] += 1 if v == d.primo else 0
        ris["azioni"].append(d.azioni)
        if v < 0:
            ris["patte"] += 1
            continue
        if v == d.primo:
            ris["vinti_primo"] += 1
        for p, g in enumerate((a, b)):
            w = 1 if v == p else 0
            for tid in set(g.coll):
                ris["pres"][tid][0] += w
                ris["pres"][tid][1] += 1
            ris["dom"][g.dominante()][0] += w
            ris["dom"][g.dominante()][1] += 1
            ris["ritmo"][g.R][0] += w
            ris["ritmo"][g.R][1] += 1
            k = g.raro_id or "nessuno"
            ris["raro"][k][0] += w
            ris["raro"][k][1] += 1
    ris["st"] = st
    return ris


def regressione(r):
    """Regressione logistica: quanto vale un punto di ogni caratteristica, il Ritmo 3, ogni token."""
    import numpy as np
    ids = list(CATALOGO) + list(RARI)
    nomi = ["Forza", "Agilita", "Percezione", "Costituzione", "Ritmo3"] + ids
    X, y = [], []
    for a, b, v in r["rec"]:
        if v < 0:
            continue
        def f(g):
            base = [g.F, g.A, g.P, g.C, 1 if g.R == 3 else 0]
            return base + [1 if t in g.coll or t == g.raro_id else 0 for t in ids]
        X.append(np.array(f(a)) - np.array(f(b)))
        y.append(1 if v == 0 else 0)
    X = np.array(X, dtype=float)
    y = np.array(y, dtype=float)
    w = np.zeros(X.shape[1])
    for _ in range(3000):
        pr = 1 / (1 + np.exp(-X @ w))
        w -= 0.05 * (X.T @ (pr - y) / len(y) + 0.01 * w)
    return dict(zip(nomi, w))


def media(a):
    return sum(a) / len(a) if a else 0


def riassunto(r):
    st = r["st"]
    n = r["n"]
    dec = n - r["patte"]
    out = {
        "partite": n,
        "scambi_medi": round(media(r["scambi"]), 2),
        "azioni_medie": round(media(r["azioni"]), 1),
        "azioni_per_scambio": round(sum(r["azioni"]) / max(1, sum(r["scambi"])), 1),
        "patte_pct": round(100 * r["patte"] / n, 1),
        "primo_vince_pct": round(100 * r["vinti_primo"] / max(1, dec), 1),
        "passaggi_falliti_pct": round(100 * st["passaggi_falliti"] / max(1, st["passaggi"]), 1),
        "ritiri_pct": round(100 * st["ritiri"] / max(1, st["passaggi"]), 1),
        "iniziative_prese": round(st["iniziative_rubate"] / n, 2),
        "flussi_per_duello": round(st["flussi"] / n, 2),
        "scatti_per_duello": round(sum(st["scatti"].values()) / n, 2),
        "combo_per_duello": round(st["combo"] / n, 2),
        "blocchi_per_duello": round(st["blocchi"] / n, 2),
        "brevi_pct": round(100 * sum(1 for s in r["scambi"] if s <= 2) / n, 1),
        "lunghi_pct": round(100 * sum(1 for s in r["scambi"] if s >= 10) / n, 1),
    }
    return out


def tabella_token(r):
    st = r["st"]
    righe = []
    for tid, t in CATALOGO.items():
        w, m = r["pres"].get(tid, [0, 0])
        pz = st["piazzati"][tid]
        righe.append({
            "id": tid, "nome": t["nome"], "col": t["col"], "costo": t["costo"],
            "presenze": m, "vittorie_pct": round(100 * w / m, 1) if m else 0,
            "piazzato": pz, "scatti": st["scatti"][tid],
            "scatta_pct": round(100 * st["scatti"][tid] / pz, 1) if pz else 0,
            "danni_per_scatto": round(st["danni"][tid] / st["scatti"][tid], 1) if st["scatti"][tid] else 0,
        })
    return righe


def aggiusta_costi(r, passo=1, alto=54, basso=46):
    cambi = 0
    for rid, t in RARI.items():
        w, m = r["raro"].get(rid, [0, 0])
        if m >= 80:
            pct = 100 * w / m
            if pct > alto and t["costo"] < 9:
                t["costo"] += 1
                cambi += 1
            elif pct < basso and t["costo"] > 3:
                t["costo"] -= 1
                cambi += 1
    for row in tabella_token(r):
        if row["presenze"] < 80:
            continue
        t = CATALOGO[row["id"]]
        if row["vittorie_pct"] > alto and t["costo"] < REGOLE.get("costo_max", 8):
            t["costo"] += passo
            cambi += 1
        elif row["vittorie_pct"] < basso and t["costo"] > 1:
            t["costo"] -= passo
            cambi += 1
    return cambi


VARIANTI = {
    "base": {},
    "senza_ritiro": {"ritiro": False},
    "senza_ridotto": {"ridotto": False},
    "soglia+1": {"soglia_delta": 1},
    "soglia-1": {"soglia_delta": -1},
    "senza_flusso": {"flusso": False},
    "flusso_anche_da_sali": {"flusso_da_sali": True},
    "flusso_2_per_scambio": {"flusso_per_scambio": 2},
    "senza_doppia_faccia": {"doppia_faccia": False, "combo": False},
    "token_non_persistenti": {"persistenti": False},
    "pesca3": {"pesca": 3},
    "pesca5": {"pesca": 5},
    "danni_pieni": {"danno_div": 1},
    "senza_raro": {"raro": False},
    "presa_toglie": {"presa_toglie": True},
    "soglia_vecchia": {"passaggio": "soglia"},
    "catena_2": {"catena_max": 2},
    "catena_libera": {"catena_max": 99},
    "ia_prudente": {"ia_rischio": 2},
    "ia_azzardo": {"ia_rischio": 5},
    "fallisce_solo_1": {"fallisce_fino": 1},
    "reazione_continua": {"reazione_continua": True},
    "senza_potenziamenti": {"senza_potenziamenti": True},
    "potenziamenti_fuori_ritmo": {"potenziamenti_fuori_ritmo": True},
    "token_potenziamento": {"senza_potenziamenti": False, "cavalieri": False},
    "senza_vantaggio_ritiro": {"vant_ritiro": False},
}


def main():
    arg = {"partite": "600", "seme": "1", "variante": "base", "iterazioni": "0", "json": ""}
    for a in sys.argv[1:]:
        if "=" in a:
            k, v = a.split("=", 1)
            arg[k] = v
    base = dict(REGOLE)
    risultati = {}
    nomi = list(VARIANTI) if arg["variante"] == "tutte" else arg["variante"].split(",")
    if arg.get("griglia"):
        # griglia=chiave:v1,v2;chiave2:v1,v2
        import itertools
        assi = [(k, [int(x) if x.lstrip('-').isdigit() else x for x in v.split(",")]) for k, v in (c.split(":") for c in arg["griglia"].split(";"))]
        for combo in itertools.product(*[v for _, v in assi]):
            REGOLE.clear(); REGOLE.update(base)
            for nome_v in arg["variante"].split(","):
                REGOLE.update(VARIANTI.get(nome_v, {}))
            for (k, _), v in zip(assi, combo):
                REGOLE[k] = v
            r = giro(int(arg["partite"]), int(arg["seme"]))
            q = riassunto(r)
            dom = {k: round(100 * w / m) for k, (w, m) in r["dom"].items()}
            print(dict(zip([k for k, _ in assi], combo)), "scambi", q["scambi_medi"], "azioni", q["azioni_medie"], "brevi", q["brevi_pct"], "lunghi", q["lunghi_pct"], "patte", q["patte_pct"], "primo", q["primo_vince_pct"], "dom", dom)
        return
    for it in range(int(arg["iterazioni"])):
        r = giro(int(arg["partite"]), int(arg["seme"]) + 100 * it)
        c = aggiusta_costi(r)
        print("iterazione", it + 1, "costi cambiati:", c, riassunto(r))
    for nome in nomi:
        REGOLE.clear()
        REGOLE.update(base)
        REGOLE.update(VARIANTI[nome])
        r = giro(int(arg["partite"]), int(arg["seme"]))
        risultati[nome] = {"riassunto": riassunto(r), "token": tabella_token(r),
                           "dominante": {k: round(100 * w / m, 1) for k, (w, m) in r["dom"].items()},
                           "ritmo": {str(k): round(100 * w / m, 1) for k, (w, m) in r["ritmo"].items()},
                           "raro": {k: [round(100 * w / m, 1), m] for k, (w, m) in r["raro"].items()},
                           "azioni": dict(r["st"]["azioni"]), "reazioni": dict(r["st"]["reazioni"]),
                           "girate": dict(r["st"]["girate"]), "raro_scatti": dict(r["st"]["raro_scatti"])}
        print(nome, risultati[nome]["riassunto"])
    if arg["json"]:
        with open(arg["json"], "w") as f:
            json.dump({"risultati": risultati, "catalogo": CATALOGO, "rari": RARI}, f, indent=1, ensure_ascii=False)


if __name__ == "__main__":
    main()
