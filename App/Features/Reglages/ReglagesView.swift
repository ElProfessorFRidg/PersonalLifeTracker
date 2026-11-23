import SwiftUI
import SwiftData
import UIKit

/// Réglages (section 49). Poussé depuis Accueil. Prototype : design/prototype/src/screens/90_reglages.html.
struct ReglagesView: View {
    @Environment(GeofenceService.self) private var geofence
    @Environment(AppSettings.self) private var settings
    @Environment(ModuleStore.self) private var modules
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    @Query private var places: [Place]
    @Query private var sessions: [WorkSession]

    @State private var capabilities: CapabilityService = CapabilityService()
    @State private var showBaseInfo: Bool = false
    @State private var showDeleteAll: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var exportURL: URL? = nil
    @State private var dataError: String? = nil

    var body: some View {
        PLTScreen(title: "Réglages") {
            detectionSection
            featuresSection
            setupSection
            diagnosticSection
            if modules.isActive("employment") {
                employmentSection
            }
            if modules.isActive("send_hours_reminder") {
                SendHoursReminderCard()
            }
            appearanceSection
            preferencesSection
            dataSection
            resetSection
            aboutSection
        }
        .onAppear {
            capabilities.refresh()
            prepareExport()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { capabilities.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            capabilities.refresh()
        }
        .onChange(of: places.count) { _, _ in prepareExport() }
        .onChange(of: sessions.count) { _, _ in prepareExport() }
        .sheet(isPresented: $showBaseInfo) {
            BaseCalculSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDeleteAll) {
            SuppressionTotaleSheet(placeCount: places.count, sessionCount: sessions.count) {
                deleteEverything()
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Remettre les réglages d'origine ?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Réinitialiser les réglages", role: .destructive) { settings.resetToDefaults() }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes lieux et tes sessions ne bougent pas.")
        }
    }

    // MARK: Ce que je détecte

    private var detectionSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Ce que je détecte")
            if capabilities.location != .always {
                PLTBanner(kind: locationBannerKind,
                          title: locationBannerTitle,
                          message: locationBannerMessage,
                          actionTitle: "Ouvrir les réglages iOS",
                          action: { openIOSSettings() })
            }
            PLTListGroup {
                StatusRow(symbol: "location.fill",
                          title: "Localisation",
                          subtitle: "Pour savoir quand t'arrives et quand tu pars",
                          statusSymbol: locationStatus.symbol,
                          statusText: locationStatus.text,
                          level: locationStatus.level)
                StatusRow(symbol: "scope",
                          title: "Position exacte",
                          subtitle: "Sans ça, je confonds le taf et le magasin d'à côté",
                          statusSymbol: preciseStatus.symbol,
                          statusText: preciseStatus.text,
                          level: preciseStatus.level)
                StatusRow(symbol: "bell.fill",
                          title: "Notifications",
                          subtitle: "Pour te demander de confirmer en un tap",
                          statusSymbol: notificationStatus.symbol,
                          statusText: notificationStatus.text,
                          level: notificationStatus.level)
                StatusRow(symbol: "arrow.triangle.2.circlepath",
                          title: "Actualisation en arrière-plan",
                          subtitle: "Pour rattraper ce qui s'est passé écran éteint",
                          statusSymbol: backgroundStatus.symbol,
                          statusText: backgroundStatus.text,
                          level: backgroundStatus.level)
                StatusRow(symbol: "battery.50percent",
                          title: "Mode économie d'énergie",
                          subtitle: "Quand il est actif, la détection peut avoir quelques minutes de retard",
                          statusSymbol: capabilities.isLowPowerMode ? "info.circle" : "checkmark",
                          statusText: capabilities.isLowPowerMode ? "Actif" : "Inactif",
                          level: capabilities.isLowPowerMode ? .warn : .neutral,
                          showsSeparator: false)
            }
            Text("Tout reste sur ton tel. Pas de compte, pas de serveur.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var locationStatus: StatusInfo {
        switch capabilities.location {
        case .always: return StatusInfo(symbol: "checkmark", text: "Toujours", level: .ok)
        case .whenInUse: return StatusInfo(symbol: "exclamationmark.triangle.fill", text: "App ouverte", level: .error)
        case .denied: return StatusInfo(symbol: "exclamationmark.triangle.fill", text: "Refusée", level: .error)
        case .restricted: return StatusInfo(symbol: "exclamationmark.triangle.fill", text: "Restreinte", level: .error)
        case .notDetermined: return StatusInfo(symbol: "info.circle", text: "À demander", level: .warn)
        }
    }

    private var preciseStatus: StatusInfo {
        guard let precise = capabilities.hasPreciseLocation else {
            return StatusInfo(symbol: "info.circle", text: "Inconnue", level: .neutral)
        }
        if precise { return StatusInfo(symbol: "checkmark", text: "Activée", level: .ok) }
        return StatusInfo(symbol: "info.circle", text: "Approximative", level: .warn)
    }

    private var notificationStatus: StatusInfo {
        switch capabilities.notifications {
        case .allowed: return StatusInfo(symbol: "checkmark", text: "Autorisées", level: .ok)
        case .provisional: return StatusInfo(symbol: "info.circle", text: "En silence", level: .warn)
        case .denied: return StatusInfo(symbol: "exclamationmark.triangle.fill", text: "Refusées", level: .error)
        case .notDetermined: return StatusInfo(symbol: "info.circle", text: "À demander", level: .warn)
        }
    }

    private var backgroundStatus: StatusInfo {
        switch capabilities.backgroundRefresh {
        case .available: return StatusInfo(symbol: "checkmark", text: "Activée", level: .ok)
        case .denied: return StatusInfo(symbol: "info.circle", text: "Désactivée", level: .warn)
        case .restricted: return StatusInfo(symbol: "exclamationmark.triangle.fill", text: "Restreinte", level: .error)
        }
    }

    private var locationBannerKind: PLTBannerKind {
        switch capabilities.location {
        case .denied, .restricted: return .error
        case .whenInUse, .notDetermined, .always: return .warning
        }
    }

    private var locationBannerTitle: String {
        switch capabilities.location {
        case .whenInUse: return "Je te vois seulement quand l'app est ouverte"
        case .denied: return "La localisation est refusée"
        case .restricted: return "La localisation est bloquée sur cet iPhone"
        case .notDetermined: return "Je n'ai pas encore demandé la localisation"
        case .always: return ""
        }
    }

    private var locationBannerMessage: String {
        switch capabilities.location {
        case .whenInUse:
            return "Du coup je rate tes arrivées et tes départs. Passe la localisation sur « Toujours » pour que je note tes heures tout seul."
        case .denied:
            return "Sans localisation, je ne peux pas détecter tes arrivées et tes départs. Tu peux toujours saisir tes sessions à la main."
        case .restricted:
            return "Une restriction de l'iPhone l'empêche. Tu peux toujours saisir tes sessions à la main."
        case .notDetermined:
            return "Tant que tu n'as rien choisi, je ne détecte rien. Tu peux toujours saisir tes sessions à la main."
        case .always:
            return ""
        }
    }

    private func openIOSSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    // MARK: Assistant de configuration

    private var setupSection: some View {
        NavigationLink {
            SetupAssistantView()
        } label: {
            PLTListGroup {
                PLTRow(symbol: "wand.and.stars",
                       title: "Assistant de configuration",
                       subtitle: "Vérifie ce qui manque et règle-le en quelques taps",
                       showsChevron: true,
                       showsSeparator: false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Assistant de configuration")
    }

    // MARK: Diagnostic et instantanés

    private var diagnosticSection: some View {
        PLTListGroup {
            NavigationLink {
                DiagnosticView()
            } label: {
                PLTRow(symbol: "stethoscope",
                       title: "Diagnostic de la détection",
                       subtitle: "Pourquoi une arrivée ou un départ a été raté",
                       showsChevron: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Diagnostic de la détection")
            NavigationLink {
                InstantanesView()
            } label: {
                PLTRow(symbol: "clock.arrow.circlepath",
                       title: "Instantanés",
                       subtitle: "Revenir à un état précédent de tes données",
                       showsChevron: true,
                       showsSeparator: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Instantanés")
        }
    }

    // MARK: Fonctionnalités

    private var featuresSection: some View {
        let counts = ModuleCatalog.counts(enabled: modules.enabledIDs)
        return NavigationLink {
            FonctionnalitesView()
        } label: {
            PLTListGroup {
                PLTRow(symbol: "square.grid.2x2",
                       title: "Fonctionnalités",
                       subtitle: "Active seulement ce qui te sert : planning, paie, congés...",
                       value: "\(counts.active) sur \(counts.total)",
                       showsChevron: true,
                       showsSeparator: false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Fonctionnalités, \(counts.active) actives sur \(counts.total)")
    }

    // MARK: Emploi (module optionnel)

    private var employmentSection: some View {
        NavigationLink {
            EmploiView()
        } label: {
            PLTListGroup {
                PLTRow(symbol: "briefcase",
                       title: "Emploi",
                       subtitle: "Ton employeur, ton contrat et sa fin",
                       showsChevron: true,
                       showsSeparator: false)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Emploi")
    }

    // MARK: Apparence

    private var themeBinding: Binding<ThemeChoice> {
        Binding<ThemeChoice>(get: { settings.themeChoice }, set: { settings.themeChoice = $0 })
    }

    private var densityBinding: Binding<Density> {
        Binding<Density>(get: { settings.density }, set: { settings.density = $0 })
    }

    private var reduceBinding: Binding<Bool> {
        Binding<Bool>(get: { settings.reduceAnimations }, set: { settings.reduceAnimations = $0 })
    }

    private var currencyBinding: Binding<String> {
        Binding<String>(get: { settings.currencyCode }, set: { settings.currencyCode = $0 })
    }

    private var baseBinding: Binding<CalculationBase> {
        Binding<CalculationBase>(get: { settings.calculationBase }, set: { settings.calculationBase = $0 })
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Apparence")
            PLTCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Thème")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                    Picker("Thème", selection: themeBinding) {
                        ForEach(ThemeChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Auto suit le réglage de ton iPhone.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Densité")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                    Picker("Densité", selection: densityBinding) {
                        ForEach(Density.allCases) { d in
                            Text(d.title).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Toggle("Réduire les animations", isOn: reduceBinding)
                    .font(.body)
                    .frame(minHeight: 44)
            }
            Text("La taille du texte suit celle de ton iPhone, partout.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Préférences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Préférences")
            PLTCard {
                HStack {
                    Text("Devise")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Devise", selection: currencyBinding) {
                        ForEach(Currency.all) { c in
                            Text("\(c.name) (\(c.symbol))").tag(c.code)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 44)
                HStack {
                    Text("Exemple")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                    Spacer(minLength: Theme.Spacing.s)
                    Text(settings.formatMoney(1234.5))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                }
                .accessibilityElement(children: .combine)
                HStack {
                    Text("Base de calcul")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Base de calcul", selection: baseBinding) {
                        ForEach(CalculationBase.allCases) { b in
                            Text(b.title).tag(b)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 44)
                Button("Comment ça marche ?") { showBaseInfo = true }
                    .font(.subheadline)
                    .frame(minHeight: 44, alignment: .leading)
            }
            Text("Ce qui compte pour tes stats et ton contrat. L'heure exacte reste toujours gardée.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    // MARK: Données

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Tes données")
            if let message = dataError {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: message)
            }
            PLTListGroup {
                if let url = exportURL {
                    ShareLink(item: url) {
                        PLTRow(symbol: "square.and.arrow.up",
                               title: "Exporter en JSON",
                               subtitle: "\(places.count) lieux et \(sessions.count) sessions dans un seul fichier")
                    }
                    .buttonStyle(.plain)
                } else {
                    PLTRow(symbol: "square.and.arrow.up",
                           tone: .neutral,
                           title: "Exporter en JSON",
                           subtitle: "Le fichier n'est pas prêt")
                }
                PLTRow(symbol: "trash.fill",
                       tone: .danger,
                       title: "Tout supprimer",
                       subtitle: "Lieux et sessions. Avec double confirmation.",
                       showsChevron: true,
                       showsSeparator: false,
                       action: { showDeleteAll = true })
            }
            Text("Le fichier est lisible par n'importe quel outil. Rien n'est envoyé nulle part.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func prepareExport() {
        let document: ExportDocument = DataExport.document(places: places, sessions: sessions)
        do {
            exportURL = try DataExport.writeTemporaryFile(document)
        } catch {
            exportURL = nil
            dataError = "Je n'ai pas réussi à préparer l'export."
        }
    }

    private func deleteEverything() {
        do {
            try context.delete(model: WorkSession.self)
            try context.delete(model: Place.self)
            try context.save()
            geofence.discovery.clearHistory()
            dataError = nil
            prepareExport()
        } catch {
            dataError = "La suppression a échoué. Tes données sont restées comme avant."
        }
    }

    // MARK: Réinitialisation et à propos

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Button("Réinitialiser les réglages") { showResetConfirm = true }
                .buttonStyle(.pltSecondary)
            Text("Réinitialiser remet les réglages d'origine sans toucher à tes données.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var versionText: String {
        let info: [String: Any] = Bundle.main.infoDictionary ?? [:]
        let short: String = (info["CFBundleShortVersionString"] as? String) ?? "?"
        let build: String = (info["CFBundleVersion"] as? String) ?? "?"
        return "\(short) (\(build))"
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "À propos")
            PLTListGroup {
                PLTRow(symbol: "info.circle",
                       tone: .neutral,
                       title: "Version",
                       value: versionText)
                PLTRow(symbol: "lock.shield.fill",
                       title: "100\u{00A0}% local",
                       subtitle: "Pas de compte, pas de serveur. Tes données restent sur ton tel.",
                       showsSeparator: false)
            }
        }
    }
}

/// Niveau d'un statut : ok (vert), warn (ambre), error (rouge), neutral (gris).
enum StatusLevel {
    case ok
    case warn
    case error
    case neutral
}

struct StatusInfo {
    let symbol: String
    let text: String
    let level: StatusLevel
}

/// Pastille de statut : icône + libellé court sur une ligne, comme `status--ok/warn/error` de la maquette.
struct StatusPill: View {
    @Environment(\.palette) private var palette
    let symbol: String
    let text: String
    let level: StatusLevel

    private var color: Color {
        switch level {
        case .ok: return palette.success
        case .warn: return palette.warning
        case .error: return palette.danger
        case .neutral: return palette.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .fixedSize()
    }
}

/// Ligne de statut : tuile d'icône, titre, sous-titre, pastille à droite.
struct StatusRow: View {
    @Environment(\.palette) private var palette
    let symbol: String
    let title: String
    let subtitle: String
    let statusSymbol: String
    let statusText: String
    let level: StatusLevel
    let showsSeparator: Bool

    init(symbol: String, title: String, subtitle: String, statusSymbol: String, statusText: String,
         level: StatusLevel, showsSeparator: Bool = true) {
        self.symbol = symbol
        self.title = title
        self.subtitle = subtitle
        self.statusSymbol = statusSymbol
        self.statusText = statusText
        self.level = level
        self.showsSeparator = showsSeparator
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 32, height: 32)
                .background(palette.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.xs)
            StatusPill(symbol: statusSymbol, text: statusText, level: level)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                Rectangle()
                    .fill(palette.separator)
                    .frame(height: 0.5)
                    .padding(.leading, Theme.Spacing.m)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
