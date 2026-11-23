#!/usr/bin/env python3
"""Découpe la spec en fichiers par section (spec/sections/Snnn.md) et écrit spec/INDEX.md.
À relancer quand la spec est modifiée par l'utilisateur."""
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import spec_section as ss  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "spec" / "sections"


def slug(t):
    t = re.sub(r"\(.*?\)", "", t).lower()
    t = re.sub(r"[^a-z0-9]+", "-", t.encode("ascii", "ignore").decode() or "section")
    return t.strip("-")[:40] or "section"


def main():
    lines = ss.load_lines()
    secs = ss.find_sections(lines)
    OUT.mkdir(parents=True, exist_ok=True)
    for f in OUT.glob("S*.md"):
        f.unlink()
    first = int(secs[0][2])
    head = "\n".join(lines[:first]).strip()
    (OUT / "S000-sommaire-et-index.md").write_text(head + "\n", encoding="utf-8")
    index = ["# INDEX DE LA SPEC", "", "Lire UNIQUEMENT les sections utiles : `python3 scripts/spec_section.py N`.", "",
             "| § | Mots | Titre | Fichier |", "|---|---|---|---|"]
    for num, title, a, b in secs:
        name = f"S{int(num):03d}-{slug(title)}.md"
        (OUT / name).write_text("\n".join(lines[a:b]) + "\n", encoding="utf-8")
        words = sum(len(l.split()) for l in lines[a:b])
        index.append(f"| {num} | {words} | {title} | spec/sections/{name} |")
    index += ["", "## Quoi lire selon la phase", "",
              "- Phase 0 (UI) : 3, 13 (zone de doute), 44.1, 47, 48, 49, 50, 51, 122, 133, 154.",
              "- Phase 1 (CI/CD) : 6, 7, 57 et docs/CI-CD.md.",
              "- Phase 2 : section 60 (ordre), puis `module_info.py --step N`, jamais le fichier entier."]
    (ROOT / "spec" / "INDEX.md").write_text("\n".join(index) + "\n", encoding="utf-8")
    print(f"{len(secs)} sections écrites dans {OUT}")


if __name__ == "__main__":
    main()
