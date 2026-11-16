## 11. LOGIQUE TRAVAIL CONTRE COURSES

Un supermarché peut être lieu de travail, de courses et de visite. Score de 0 à 100 par visite d'un lieu à double usage, explicable dans l'écran de détail ("Pourquoi cette classification ?").
Facteurs par ordre d'importance :
1. Correction manuelle antérieure dans un contexte similaire (même jour de semaine, plage horaire proche).
2. Correspondance avec un créneau du planning importé de la semaine (si le module est actif). Quand les plannings varient, c'est le facteur le plus fiable après les corrections manuelles.
3. Durée : sous 20 minutes, probablement des courses ; au-dessus de 2 heures, probablement du travail ; entre les deux, ambigu.
4. Récurrence : même jour et même heure d'arrivée que des visites déjà confirmées comme travail (poids réduit quand les plannings varient d'une semaine à l'autre).
5. Heure d'arrivée proche d'une prise de poste habituelle.
6. Contexte : arrivée directe depuis le lycée ou le domicile à une heure de prise de poste.
Analyser aussi les activités précédentes et suivantes.
Seuils : au-dessus de 75, classement automatique sans question. Entre 40 et 75, classement provisoire et confirmation proposée. Sous 40, "inconnu" avec demande de confirmation.
Types : travail, courses, visite personnelle, passage, inconnu, et avec le module multi_site déplacement professionnel (section 151).
Toute confirmation ou correction crée une règle locale limitée à son contexte (lieu, jour, plage horaire). Après 3 confirmations concordantes dans un même contexte, la classification devient automatique pour ce contexte. Jamais de correction appliquée à tous les contextes.
