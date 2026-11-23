## 7. ARCHITECTURE

Structure indicative, améliorable :

```
PersonalLifeTracker/
  App/
  Core/ (Models, Persistence, Services, Utilities, ModuleRegistry)
  Features/
    Core/ (Home, Locations, Statistics, ActivityTracking, Settings)
    Modules/ (un dossier par module, liste dans MODULES.md)
  Services/ (LocationService, ActivityDetectionService, HabitLearningService, PlaceDiscoveryService, PlaceCalibrationService, ScheduleOCRService, PlanningTextParser, PayslipOCRService, StatisticsService, PayService, ConventionService, LeaveService, ContractLifecycleService, ContractHoursService, SimulatorService, PatternDetectionService, TravelTimeService, GoalService, RecapService, SearchService, DataTrustService, ActionEngine, NotificationCoordinator, CapabilityService, UndoService, SnapshotService, IntegrityService, CloudSyncService, LiveActivityService, WidgetDataService, SignalService, FolderBackupService, ClockService, AssistantToolService, AgeRulesService, PaperScanService, TimetableService, OfferImpactService, PayPeriodService, ContractCheckService, DayReplayService, GlossaryService, CalendarConstraintsService, DayInsightService, ReliabilityCenterService)
  Widgets/ (extension unique : widgets, Live Activity, contrôles)
  Resources/ (conventions/*.json, reference/*.json, Localizable.xcstrings, PrivacyInfo.xcprivacy)
  Tests/ (UnitTests, IntegrationTests)
```

Pas de logique métier dans les vues, pas d'abstractions inutiles, responsabilités claires. Le code d'un module optionnel ne dépend jamais du noyau dans l'autre sens.
