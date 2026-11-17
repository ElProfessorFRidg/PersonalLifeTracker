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
                    Text("L'heure exacte reste gardée et affichée à côté. Tu choisis seulement l'heure pleine qui compte pour tes totaux.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
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
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTChip("Zone de doute", kind: .doubt)
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("Ça tombe entre :15 et :45, trop loin d'une heure pleine pour que je devine. C'est toi qui choisis.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            ForEach(options, id: \.hour) { (option: DoubtOption) in
                optionRow(kind: kind, option: option, selected: picked == option.hour)
            }
            Text("Exact : \(SessionRules.clockWithSeconds(exact, calendar: cal)), gardé tel quel.")
                .font(.footnote.monospacedDigit())
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func relationText(kind: SessionBoundKind, option: DoubtOption) -> String {
        let subject = (kind == .start) ? "Tu arrives" : "Tu pars"
        let side = option.hourIsBeforeExact ? "après" : "avant"
        return "\(subject) \(option.minutesApart) min \(side)"
    }

    private func optionRow(kind: SessionBoundKind, option: DoubtOption, selected: Bool) -> some View {
        let cal = session.calendar
        let clock = Formatting.clock(option.hour, calendar: cal)
        let position = option.hourIsBeforeExact ? "heure pleine avant" : "heure pleine après"
        let duration = Formatting.duration(seconds: option.resultingSeconds)
        return Button {
            switch kind {
            case .start: pickedStart = option.hour
            case .end: pickedEnd = option.hour
            }
        } label: {
            HStack(spacing: Theme.Spacing.m) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? palette.accent : palette.textTertiary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("\(clock), \(position)")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(palette.textPrimary)
                    Text(relationText(kind: kind, option: option))
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                Text(duration)
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(selected ? palette.accentSoft : palette.surface,
                        in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(selected ? palette.accent : Color.clear, lineWidth: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(clock), \(position), \(relationText(kind: kind, option: option)), durée \(duration)")
        .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
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
