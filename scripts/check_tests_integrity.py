#!/usr/bin/env python3
"""Détecte les techniques courantes de tests truqués. Ne remplace pas la relecture humaine."""
import re, sys, json, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
errs = []
tests = list((root/"Tests").rglob("*.swift"))
app = list((root/"App").rglob("*.swift"))
BAD = [
 (r"\bXCTSkip(If|Unless)?\b|\bXCTExpectFailure\b", "skip ou expected failure interdit"),
 (r"XCTAssertTrue\(\s*true\s*\)|XCTAssertFalse\(\s*false\s*\)|XCTAssert\(\s*true\s*\)", "assertion triviale"),
 (r"XCTAssertEqual\(\s*([A-Za-z0-9_.]+)\s*,\s*\1\s*\)", "assertion circulaire x == x"),
 (r"\.disabled\(|//\s*func test|/\*\s*func test", "test désactivé ou commenté"),
]
nb = 0
for f in tests:
    s = f.read_text(encoding="utf-8")
    nb += len(re.findall(r"func test\w+\s*\(", s)) + len(re.findall(r"@Test\b", s))
    for pat, msg in BAD:
        for m in re.finditer(pat, s):
            errs.append(f"{f.relative_to(root)}: {msg}")
    # test sans assertion
    for m in re.finditer(r"func (test\w+)\s*\([^)]*\)[^{]*\{", s):
        i = m.end(); depth = 1
        while i < len(s) and depth:
            depth += (s[i] == "{") - (s[i] == "}"); i += 1
        body = s[m.end():i]
        if not re.search(r"XCTAssert|XCTFail|#expect|#require|XCTUnwrap|XCTAssertThrows", body):
            errs.append(f"{f.relative_to(root)}: {m.group(1)} sans aucune assertion")
for f in app:
    s = f.read_text(encoding="utf-8")
    if re.search(r"XCTestCase|NSClassFromString\(\"XCTest|XCTestConfigurationFilePath|XCTestSessionIdentifier", s):
        errs.append(f"{f.relative_to(root)}: le code applicatif détecte XCTest (interdit)")
cf = root/"evidence/test_count.json"
prev = json.loads(cf.read_text())["count"] if cf.exists() else None
if prev is not None and nb < prev:
    errs.append(f"nombre de tests passé de {prev} à {nb} : justifie dans notes/ERREURS.md puis mets à jour evidence/test_count.json à la main")
if "--update" in sys.argv and not errs:
    cf.write_text(json.dumps({"count": nb}))
for e in errs: print("ERREUR:", e)
print(f"tests trouvés: {nb}")
sys.exit(1 if errs else 0)
