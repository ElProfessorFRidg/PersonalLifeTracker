#!/usr/bin/env python3
"""Affiche une section ou sous-section de la spec sans charger tout le fichier.

Usage :
  python3 scripts/spec_section.py 106          # section 106 entière
  python3 scripts/spec_section.py 13.1         # sous-section 13.1
  python3 scripts/spec_section.py 16 17 18     # plusieurs à la suite
  python3 scripts/spec_section.py --list       # index : numéro, titre, nombre de mots
"""
import pathlib
import re
import sys

SPEC = pathlib.Path(__file__).resolve().parent.parent / "spec" / "PERSONAL_LIFE_TRACKER_PROMPT.md"


def load_lines():
    return SPEC.read_text(encoding="utf-8").split("\n")


def find_sections(lines):
    starts = [i for i, l in enumerate(lines) if re.match(r"^## \d+\. ", l)]
    result = []
    for k, i in enumerate(starts):
        end = starts[k + 1] if k + 1 < len(starts) else len(lines)
        for j in range(i + 1, end):
            if lines[j].startswith("# "):
                end = j
                break
        while end > i and lines[end - 1].strip() in ("", "---"):
            end -= 1
        m = re.match(r"^## (\d+)\. (.*)", lines[i])
        result.append((m.group(1), m.group(2), i, end))
    return result


def get(lines, ref):
    secs = find_sections(lines)
    main = ref.split(".")[0]
    for num, title, a, b in secs:
        if num != main:
            continue
        block = lines[a:b]
        if "." not in ref:
            return "\n".join(block)
        pat = re.compile(r"^\**" + re.escape(ref) + r"[ .:*]")
        nxt = re.compile(r"^\**\d+\.\d+[ .:*]")
        out, on = [], False
        for l in block:
            if pat.match(l):
                on = True
            elif on and nxt.match(l):
                break
            if on:
                out.append(l)
        return "\n".join(out) if out else None
    return None


def main(argv):
    lines = load_lines()
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if argv[0] == "--list":
        for num, title, a, b in find_sections(lines):
            words = sum(len(l.split()) for l in lines[a:b])
            print(f"{num:>4}  {words:>5} mots  {title}")
        return 0
    code = 0
    for ref in argv:
        text = get(lines, ref)
        if text is None:
            print(f"[introuvable] {ref}", file=sys.stderr)
            code = 1
            continue
        print(text)
        print()
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
