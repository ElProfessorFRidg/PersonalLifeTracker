#!/usr/bin/env bash
# Affiche l'UDID d'un simulateur iPhone disponible (runtime iOS le plus récent). Échoue clairement sinon.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json,sys,re
d=json.load(sys.stdin)["devices"]; best=None
for rt,devs in d.items():
    m=re.search(r"iOS-(\d+)-(\d+)",rt)
    if not m: continue
    v=(int(m.group(1)),int(m.group(2)))
    for x in devs:
        if "iPhone" in x["name"] and x.get("isAvailable",True):
            if best is None or v>best[0]: best=(v,x["udid"],x["name"])
if not best: sys.exit("Aucun simulateur iPhone disponible")
sys.stderr.write(f"simulateur: {best[2]} iOS {best[0][0]}.{best[0][1]}\n"); print(best[1])'
