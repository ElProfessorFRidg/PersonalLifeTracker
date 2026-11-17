import SwiftUI

/// Textes courts du parcours d'import : jours, heures, pluriels.
enum PlanningImportFormat {
    private static func formatter(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = Calendar.current
        f.timeZone = Calendar.current.timeZone
        f.dateFormat = pattern
        return f
    }

    /// "Lun. 23 nov."
    static func dayLabel(_ date: Date) -> String {
        let text = formatter("EEE d MMM").string(from: date)
        guard let first = text.first else { return text }
        return String(first).uppercased() + String(text.dropFirst())
    }

    /// "23 nov."
    static func shortDay(_ date: Date) -> String {
        return formatter("d MMM").string(from: date)
    }

    /// Pour VoiceOver : "lundi 23 novembre".
    static func spokenDay(_ date: Date) -> String {
        return Formatting.dayTitle(date, calendar: Calendar.current)
    }

    /// "18:00 à 21:00", "22:00 à 06:00 le lendemain", "Heures à saisir".
    static func timeLabel(start: Int?, end: Int?) -> String {
        guard let s = start, let e = end else { return "Heures à saisir" }
        let from = Formatting.clock(minutesFromMidnight: s % 1440)
        let to = Formatting.clock(minutesFromMidnight: e % 1440)
        if e > 1440 || (e == 1440 && s > 0 && false) {
            return "\(from) à \(to) le lendemain"
        }
        return "\(from) à \(to)"
    }

    static func shiftCount(_ n: Int) -> String {
        return n == 1 ? "1 créneau" : "\(n) créneaux"
    }

    static func ordinal(_ n: Int) -> String {
        return n == 1 ? "1re" : "\(n)e"
    }
}

/// Un créneau lu : jour, heures, fiabilité, raison du doute et actions (C'est bon, Corriger, Retirer).
struct PlanningDraftRow: View {
    @Environment(\.palette) private var palette
    let draft: PlanningShiftDraft
    let onConfirmAsIs: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    private var level: ReliabilityLevel {
        switch draft.level {
        case .high: return .high
        case .mid: return .mid
        case .low: return .low
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: ActivityType.work.symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PLTTone.work.color(palette))
                    .frame(width: 36, height: 36)
                    .background(PLTTone.work.soft(palette),
                                in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(PlanningImportFormat.dayLabel(draft.day))
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Text("\(ActivityType.work.title) \(PlanningImportFormat.timeLabel(start: draft.startMinutes, end: draft.endMinutes))")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer(minLength: Theme.Spacing.s)
                reliability
            }
            .accessibilityElement(children: .combine)

            if let reason = draft.reason, !draft.isResolved {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }

            HStack(spacing: Theme.Spacing.s) {
                if draft.canConfirmAsIs {
                    Button("C'est bon", action: onConfirmAsIs)
                        .buttonStyle(.pltSecondary)
                        .accessibilityLabel("C'est bon pour le \(PlanningImportFormat.spokenDay(draft.day))")
                }
                Button("Corriger", action: onEdit)
                    .buttonStyle(.pltSecondary)
                    .accessibilityLabel("Corriger le \(PlanningImportFormat.spokenDay(draft.day))")
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(palette.danger)
                        .frame(width: 44, height: 44)
                        .background(palette.dangerSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retirer le \(PlanningImportFormat.spokenDay(draft.day))")
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var reliability: some View {
        if draft.wasEdited {
            PLTChip("Corrigé par toi", kind: .neutral)
        } else if draft.isResolved {
            PLTChip("Vérifié", kind: .neutral)
        } else if draft.hasTimes {
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                ReliabilityBadge(level)
                Text("\(ScheduleConfidence.percent(draft.confidence)) %")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
        } else {
            ReliabilityBadge(.low)
        }
    }
}

/// Éditeur en ligne : début et fin au format 09:00.
struct PlanningShiftEditor: View {
    @Environment(\.palette) private var palette
    @Binding var startText: String
    @Binding var endText: String
    let error: String?
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.m) {
                field(label: "Début", text: $startText)
                field(label: "Fin", text: $endText)
            }
            Text(error ?? "Heure au format 09:00. Si la fin est avant le début, elle tombe le lendemain.")
                .font(.footnote)
                .foregroundStyle(error == nil ? palette.textSecondary : palette.danger)
            HStack(spacing: Theme.Spacing.s) {
                Button("Enregistrer", action: onSave)
                    .buttonStyle(.pltPrimary)
                Button("Annuler", action: onCancel)
                    .buttonStyle(.pltSecondary)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.surfaceRaised)
    }

    private func field(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textSecondary)
            TextField("09:00", text: text)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospacedDigit())
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, Theme.Spacing.s + Theme.Spacing.xs)
                .frame(minHeight: 44)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .stroke(palette.separator, lineWidth: 1)
                )
                .accessibilityLabel(label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
