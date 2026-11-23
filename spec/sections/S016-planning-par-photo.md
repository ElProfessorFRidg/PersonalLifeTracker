## 16. PLANNING PAR PHOTO (module planning_ocr)

Formats : JPG, JPEG, PNG, HEIC, captures d'écran, PDF si pertinent. Traitement local avec Vision (VNRecognizeTextRequest).
Parcours :
1. Profil unique : prénom, nom, initiales, surnoms, plusieurs variantes possibles.
2. Import depuis Photos, Fichiers ou capture partagée.
3. Analyse locale avec indicateur de progression.
4. Écran de validation : image d'origine en haut, planning reconstruit en bas, créneaux de l'utilisateur surlignés. Si plusieurs lignes ressemblent à son nom, l'app demande de choisir.
5. Chaque créneau est modifiable (date, début, fin, activité, lieu), ajout et suppression possibles.
6. Confirmation : les créneaux deviennent le planning prévu, comparable ensuite au réel.
Extraction : jours, dates, heures, noms, prénoms, initiales, matières, activités, lieux. Reconstruction par la position des textes (colonnes, lignes, en-têtes, cases, créneaux, association personnes/horaires), jamais en lisant le texte dans l'ordre. Gérer : semaine en colonnes, une personne par ligne ou par colonne, "8h-12h / 14h-18h", abréviations de jours, cases vides, repos, congés.
Ne jamais supposer que le premier nom détecté est le bon. Ne jamais enregistrer silencieusement un résultat incertain. Afficher l'écart avec le réel ("prévu 18:00, arrivé 17:56").
Onglet Planning : vues jour, semaine, mois ; distinguer prévu, réel, détecté, corrigé ; détection de conflits (créneau de travail qui chevauche un cours ou un trajet).
