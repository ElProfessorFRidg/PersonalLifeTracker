import SwiftUI
import SwiftData

/// Feuille d'ajout ou de modification d'un contrat. `draft` sert au renouvellement et au passage en CDI (infos reprises).
struct ContratEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Place.name) private var places: [Place]

    let employer: Employer
    let contract: Contract?

    @State private var kind: ContractKind
    @State private var startDate: Date
    @State private var hasEnd: Bool
    @State private var endDate: Date
    @State private var hoursText: String
    @State private var rateText: String
    @State private var hasTrial: Bool
    @State private var trialEnd: Date
    @State private var placeUIDs: Set<UUID>
    @State private var saveFailed: Bool = false
    @State private var showDelete: Bool = false

    init(employer: Employer, contract: Contract?, draft: ContractDraft?) {
        self.employer = employer
        self.contract = contract
        let calendar: Calendar = Calendar.current
        let today: Date = calendar.startOfDay(for: Date())
        var k: ContractKind = .cdi
        var start: Date = today
        var end: Date? = nil
        var hours: Double = 0
        var rate: Double? = nil
        var trial: Date? = nil
        var uids: Set<UUID> = []
        if let c = contract {
            k = c.kind
            start = c.startDate
            end = c.endDate
            hours = c.weeklyHours
            rate = c.hourlyGrossRate
            trial = c.trialEndDate
            uids = Set(c.placeUIDs)
        } else if let d = draft {
            k = d.kind
            start = d.startDate
            end = d.endDate
            hours = d.weeklyHours
            rate = d.hourlyGrossRate
            // Le contrat précédent a les mêmes lieux : on les reprend.
            let previous: Contract? = employer.contracts.sorted { (a: Contract, b: Contract) -> Bool in
                return a.startDate > b.startDate
            }.first
            if let p = previous { uids = Set(p.placeUIDs) }
        }
        _kind = State(initialValue: k)
        _startDate = State(initialValue: start)
        _hasEnd = State(initialValue: end != nil)
        _endDate = State(initialValue: end ?? (calendar.date(byAdding: .day, value: 90, to: start) ?? start))
        _hoursText = State(initialValue: hours > 0 ? EmploiFormat.plain(hours) : "")
        _rateText = State(initialValue: rate != nil ? EmploiFormat.plain(rate ?? 0) : "")
        _hasTrial = State(initialValue: trial != nil)
        _trialEnd = State(initialValue: trial ?? (calendar.date(byAdding: .day, value: 14, to: start) ?? start))
        _placeUIDs = State(initialValue: uids)
    }

    // MARK: Valeurs saisies

    private var hours: Double { return EmploiFormat.parseDecimal(hoursText) ?? 0 }
    private var rate: Double? { return EmploiFormat.parseDecimal(rateText) }
    private var rateTextUnreadable: Bool {
        let trimmed: String = rateText.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && rate == nil
    }

    private var issues: [ContractIssue] {
        return ContractRules.validate(kind: kind,
                                      start: startDate,
                                      end: hasEnd ? endDate : nil,
                                      weeklyHours: hours,
                                      trialEnd: hasTrial ? trialEnd : nil,
                                      hourlyRate: rate,
                                      calendar: Calendar.current)
    }

    private var canSave: Bool {
        return !ContractRules.hasBlockingIssue(issues) && !rateTextUnreadable
    }

    private var workPlaces: [Place] {
        return places.filter { (p: Place) -> Bool in p.type == .taf }
    }

    // MARK: Corps

    var body: some View {
        NavigationStack {
            PLTScreen(title: contract == nil ? "Nouveau contrat" : "Ton contrat") {
                typeSection
                datesSection
                hoursSection
                trialSection
                placesSection
                issuesSection
                if saveFailed {
                    PLTBanner(kind: .error, title: "Oups, ça a pas marché.", message: "Le contrat n'a pas été enregistré. Réessaie ?")
                }
                Button("Enregistrer") { save() }
                    .buttonStyle(.pltPrimary)
                    .disabled(!canSave)
                if contract != nil {
                    Button("Supprimer ce contrat") { showDelete = true }
                        .buttonStyle(.pltDestructive)
                    Text("À utiliser pour une erreur de saisie. Un contrat fini reste dans ta liste, il n'a pas besoin d'être supprimé.")
                        .font(.footnote)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .confirmationDialog("Supprimer ce contrat ?", isPresented: $showDelete, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) { deleteContract() }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Tes sessions et tes stats ne bougent pas.")
            }
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Type de contrat")
            PLTCard {
                HStack {
                    Text("Type")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Type de contrat", selection: $kind) {
                        ForEach(ContractKind.allCases, id: \.self) { (k: ContractKind) in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Dates")
            PLTCard {
                DatePicker("Début", selection: $startDate, displayedComponents: .date)
                    .font(.body)
                    .frame(minHeight: 44)
                Toggle("Date de fin", isOn: $hasEnd)
                    .font(.body)
                    .frame(minHeight: 44)
                    .tint(palette.accent)
                if hasEnd {
                    DatePicker("Fin", selection: $endDate, displayedComponents: .date)
                        .font(.body)
                        .frame(minHeight: 44)
                }
            }
            Text("Un CDI n'a pas de date de fin. Tu peux en ajouter une plus tard.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Heures et taux")
            PLTCard {
                HStack {
                    Text("Heures par semaine")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    TextField("13", text: $hoursText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                        .frame(maxWidth: 100, minHeight: 44)
                        .accessibilityLabel("Heures par semaine")
                }
                HStack {
                    Text("Taux horaire brut")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    TextField("Facultatif", text: $rateText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .font(.body.monospacedDigit())
                        .frame(maxWidth: 100, minHeight: 44)
                        .accessibilityLabel("Taux horaire brut en \(settings.currency.name)")
                    Text(settings.currency.symbol)
                        .font(.body)
                        .foregroundStyle(palette.textSecondary)
                }
            }
            if rateTextUnreadable {
                Text("Je n'arrive pas à lire ce taux. Mets par exemple 12,02.")
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            } else {
                Text("Le taux est facultatif. Ta fiche de paie fait foi.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var trialSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Période d'essai")
            PLTCard {
                Toggle("J'ai une période d'essai", isOn: $hasTrial)
                    .font(.body)
                    .frame(minHeight: 44)
                    .tint(palette.accent)
                if hasTrial {
                    DatePicker("Fin de l'essai", selection: $trialEnd, displayedComponents: .date)
                        .font(.body)
                        .frame(minHeight: 44)
                }
            }
            Text("Regarde la durée dans ton contrat. Je ne la devine pas.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Où tu travailles")
            if workPlaces.isEmpty {
                PLTCard {
                    Text("Tu n'as pas encore de lieu de type Taf. Ajoute-en un dans l'onglet Lieux, tu pourras le rattacher ici.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(workPlaces) { (place: Place) in
                        PLTRow(symbol: placeUIDs.contains(place.uid) ? "checkmark.circle.fill" : "circle",
                               tone: placeUIDs.contains(place.uid) ? .work : .neutral,
                               title: place.name,
                               subtitle: place.address.isEmpty ? nil : place.address,
                               showsSeparator: place.id != workPlaces.last?.id,
                               action: { togglePlace(place) })
                            .accessibilityValue(placeUIDs.contains(place.uid) ? "Rattaché" : "Pas rattaché")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issuesSection: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(Array(issues.enumerated()), id: \.offset) { item in
                    Text(item.element.message)
                        .font(.footnote)
                        .foregroundStyle(item.element.isBlocking ? palette.danger : palette.textSecondary)
                }
            }
        }
    }

    // MARK: Actions

    private func togglePlace(_ place: Place) {
        if placeUIDs.contains(place.uid) {
            placeUIDs.remove(place.uid)
        } else {
            placeUIDs.insert(place.uid)
        }
    }

    private func save() {
        if !canSave { return }
        let calendar: Calendar = Calendar.current
        let start: Date = calendar.startOfDay(for: startDate)
        let end: Date? = hasEnd ? calendar.startOfDay(for: endDate) : nil
        let trial: Date? = hasTrial ? calendar.startOfDay(for: trialEnd) : nil
        let target: Contract
        if let existing = contract {
            target = existing
        } else {
            let created: Contract = Contract(kind: kind, startDate: start, endDate: end, weeklyHours: hours, employer: nil)
            context.insert(created)
            created.employer = employer
            target = created
        }
        target.kind = kind
        target.startDate = start
        target.endDate = end
        target.weeklyHours = hours
        target.hourlyGrossRate = rate
        target.trialEndDate = trial
        target.placeUIDs = Array(placeUIDs)
        do {
            try context.save()
            dismiss()
        } catch {
            saveFailed = true
        }
    }

    private func deleteContract() {
        guard let existing = contract else { return }
        context.delete(existing)
        do {
            try context.save()
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}
