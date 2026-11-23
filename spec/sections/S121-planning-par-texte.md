## 121. PLANNING PAR TEXTE (module planning_text, exige planning_ocr, désactivé par défaut)

Beaucoup d'employeurs envoient le planning en texte (SMS, WhatsApp, mail). L'utilisateur le colle ou le partage, et l'app le comprend sans photo.
- Entrées : bouton de collage natif (qui évite l'alerte système de presse-papiers), partage d'un texte via la feuille de partage (nouveau type de contenu pour le module share_import), saisie directe.
- Analyse locale, déterministe et explicable (règles avec les outils d'analyse de texte de l'appareil, sans IA distante) : jours (lundi, lun., 17/11), plages ("14-19", "14h-19h", "de 14h à 19h", "14h00/19h00"), deux plages dans un jour ("8-12 / 14-18"), repos et congés ("repos", "OFF", "R", "congé"), jours fériés, lieux, plusieurs semaines, listes, tableaux copiés, dates relatives ("semaine du 17"). Si le texte contient plusieurs personnes, même identification par nom ou initiales que pour une photo (section 16).
- Les ambiguïtés ne sont jamais devinées ("14-19" est lu 14 h à 19 h, "6-2" demande confirmation).
- Écran de validation comme en section 16 : texte d'origine avec les passages reconnus surlignés, créneaux reconstruits et modifiables. Jamais d'import silencieux.
- Apprentissage local du gabarit de l'employeur après validation, pour mieux lire le message suivant. Rien ne quitte l'appareil.
