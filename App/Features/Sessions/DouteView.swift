import SwiftUI
import SwiftData

/// Écran `doute` (zone de doute 13.1). Présenté en feuille : il porte sa propre NavigationStack.
/// Règle : :00 à :14 arrondi vers le bas, :46 à :59 vers le haut, :15 à :45 l'utilisateur choisit.
/// Le choix va dans chosenStart / chosenEnd, l'heure exacte n'est jamais touchée.
struct DouteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context

    let session: WorkSession

    @State private var pickedStart: Date?
    @State private var pickedEnd: Date?

    init(session: WorkSession) {
        self.session = session
        _pickedStart = State(initialValue: session.chosenStart)
        _pickedEnd = State(initialValue: session.chosenEnd)
    }

    private var endForCalculation: Date {
        return session.effectiveEnd(now: Date())
    }

    private var startOptions: [DoubtOption] {
        return SessionRules.doubtOptions(bound: .start, start: session.startDate, end: endForCalculation,
                                         chosenStart: pickedStart, chosenEnd: pickedEnd, calendar: session.calendar)
    }

    private var endOptions: [DoubtOption] {
        if session.endDate == nil { return [] }
        return SessionRules.doubtOptions(bound: .end, start: session.startDate, end: endForCalculation,
                                         chosenStart: pickedStart, chosenEnd: pickedEnd, calendar: session.calendar)
    }

    private var canSave: Bool {
        let startOK = startOptions.isEmpty || pickedStart != nil
        let endOK = endOptions.isEmpty || pickedEnd != nil
        return startOK && endOK
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Choisir l'heure") {
                if startOptions.isEmpty && endOptions.isEmpty {
                    PLTEmptyState(symbol: "checkmark.circle",
                                  title: "Rien à choisir ici.",
                                  message: "Les heures de cette session tombent assez près d'une heure pleine, je m'en occupe tout seul.")
                } else {
                    if !startOptions.isEmpty {
                        boundSection(kind: .start, options: startOptions, exact: session.startDate, picked: pickedStart)
                    }
                    if !endOptions.isEmpty, let end = session.endDate {
                        boundSection(kind: .end, options: endOptions, exact: end, picked: pickedEnd)
                    }
                    PLTCard {
                        HStack {
                            Text("L'heure exacte reste gardée")
                                .font(.headline)
                                .foregroundStyle(palette.textPrimary)
                            Spacer(minLength: Theme.Spacing.s)
                            Image(systemName: "lock")
                                .foregroundStyle(palette.textSecondary)
                                .accessibilityHidden(true)
                        }
                        Text("L'heure exacte reste gardée et affichée à côté. Tu choisis seulement l'heure pleine qui compte pour tes totaux.")
                            .font(.subheadline)
                            .foregroundStyle(palette.textSecondary)
                    }
                    Button("Enregistrer mon choix") { save() }
                        .buttonStyle(.pltPrimary)
                        .disabled(!canSave)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    // MARK: Sections

    private func hourLabel(_ date: Date) -> String {
        let h = session.calendar.component(.hour, from: date)
        return h == 0 ? "minuit" : "\(h) h"
    }

    private func boundSection(kind: SessionBoundKind, options: [DoubtOption], exact: Date, picked: Date?) -> some View {
        let cal = session.calendar
        let exactClock = Formatting.clock(exact, calendar: cal)
        let first = options[0]
        let second = options[options.count - 1]
        let verb = (kind == .start) ? "Arrivée" : "Départ"
        let title = "\(verb) à \(exactClock) : \(hourLabel(first.hour)) ou \(hourLabel(second.hour)) ?"
        let placeTitle: String = session.place.map { "\(session.activity.title), \($0.name)" } ?? session.activity.title
        return VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            PLTCard(isNow: true) {
                Text("ZONE DE DOUTE")
                    .font(.footnote.weight(.semibold))
                    .tracking(0.6)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text("Ça tombe entre :15 et :45, trop loin d'une heure pleine pour que je devine. C'est toi qui choisis.")
                    .font(.subheadline)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                PLTSectionHeader(title: placeTitle)
                PLTListGroup {
                    ForEach(options, id: \.hour) { (option: DoubtOption) in
                        optionRow(kind: kind, option: option, selected: picked == option.hour,
                                  isLast: option.hour == options[options.count - 1].hour)
                    }
                }
                Text("Exact : \(SessionRules.clockWithSeconds(exact, calendar: cal)), gardé tel quel.")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func relationText(kind: SessionBoundKind, option: DoubtOption) -> String {
        let subject = (kind == .start) ? "Tu arrives" : "Tu pars"
        let side = option.hourIsBeforeExact ? "après" : "avant"
        return "\(subject) \(option.minutesApart) min \(side)"
    }

    private func optionRow(kind: SessionBoundKind, option: DoubtOption, selected: Bool, isLast: Bool) -> some View {
        let cal = session.calendar
        let clock = Formatting.clock(option.hour, calendar: cal)
        let position = option.hourIsBeforeExact ? "heure pleine avant" : "heure pleine après"
        let duration = Formatting.duration(seconds: option.resultingSeconds)
        let relation = relationText(kind: kind, option: option)
        return PLTRadioRow(title: "\(clock), \(position)",
                           subtitle: relation,
                           value: duration,
                           selected: selected,
                           showsSeparator: !isLast,
                           accessibilityText: "\(clock), \(position), \(relation), durée \(duration)",
                           action: {
                               switch kind {
                               case .start: pickedStart = option.hour
                               case .end: pickedEnd = option.hour
                               }
                           })
    }

    // MARK: Enregistrement

    private func save() {
        if !startOptions.isEmpty {
            session.chosenStart = pickedStart
        }
        if !endOptions.isEmpty {
            session.chosenEnd = pickedEnd
        }
        try? context.save()
        dismiss()
    }
}
