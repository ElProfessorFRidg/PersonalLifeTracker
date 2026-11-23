#!/usr/bin/env python3
"""Vérifie que PROGRESS.md ne ment pas (dans la mesure du vérifiable). Code retour 1 si problème."""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
ALLOWED = {"NON COMMENCÉ","EN COURS","CODÉ NON TESTÉ","TESTS AUTO OK","VÉRIFIÉ SIMULATEUR","VÉRIFIÉ SUR APPAREIL","BLOQUÉ"}
NEED_PROOF = {"TESTS AUTO OK","VÉRIFIÉ SIMULATEUR","VÉRIFIÉ SUR APPAREIL"}
errs, warns = [], []
p = root/"PROGRESS.md"
if not p.exists():
    sys.exit("PROGRESS.md absent : lance python3 scripts/gen_progress.py")
ui = root/"design/UI_VALIDATED.md"
ui_ok = ui.exists() and re.search(r"^Validation de l'utilisateur\s*:\s*\S+", ui.read_text(encoding="utf-8"), re.M)
if ui.exists() and not ui_ok:
    errs.append("design/UI_VALIDATED.md existe mais sans ligne `Validation de l'utilisateur : <citation>`")
counts = {}
for n, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
    if not line.startswith("| ") or line.startswith("| ID") or line.startswith("|---"):
        continue
    c = [x.strip() for x in line.strip().strip("|").split("|")]
    if len(c) < 6: continue
    ident, status, proof = c[0], c[3], c[4]
    if status not in ALLOWED:
        errs.append(f"ligne {n} {ident}: statut inconnu '{status}'"); continue
    counts[status] = counts.get(status, 0) + 1
    kind = ident.split(":")[0]
    if kind != "phase" and status != "NON COMMENCÉ" and not ui_ok:
        errs.append(f"ligne {n} {ident}: avancée en Phase 2 sans design/UI_VALIDATED.md valide (porte UI)")
    if kind == "phase" and ident != "phase:P0_ui" and status not in ("NON COMMENCÉ","BLOQUÉ") and not ui_ok:
        errs.append(f"ligne {n} {ident}: Phase 1 avant validation UI")
    if status in NEED_PROOF:
        if not proof:
            errs.append(f"ligne {n} {ident}: {status} sans preuve")
        elif proof.startswith("evidence/"):
            f = root/proof
            if not f.exists():
                errs.append(f"ligne {n} {ident}: preuve introuvable {proof}")
            elif status == "VÉRIFIÉ SUR APPAREIL" and not re.search(r"Confirmé par l'utilisateur\s*:\s*\S+", f.read_text(encoding="utf-8")):
                errs.append(f"ligne {n} {ident}: {proof} sans ligne `Confirmé par l'utilisateur :`")
        elif not proof.startswith("http"):
            errs.append(f"ligne {n} {ident}: preuve doit être evidence/... ou une URL")
    if status == "VÉRIFIÉ SUR APPAREIL" and proof.startswith("http"):
        errs.append(f"ligne {n} {ident}: VÉRIFIÉ SUR APPAREIL ne peut pas être prouvé par une URL de CI")
    if status == "BLOQUÉ" and not c[5]:
        warns.append(f"ligne {n} {ident}: BLOQUÉ sans raison dans Note")
for w in warns: print("avertissement:", w)
for e in errs: print("ERREUR:", e)
print("statuts:", counts)
sys.exit(1 if errs else 0)
