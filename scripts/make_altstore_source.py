#!/usr/bin/env python3
"""Ajoute une version à une source AltStore (format 'versions'). Format NON vérifié contre AltStore réel : à tester sur iPhone.
usage: make_altstore_source.py --config altstore/config.json --repo owner/repo --tag v1.0.0 --ipa-url URL --size N \
       --channel stable|beta --branch-dir DIR [--date ISO] [--notes FILE]"""
import argparse, json, pathlib, datetime, re, sys
ap = argparse.ArgumentParser()
ap.add_argument("--config", required=True); ap.add_argument("--repo", required=True)
ap.add_argument("--tag", required=True); ap.add_argument("--ipa-url", required=True)
ap.add_argument("--size", type=int, required=True); ap.add_argument("--channel", choices=["stable","beta"], required=True)
ap.add_argument("--branch-dir", required=True); ap.add_argument("--date"); ap.add_argument("--notes")
ap.add_argument("--build", default="1")
a = ap.parse_args()
cfg = json.loads(pathlib.Path(a.config).read_text(encoding="utf-8")); app = cfg["app"]
d = pathlib.Path(a.branch_dir); d.mkdir(parents=True, exist_ok=True)
raw = f"https://raw.githubusercontent.com/{a.repo}/altstore-source"
fname = "source.json" if a.channel == "stable" else "source-beta.json"
p = d / fname
version = a.tag.lstrip("v")
if not re.match(r"^\d+\.\d+\.\d+([-.][0-9A-Za-z.]+)?$", version):
    sys.exit(f"tag invalide: {a.tag}")
date = a.date or datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
notes = pathlib.Path(a.notes).read_text(encoding="utf-8").strip() if a.notes else ""
src = json.loads(p.read_text(encoding="utf-8")) if p.exists() else {
    "name": cfg["sourceName"] + (" (bêta)" if a.channel == "beta" else ""),
    "identifier": cfg["sourceIdentifier"] + (".beta" if a.channel == "beta" else ""),
    "sourceURL": f"{raw}/{fname}", "apps": [], "news": []}
entry = next((x for x in src["apps"] if x["bundleIdentifier"] == app["bundleIdentifier"]), None)
if entry is None:
    entry = {"name": app["name"], "bundleIdentifier": app["bundleIdentifier"], "developerName": app["developerName"],
             "subtitle": app["subtitle"], "localizedDescription": app["localizedDescription"],
             "iconURL": f"{raw}/icon.png", "tintColor": app["tintColor"].lstrip("#"),
             "screenshotURLs": [], "versions": [], "appPermissions": {"entitlements": [], "privacy": {}}}
    src["apps"].append(entry)
entry["versions"] = [v for v in entry["versions"] if v["version"] != version]
entry["versions"].insert(0, {"version": version, "buildVersion": a.build, "date": date, "downloadURL": a.ipa_url,
    "size": a.size, "minOSVersion": app["minOSVersion"], "localizedDescription": notes or f"Version {version}"})
entry["versions"].sort(key=lambda v: v["date"], reverse=True)
p.write_text(json.dumps(src, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"écrit {p} ({len(entry['versions'])} version(s))")
