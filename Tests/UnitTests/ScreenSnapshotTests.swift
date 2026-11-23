import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import PersonalLifeTracker

/// Les trois rendus possibles d'un écran.
enum ShotTheme: String {
    case light
    case dark
    case amoled

    var choice: ThemeChoice {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .amoled: return .amoled
        }
    }

    var scheme: ColorScheme {
        switch self {
        case .light: return .light
        case .dark, .amoled: return .dark
        }
    }

    static let twoThemes: [ShotTheme] = [.light, .dark]
    static let threeThemes: [ShotTheme] = [.light, .dark, .amoled]
}

/// Résultat d'un rendu, vérifié par les tests (une image absente ou de mauvaise taille fait échouer le test).
struct ShotResult {
    let fileName: String
    let rendered: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let expectedWidth: Int
    let expectedHeight: Int
    let fileWritten: Bool
    let looksBlank: Bool
    let usedWithoutNavigationStack: Bool
}

/// Fond posé sous l'écran, dans l'environnement du thème (la palette vient de `.pltTheme()`).
private struct ShotBackdrop: View {
    @Environment(\.palette) private var palette
    let content: AnyView

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            content
        }
    }
}

/// Captures PNG des vrais écrans SwiftUI avec ImageRenderer (échelle 2, largeur 390 pt), pour les comparer à la maquette.
/// Un écran par méthode : un échec n'arrête pas les autres. Voir notes/screenshots.md.
@MainActor
final class ScreenSnapshotTests: XCTestCase {

    private static let width: CGFloat = 390
    private static let scale: CGFloat = 2

    // MARK: Tests, un par écran

    func test01Accueil() {
        let results: [ShotResult] = shoot("01-accueil", height: 1700, themes: ShotTheme.threeThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(AccueilView(onReviewPlaces: {}))
        }
        XCTAssertEqual(results.count, 3)
        assertRendered(results)
    }

