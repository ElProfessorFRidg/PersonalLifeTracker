import SwiftUI

/// Règles de calcul des congés, modifiables. Les valeurs par défaut sont à vérifier : ta convention ou ton entreprise
/// peut fixer autre chose. Enregistrées dans UserDefaults par LeaveParameters.
struct CongesParamsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    let onSaved: (LeaveParameters) -> Void

    @State private var unit: LeaveUnit
    @State private var month: Int
    @State private var perMonthText: String
    @State private var maxText: String
    @State private var alertText: String

    init(initial: LeaveParameters, onSaved: @escaping (LeaveParameters) -> Void) {
        self.onSaved = onSaved
        _unit = State(initialValue: initial.unit)
        _month = State(initialValue: initial.referenceStartMonth)
        _perMonthText = State(initialValue: CongesFormat.number(initial.daysPerMonth))
        _maxText = State(initialValue: CongesFormat.number(initial.maxPerPeriod))
        _alertText = State(initialValue: String(initial.alertDays))
    }

    private var perMonth: Double? { return CongesFormat.parseDecimal(perMonthText) }
    private var maxDays: Double? { return CongesFormat.parseDecimal(maxText) }
    private var alertDays: Int? { return Int(alertText.trimmingCharacters(in: .whitespaces)) }

    private var isValid: Bool {
        guard let p = perMonth, let m = maxDays, let a = alertDays else { return false }
        return p > 0 && p <= 10 && m > 0 && m <= 100 && a >= 0 && a <= 366
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: "Règles de calcul") {
                PLTBanner(kind: .info, title: "À vérifier", message: LeaveParameters.verificationNote)
                unitSection
                periodSection
                numbersSection
                Button("Enregistrer") { save() }
                    .buttonStyle(.pltPrimary)
                    .disabled(!isValid)
                Button("Remettre les valeurs par défaut") { resetToDefaults() }
                    .buttonStyle(.pltSecondary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var unitSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Unité")
            PLTCard {
                Picker("Unité de décompte", selection: $unit) {
                    ForEach(LeaveUnit.allCases, id: \.self) { (u: LeaveUnit) in
                        Text(u.shortTitle).tag(u)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .onChange(of: unit) { (_: LeaveUnit, newValue: LeaveUnit) in
                    let base: LeaveParameters = LeaveParameters.defaults(unit: newValue)
                    perMonthText = CongesFormat.number(base.daysPerMonth)
                    maxText = CongesFormat.number(base.maxPerPeriod)
                }
                Text(unit.title)
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Période de référence")
            PLTCard {
                HStack {
                    Text("Elle commence le 1er")
                        .font(.body)
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: Theme.Spacing.s)
                    Picker("Mois de début de la période", selection: $month) {
                        ForEach(1...12, id: \.self) { (m: Int) in
                            Text(CongesFormat.monthName(m)).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .frame(minHeight: 44)
            }
        }
    }

    private var numbersSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Jours")
            PLTCard {
                numberRow(title: "Jours acquis par mois", placeholder: "2,5", text: $perMonthText)
                numberRow(title: "Maximum sur la période", placeholder: "30", text: $maxText)
                numberRow(title: "Alerte avant la fin (jours)", placeholder: "60", text: $alertText)
            }
            if !isValid {
                Text("Vérifie les chiffres : ils doivent être positifs et raisonnables.")
                    .font(.footnote)
                    .foregroundStyle(palette.danger)
            }
        }
    }

    private func numberRow(title: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: Theme.Spacing.s)
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .frame(maxWidth: 100, minHeight: 44)
                .accessibilityLabel(title)
        }
    }

    private func save() {
        guard let p = perMonth, let m = maxDays, let a = alertDays else { return }
        var params: LeaveParameters = LeaveParameters.defaults(unit: unit)
        params.daysPerMonth = p
        params.maxPerPeriod = m
        params.referenceStartMonth = month
        params.alertDays = a
        params.save(to: UserDefaults.standard)
        onSaved(params)
        dismiss()
    }

    private func resetToDefaults() {
        LeaveParameters.reset(in: UserDefaults.standard)
        onSaved(LeaveParameters.load(from: UserDefaults.standard))
        dismiss()
    }
}
