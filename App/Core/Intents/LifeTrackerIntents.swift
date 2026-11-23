import Foundation
import AppIntents
import SwiftData

/// Conteneur SwiftData partagé entre l'app et les raccourcis : un seul par processus, ouvert à la demande.
/// Un raccourci lancé à froid n'a aucune vue : il passe par ici, comme l'app (AppModelContainer.make()).
@MainActor
enum IntentStore {
    private static var cached: ModelContainer? = nil

    static func sharedContainer() throws -> ModelContainer {
        if let container = cached { return container }
        let container: ModelContainer = try AppModelContainer.make()
        cached = container
        return container
    }
}

/// Choix d'activité proposé dans Raccourcis.
enum StartActivityOption: String, AppEnum {
    case work
    case education

    static let typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Activité")

    static let caseDisplayRepresentations: [StartActivityOption: DisplayRepresentation] = [
        StartActivityOption.work: DisplayRepresentation(title: "Taf"),
        StartActivityOption.education: DisplayRepresentation(title: "Cours")
    ]

    var activity: ActivityType {
        switch self {
        case .work: return .work
        case .education: return .education
        }
    }
}

/// Logique des raccourcis : renvoie le texte à dire. Ne jette jamais d'erreur (refus poli).
@MainActor
enum IntentActions {
    static func startWork(option: StartActivityOption?) -> String {
        let container: ModelContainer
        do {
            container = try IntentStore.sharedContainer()
        } catch {
            return IntentDialogs.storeUnavailable
        }
        let context: ModelContext = container.mainContext
        let service: SessionService = SessionService(context: context)
        let store: LastStartStore = LastStartStore()

        let lastActivity: ActivityType? = store.activity
        let activity: ActivityType = option?.activity ?? lastActivity ?? ActivityType.work

        var place: Place? = nil
        if activity == lastActivity, let uid = store.placeUID {
            let places: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
            place = places.first(where: { (p: Place) -> Bool in p.uid == uid })
        }

        do {
            _ = try service.start(activity: activity, place: place, now: Date())
            store.remember(activity: activity, placeUID: place?.uid)
            return IntentDialogs.started(activity: activity, placeName: place?.name)
        } catch SessionServiceError.alreadyRunning {
            if let running = try? service.runningSession() {
                return IntentDialogs.alreadyRunning(activity: running.activity, since: running.startDate,
                                                    calendar: running.calendar)
            }
            return "Une session tourne déjà. Arrête-la d'abord."
        } catch {
            return IntentDialogs.failure
        }
    }

    static func stopSession() -> String {
        let container: ModelContainer
        do {
            container = try IntentStore.sharedContainer()
        } catch {
            return IntentDialogs.storeUnavailable
        }
        let service: SessionService = SessionService(context: container.mainContext)
        do {
            guard let running = try service.runningSession() else { return IntentDialogs.nothingRunning }
            let stopped: WorkSession = try service.stop(running, now: Date())
            return IntentDialogs.stopped(activity: stopped.activity, seconds: stopped.exactSeconds(now: Date()))
        } catch {
            return IntentDialogs.failure
        }
    }

    static func todayHours() -> String {
        let container: ModelContainer
        do {
            container = try IntentStore.sharedContainer()
        } catch {
            return IntentDialogs.storeUnavailable
        }
        let context: ModelContext = container.mainContext
        let sessions: [WorkSession]
        do {
            sessions = try context.fetch(FetchDescriptor<WorkSession>())
        } catch {
            return IntentDialogs.failure
        }
        let now: Date = Date()
        let calendar: Calendar = Calendar.current
        let base: CalculationBase = AppSettings().calculationBase
        var inputs: [DaySessionInput] = []
        for s in sessions {
            inputs.append(DaySessionInput(id: s.uid, start: s.startDate, end: s.endDate, activity: s.activity,
                                          chosenStart: s.chosenStart, chosenEnd: s.chosenEnd))
        }
        let work: ActivityDayTotal = DaySummary.total(activity: .work, day: now, inputs: inputs, base: base, now: now, calendar: calendar)
        let study: ActivityDayTotal = DaySummary.total(activity: .education, day: now, inputs: inputs, base: base, now: now, calendar: calendar)
        let running: Bool = sessions.contains(where: { (s: WorkSession) -> Bool in s.endDate == nil })
        return IntentDialogs.today(workSeconds: work.seconds, studySeconds: study.seconds, isRunning: running)
    }
}

struct StartWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Démarrer le taf"
    static var description: IntentDescription = IntentDescription("Démarre une session. Sans choix, je reprends la dernière activité et le dernier lieu.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Activité")
    var activity: StartActivityOption?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text: String = IntentActions.startWork(option: activity)
        return .result(dialog: "\(text)")
    }
}

struct StopSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Arrêter ma session"
    static var description: IntentDescription = IntentDescription("Arrête la session en cours.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text: String = IntentActions.stopSession()
        return .result(dialog: "\(text)")
    }
}

struct TodayHoursIntent: AppIntent {
    static var title: LocalizedStringResource = "Mes heures aujourd'hui"
    static var description: IntentDescription = IntentDescription("Dit tes heures de taf et de cours d'aujourd'hui.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text: String = IntentActions.todayHours()
        return .result(dialog: "\(text)")
    }
}

struct LifeTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartWorkIntent(),
                    phrases: ["Démarre mon taf avec \(.applicationName)",
                              "Lance mon taf avec \(.applicationName)"],
                    shortTitle: "Démarrer le taf",
                    systemImageName: "play.fill")
        AppShortcut(intent: StopSessionIntent(),
                    phrases: ["Arrête ma session avec \(.applicationName)",
                              "Stoppe mon taf avec \(.applicationName)"],
                    shortTitle: "Arrêter ma session",
                    systemImageName: "stop.fill")
        AppShortcut(intent: TodayHoursIntent(),
                    phrases: ["Mes heures aujourd'hui avec \(.applicationName)",
                              "Combien j'ai fait aujourd'hui avec \(.applicationName)"],
                    shortTitle: "Mes heures aujourd'hui",
                    systemImageName: "clock")
    }
}
