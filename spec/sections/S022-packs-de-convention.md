## 22. PACKS DE CONVENTION (module pay)

Chaque pack est un fichier JSON versionné dans Resources/conventions/, lisible et modifiable : nom, IDCC, secteur, mots-clés de recherche, description simple, liens vers sources officielles, date de dernière vérification, et règles : majoration dimanche, jours fériés, soirée et nuit, heures complémentaires et supplémentaires, pauses, durées maximales quotidienne et hebdomadaire, repos minimal entre deux journées, primes usuelles (proposées, jamais appliquées sans confirmation), banque d'heures, remarques.
Priorité : valeurs saisies par l'utilisateur depuis son contrat ou sa fiche de paie, puis pack de convention, puis règles générales du Code du travail. Surcharge manuelle de chaque règle en quelques taps.

Packs à créer en priorité (les plus utilisés ; l'agent valide chaque numéro et chaque nom sur Légifrance ou code.travail.gouv.fr et corrige s'il est inexact) :
- Commerce de détail et de gros à prédominance alimentaire (IDCC 2216)
- Commerce de détail non alimentaire (IDCC 1517)
- Commerce de détail de l'habillement et articles textiles (IDCC 1483)
- Commerces de détail de bricolage (IDCC 1606)
- Commerce de détail de produits culturels et de loisirs (IDCC 1686)
- Commerce de gros (IDCC 573)
- Restauration rapide (IDCC 1501)
- Hôtels, cafés, restaurants (IDCC 1979)
- Restauration de collectivités (IDCC 1266)
- Commerce et réparation de l'automobile, du cycle et du motocycle, vendeurs en concession ou garage (IDCC 1090)
- Pharmacie d'officine (IDCC 1996)
- Propreté et services associés (IDCC 3043)
- Transports routiers et activités auxiliaires (IDCC 16)
- Bureaux d'études techniques, conseil, ingénierie (IDCC 1486)
- Prestataires de services du secteur tertiaire (IDCC 2098)
- Travail temporaire (IDCC 2378)
- Hospitalisation privée (IDCC 2264)
- Sport (IDCC 2511) et animation (IDCC 1518)
- Bâtiment : ouvriers jusqu'à 10 salariés (IDCC 1596) et plus de 10 salariés (IDCC 1597)
- Personnalisée (l'utilisateur saisit tout)
- Règles générales du Code du travail (pack de base utilisé par défaut)
Pas besoin d'être exhaustif : l'architecture permet d'ajouter un pack en déposant un fichier JSON, sans recompiler.

Travail de l'agent : rechercher sur internet, dans des sources officielles (Légifrance, service-public.fr, code.travail.gouv.fr, texte de la convention), les règles de chaque pack, en commençant par le pack supermarché. Remplir chaque pack avec sources et date de vérification. Ne rien inventer : règle introuvable ou ambiguë, la laisser vide, la marquer "à renseigner", la lister dans le rapport final. Beaucoup de règles dépendent de l'entreprise (accords internes) : l'app le dit et invite à vérifier son contrat.
Mise à jour des packs sans serveur obligatoire : import d'un fichier JSON, et en option (désactivée par défaut) téléchargement depuis une URL statique (par exemple un fichier JSON dans le dépôt GitHub), sans aucune donnée personnelle envoyée.
Application automatique : à chaque session, l'app découpe les heures selon les règles (dimanche, férié, soir/nuit, heures complémentaires) et affiche le détail. Alertes avec la source de la règle ("tu approches du plafond", "moins de 11 h de repos entre ces deux journées").
