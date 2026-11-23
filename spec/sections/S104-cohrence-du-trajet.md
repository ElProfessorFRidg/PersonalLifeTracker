## 104. COHÉRENCE DU TRAJET (module travel_calibration, exige travel_departure, désactivé par défaut)

Compare les durées de trajet réellement observées (du départ de la zone à l'arrivée au lieu) avec l'estimation MKDirections, par trajet, mode de transport, créneau horaire et jour. Calcule l'écart médian et propose d'ajuster la marge de "Pars maintenant" : "Ton trajet dure en moyenne 6 min de plus que prévu, je prends une marge de 16 min." L'utilisateur accepte, refuse ou règle à la main.
Échantillon minimal réglable (défaut 8 trajets comparables). Exclure les trajets avec arrêt (courses détectées, pause). Confidentialité : seules les durées et horodatages sont conservés, jamais de trace GPS détaillée.
