# Maquette Phase 0 : guide du contributeur

Tu ajoutes des écrans à la maquette. Lis ce fichier et les deux écrans de référence
(`src/screens/10_accueil.html`, `src/screens/90_reglages.html`), rien d'autre.

## Règles du jeu

- Tu ne touches QUE tes fichiers `src/screens/NN_nom.html`. Jamais `shell_*.html`, `tokens.json`,
  `index.html` (généré) ni l'écran d'un autre. Un manque dans le shell : dis-le dans ton rapport.
- Build : `python3 scripts/build_prototype.py` (régénère le thème, valide les fragments, écrit `index.html`).
  Il refuse : tiret cadratin, lorem ipsum, `alert/confirm/prompt`, ressource externe, id en double.
- Aucune couleur en dur : uniquement les variables du thème. Aucune police en dur.
- Icônes : SVG inline du sprite, jamais d'emoji.
- Cibles tactiles de 44 px minimum. Tout bouton est un `<button type="button">`.
- Préfixe tous tes `id` par ceux de ton écran (`acc-`, `reg-`...) : la page est unique, les id sont globaux.

## Fichiers

```
src/shell_head.html    title, fonts, LE <style> partagé (thème injecté à la place de /*THEME*/)
src/shell_frame.html   sprite d'icônes, panneau de contrôle, cadre iPhone, onglets, couche feuilles + toast
src/screens/*.html     un fragment par écran, concaténés par ordre de nom de fichier
src/shell_tail.html    JS partagé
index.html             GÉNÉRÉ, c'est lui qui est publié
```

Numérotation : 00-09 onboarding, 10-19 accueil, 20-29 lieux, 30-39 sessions, 40-49 planning,
50-59 emploi et paie, 60-69 statistiques, 70-79 fonctionnalités, 80-89 Live Activity, widgets, notifications,
90-99 réglages et états. L'ordre des fichiers = l'ordre dans le sélecteur d'écrans.

Noms d'écran déjà visés par des `data-go` (garde-les si c'est ton écran) : `accueil`, `reglages`,
`planning`, `lieux`, `stats` (les 4 onglets + réglages), `lieu-ajout`, `sessions`, `session` (détail et correction),
`session-ajout`, `doute`, `fonctionnalites`, `notifications`. Un `go()` vers un écran absent affiche un toast, sans erreur.
Interdits (réservés par claude.ai) : `settings`, `sidebar`, `customize`, `upgrade`, `downloads`, `comment-*`.

## Gabarit d'un écran

```html
<section class="screen" id="scr-lieux" data-title="Lieux" data-group="Lieux" data-tab="lieux"
         data-states="liste:Liste,vide:Aucun lieu">
  <header class="largetitle"><div><p class="eyebrow">3 lieux</p><h1>Lieux</h1></div></header>
  <div class="screen-body">
    <section class="section">
      <div class="section-head"><h2 class="section-title">Titre</h2><button type="button" class="section-link">Tout voir</button></div>
      <!-- composants -->
      <p class="section-foot">Petite explication sous le bloc.</p>
    </section>
  </div>
  <div class="sheet" id="sheet-lieux-x">...</div>
  <style>#scr-lieux .ma-classe { ... }</style>
  <script>PLT.ready(function () { /* ton code, sélecteurs limités à tes id */ });</script>
</section>
```

Attributs de `<section class="screen">` :

| Attribut | Rôle |
|---|---|
| `id="scr-nom"` | obligatoire. `nom` (minuscules, chiffres, tirets) sert à `go('nom')` et à l'URL `#nom` |
| `data-title` | obligatoire, libellé dans le sélecteur d'écrans |
| `data-group` | groupe dans le sélecteur (Onboarding, Accueil, Lieux, Sessions, Planning, Emploi et paie, Statistiques, Fonctionnalités, Système iOS, Réglages, États) |
| `data-tab` | onglet allumé : `accueil`, `planning`, `lieux`, `stats`, ou absent |
| `data-tabbar="hide"` | cache la barre d'onglets (onboarding, écran verrouillé, plein écran) |
| `data-fullbleed` | l'écran passe sous la barre d'état, rendue transparente (écran verrouillé, carte). À toi de gérer le fond |
| `data-states="id:Libellé,..."` | états de l'écran, pilotés par le panneau « État de cet écran » (hors app). Le premier est celui par défaut |

États : tout élément de l'écran avec `data-when="id1 id2"` n'est visible que dans ces états (voir Accueil :
`encours`, `calme`, `vide`). Change d'état en JS avec `setState('nom', 'id')`. N'ajoute pas de sélecteur d'état dans l'app.
`data-when` ne marche pas dans une feuille. Pour masquer en JS : `el.hidden = true`, jamais `style.display`.

