#!/usr/bin/env python3
"""Génère PROGRESS.md (tout à NON COMMENCÉ). N'écrase pas un PROGRESS.md existant sans --force."""
import re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
out = root / "PROGRESS.md"
if out.exists() and "--force" not in sys.argv:
    sys.exit("PROGRESS.md existe déjà (utilise --force pour regénérer, ça efface l'avancée).")

rows = []
for line in (root/"spec/MODULES.md").read_text(encoding="utf-8").splitlines():
    if not line.startswith("| ") or line.startswith("| Module") or line.startswith("|---"):
        continue
    c = [x.strip() for x in line.strip().strip("|").split("|")]
    if len(c) >= 7:
        rows.append((c[0], c[2], c[6]))

scen = []
txt = (root/"spec/sections").glob("S004-*.md")
for f in txt:
    for l in f.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^([A-Z]{1,2})\. (.{0,70})", l)
        if m:
            scen.append((m.group(1), m.group(2).split(":")[0].strip()))

core = [
 ("core_models","Noyau : modèles SwiftData, ModuleRegistry, écran Fonctionnalités","1"),
 ("core_places","Noyau : lieux, sessions, saisie manuelle, onglets Accueil et Lieux","1"),
 ("core_geofence","Géorepérage, arrivée/départ, notifications, diagnostic, annuler partout","2"),
 ("core_classify","Classification travail/études/courses, apprentissage, récupération","3"),
 ("core_time_rounding","Heures : timestamp exact + base normalisée + zone de doute (13.1)","1"),
]
phases = [
 ("P0_ui","Phase 0 : artefact UI + thème validé par l'utilisateur","0"),
 ("P1_ci","Phase 1 : CI (build + tests) verte","1"),
 ("P1_beta","Phase 1 : pré-release avec IPA","1"),
 ("P1_release","Phase 1 : release avec IPA","1"),
 ("P1_altstore","Phase 1 : source AltStore + installation réelle","1"),
]

L = []
L.append("# PROGRESS : avancement réel (généré par scripts/gen_progress.py, édité à la main avec preuves)\n")
L.append("Règles : un statut sans preuve est faux. `python3 scripts/check_progress.py` le vérifie. Statuts : NON COMMENCÉ, EN COURS, CODÉ NON TESTÉ, TESTS AUTO OK, VÉRIFIÉ SIMULATEUR, VÉRIFIÉ SUR APPAREIL, BLOQUÉ.")
L.append("La colonne Preuve contient un chemin evidence/... ou une URL de run CI. VÉRIFIÉ SUR APPAREIL exige un fichier evidence contenant la ligne `Confirmé par l'utilisateur :`.\n")
def table(title, items, kind):
    L.append(f"## {title}\n")
    L.append("| ID | Titre | Étape | Statut | Preuve | Note |")
    L.append("|---|---|---|---|---|---|")
    for i, t, s in items:
        L.append(f"| {kind}:{i} | {t} | {s} | NON COMMENCÉ |  |  |")
    L.append("")
table("Phases", phases, "phase")
table("Noyau", core, "core")
table("Modules (registre MODULES.md)", rows, "module")
table("Scénarios de référence (section 4)", [(a,b,"-") for a,b in scen], "scenario")
L.append("## Journal des erreurs et limites connues\n\n(voir notes/ERREURS.md)\n")
out.write_text("\n".join(L), encoding="utf-8")
print(f"PROGRESS.md écrit : {len(phases)} phases, {len(core)} noyau, {len(rows)} modules, {len(scen)} scénarios")
