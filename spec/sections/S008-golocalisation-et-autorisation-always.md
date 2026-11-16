## 8. GÉOLOCALISATION ET AUTORISATION ALWAYS

Parcours de permission progressif : expliquer l'intérêt, demander l'autorisation initiale, expliquer pourquoi Always est nécessaire, demander Always au moment adapté au processus iOS, détecter refus et restrictions, proposer les Réglages. Ne jamais prétendre imposer une autorisation, ne jamais bloquer l'app en cas de refus (mode réduit).
Surveillance : CLCircularRegion, startMonitoring(for:), startMonitoringSignificantLocationChanges(), CLMonitor si disponible, événements de région, restauration du suivi. API choisies selon l'iOS minimal, pas de surveillance redondante, limite de 20 régions respectée, lieux importants prioritaires.
Arrivées : combiner distance, précision, stabilité, durée de présence, événement de région, habitudes, contexte. Jamais d'arrivée sur une seule position imprécise.
Départs : éviter les faux positifs. Une perte momentanée de GPS n'est pas un départ. Utiliser distance, stabilité, temps hors zone, événements de région, cohérence temporelle.
Arrière-plan : fonctionner écran verrouillé, app en arrière-plan ou suspendue, réactivation par événement système, redémarrage du téléphone. Distinguer suspension système et arrêt forcé par l'utilisateur, ne jamais promettre un suivi garanti après un forçage à quitter.
Récupération : au lancement suivant, reconstituer les événements manqués à partir des événements de région, changements significatifs et visites, et marquer ces sessions "reconstituées".
CoreMotion : activité (immobile, marche, voiture, transport) pour réduire la consommation, détecter les trajets et affiner les départs.