Un écran de niveau 2 commence par une barre de navigation à la place du grand titre :

```html
<header class="navbar">
  <button type="button" class="navbar-back" data-back="lieux"><svg class="icon" aria-hidden="true"><use href="#i-chev-left"/></svg>Lieux</button>
  <h1 class="navbar-title">Supérette du Canal</h1>
  <div class="navbar-actions"><button type="button" class="iconbtn" aria-label="Modifier"><svg class="icon" aria-hidden="true"><use href="#i-pencil"/></svg></button></div>
</header>
```

## Variables du thème

Couleurs (clair, sombre, AMOLED, contrastes AA vérifiés) : `--background` `--surface` `--surfaceRaised` `--fill`
`--separator` `--textPrimary` `--textSecondary` `--textTertiary` `--accent` `--accentOn` `--accentSoft`
`--work` `--workSoft` `--study` `--studySoft` `--errand` `--errandSoft` `--danger` `--dangerOn` `--dangerSoft`
`--warning` `--warningSoft` `--success`.
Règle : texte `--x` sur fond `--xSoft`, `--surface`, `--surfaceRaised` ou `--background`. Texte `--accentOn` sur `--accent`.
Taf = work, cours = study, courses = errand. L'accent n'est jamais une couleur d'activité.

Espaces `--space-xxs|xs|s|m|l|xl|xxl` (2, 4, 8, 16, 24, 32, 48). Rayons `--radius-small|medium|large|sheet|pill`.
Texte : `font: var(--t-body) var(--font-text)` avec `--t-largeTitle|title1|title2|title3|headline|body|callout|subhead|footnote|caption|timer|figure`.
Ombres `--shadow-card|float|sheet`. Durées `--motion-fast|normal|slow`, courbes `--ease`, `--ease-sheet`.
Marge latérale d'un écran : `--gutter`. Hauteurs : `--tab-h`, `--sb-h`, `--home-h`.

Identité à respecter : calme et natif iOS. Le bleu de travail (accent) sert aux actions, pas à la déco.
Toute heure, durée ou montant porte `class="num"` (chiffres mono, façon ticket de pointeuse).
Une seule carte en aplat d'accent par écran (`card--now`). Pas de dégradés, pas de carte dans une carte.

## Composants

Icônes : `<svg class="icon" aria-hidden="true"><use href="#i-pin"/></svg>` (+ `icon--s` 18 px, `icon--l` 32 px).
Disponibles : home calendar pin chart sliders plus chev-right chev-left chev-down check x clock briefcase book cart
question alert info bell nav play pause stop pencil trash undo lock faceid eye-off sun moon amoled battery download
upload share camera image grid user euro search map route bolt refresh wifi-off shield star vibrate sound list doc more.
Une icône qui manque : SVG inline dans ton fragment, viewBox 24, trait `currentColor`, classe `icon`.

**Carte** `card` (+ `card--outline` sans fond, `card--now` carte Maintenant, `card--now is-calm` version calme)
```html
<article class="card"><div class="card-head"><span class="chip chip--work">Taf</span></div>
  <h2 class="card-title">Titre</h2><p class="card-text">Texte secondaire.</p></article>
```

**Liste et ligne** `list` > `row`. La ligne est un `<button>` si elle se tape, un `<div>` sinon.
```html
<div class="list">
  <button type="button" class="row" data-go="session">
    <span class="row-icon row-icon--work"><svg class="icon" aria-hidden="true"><use href="#i-briefcase"/></svg></span>
    <span class="row-main"><span class="row-title">Taf</span><span class="row-sub">Supérette du Canal</span></span>
    <span class="row-value num">3 h 04</span>
    <svg class="icon row-chev" aria-hidden="true"><use href="#i-chev-right"/></svg>
  </button>
</div>
```
Variantes : `row-icon--work|study|errand|accent|danger`, `row--destructive`. Tout est optionnel sauf `row-main`.
Choix unique : `<div class="list" role="radiogroup">` + lignes `role="radio" aria-checked data-value` terminées par
`<svg class="icon row-check"><use href="#i-check"/></svg>` ; le groupe émet `change` (`e.detail.value`).

**Pastilles** `chip` + `chip--work|study|errand|doubt|accent|danger` (sans variante : neutre). `chip--doubt` = pointillés, pour l'incertain.
```html
<span class="chip chip--study">Cours</span> <span class="chip chip--doubt">À confirmer</span>
<span class="chip chip--work"><span class="dot-live"></span>Taf en cours</span>
```
Plusieurs pastilles : dans `<div class="chip-row">`.

