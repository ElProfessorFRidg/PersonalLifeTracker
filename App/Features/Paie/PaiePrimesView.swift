import SwiftUI
import SwiftData

/// Demande d'ouverture du formulaire de prime (feuille). `premium` = nil pour une nouvelle prime.
struct PaiePremiumFormRequest: Identifiable {
    let id: UUID = UUID()
    let premium: PayPremium?
}

/// Primes et indemnités d'un employeur (section 26). Tout est saisi par toi et marqué comme tel.
/// Rien n'est jamais ajouté sans ta confirmation. Écran poussé depuis PaieView.
struct PaiePrimesView: View {
    let employer: Employer

    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @State private var all: [PayPremium] = []
    @State private var loadFailed: Bool = false
    @State private var saveFailed: Bool = false
    @State private var formRequest: PaiePremiumFormRequest? = nil

    private var employerKey: String { return employer.uid.uuidString }

    private var mine: [PayPremium] {
        return PremiumStore.premiums(for: employerKey, in: all)
    }

    var body: some View {
        PLTScreen(title: "Primes") {
            Text("Ajoute les primes et indemnités de \(employer.name) : panier, transport, 13e mois, objectifs, repas. Je les ajoute à l'estimation avec une ligne chacune, marquée \"saisie par toi\". Ta fiche de paie fait foi.")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            if loadFailed {
                PLTBanner(kind: .error, title: "Je n'ai pas pu relire tes primes",
                          message: "Je ne modifie rien pour ne pas les écraser. Ferme et rouvre l'écran, ou contacte le support si ça continue.")
            }
            if saveFailed {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: "Je n'ai pas réussi à enregistrer la prime. Réessaie ?")
            }
            listSection
            Button("Ajouter une prime") { formRequest = PaiePremiumFormRequest(premium: nil) }
                .buttonStyle(.pltPrimary)
                .disabled(loadFailed)
            Text("Quand ta convention suggère des primes usuelles, je te les montre \"à renseigner\" : je ne les applique jamais sans que tu les saisisses.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
        .onAppear { reload() }
        .sheet(item: $formRequest) { (request: PaiePremiumFormRequest) in
            PaiePrimeFormView(employerKey: employerKey, existing: request.premium,
                              onSave: { (p: PayPremium) in upsert(p) },
                              onDelete: { (id: String) in remove(id) })
        }
    }

    private func reload() {
        let loaded: PremiumLoad = PremiumStore.load(defaults: UserDefaults.standard)
        all = loaded.premiums
        loadFailed = loaded.failed
    }

    private func upsert(_ p: PayPremium) {
        if loadFailed { return }
        let next: [PayPremium] = PremiumStore.upserting(p, in: all)
        if PremiumStore.save(next, defaults: UserDefaults.standard) {
            all = next
            saveFailed = false
        } else {
            saveFailed = true
        }
    }

    private func remove(_ id: String) {
        if loadFailed { return }
        let next: [PayPremium] = PremiumStore.removing(id: id, from: all)
        if PremiumStore.save(next, defaults: UserDefaults.standard) {
            all = next
            saveFailed = false
        } else {
            saveFailed = true
        }
    }

    private var listSection: some View {
        let list: [PayPremium] = mine
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Tes primes")
            if list.isEmpty {
                PLTCard {
                    Text("Aucune prime saisie. Sans prime, l'estimation ne compte que les heures et les majorations.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(0..<list.count, id: \.self) { i in
                        row(list[i], showsSeparator: i < list.count - 1)
                    }
                }
                Text("Touche une prime pour la modifier ou la supprimer.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func row(_ p: PayPremium, showsSeparator: Bool) -> some View {
        var parts: [String] = [p.kind.title, p.frequency.title, p.basis.title]
        if p.frequency.supportsCondition && p.condition != .none { parts.append(p.condition.title.lowercased()) }
        let subtitle: String = parts.joined(separator: ", ") + ". Saisie par toi."
        let value: String
        switch p.amountType {
        case .fixed: value = settings.formatMoney(PayMath.units(fromCents: p.amountCents))
        case .percentOfGross: value = PaieRuleText.percent(p.percent)
        }
        return PLTRow(symbol: "gift", tone: .accent, title: p.name, subtitle: subtitle, value: value,
                      showsSeparator: showsSeparator,
                      action: { formRequest = PaiePremiumFormRequest(premium: p) })
    }
}

/// Feuille d'ajout ou de modification d'une prime. Porte sa NavigationStack.
struct PaiePrimeFormView: View {
    let employerKey: String
    let existing: PayPremium?
    let onSave: (PayPremium) -> Void
    let onDelete: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var name: String
    @State private var kind: PremiumKind
    @State private var amountType: PremiumAmountType
    @State private var amountText: String
    @State private var frequency: PremiumFrequency
    @State private var basis: PremiumBasis
    @State private var subjectToContributions: Bool
    @State private var condition: PremiumCondition
    @State private var eveningStart: Date
    @State private var hasStart: Bool
    @State private var startDate: Date
    @State private var hasEnd: Bool
    @State private var endDate: Date
    @State private var anchorDate: Date
    @State private var note: String
    @State private var errorMessage: String? = nil
    @State private var showDeleteDialog: Bool = false

    init(employerKey: String, existing: PayPremium?, onSave: @escaping (PayPremium) -> Void, onDelete: @escaping (String) -> Void) {
        self.employerKey = employerKey
        self.existing = existing
        self.onSave = onSave
        self.onDelete = onDelete
        let cal: Calendar = Calendar.current
        let today: Date = cal.startOfDay(for: Date())
        let p: PayPremium? = existing
        _name = State(initialValue: p?.name ?? "")
        _kind = State(initialValue: p?.kind ?? PremiumKind.panier)
        _amountType = State(initialValue: p?.amountType ?? PremiumAmountType.fixed)
        var amount: String = ""
        if let p = p {
            switch p.amountType {
            case .fixed: amount = PayExport.centsText(p.amountCents)
            case .percentOfGross: amount = PaieRuleText.percent(p.percent).replacingOccurrences(of: "\u{00A0}%", with: "")
            }
        }
        _amountText = State(initialValue: amount)
        _frequency = State(initialValue: p?.frequency ?? PremiumFrequency.monthly)
        _basis = State(initialValue: p?.basis ?? PremiumBasis.gross)
        _subjectToContributions = State(initialValue: p?.subjectToContributions ?? true)
        _condition = State(initialValue: p?.condition ?? PremiumCondition.none)
        let eveningMinute: Int = p?.eveningStartMinute ?? (20 * 60)
        _eveningStart = State(initialValue: cal.date(bySettingHour: eveningMinute / 60, minute: eveningMinute % 60, second: 0, of: today) ?? today)
        _hasStart = State(initialValue: p?.startDate != nil)
        _startDate = State(initialValue: p?.startDate ?? today)
        _hasEnd = State(initialValue: p?.endDate != nil)
        _endDate = State(initialValue: p?.endDate ?? today)
        _anchorDate = State(initialValue: p?.anchorDate ?? today)
        _note = State(initialValue: p?.note ?? "")
    }

    private var availableFrequencies: [PremiumFrequency] {
        if amountType == .percentOfGross { return [.monthly, .annual, .oneOff] }
        return PremiumFrequency.allCases
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: existing == nil ? "Ajouter une prime" : "Modifier la prime") {
                nameCard
                amountCard
                frequencyCard
                if frequency.supportsCondition { conditionCard }
                if frequency == .annual || frequency == .oneOff { anchorCard }
                periodCard
                basisCard
                if let message = errorMessage {
                    PLTBanner(kind: .error, title: "Pas enregistré", message: message)
                }
                Button("Enregistrer la prime") { save() }
                    .buttonStyle(.pltPrimary)
                if existing != nil {
                    Button("Supprimer cette prime") { showDeleteDialog = true }
                        .buttonStyle(.pltDestructive)
                }
                Text("Saisie par toi, comptée dans l'estimation. Ta fiche de paie fait foi.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .confirmationDialog("Supprimer cette prime ?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    if let e = existing { onDelete(e.id) }
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    private var nameCard: some View {
        PLTCard {
            TextField("Nom, par exemple Prime de panier", text: $name)
                .frame(minHeight: 44)
                .accessibilityLabel("Nom de la prime")
            Picker("Type", selection: $kind) {
                ForEach(PremiumKind.allCases, id: \.self) { (k: PremiumKind) in
                    Text(k.title).tag(k)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
        }
    }

    private var amountCard: some View {
        PLTCard {
            Picker("Forme", selection: $amountType) {
                ForEach(PremiumAmountType.allCases, id: \.self) { (t: PremiumAmountType) in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: amountType) { _, newValue in
                if newValue == .percentOfGross && frequency.supportsCondition { frequency = .monthly }
            }
            TextField(amountType == .fixed ? "Montant en euros, par exemple 5,50" : "Pourcentage du brut, par exemple 3", text: $amountText)
                .keyboardType(.decimalPad)
                .font(.title3.monospacedDigit())
                .frame(minHeight: 44)
                .accessibilityLabel("Montant")
        }
    }

    private var frequencyCard: some View {
        PLTCard {
            Picker("Fréquence", selection: $frequency) {
                ForEach(availableFrequencies, id: \.self) { (f: PremiumFrequency) in
                    Text(f.title).tag(f)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            Text(frequencyHint)
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private var frequencyHint: String {
        switch frequency {
        case .perHour: return "Le montant est compté pour chaque heure travaillée."
        case .perSession: return "Le montant est compté pour chaque session de taf."
        case .perDay: return "Le montant est compté une fois par jour où tu as travaillé."
        case .monthly: return "Le montant est compté chaque mois, en entier, sans prorata."
        case .annual: return "Le montant est compté seulement le mois de versement."
        case .oneOff: return "Le montant est compté seulement le mois de la date choisie."
        }
    }

    private var conditionCard: some View {
        PLTCard {
            Picker("Condition", selection: $condition) {
                ForEach(PremiumCondition.allCases, id: \.self) { (c: PremiumCondition) in
                    Text(c.title).tag(c)
                }
            }
            .pickerStyle(.menu)
            .frame(minHeight: 44)
            if condition == .evening {
                DatePicker("La soirée commence à", selection: $eveningStart, displayedComponents: .hourAndMinute)
                    .frame(minHeight: 44)
                Text("Je n'ai pas d'heure de soirée par défaut : mets celle de ton contrat.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var anchorCard: some View {
        PLTCard {
            DatePicker(frequency == .annual ? "Mois de versement" : "Date de la prime", selection: $anchorDate, displayedComponents: .date)
                .frame(minHeight: 44)
        }
    }

    private var periodCard: some View {
        PLTCard {
            Toggle("Commence à une date", isOn: $hasStart).frame(minHeight: 44)
            if hasStart {
                DatePicker("À partir du", selection: $startDate, displayedComponents: .date).frame(minHeight: 44)
            }
            Toggle("Se termine à une date", isOn: $hasEnd).frame(minHeight: 44)
            if hasEnd {
                DatePicker("Jusqu'au", selection: $endDate, displayedComponents: .date).frame(minHeight: 44)
            }
        }
    }

    private var basisCard: some View {
        PLTCard {
            Picker("Montant", selection: $basis) {
                ForEach(PremiumBasis.allCases, id: \.self) { (b: PremiumBasis) in
                    Text(b.title).tag(b)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Soumise à cotisations (indicatif)", isOn: $subjectToContributions).frame(minHeight: 44)
            Text("Brut : ajouté au brut, puis converti en net avec ton ratio. Net : ajouté au net seulement. La case des cotisations est une note pour toi, elle ne change pas le calcul.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
            TextField("Note (facultatif)", text: $note)
                .frame(minHeight: 44)
                .accessibilityLabel("Note")
        }
    }

    private func save() {
        let trimmed: String = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            errorMessage = "Donne un nom à la prime."
            return
        }
        var cents: Int = 0
        var percent: Double = 0
        switch amountType {
        case .fixed:
            guard let c = PayRules.parseMoneyCents(amountText) else {
                errorMessage = "Écris un montant en euros, par exemple 5,50."
                return
            }
            cents = c
        case .percentOfGross:
            guard let p = PayRules.parsePercent(amountText), p > 0 else {
                errorMessage = "Écris un pourcentage plus grand que 0, par exemple 3."
                return
            }
            percent = p
        }
        if hasStart && hasEnd && endDate < startDate {
            errorMessage = "La date de fin est avant la date de début."
            return
        }
        let cal: Calendar = Calendar.current
        let eveningMinute: Int = cal.component(.hour, from: eveningStart) * 60 + cal.component(.minute, from: eveningStart)
        let premium = PayPremium(id: existing?.id ?? UUID().uuidString,
                                 employerKey: employerKey,
                                 name: trimmed,
                                 kind: kind,
                                 amountType: amountType,
                                 amountCents: cents,
                                 percent: percent,
                                 frequency: frequency,
                                 basis: basis,
                                 subjectToContributions: subjectToContributions,
                                 condition: frequency.supportsCondition ? condition : PremiumCondition.none,
                                 eveningStartMinute: (frequency.supportsCondition && condition == .evening) ? eveningMinute : nil,
                                 startDate: hasStart ? cal.startOfDay(for: startDate) : nil,
                                 endDate: hasEnd ? cal.startOfDay(for: endDate) : nil,
                                 anchorDate: (frequency == .annual || frequency == .oneOff) ? cal.startOfDay(for: anchorDate) : nil,
                                 note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        onSave(premium)
        dismiss()
    }
}
