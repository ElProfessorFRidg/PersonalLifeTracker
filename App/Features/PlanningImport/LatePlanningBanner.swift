import SwiftUI

/// Bandeau du rappel "planning de la semaine prochaine pas encore là" (section 70).
/// À placer par les écrans qui le veulent, à partir d'un `LatePlanningReminder` donné par `LatePlanningRules.decide`.
/// Ton doux : jamais culpabilisant, quatre sorties claires.
struct LatePlanningBanner: View {
    @Environment(\.palette) private var palette
    let reminder: LatePlanningReminder
    let onAction: (LatePlanningAction) -> Void

    init(reminder: LatePlanningReminder, onAction: @escaping (LatePlanningAction) -> Void) {
        self.reminder = reminder
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top, spacing: Theme.Spacing.s + Theme.Spacing.xs) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(palette.accent)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(reminder.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                    Text(reminder.message)
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            Button(LatePlanningAction.importPhoto.title) {
                onAction(.importPhoto)
            }
            .buttonStyle(.pltPrimary)

            ForEach(secondaryActions, id: \.rawValue) { action in
                Button(action.title) {
                    onAction(action)
                }
                .font(.subheadline)
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .accessibilityLabel(action.title)
            }
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.accentSoft, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }

    private var secondaryActions: [LatePlanningAction] {
        return reminder.actions.filter { $0 != .importPhoto }
    }
}
