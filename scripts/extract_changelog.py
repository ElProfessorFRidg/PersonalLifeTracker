#!/usr/bin/env python3
"""Affiche la section CHANGELOG.md d'une version : extract_changelog.py v1.2.3 (sinon section Unreleased)."""
import sys, re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
ver = (sys.argv[1] if len(sys.argv) > 1 else "Unreleased").lstrip("v")
txt = (root/"CHANGELOG.md").read_text(encoding="utf-8")
m = re.search(rf"^## \[?{re.escape(ver)}\]?.*?$(.*?)(?=^## |\Z)", txt, re.M | re.S)
body = m.group(1).strip() if m else ""
if not body:
    m = re.search(r"^## \[?Unreleased\]?.*?$(.*?)(?=^## |\Z)", txt, re.M | re.S)
    body = (m.group(1).strip() if m else "") or "Pas de notes."
print(body)
