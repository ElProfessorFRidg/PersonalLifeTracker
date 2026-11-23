import SwiftUI
import SwiftData

extension WorkSession {
    /// Données de liste pour SessionRules (logique pure).
    var listItem: SessionListItem {
        return SessionListItem(id: uid, start: startDate, end: endDate, activity: activity,
                               isConfirmed: isConfirmed, hasUnresolvedDoubt: hasUnresolvedDoubt)
    }
}

/// Textes d'affichage partagés par les écrans Sessions.
enum SessionDisplay {
    /// Durée dans la base retenue. Une session en cours donne "En cours".
    static func durationText(_ session: WorkSession, base: CalculationBase, now: Date) -> String {
        guard let end = session.endDate else { return "En cours" }
        let result = SessionDurations.retained(base: base, start: session.startDate, end: end,
                                               chosenStart: session.chosenStart, chosenEnd: session.chosenEnd,
                                               calendar: session.calendar)
        return Formatting.duration(seconds: result.seconds)
    }

    /// "08:05 à 12:02" ou "depuis 17:56".
    static func rangeText(_ session: WorkSession) -> String {
        let cal = session.calendar
        let start = Formatting.clock(session.startDate, calendar: cal)
        if let end = session.endDate {
            return "\(start) à \(Formatting.clock(end, calendar: cal))"
        }
        return "depuis \(start)"
    }

    static func title(_ session: WorkSession) -> String {
        if let place = session.place { return place.name }
        return session.activity.title
    }
}

/// Écran `sessions` : historique groupé par jour. Poussé dans une NavigationStack existante.
struct SessionsView: View {
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Query(sort: \WorkSession.startDate, order: .reverse) private var sessions: [WorkSession]

    @State private var filter: SessionFilter = .all
    @State private var showAdd: Bool = false

    private var items: [SessionListItem] {
        return sessions.map { (s: WorkSession) -> SessionListItem in s.listItem }
    }

    private var toConfirmCount: Int {
        return items.filter { SessionRules.needsConfirmation($0) }.count
    }

    private func chipTitle(_ f: SessionFilter) -> String {
        if f == .toConfirm { return "À confirmer (\(toConfirmCount))" }
        return f.title
    }

    var body: some View {
        PLTScreen(title: "Sessions") {
            if sessions.isEmpty {
                PLTCard {
                    PLTEmptyState(symbol: "clock",
                                  title: "Aucune session pour l'instant.",
                                  message: "Dès que t'arrives à un de tes lieux, ta session apparaît ici. Tu peux aussi en ajouter une à la main.",
                                  actionTitle: "Ajouter une session",
                                  action: { showAdd = true })
                }
            } else {
                filterBar
                listContent
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAdd = true
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Ajouter une session")
            }
        }
        .sheet(isPresented: $showAdd) {
            SessionAjoutView()
        }
    }

    // MARK: Filtres

    private var segmentFilters: [SessionFilter] {
        let list: [SessionFilter] = [.all, .work, .education, .shopping]
        return list
    }

    private var visibleCount: Int {
        return SessionRules.filter(items, by: filter).count
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Picker("Filtrer par type", selection: $filter) {
                ForEach(segmentFilters) { (f: SessionFilter) in
                    Text(f.title).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            HStack {
                Button {
                    filter = (filter == .toConfirm) ? .all : .toConfirm
                } label: {
                    let selected: Bool = (filter == .toConfirm)
                    Text(chipTitle(.toConfirm))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selected ? palette.accent : palette.textSecondary)
                        .padding(.horizontal, Theme.Spacing.m)
                        .frame(minHeight: 44)
                        .background(selected ? palette.accentSoft : palette.surface, in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(selected ? palette.accent : palette.textSecondary,
                                                   style: StrokeStyle(lineWidth: 1, dash: selected ? [] : [3, 2]))
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(filter == .toConfirm ? AccessibilityTraits.isSelected : AccessibilityTraits())
                Spacer(minLength: Theme.Spacing.s)
                Text(visibleCount > 1 ? "\(visibleCount) sessions" : "\(visibleCount) session")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    // MARK: Liste

    @ViewBuilder
    private var listContent: some View {
        let visible = SessionRules.filter(items, by: filter)
        if visible.isEmpty {
            PLTEmptyState(symbol: "line.3.horizontal.decrease.circle",
                          title: filter == .toConfirm ? "Rien à confirmer." : "Rien dans ce filtre.",
                          message: filter == .toConfirm ? "Toutes tes sessions sont en règle, profites-en." : "Aucune session de ce type pour l'instant.",
                          actionTitle: "Tout afficher",
                          action: { filter = .all })
        } else {
            let calendar = Calendar.current
            let now = Date()
            let groups = SessionRules.groupByDay(visible, calendar: calendar)
            let lookup = Dictionary(sessions.map { ($0.uid, $0) }, uniquingKeysWith: { (first: WorkSession, _: WorkSession) -> WorkSession in first })
            ForEach(groups, id: \.day) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    PLTSectionHeader(title: SessionRules.dayLabel(day: group.day, now: now, calendar: calendar))
                    PLTListGroup {
                        ForEach(group.items, id: \.id) { entry in
                            if let session = lookup[entry.id] {
                                NavigationLink {
                                    SessionDetailView(session: session)
                                } label: {
                                    SessionRowView(session: session, base: settings.calculationBase, now: now)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            Text("Les courses sont notées mais jamais comptées dans tes heures.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }
}

/// Une ligne de l'historique : lieu, horaires, type, "À confirmer" et durée.
private struct SessionRowView: View {
    @Environment(\.palette) private var palette
    let session: WorkSession
    let base: CalculationBase
    let now: Date

    var body: some View {
        let needs = SessionRules.needsConfirmation(session.listItem)
        let duration = SessionDisplay.durationText(session, base: base, now: now)
        return HStack(spacing: Theme.Spacing.m) {
            Image(systemName: session.activity.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(session.activity.tone.color(palette))
                .frame(width: 36, height: 36)
                .background(session.activity.tone.soft(palette),
                            in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(session.activity.title)
                    .font(.body)
                    .foregroundStyle(palette.textPrimary)
                Text(subtitleText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
                if needs {
                    PLTChip("À confirmer", kind: .doubt)
                        .padding(.top, Theme.Spacing.xxs)
                }
            }
            Spacer(minLength: Theme.Spacing.s)
            if session.isOngoing {
                PLTChip("En cours", kind: session.activity.chipKind)
            } else {
                Text(duration)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(palette.separator)
                .frame(height: 0.5)
                .padding(.leading, Theme.Spacing.m)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(needs: needs, duration: duration))
    }

    /// "Supérette du Canal, 17:56 à 20:38" ou "Marché du Canal, 12:20 à 12:45. Pas compté."
    private var subtitleText: String {
        let range: String = SessionDisplay.rangeText(session)
        let base: String
        if let place = session.place {
            base = "\(place.name), \(range)"
        } else {
            base = range
        }
        return session.activity == .shopping ? base + ". Pas compté." : base
    }

    private func accessibilityText(needs: Bool, duration: String) -> String {
        var text = "\(session.activity.title), \(SessionDisplay.title(session)), \(SessionDisplay.rangeText(session)), \(duration)"
        if needs { text += ", à confirmer" }
        return text
    }
}
