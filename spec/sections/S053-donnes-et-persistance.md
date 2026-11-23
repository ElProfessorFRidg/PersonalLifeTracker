## 53. DONNÉES ET PERSISTANCE

SwiftData. Modèles du noyau : UserProfile, ActivitySession, Place, Habit, ActivityCorrection, DetectionEvent, AuditEntry, ModuleState, SyncMetadata.
Modèles des modules : liste dans MODULES.md (annexe C), un modèle par besoin de module, créés seulement quand le module est livré.
Identifiants stables, relations cohérentes, dates normalisées, migrations, gestion des suppressions, intégrité, accès asynchrones, gestion des erreurs. Les données locales sont la source de vérité, l'app reste utilisable hors ligne. Les données d'un module désactivé sont conservées (section 3).
