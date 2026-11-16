#!/usr/bin/env python3
"""Assemble design/prototype/index.html (artefact Phase 0) depuis design/prototype/src/.

  shell_head.html   : <title>, meta, fonts, LE <style> partagé (placeholder /*THEME*/)
  shell_frame.html  : page autour + cadre iPhone (placeholder <!--SCREENS-->)
  screens/*.html    : un fragment <section class="screen" id="scr-nom"> par écran, triés par nom de fichier
  shell_tail.html   : JS partagé

Le thème vient de design/theme.css (généré par scripts/gen_theme.py depuis design/tokens.json).
Il est recopié inline, avec ses sélecteurs de couleurs limités à .app pour que le thème de
l'app (data-theme sur .app) reste indépendant du thème de la page hôte (data-theme sur <html>).
Typographie, ombres et durées sont lues directement dans tokens.json.

Usage : python3 scripts/build_prototype.py          (sort en erreur si un fragment casse les règles)
"""
import json, pathlib, re, subprocess, sys

root = pathlib.Path(__file__).resolve().parent.parent
src = root / "design/prototype/src"
out = root / "design/prototype/index.html"
MODES = ["light", "dark", "amoled"]


def theme_css():
    subprocess.run([sys.executable, str(root / "scripts/gen_theme.py")], check=True, stdout=subprocess.DEVNULL)
    css = (root / "design/theme.css").read_text(encoding="utf-8")
    # 1er bloc ":root {" = couleurs du mode clair -> .app ; le 2e (rayons, espacements) reste sur :root
    css = css.replace(":root {", ".app {", 1)
    for m in MODES[1:]:
        css = css.replace(f'[data-theme="{m}"] {{', f'.app[data-theme="{m}"] {{')
    t = json.loads((root / "design/tokens.json").read_text(encoding="utf-8"))
    ty, mo, sh = t["typography"], t["motion"], t["shadows"]
    v = [f"  --font-text: {ty['fontText']};", f"  --font-mono: {ty['fontMono']};"]
    for n, s in ty["styles"].items():
        v.append(f"  --t-{n}: {s['weight']} {s['size']}px/{s['line']}px")
    v = [x if x.endswith(";") else x + ";" for x in v]
    for n in ("fast", "normal", "slow"):
        v.append(f"  --motion-{n}: {mo[n]}s;")
    v.append(f"  --ease: {mo['easeStandard']};")
    v.append(f"  --ease-sheet: {mo['easeSheet']};")
    css += ":root {\n" + "\n".join(v) + "\n}\n"
    for m in MODES:
        sel = ".app" if m == "light" else f'.app[data-theme="{m}"]'
        lines = []
        for n, s in sh.items():
            if n.startswith("_"):
                continue
            o = s["opacity"][m]
            lines.append(f"  --shadow-{n}: " + (f"0 {s['y']}px {s['blur']}px rgba(0,0,0,{o})" if o else "0 0 0 rgba(0,0,0,0)") + ";")
        css += sel + " {\n" + "\n".join(lines) + "\n}\n"
    return css


def check_fragment(path, html, seen, errors):
    name = path.name
    m = re.search(r'<section\b[^>]*\bclass="screen[^"]*"[^>]*>', html)
    if not m:
        errors.append(f'{name}: pas de <section class="screen" ...>')
        return
    tag = m.group(0)
    sid = re.search(r'\bid="scr-([a-z0-9-]+)"', tag)
    if not sid:
        errors.append(f'{name}: id manquant ou invalide (attendu id="scr-nom", minuscules, chiffres, tirets)')
    else:
        if sid.group(1) in seen:
            errors.append(f"{name}: id scr-{sid.group(1)} déjà pris par {seen[sid.group(1)]}")
        seen[sid.group(1)] = name
        if sid.group(1) in ("settings", "sidebar", "customize", "upgrade", "downloads") or sid.group(1).startswith("comment-"):
            errors.append(f"{name}: nom d'écran réservé par claude.ai ({sid.group(1)})")
    if 'data-title="' not in tag:
        errors.append(f"{name}: data-title manquant")
    if html.count("<section") != html.count("</section>"):
        errors.append(f"{name}: <section> non fermée")
    if "—" in html:
        errors.append(f"{name}: tiret cadratin interdit dans les textes")
    if re.search(r"<!DOCTYPE|<html\b|<head\b|<body\b", html, re.I):
        errors.append(f"{name}: balises doctype/html/head/body interdites")
    if re.search(r"\b(alert|confirm|prompt)\s*\(", re.sub(r"\.\s*(alert|confirm|prompt)\b", "", html)):
        errors.append(f"{name}: alert/confirm/prompt interdits (utilise toast() ou une feuille)")
    if re.search(r"lorem ipsum", html, re.I):
        errors.append(f"{name}: lorem ipsum interdit")
    for url in re.findall(r'(?:src|href)="(https?://[^"]+)"', html):
        if not url.startswith("https://cdnjs.cloudflare.com/"):
            errors.append(f"{name}: ressource externe interdite ({url})")
    if re.search(r"url\(\s*['\"]?https?:", html):
        errors.append(f"{name}: url() externe interdite")


def main():
    head = (src / "shell_head.html").read_text(encoding="utf-8")
    frame = (src / "shell_frame.html").read_text(encoding="utf-8")
    tail = (src / "shell_tail.html").read_text(encoding="utf-8")
    if "/*THEME*/" not in head or "<!--SCREENS-->" not in frame:
        sys.exit("placeholder /*THEME*/ ou <!--SCREENS--> manquant dans le shell")
    files = sorted((src / "screens").glob("*.html"))
    if not files:
        sys.exit("aucun écran dans design/prototype/src/screens/")
    errors, seen, parts = [], {}, []
    for f in files:
        html = f.read_text(encoding="utf-8").strip()
        check_fragment(f, html, seen, errors)
        parts.append(f"<!-- {f.name} -->\n{html}")
    if errors:
        sys.exit("ERREURS:\n  " + "\n  ".join(errors))
    page = head.replace("/*THEME*/", theme_css()) + "\n" + frame.replace("<!--SCREENS-->", "\n".join(parts)) + "\n" + tail
    page = page.lstrip()
    if not page.startswith("<title>"):
        sys.exit("la sortie doit commencer par <title>")
    if re.search(r"<!DOCTYPE|<html\b|<head\b|<body\b", page, re.I):
        sys.exit("la sortie contient doctype/html/head/body")
    out.write_text(page, encoding="utf-8")
    print(f"OK {out.relative_to(root)} : {len(files)} écrans ({', '.join(seen)}), {len(page.encode('utf-8')) // 1024} Ko")


if __name__ == "__main__":
    main()