    func test02Lieux() {
        let results: [ShotResult] = shoot("02-lieux", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(LieuxView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test03LieuAjout() {
        // Feuille : elle porte sa propre NavigationStack.
        let results: [ShotResult] = shoot("03-lieu-ajout", height: 1400, themes: ShotTheme.twoThemes, navigation: false) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(LieuAjoutView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test04LieuDetail() {
        let results: [ShotResult] = shoot("04-lieu-detail", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (h: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(LieuDetailView(place: h.tafPlace))
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test05Sessions() {
        let results: [ShotResult] = shoot("05-sessions", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(SessionsView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test06SessionDetail() {
        let results: [ShotResult] = shoot("06-session-detail", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (h: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(SessionDetailView(session: h.ongoingSession))
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test07SessionAjout() {
        let results: [ShotResult] = shoot("07-session-ajout", height: 1200, themes: ShotTheme.twoThemes, navigation: false) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(SessionAjoutView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test08Doute() {
        let results: [ShotResult] = shoot("08-doute", height: 844, themes: ShotTheme.twoThemes, navigation: false) { (h: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(DouteView(session: h.doubtSession))
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test09Planning() {
        let results: [ShotResult] = shoot("09-planning", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(PlanningView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test10Stats() {
        let results: [ShotResult] = shoot("10-stats", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(StatsView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test11Fonctionnalites() {
        let results: [ShotResult] = shoot("11-fonctionnalites", height: 2600, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(FonctionnalitesView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test12Reglages() {
        let results: [ShotResult] = shoot("12-reglages", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(ReglagesView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test13OnboardingWelcome() {
        // Première étape : OnboardingView démarre toujours sur l'accueil (l'étape est un @State privé).
        let results: [ShotResult] = shoot("13-onboarding-bienvenue", height: 844, themes: ShotTheme.twoThemes, navigation: false) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(OnboardingView(onDone: {}))
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test14OnboardingModules() {
        // L'étape Modules est rendue seule (sans l'en-tête d'OnboardingView), car on ne peut pas piloter son @State privé.
        let results: [ShotResult] = shoot("14-onboarding-modules", height: 1700, themes: ShotTheme.twoThemes, navigation: false) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(
                ScrollView {
                    OnboardingModulesStep(onContinue: {})
                        .padding(.horizontal, Theme.Spacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            )
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test15Diagnostic() {
        let results: [ShotResult] = shoot("15-diagnostic", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(DiagnosticView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test16Emploi() {
        let results: [ShotResult] = shoot("16-emploi", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(EmploiView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test17Paie() {
        let results: [ShotResult] = shoot("17-paie", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(PaieView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test18ContratHeures() {
        let results: [ShotResult] = shoot("18-contrat-heures", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(ContratHeuresView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test19Conges() {
        let results: [ShotResult] = shoot("19-conges", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(CongesView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    func test20Instantanes() {
        let results: [ShotResult] = shoot("20-instantanes", height: 1700, themes: ShotTheme.twoThemes, navigation: true) { (_: ScreenSnapshotSeedHandles) -> AnyView in
            return AnyView(InstantanesView())
        }
        XCTAssertEqual(results.count, 2)
        assertRendered(results)
    }

    // MARK: Vérifications communes

    private func assertRendered(_ results: [ShotResult]) {
        for r in results {
            XCTAssertTrue(r.rendered, "\(r.fileName) : ImageRenderer n'a rendu aucune image")
            XCTAssertEqual(r.pixelWidth, r.expectedWidth, "\(r.fileName) : largeur en pixels")
            XCTAssertEqual(r.pixelHeight, r.expectedHeight, "\(r.fileName) : hauteur en pixels")
            XCTAssertTrue(r.fileWritten, "\(r.fileName) : le PNG n'a pas pu être écrit")
        }
    }

    // MARK: Rendu

    /// Rend l'écran dans chaque thème, écrit `<name>-<thème>.png` et un `<name>.report.txt`.
    /// `navigation` : enveloppe dans une NavigationStack (écrans poussés). Si l'image est unie (écran vide),
    /// un second essai sans NavigationStack est tenté et gardé s'il montre quelque chose.
    private func shoot(_ name: String,
                       height: CGFloat,
                       themes: [ShotTheme],
                       navigation: Bool,
                       content: (ScreenSnapshotSeedHandles) -> AnyView) -> [ShotResult] {
        let container: ModelContainer
        let handles: ScreenSnapshotSeedHandles
        do {
            container = try AppModelContainer.make(inMemory: true)
            handles = try ScreenSnapshotSeed.seed(into: container, now: Date(), calendar: Calendar.current)
        } catch {
            XCTFail("\(name) : base en mémoire ou jeu d'exemple impossible : \(error)")
            return []
        }

        // GeofenceService : se construit sans démarrer (pas de start()), donc sans localisation ni région.
        let notifier: DetectionNotifier = DetectionNotifier(container: container)
        let geofence: GeofenceService = GeofenceService(container: container, notifier: notifier)
        let undo: UndoCenter = UndoCenter()
        let directory: URL = ScreenSnapshotTests.prepareDirectory()

        var results: [ShotResult] = []
        var reportLines: [String] = []
        for theme in themes {
            let suite: String = "PLTScreenshots.\(UUID().uuidString)"
            let defaults: UserDefaults = UserDefaults(suiteName: suite) ?? UserDefaults.standard
            let settings: AppSettings = AppSettings(defaults: defaults)
            settings.themeChoice = theme.choice
            let modules: ModuleStore = ModuleStore(defaults: defaults)
            for def in ModuleRegistry.all where def.isAvailable && !def.isMandatory {
                modules.setEnabled(def.id, true)
            }

            let fileName: String = "\(name)-\(theme.rawValue).png"
            let screen: AnyView = content(handles)
            var image: UIImage? = render(screen: screen, navigation: navigation, height: height, theme: theme,
                                         container: container, settings: settings, modules: modules,
                                         geofence: geofence, undo: undo)
            var blank: Bool = image.map { (i: UIImage) -> Bool in ScreenSnapshotTests.isUniform(i) } ?? true
            var withoutNav: Bool = false
            if blank && navigation {
                let retry: UIImage? = render(screen: content(handles), navigation: false, height: height, theme: theme,
                                             container: container, settings: settings, modules: modules,
                                             geofence: geofence, undo: undo)
                if let retry = retry, !ScreenSnapshotTests.isUniform(retry) {
                    image = retry
                    blank = false
                    withoutNav = true
                }
            }

            var written: Bool = false
            var pixelWidth: Int = 0
            var pixelHeight: Int = 0
            if let image = image, let cg = image.cgImage {
                pixelWidth = cg.width
                pixelHeight = cg.height
                if let data = image.pngData() {
                    do {
                        try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
                        written = true
                    } catch {
                        written = false
                    }
                }
            }
            let result: ShotResult = ShotResult(fileName: fileName,
                                                rendered: image != nil,
                                                pixelWidth: pixelWidth,
                                                pixelHeight: pixelHeight,
                                                expectedWidth: Int(ScreenSnapshotTests.width * ScreenSnapshotTests.scale),
                                                expectedHeight: Int(height * ScreenSnapshotTests.scale),
                                                fileWritten: written,
                                                looksBlank: blank,
                                                usedWithoutNavigationStack: withoutNav)
            results.append(result)
            reportLines.append("\(fileName) : \(pixelWidth)x\(pixelHeight) px, image unie (vide) : \(blank ? "oui" : "non"), "
                               + "rendu sans NavigationStack : \(withoutNav ? "oui" : "non")")
            defaults.removePersistentDomain(forName: suite)
        }

        let report: String = reportLines.joined(separator: "\n") + "\n"
        try? report.write(to: directory.appendingPathComponent("\(name).report.txt"), atomically: true, encoding: .utf8)
        // Garde la base en vie jusqu'ici : les objets du jeu d'exemple en dépendent.
        withExtendedLifetime(container) {}
        return results
    }

    private func render(screen: AnyView,
                        navigation: Bool,
                        height: CGFloat,
                        theme: ShotTheme,
                        container: ModelContainer,
                        settings: AppSettings,
                        modules: ModuleStore,
                        geofence: GeofenceService,
                        undo: UndoCenter) -> UIImage? {
        let inner: AnyView = navigation ? AnyView(NavigationStack { screen }) : screen
        let root: AnyView = AnyView(
            ShotBackdrop(content: inner)
                .pltTheme()
                .environment(settings)
                .environment(modules)
                .environment(geofence)
                .environment(undo)
                .modelContainer(container)
                .environment(\.colorScheme, theme.scheme)
                .frame(width: ScreenSnapshotTests.width, height: height)
        )
        let renderer: ImageRenderer<AnyView> = ImageRenderer(content: root)
        renderer.scale = ScreenSnapshotTests.scale
        renderer.proposedSize = ProposedViewSize(width: ScreenSnapshotTests.width, height: height)
        return renderer.uiImage
    }

    // MARK: Fichiers

    /// Dossier de sortie : PLT_SCREENSHOT_DIR si présent, sinon `<dépôt>/build/screens` déduit de #filePath
    /// (le simulateur partage le disque de l'hôte, et les variables d'environnement de xcodebuild ne sont pas transmises aux tests).
    private static func prepareDirectory() -> URL {
        let fm: FileManager = FileManager.default
        var candidates: [URL] = []
        if let env = ProcessInfo.processInfo.environment["PLT_SCREENSHOT_DIR"], !env.isEmpty {
            candidates.append(URL(fileURLWithPath: env, isDirectory: true))
        }
        let repoRoot: URL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        candidates.append(repoRoot.appendingPathComponent("build", isDirectory: true).appendingPathComponent("screens", isDirectory: true))
        candidates.append(URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("screens", isDirectory: true))
        for url in candidates {
            do {
                try fm.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            } catch {
                continue
            }
        }
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    /// Vrai si l'image réduite ne contient qu'une seule couleur (écran qui n'a rien dessiné).
    private static func isUniform(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return true }
        let w: Int = 48
        let h: Int = 96
        var buffer: [UInt8] = [UInt8](repeating: 0, count: w * h * 4)
        let space: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = buffer.withUnsafeMutableBytes { (ptr: UnsafeMutableRawBufferPointer) -> Bool in
            guard let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        if !drawn { return false }
        let r0: Int = Int(buffer[0])
        let g0: Int = Int(buffer[1])
        let b0: Int = Int(buffer[2])
        var i: Int = 4
        while i < buffer.count {
            if abs(Int(buffer[i]) - r0) > 1 || abs(Int(buffer[i + 1]) - g0) > 1 || abs(Int(buffer[i + 2]) - b0) > 1 {
                return false
            }
            i += 4
        }
        return true
    }
}
