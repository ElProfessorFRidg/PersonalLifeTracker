import SwiftUI

/// Boutons posés sur la carte "Maintenant" (fond d'accent) : fond inversé pour garder le contraste.
struct NowCardButtonStyle: ButtonStyle {
    @Environment(\.palette) private var palette
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(prominent ? palette.accent : palette.accentOn)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Theme.Spacing.m)
            .background(prominent ? palette.accentOn : palette.accentOn.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

/// Carte "Maintenant" : une seule chose à faire. La décision vient de DaySummary.decideNow.
struct AccueilNowCard: View {
    let decision: NowDecision
    let running: WorkSession?
    let doubtSession: WorkSession?
    let onStop: () -> Void
    let onChooseDoubt: () -> Void

    var body: some View {
        PLTCard(isNow: true) {
            Text("Maintenant")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            switch decision {
            case .confirmRunning:
                runningContent
            case .chooseDoubt:
                doubtContent
            case .firstDay:
                textBlock(title: "On commence quand tu veux.",
                          message: "Appuie sur Démarrer quand tu arrives au taf ou en cours. Je compte tes heures pour toi, et rien ne sort de ton tel.")
            case .calm:
                textBlock(title: "Rien à faire, profites-en.",
                          message: "Je te préviens s'il y a un truc à confirmer.")
            }
        }
    }

    private func textBlock(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.body)
        }
    }

    @ViewBuilder
    private var runningContent: some View {
        if let session = running {
            let start: String = Formatting.clock(session.startDate, calendar: session.calendar)
            textBlock(title: "\(session.activity.title) depuis \(start), t'as fini ?",
                      message: "Arrête la session quand t'as terminé, ou corrige l'heure si elle est fausse.")
            HStack(spacing: Theme.Spacing.s) {
                Button(action: onStop) {
                    Text("Arrêter")
                }
                .buttonStyle(NowCardButtonStyle(prominent: true))
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    Text("Corriger l'heure")
                }
                .buttonStyle(NowCardButtonStyle(prominent: false))
            }
        } else {
            textBlock(title: "Rien à faire, profites-en.",
                      message: "Je te préviens s'il y a un truc à confirmer.")
        }
    }

    @ViewBuilder
    private var doubtContent: some View {
        if let session = doubtSession, let end = session.endDate {
            let cal: Calendar = session.calendar
            let start: String = Formatting.clock(session.startDate, calendar: cal)
            let stop: String = Formatting.clock(end, calendar: cal)
            textBlock(title: "Il me faut une heure pleine.",
                      message: "Ta session de \(session.activity.title) de \(start) à \(stop) tombe entre :15 et :45. Choisis l'heure à garder.")
            Button(action: onChooseDoubt) {
                Text("Choisir l'heure")
            }
            .buttonStyle(NowCardButtonStyle(prominent: true))
        } else {
            textBlock(title: "Rien à faire, profites-en.",
                      message: "Je te préviens s'il y a un truc à confirmer.")
        }
    }
}

/// Session en cours : chrono en direct (le parent fournit `now` via TimelineView), lieu, heure de début.
struct AccueilRunningCard: View {
    @Environment(\.palette) private var palette
    let session: WorkSession
    let now: Date
    let onStop: () -> Void

    var body: some View {
        let cal: Calendar = session.calendar
        let start: String = Formatting.clock(session.startDate, calendar: cal)
        let seconds: Int = session.exactSeconds(now: now)
        let placeName: String = session.place?.name ?? "Sans lieu"
        let origin: String = session.source == .manual ? "démarrée à la main" : "détectée"
        return PLTCard {
            HStack {
                PLTChip("\(session.activity.title) en cours", kind: session.activity.chipKind)
                Spacer(minLength: 0)
            }
            Text(placeName)
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            Text(Formatting.timer(seconds: seconds))
                .font(.largeTitle.weight(.semibold).monospacedDigit())
                .foregroundStyle(palette.textPrimary)
                .accessibilityLabel("Durée de la session en cours")
                .accessibilityValue(Formatting.duration(seconds: seconds))
                .accessibilityAddTraits(.updatesFrequently)
            Text("Depuis \(start), \(origin).")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            HStack(spacing: Theme.Spacing.s) {
                Button(action: onStop) {
                    Label("Arrêter", systemImage: "stop.fill")
                }
                .buttonStyle(.pltSecondary)
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    Label("Corriger", systemImage: "pencil")
                }
                .buttonStyle(.pltSecondary)
            }
        }
    }
}
