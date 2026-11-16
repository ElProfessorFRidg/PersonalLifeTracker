#!/usr/bin/env python3
"""Affiche la ligne du registre d'un module et ses sections de spec.

Usage :
  python3 scripts/module_info.py contract_hours      # ligne + sections
  python3 scripts/module_info.py contract_hours --row # ligne seule
  python3 scripts/module_info.py --step 6            # modules de l'étape 6
  python3 scripts/module_info.py --all               # tous les modules (id, défaut, étape)
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
MODULES = ROOT / "spec" / "MODULES.md"


def rows():
    out = []
    for line in MODULES.read_text(encoding="utf-8").split("\n"):
        if not line.startswith("| ") or line.startswith("| Module") or line.startswith("|---"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 7:
            out.append(dict(zip(["id", "sections", "titre", "defaut", "exige", "enrichi", "etape"], cells)))
    return out


def expand_sections(text):
    refs = []
    for part in re.split(r",\s*", text):
        m = re.match(r"^(\d+)\s*à\s*(\d+)$", part)
        if m:
            refs += [str(n) for n in range(int(m.group(1)), int(m.group(2)) + 1)]
        elif re.match(r"^\d+(\.\d+)?$", part):
            refs.append(part)
    return refs


def main(argv):
    rs = rows()
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv[0] == "--all":
        for r in rs:
            print(f"{r['id']:<26} {r['defaut']:<8} étape {r['etape']}")
        return 0
    if argv[0] == "--step":
        n = argv[1]
        for r in rs:
            if re.search(rf"(^|\D){re.escape(n)}(\D|$)", r["etape"]):
                print(f"{r['id']:<26} § {r['sections']:<20} {r['titre']}")
        return 0
    r = next((x for x in rs if x["id"] == argv[0]), None)
    if not r:
        print(f"[module inconnu] {argv[0]}", file=sys.stderr)
        return 1
    for k, v in r.items():
        print(f"{k:>8} : {v}")
    if "--row" in argv:
        return 0
    print()
    for ref in expand_sections(r["sections"]):
        subprocess.run([sys.executable, str(ROOT / "scripts" / "spec_section.py"), ref])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