**Boutons** `btn` + `btn--primary|secondary|destructive|destructive-soft|ghost`, tailles `btn--small`, `btn--block`.
```html
<div class="btn-row"><button type="button" class="btn btn--primary">Oui, c'est bon</button><button type="button" class="btn btn--secondary">Corriger</button></div>
<div class="btn-stack"><button type="button" class="btn btn--destructive btn--block">Supprimer</button></div>
```
`btn-row` = côte à côte à largeurs égales, `btn-stack` = empilés, `btn-row btn-row--links` = deux liens `btn--ghost` aux extrémités.
Bouton rond d'icône : `iconbtn` (accent) ou `iconbtn iconbtn--tonal`, toujours avec `aria-label`.
Bouton flottant, dernier enfant direct de la section : `<div class="fab-dock"><button type="button" class="fab" aria-label="Ajouter">...</button></div>`.

**Interrupteur** (le shell gère le clic, émet `change` avec `e.detail.checked`)
```html
<div class="row"><span class="row-main"><span class="row-title" id="x-lbl">Sons</span><span class="row-sub">Coupés par défaut</span></span>
  <button type="button" class="switch" role="switch" aria-checked="false" aria-labelledby="x-lbl"></button></div>
```

**Contrôle segmenté** (le shell gère la sélection, le conteneur émet `change` avec `e.detail.value`)
```html
<div class="segmented" role="group" aria-label="Période">
  <button type="button" data-value="jour" aria-pressed="true">Jour</button><button type="button" data-value="semaine" aria-pressed="false">Semaine</button></div>
```

**Champ**
```html
<div class="field"><label class="field-label" for="x-nom">Nom du lieu</label>
  <input class="input" id="x-nom" type="text" placeholder="Ex. Supérette du Canal"><span class="field-help">Aide courte.</span></div>
```
Erreur : ajoute `is-invalid` sur `.field`. Pastilles de couleur : `<div class="swatches">` + `<button class="swatch" style="--c:var(--work)" aria-pressed aria-label>`.

**Feuille (bottom sheet)** : écris-la dans ta section, le shell la déplace dans la couche des feuilles, ajoute la poignée,
gère le fond, Échap et le focus. Stylise-la par son id (plus par `#scr-...`).
```html
<button type="button" class="btn btn--secondary" data-sheet="sheet-lieux-x">Ouvrir</button>
<div class="sheet" id="sheet-lieux-x"><h2 class="sheet-title">Titre</h2><p class="sheet-text">Explication.</p>
  <div class="list">...</div><button type="button" class="btn btn--secondary btn--block" data-sheet-close>Fermer</button></div>
```

**Toast** : `toast('Session supprimée.', { undo: function () { /* remet en place */ } })` affiche « Annuler ».
Sans JS : `data-toast="Message"` sur un bouton. Toute action destructive ou automatique propose Annuler.

**État vide**
```html
<div class="empty"><span class="empty-icon"><svg class="icon icon--l" aria-hidden="true"><use href="#i-pin"/></svg></span>
  <h3 class="empty-title">Aucun lieu pour l'instant.</h3><p class="empty-text">Ajoute ton taf ou ta fac pour commencer.</p>
  <button type="button" class="btn btn--primary">Ajouter un lieu</button></div>
```

**Bandeau** `banner` + `banner--error|warning|info` (sans variante : neutre). `role="alert"` pour une erreur.
```html
<div class="banner banner--error" role="alert"><svg class="icon" aria-hidden="true"><use href="#i-alert"/></svg>
  <div class="banner-main"><p class="banner-title">Ce qui se passe</p><p class="banner-text">Comment le régler.</p>
  <button type="button" class="banner-action">Réessayer</button></div></div>
```

**Chargement** : `<span class="skeleton skeleton--line"></span>` + `skeleton--title|block|circle` ; fixe la largeur en style inline si besoin.

**Ruban horaire** : `--from`/`--to` = bornes en heures, chaque segment `--s`/`--e` en heures décimales (17:56 = 17.93).
```html
<div class="timeline" style="--from:6;--to:24" role="img" aria-label="Décris la journée en une phrase.">
  <div class="timeline-track">
    <i class="timeline-seg timeline-seg--study" style="--s:8.08;--e:12.03"></i>
    <i class="timeline-seg timeline-seg--work is-live" style="--s:17.93;--e:19.17"></i>
    <i class="timeline-now" style="--s:19.17"></i></div>
  <div class="timeline-axis" aria-hidden="true"><span>6</span><span>9</span><span>12</span><span>15</span><span>18</span><span>21</span><span>24</span></div>
</div>
```
Segments : `--work|study|errand`, `--planned` (prévu, pointillés), `--doubt` (hachuré), sans variante = autre.
Les graduations de l'axe doivent être régulières entre `--from` et `--to`. Légende : `timeline-legend` (voir Accueil).

