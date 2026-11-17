## 133. GALERIE DE WIDGETS : FORMATS, STYLES ET PERSONNALISATION (extension du module live_activity_widgets)

133.1 Familles à supporter (WidgetKit, à vérifier dans le SDK utilisé) :
- iPhone, écran d'accueil et vue Aujourd'hui : systemSmall (2×2), systemMedium (4×2), systemLarge (4×4) et, avec iOS 27, systemExtraLargePortrait (4×6, portrait uniquement).
- Écran verrouillé : accessoryCircular, accessoryRectangular, accessoryInline.
- StandBy : les widgets de taille small s'y affichent, avec une version adaptée (gros chiffres, teinte nocturne).
- iPad et Mac : systemExtraLarge, seulement si l'app devient universelle plus tard. Apple Watch (accessoryCorner et autres) et visionOS : hors périmètre tant qu'aucune cible dédiée n'existe. CarPlay : les widgets introduits avec iOS 26 et étendus avec iOS 27 sont à étudier seulement s'ils sont accessibles sans autorisation spéciale, sinon hors périmètre.
Chaque widget déclare ses familles avec supportedFamilies et réutilise le même fournisseur de timeline avec une vue adaptée à chaque famille.
Contrainte de compilation : systemExtraLargePortrait n'existe que dans le SDK Xcode 27 (Swift 6.4) et sur iOS 27 ou plus. L'ajouter derrière une vérification de compilation ET de disponibilité (#if compiler(>=6.4) et #available(iOS 27.0, *)) pour que le projet compile encore avec un Xcode plus ancien. Dans le CI (section 57), prévoir un runner avec Xcode 27 pour compiler ce chemin et documenter le comportement quand il n'est pas disponible.

133.2 Widgets proposés. Pour ne pas multiplier les widgets, un nombre limité de widgets très configurables (AppIntentConfiguration), chacun avec plusieurs affichages. Le groupe de widgets (WidgetBundle) est fixé à la compilation et ne peut pas masquer un widget selon les modules actifs : un widget d'un module désactivé affiche un état d'invitation ("Active le module X dans l'app") au lieu de disparaître.
1. Maintenant (activité en cours, prochaine, ou "rien à faire", avec actions rapides) : small, medium, large, XL portrait, accessoryRectangular.
2. Ma journée (frise avec trait "maintenant", cours et travail) : medium, large, XL portrait.
3. Ma semaine (grille de 7 jours, couleur par activité, barre de quota) : large, XL portrait, version compacte en medium.
4. Heures et quota (anneau, barre ou chiffre : heures de la semaine ou du mois, quota, projection) : small, medium, accessoryCircular, accessoryRectangular, accessoryInline.
5. Compte à rebours (au choix : fin de service "encore X h", prochaine prise de poste, paie dans X jours, fin de contrat, fin de période d'essai, congés restants, examens, objectif d'épargne) : small, accessoryCircular, accessoryRectangular, accessoryInline, StandBy.
6. Argent (net estimé du mois, reste de fin de mois, épargne, gains en direct) : small, medium, accessoryCircular, masqué par défaut.
7. Carte de chaleur (section 102) : large, XL portrait, version compacte en medium.
8. Actions rapides (démarrer, arrêter, pause, "je suis en retard", appeler le responsable) : small, medium, boutons interactifs.
9. Aperçu (aperçu de fin de semaine, brief du matin, charge de la semaine, périodes bloquées à venir, disponibilités) : medium, large, XL portrait.
10. Fiabilité et suivi (score de fiabilité, état du suivi, éléments à confirmer) : small, accessoryCircular, accessoryRectangular.
11. Mot de pote (phrase courte, drôle ou encourageante, dans le ton de l'app, jamais sur un sujet sérieux) : small, medium, accessoryInline.
Chaque widget a, dans la galerie du système, une description tutoyée et un aperçu réaliste.

133.3 Personnalisation (intents) : employeur (si multi_employer), période (jour, semaine, mois, année), affichage (anneau, barre, chiffre, graphique), unité (net ou brut), contenu du compte à rebours, objectif d'épargne choisi, densité (compacte ou confortable), masquer les montants, masquer les lieux, style. Valeurs par défaut sobres, paramètres dynamiques (liste des employeurs, des objectifs) alimentés par les données de l'app.
133.4 Styles visuels : un style global choisi dans l'app, surchargeable par widget : Épuré clair, Sombre profond (OLED), Verre (matériaux du système), Cartes colorées (couleur d'activité), Monochrome accent, Gros chiffres, Graphique d'abord, Contraste élevé. Palette d'accent de 8 à 10 couleurs identique à l'app, option police arrondie, aucune couleur codée en dur hors palette.
133.5 Modes d'apparence du système : plein couleur, teinté et clair. Utiliser les marqueurs d'accentuation de WidgetKit (widgetAccentable), le mode de rendu du widget et le fond de conteneur système (containerBackground), sans images en couleur qui se dégradent en mode teinté. Tester chaque widget dans les trois modes, en clair et en sombre.
133.6 Confidentialité : sur l'écran verrouillé, montants, lieux et notes sont marqués sensibles (privacySensitive et contenu masqué) et cachés tant que l'appareil est verrouillé, par défaut. Réglage pour les afficher quand même.
133.7 Données et mises à jour : timelines précalculées (heures, comptes à rebours, gains en direct par entrées minute par minute), Text(timerInterval:) pour les décomptes, rechargement ciblé (WidgetCenter) au démarrage ou à la fin d'une session et à chaque changement de planning, sans épuiser le budget de rechargements. Données via l'App Group avec le repli de la section 44 : sans App Group, les widgets affichent un contenu générique et un lien pour ouvrir l'app, et "État de l'app" l'indique. Un tap ouvre l'écran concerné (liens profonds), les actions passent par des App Intents.
133.8 Tests et qualité : aperçus SwiftUI par famille et par style, tests d'instantanés des tailles, des trois modes d'apparence, du texte agrandi, de l'état d'invitation d'un module désactivé et de l'absence d'App Group. Mode développeur de WidgetKit pour lever les limites de rechargement pendant les tests. Chaque widget reste lisible d'un coup d'œil.
