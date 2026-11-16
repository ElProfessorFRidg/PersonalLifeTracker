#!/usr/bin/env python3
"""Valide une source AltStore. usage: validate_altstore_source.py FICHIER [--check-urls] | --self-test
--check-urls fait de vraies requêtes HEAD (réseau requis). Ne remplace pas un test dans AltStore."""
import json, sys, re, urllib.request, subprocess, tempfile, pathlib
def validate(path, check_urls=False):
    errs = []; s = json.loads(pathlib.Path(path).read_text(encoding="utf-8"))
    for k in ("name","identifier","sourceURL","apps"):
        if k not in s: errs.append(f"champ manquant: {k}")
    if not str(s.get("sourceURL","")).startswith("https://"): errs.append("sourceURL doit être en https")
    if not s.get("apps"): errs.append("apps vide")
    for app in s.get("apps", []):
        for k in ("name","bundleIdentifier","developerName","versions"):
            if k not in app: errs.append(f"{app.get('name','?')}: champ manquant {k}")
        if not app.get("versions"): errs.append("aucune version")
        dates = [v.get("date","") for v in app.get("versions", [])]
        if dates != sorted(dates, reverse=True): errs.append("versions non triées (plus récente d'abord)")
        for v in app.get("versions", []):
            for k in ("version","date","downloadURL","size","minOSVersion"):
                if k not in v: errs.append(f"version {v.get('version','?')}: champ manquant {k}")
            if not str(v.get("downloadURL","")).startswith("https://"): errs.append(f"{v.get('version')}: downloadURL non https")
            if not isinstance(v.get("size"), int) or v.get("size",0) <= 0: errs.append(f"{v.get('version')}: size invalide")
            if not re.match(r"^\d{4}-\d\d-\d\dT", v.get("date","")): errs.append(f"{v.get('version')}: date non ISO")
            if check_urls and v.get("downloadURL"):
                try:
                    r = urllib.request.urlopen(urllib.request.Request(v["downloadURL"], method="HEAD"), timeout=20)
                    if r.status >= 400: errs.append(f"{v['downloadURL']}: HTTP {r.status}")
                except Exception as e: errs.append(f"{v['downloadURL']}: {e}")
    return errs
if __name__ == "__main__":
    if "--self-test" in sys.argv:
        here = pathlib.Path(__file__).parent
        with tempfile.TemporaryDirectory() as t:
            for tag, ch, date in (("v0.0.1","stable","2026-01-01T00:00:00Z"),("v0.0.2","stable","2026-02-01T00:00:00Z")):
                subprocess.run([sys.executable, str(here/"make_altstore_source.py"), "--config", str(here.parent/"altstore/config.json"),
                    "--repo","u/r","--tag",tag,"--ipa-url",f"https://github.com/u/r/releases/download/{tag}/a.ipa","--size","1234",
                    "--channel",ch,"--branch-dir",t,"--date",date], check=True, stdout=subprocess.DEVNULL)
            e = validate(pathlib.Path(t)/"source.json")
            vs = json.loads((pathlib.Path(t)/"source.json").read_text())["apps"][0]["versions"]
            if [v["version"] for v in vs] != ["0.0.2","0.0.1"]: e.append("tri des versions incorrect")
            # un cas invalide doit être détecté
            bad = pathlib.Path(t)/"bad.json"; bad.write_text(json.dumps({"name":"x","identifier":"y","sourceURL":"http://x","apps":[]}))
            if not validate(bad): e.append("la validation n'a pas détecté une source invalide")
        print("self-test:", "OK" if not e else e); sys.exit(1 if e else 0)
    f = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not f: sys.exit("usage: validate_altstore_source.py FICHIER [--check-urls] | --self-test")
    e = validate(f[0], "--check-urls" in sys.argv)
    for x in e: print("ERREUR:", x)
    print("OK" if not e else f"{len(e)} erreur(s)"); sys.exit(1 if e else 0)
