| Écran | Rôle | Composants clés | États | Module | Étape | Étiquettes VoiceOver |
|---|---|---|---|---|---|---|
| Bienvenue (`onb-bienvenue`) | Dire ce que fait l'app, 100 % local, sans compte | Icône d'accueil, titre, 3 lignes d'argument, bouton "C'est parti", feuille "Où vont tes données ?" | Un seul | Noyau | 1 sur 7 | "Étape 1 sur 7" (progression), "Ce que fait l'app" (liste), "C'est parti", "Et mes données ?" |
| Choix des modules (`onb-modules`) | Choisir les fonctionnalités optionnelles | Préréglages segmentés (Essentiel, Complet, Je choisis), ligne Noyau "Obligatoire", 16 interrupteurs en 4 groupes, compteur vivant, note de dépendance (Employeurs) | Réglage conseillé (11 cochées sur 16) | Noyau (obligatoire), modules du registre | 2 sur 7 | "Étape 2 sur 7", "Un préréglage", un interrupteur par module (libellé du module), "Continuer" |
| Permission localisation (`onb-loc`) | Expliquer la localisation "Toujours" avant iOS, puis traiter la réponse | Icône, "Ce que j'en fais", "Ce qu'iOS va te demander", "Et si tu refuses ?", fausse fenêtre iOS (2 fenêtres), bannière limite, bannière erreur, liste numérotée de réparation | Intro, iOS 1, iOS 2, Toujours, Limitée, Refusée | Noyau | 3 sur 7 | "Étape 3 sur 7", fenêtres `alertdialog` titrées, "Autoriser pendant l'utilisation", "Changer pour Toujours autoriser", "Ouvrir les réglages iOS", "Continuer sans localisation" |
| Permission notifications (`onb-notifs`) | Expliquer les notifications avant iOS | Exemple de notification, "Mes règles" (6 par jour, silence la nuit, par catégorie), fenêtre iOS, bannière refus | Intro, Fenêtre iOS, Accordée, Refusée | Noyau (smart_notifications si cochée) | 4 sur 7 | "Étape 4 sur 7", "Exemple de notification", "Autoriser", "Ne pas autoriser", "Plus tard" |
| Permission photos (`onb-photos`) | Expliquer l'accès aux photos pour le planning | Icône, "Ce que je regarde", fenêtre iOS (limiter, tout, refuser), bannière refus | Intro, Fenêtre iOS, Accordée, Refusée | planning_ocr (étape sautée si non coché) | 5 sur 7 | "Étape 5 sur 7", "Choisir des photos…", "Autoriser l'accès à toutes les photos", "Ne pas autoriser" |
| Premier lieu (`onb-lieu`) | Ajouter son taf ou sa fac, ou passer | Choix unique Taf/Fac, champs nom et adresse, zone de 100 m, carte de confirmation, bouton "Annuler et corriger" | Formulaire, Lieu ajouté | Noyau | 6 sur 7 | "Étape 6 sur 7", "C'est quoi comme endroit ?", "Son nom", "Où ça se trouve ?", "Ajouter ce lieu", "Je le ferai plus tard" |
| C'est prêt (`onb-fin`) | Récapitulatif "Voilà ce que j'ai compris" avec correction par ligne, puis accueil | 4 lignes récap (fonctionnalités, localisation, notifications, lieu) avec statut et "Corriger", bannière si localisation limitée | Tout est bon, Il manque des trucs | Noyau | 7 sur 7 | "Fonctionnalités, corriger", "Localisation, corriger", "Notifications, corriger", "Premier lieu, corriger", "Aller à l'accueil" |

## Non maquetté

- Prénom et petit mot d'accueil (étape 1 de la spec), profil lycéen, étudiant, salarié (étape 2) : non demandés pour cette passe, "Léo" est écrit en dur dans l'écran final.
- Étapes conditionnelles par module : employeur et contrat (4), rémunération et convention, scan du contrat (5), solde de congés (7), import d'une photo de planning (8), deuxième employeur (multi_employer).
- Lieux de cours et domicile à l'onboarding (étape 6) : seul le premier lieu (taf ou fac) est maquetté.
- Permission "mouvement" : la spec 48 n'en cite pas (localisation, notifications, photos), donc absente.
- Rien de persistant : les choix passent par `PLT.store` (`onb.modules`, `onb.loc`, `onb.notif`, `onb.lieu`) pour la maquette seulement.
- Le contenu du noyau (section 3.1) est résumé en une ligne, non relu dans la spec complète.
- La carte et la recherche d'adresse du premier lieu : deux champs texte simples.
- Les fenêtres iOS sont des imitations (texte et boutons d'esprit iOS), pas les libellés exacts d'iOS.
