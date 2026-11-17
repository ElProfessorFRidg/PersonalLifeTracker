#!/usr/bin/env python3
"""design/tokens.json -> App/Core/Design/Theme.swift + design/theme.css (une seule source de vérité)."""
import json, pathlib, sys, re
root = pathlib.Path(__file__).resolve().parent.parent
t = json.loads((root/"design/tokens.json").read_text(encoding="utf-8"))
modes = ["light","dark","amoled"]
for name, v in t["colors"].items():
    for m in modes:
        if not re.fullmatch(r"#[0-9A-Fa-f]{6}", v.get(m, "")): sys.exit(f"couleur invalide: {name}.{m}")
sw = ["// GÉNÉRÉ par scripts/gen_theme.py depuis design/tokens.json : ne pas modifier à la main.",
      "import SwiftUI", "",
      "enum ThemeMode: String, CaseIterable { case light, dark, amoled }", "",
      "extension Color {",
      "    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }",
      "}", "", "struct Palette {"]
for n in t["colors"]: sw.append(f"    let {n}: Color")
sw.append("}"); sw.append(""); sw.append("enum Theme {")
for m in modes:
    sw.append(f"    static let {m} = Palette(")
    sw.append(",\n".join(f"        {n}: Color(hex: 0x{v[m][1:].upper()})" for n, v in t["colors"].items()))
    sw.append("    )")
sw.append("    static func palette(_ mode: ThemeMode) -> Palette { switch mode { case .light: return light; case .dark: return dark; case .amoled: return amoled } }")
for k, d in (("Radius","radius"),("Spacing","spacing")):
    sw.append(f"    enum {k} {{")
    for n, x in t[d].items(): sw.append(f"        static let {n}: CGFloat = {x}")
    sw.append("    }")
sw.append("}")
out = root/"App/Core/Design/Theme.swift"; out.parent.mkdir(parents=True, exist_ok=True)
out.write_text("\n".join(sw)+"\n", encoding="utf-8")
css = []
for m in modes:
    sel = ":root" if m == "light" else f'[data-theme="{m}"]'
    css.append(sel + " {\n" + "\n".join(f"  --{n}: {v[m]};" for n, v in t["colors"].items()) + "\n}")
css.append(":root {\n" + "\n".join(f"  --radius-{n}: {x}px;" for n, x in t["radius"].items()) + "\n" + "\n".join(f"  --space-{n}: {x}px;" for n, x in t["spacing"].items()) + "\n}")
(root/"design/theme.css").write_text("\n".join(css)+"\n", encoding="utf-8")
print("Theme.swift et theme.css générés")
