#!/bin/sh
# Rigenera i sei combattenti dalle pelli riggate su Mixamo (gli FBX non stanno nel repository).
# uso: sh tools/costruisci_modelli.sh CARTELLA_ANIMAZIONI CARTELLA_PELLI
A="$1"; P="$2"
python3 tools/mixamo_a_glb.py "$A" assets/modelli/donna.glb "$P/donna.fbx" 1.74
python3 tools/mixamo_a_glb.py "$A" assets/modelli/uomo.glb "$P/uomo.fbx" 1.82
python3 tools/mixamo_a_glb.py "$A" assets/modelli/uomo2.glb "$P/uomo2.fbx" 1.84
python3 tools/mixamo_a_glb.py "$A" assets/modelli/bionda.glb "$P/bionda.fbx" 1.72
python3 tools/mixamo_a_glb.py "$A" assets/modelli/mora.glb "$P/mora.fbx" 1.68
python3 tools/mixamo_a_glb.py "$A" assets/modelli/uomo3.glb "$P/uomo3.fbx" 1.80
