## 135. SAUVEGARDE AUTOMATIQUE DANS UN DOSSIER FICHIERS (module folder_backup, proposé et coché par défaut)

L'utilisateur choisit une fois un dossier dans l'app Fichiers (iCloud Drive, "Sur mon iPhone", ou un disque accessible) via le sélecteur de dossier ; l'app garde un accès durable (signet sécurisé) et y écrit des sauvegardes. Ça fonctionne avec un compte Apple gratuit et survit à la suppression de l'app, ce que ne font pas les instantanés internes de la section 128.
- Contenu : un dossier daté avec les données en JSON et un manifeste d'empreintes SHA-256 (CryptoKit), sans dépendance externe. Chiffrement facultatif par mot de passe (à réaliser avec un mécanisme standard du SDK, l'agent vérifie lequel). Choix des éléments sensibles (contacts, mémos, pièces du journal de contrat), exclus par défaut.
- Quand : chaque semaine (tâche de fond opportuniste), à la demande, et avant les opérations risquées. Conservation des N dernières sauvegardes (défaut 8), vérification d'intégrité à l'écriture.
- Restauration depuis un dossier : aperçu des différences, instantané automatique de l'état actuel avant d'appliquer, restauration complète ou sélective.
- Suivi : "Dernière sauvegarde : il y a 3 jours" dans "État de l'app". Si le dossier devient inaccessible (signet périmé), alerte douce et re-sélection en un tap. Si aucun dossier n'est choisi, le module rappelle une fois, puis se tait.