**Chiffre clé** `stat` (+ `stat--work|study|errand`), par deux dans `stat-grid`
```html
<div class="stat-grid"><div class="stat stat--work"><span class="stat-label"><i aria-hidden="true"></i>Taf</span>
  <span class="stat-value">3<small>h</small>04</span><span class="stat-note">Heures pleines, exact 3 h 04</span></div></div>
```
Grand chrono : `<p class="timer" data-timer="4447">1:14:07</p>`. Jauge : `<div class="meter meter--work"><i style="--v:62"></i></div>`.

**Fiabilité** : `rel--high` (fiable), `rel--mid` (à vérifier), `rel--low` (incertain). Les barres portent l'info, pas que la couleur.
```html
<span class="rel rel--mid"><span class="rel-bars" aria-hidden="true"><i></i><i></i><i></i></span>À vérifier</span>
```
Statut détecté (permissions) : `<span class="status status--ok"><svg class="icon" aria-hidden="true"><use href="#i-check"/></svg>Toujours</span>` + `status--warn|error`.

Utilitaires : `num`, `muted`, `eyebrow`, `sr-only`.

## JS partagé

| Appel | Effet |
|---|---|
| `data-go="nom"` / `go('nom')` | navigue (met à jour `#nom`) |
| `data-back="repli"` / `back('repli')` | écran précédent, sinon `repli` |
| `data-sheet="id"` / `openSheet('id')`, `data-sheet-close` / `closeSheet()` | feuilles |
| `toast(msg, {undo, undoLabel, duration})`, `data-toast="msg"` | toast |
| `data-theme-set="auto\|light\|dark\|amoled"` / `setTheme(mode)` | thème de l'app (posé sur `#app[data-theme]`) |
| `setState('nom', 'id')` | change l'état d'un écran |
| `data-timer="secondes"` | chrono vivant `H:MM:SS` ; `data-timer-format="hm"` donne `1 h 14`, `"stat"` pour un `stat-value` |
| `PLT.ready(fn)` | lance ton code quand le shell est prêt (obligatoire, les helpers n'existent pas avant) |
| `PLT.onShow('nom', fn)` | à chaque affichage de l'écran |
| `PLT.fmtHMS(s)`, `PLT.fmtHM(s)`, `PLT.store.get(k, def)` / `.set(k, v)` | formats, stockage local protégé |

Événements qui remontent : `plt:show`, `plt:state`, `plt:theme`, `plt:sheet`. N'utilise jamais `localStorage` en direct,
ni `document.documentElement` pour le thème, ni un `<a href="#...">` pour naviguer.

## Textes

- Français, tutoiement, ton de pote : « T'es arrivé au taf à 17:56, c'est bon ? », « Rien pour l'instant, profites-en. »
- Pas de jargon (« session de géolocalisation » non, « taf », « cours », « courses » oui). Pas de blague sur les heures, la paie, les permissions, la suppression.
- Jamais de tiret cadratin. Jamais de lorem ipsum. Pas d'emoji.
- Espace insécable avant `? ! :` : écris `&nbsp;?` dans le HTML.
- Une erreur dit ce qui se passe et comment régler. Un bouton dit ce qu'il fait (« Tout supprimer », pas « OK »).
- Heures en 24 h (`17:56`), durées `3 h 04` ou `25 min`, marge « à plus ou moins 3 min ».
- Données d'exemple communes : Léo, lundi 16 novembre, il est 19:10. Taf : Supérette du Canal (17:56, prévu 18:00 à 21:00).
  Cours : Fac de lettres (08:05 à 12:02). Courses : Marché du Canal (12:20 à 12:45, pas compté).
- Accessibilité : `aria-label` sur tout bouton sans texte, `aria-hidden="true"` sur les icônes décoratives,
  titres `h1` (écran), `h2` (section), `h3` (dans une carte).

## Vérifier

Build, puis ouvre `index.html` enveloppé dans une page HTML minimale, à 1280 px et à 400 px de large, dans les trois thèmes.
Rien ne doit déborder du cadre ni faire défiler la page à l'horizontale, et la console doit rester vide.
