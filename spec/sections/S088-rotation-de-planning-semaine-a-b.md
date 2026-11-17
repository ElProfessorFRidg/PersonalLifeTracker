## 88. ROTATION DE PLANNING SEMAINE A/B (module schedule_rotation, exige planning_ocr, désactivé par défaut)

Réservé aux plannings qui se répètent vraiment. La rotation peut être saisie à la main ou détectée par le module pattern_detection (section 107) : quand l'app repère un cycle (2 semaines, 3 semaines, mensuel, autre), elle propose de l'activer. Si les semaines sont toutes différentes, rien n'est proposé.

L'utilisateur définit un cycle (deux semaines A/B, ou N semaines), la semaine de départ, et pour chaque semaine type les créneaux (jour, début, fin, activité, lieu). À l'import d'un planning par photo, l'app demande "C'est la semaine A ou B ?" et peut déduire la rotation après deux plannings consécutifs.
Elle préremplit le planning prévu des semaines suivantes avec des créneaux "prévus par rotation", non confirmés, confirmables en un tap. Un planning réel importé prime toujours sur la rotation. Gérer les exceptions (vacances, fériés, congés, remplacements, échanges) et le décalage de cycle ("On a décalé : cette semaine c'est B"). L'alerte de planning tardif (section 70) et la détection d'heures manquantes (section 86) tiennent compte de ces créneaux prévus.
