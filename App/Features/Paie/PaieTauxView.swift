import SwiftUI
import SwiftData

/// Historique des taux horaires d'un contrat (section 69). Écran poussé depuis PaieView.
/// Un taux vaut à partir de sa date d'effet : les mois passés ne changent pas quand un nouveau taux arrive.
struct PaieTauxView: View {
    let contractUID: UUID
    let contractStart: Date

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \PayRate.effectiveDate, order: .reverse) private var allRates: [PayRate]
    @AppStorage(PayPreferences.Key.smicOverride) private var smicOverride: Double = 0

    @State private var formRequest: PaieRateFormRequest? = nil
    @State private var pendingDelete: PayRate? = nil
    @State private var showDeleteDialog: Bool = false
    @State private var deleteFailed: Bool = false

    private var calendar: Calendar { return Calendar.current }

    private var rates: [PayRate] {
        var list: [PayRate] = []
        for r in allRates where r.contractUID == contractUID { list.append(r) }
        return list
    }

    var body: some View {
        PLTScreen(title: "Taux horaires") {
            introSection
            historySection
            actionsSection
            smicSection
        }
        .sheet(item: $formRequest) { (request: PaieRateFormRequest) in
            PaieTauxFormView(request: request)
        }
        .confirmationDialog("Supprimer ce taux ?", isPresented: $showDeleteDialog, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) { deletePending() }
            Button("Annuler", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Les mois qui utilisaient ce taux seront recalculés avec le taux d'avant. Aucune trace n'est gardée pour l'instant.")
        }
    }

    private var introSection: some View {
        Text("Chaque taux vaut à partir de sa date. Quand ton taux change, ajoute le nouveau avec sa date : les mois passés gardent l'ancien.")
            .font(.subheadline)
            .foregroundStyle(palette.textSecondary)
    }

    private var historySection: some View {
        let list: [PayRate] = rates
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "Historique")
            if deleteFailed {
                PLTBanner(kind: .error, title: "Ça n'a pas marché", message: "Le taux n'a pas été supprimé. Réessaie ?")
            }
            if list.isEmpty {
                PLTCard {
                    Text("Aucun taux saisi pour ce contrat. Sans taux, je n'affiche aucun montant.")
                        .font(.subheadline)
                        .foregroundStyle(palette.textSecondary)
                }
            } else {
                PLTListGroup {
                    ForEach(0..<list.count, id: \.self) { i in
                        rateRow(list, index: i)
                    }
                }
                Text("Touche un taux pour le supprimer si tu t'es trompé.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private func rateRow(_ list: [PayRate], index i: Int) -> some View {
        let rate: PayRate = list[i]
        let date: String = PaieFormat.longDate(rate.effectiveDate, calendar: calendar)
        var subtitle: String = "À partir du \(date)"
        if !rate.note.isEmpty { subtitle += ". " + rate.note }
        var change: String? = nil
        if i + 1 < list.count {
            let older: Decimal = PayMath.decimal(list[i + 1].hourlyGross)
            let newer: Decimal = PayMath.decimal(rate.hourlyGross)
            if let pct = PayCalculator.percentChange(from: older, to: newer) {
                change = percentText(pct)
            }
        }
        return PLTRow(symbol: "eurosign.circle", tone: .accent,
                      title: PaieFormat.rateText(PayMath.decimal(rate.hourlyGross), settings: settings) + " brut par heure",
                      subtitle: subtitle,
                      value: change,
                      showsSeparator: i < list.count - 1,
                      action: {
                          pendingDelete = rate
                          showDeleteDialog = true
                      })
    }

    private func percentText(_ pct: Decimal) -> String {
        let value: Double = PayMath.double(pct)
        let sign: String = value > 0 ? "+" : ""
        return sign + String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",") + "\u{00A0}%"
    }

    private var actionsSection: some View {
        VStack(spacing: Theme.Spacing.s) {
            Button("Ajouter un taux") {
                formRequest = PaieRateFormRequest(contractUID: contractUID, contractStart: contractStart, isSmic: false)
            }
            .buttonStyle(.pltPrimary)
            Button("Je suis au SMIC") {
                formRequest = PaieRateFormRequest(contractUID: contractUID, contractStart: contractStart, isSmic: true)
            }
            .buttonStyle(.pltSecondary)
        }
    }

    private var smicSection: some View {
        let smic: (hourlyGross: Decimal, isOverride: Bool) = SmicReference.resolved(overrideValue: smicOverride > 0 ? smicOverride : nil)
        let date: String = PaieFormat.longDate(SmicReference.effectiveDate(calendar: calendar), calendar: calendar)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PLTSectionHeader(title: "SMIC de référence")
            PLTListGroup {
                PLTRow(symbol: "checkmark.shield", tone: .neutral,
                       title: "SMIC horaire brut",
                       subtitle: smic.isOverride ? "Valeur modifiée par toi" : "Valeur de l'app, en vigueur au \(date)",
                       value: PaieFormat.rateText(smic.hourlyGross, settings: settings),
                       showsSeparator: smic.isOverride)
                if smic.isOverride {
                    PLTRow(symbol: "arrow.uturn.backward", tone: .accent,
                           title: "Revenir à la valeur de l'app",
                           showsSeparator: false,
                           action: { smicOverride = 0 })
                }
            }
            Text("Le SMIC change quand il est revalorisé. Cette valeur n'est pas vérifiée par l'app : vérifie-la sur \(SmicReference.sourceName) avant de t'y fier. Quand il est revalorisé, ajoute le nouveau taux avec sa date, je ne le change jamais en silence.")
                .font(.footnote)
                .foregroundStyle(palette.textSecondary)
        }
    }

    private func deletePending() {
        guard let rate = pendingDelete else { return }
        context.delete(rate)
        do {
            try context.save()
            deleteFailed = false
        } catch {
            deleteFailed = true
        }
        pendingDelete = nil
    }
}

enum PaieRateUnit: String, CaseIterable, Identifiable {
    case gross
    case net

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gross: return "Brut"
        case .net: return "Net"
        }
    }
}

/// Feuille d'ajout d'un taux (ou "Je suis au SMIC", valeur et date proposées puis modifiables). Porte sa NavigationStack.
struct PaieTauxFormView: View {
    let request: PaieRateFormRequest

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings
    @Query private var allRates: [PayRate]
    @AppStorage(PayPreferences.Key.netRatio) private var netRatioStored: Double = PayPreferences.defaultNetRatio
    @AppStorage(PayPreferences.Key.smicOverride) private var smicOverride: Double = 0

    @State private var text: String
    @State private var unit: PaieRateUnit = .gross
    @State private var date: Date
    @State private var note: String = ""
    @State private var keepAsSmic: Bool = false
    @State private var errorMessage: String? = nil

    init(request: PaieRateFormRequest) {
        self.request = request
        let cal: Calendar = Calendar.current
        if request.isSmic {
            let resolved = SmicReference.resolved(overrideValue: PayPreferences.smicOverride(defaults: UserDefaults.standard))
            _text = State(initialValue: PayExport.commaDecimal(PayExport.decimalText(resolved.hourlyGross)))
            _date = State(initialValue: PayCalculator.smicEffectiveDate(contractStart: request.contractStart, calendar: cal))
            _note = State(initialValue: "SMIC")
        } else {
            _text = State(initialValue: "")
            _date = State(initialValue: cal.startOfDay(for: Date()))
        }
    }

    private var calendar: Calendar { return Calendar.current }

    private var ratioDecimal: Decimal {
        return PayMath.decimal(PayPreferences.clampedRatio(netRatioStored))
    }

    private var grossValue: Decimal? {
        guard let v = PayCalculator.parseAmount(text) else { return nil }
        return unit == .gross ? v : PayCalculator.grossFromNet(net: v, ratio: ratioDecimal)
    }

    var body: some View {
        NavigationStack {
            PLTScreen(title: request.isSmic ? "Je suis au SMIC" : "Ajouter un taux") {
                if request.isSmic {
                    PLTBanner(kind: .info,
                              title: "SMIC de référence",
                              message: "Valeur de l'app, pas vérifiée : vérifie-la sur \(SmicReference.sourceName) et corrige-la ci-dessous si besoin. Date proposée : \(PaieFormat.longDate(date, calendar: calendar)).")
                }
                rateCard
                dateCard
                if request.isSmic {
                    PLTCard {
                        Toggle("Garder cette valeur comme SMIC de référence", isOn: $keepAsSmic)
                            .frame(minHeight: 44)
                    }
                }
                if let message = errorMessage {
                    PLTBanner(kind: .error, title: "Le taux n'est pas enregistré", message: message)
                }
                Button("Enregistrer ce taux") { save() }
                    .buttonStyle(.pltPrimary)
                Text("Tout reste sur ton tel. Ta fiche de paie fait foi.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private var rateCard: some View {
        PLTCard {
            Text("Taux horaire")
                .font(.subheadline)
                .foregroundStyle(palette.textSecondary)
            TextField("Par exemple 12,02", text: $text)
                .keyboardType(.decimalPad)
                .font(.title3.monospacedDigit())
                .frame(minHeight: 44)
                .accessibilityLabel("Taux horaire")
            Picker("Unité", selection: $unit) {
                ForEach(PaieRateUnit.allCases) { u in
                    Text(u.title).tag(u)
                }
            }
            .pickerStyle(.segmented)
            if unit == .net, let gross = grossValue {
                Text("Soit environ \(PaieFormat.rateText(gross, settings: settings)) brut par heure, avec le ratio \(PaieFormat.ratioText(PayPreferences.clampedRatio(netRatioStored))). Estimation.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            } else {
                Text("Écris un taux comme 12,02. Le net est converti avec un ratio indicatif, affiché comme une estimation.")
                    .font(.footnote)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }

    private var dateCard: some View {
        PLTCard {
            DatePicker("À partir du", selection: $date, displayedComponents: .date)
                .frame(minHeight: 44)
            TextField("Note (facultatif)", text: $note)
                .frame(minHeight: 44)
                .accessibilityLabel("Note")
        }
    }

    private func save() {
        guard let gross = grossValue else {
            errorMessage = "Écris un taux comme 12,02."
            return
        }
        let day: Date = calendar.startOfDay(for: date)
        for r in allRates where r.contractUID == request.contractUID {
            if calendar.startOfDay(for: r.effectiveDate) == day {
                errorMessage = "Un taux existe déjà à cette date. Choisis une autre date, ou supprime l'ancien dans l'historique."
                return
            }
        }
        let rate = PayRate(contractUID: request.contractUID, effectiveDate: day,
                           hourlyGross: PayMath.double(gross), note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(rate)
        do {
            try context.save()
        } catch {
            context.delete(rate)
            errorMessage = "Je n'ai pas réussi à l'enregistrer. Réessaie ?"
            return
        }
        if request.isSmic && keepAsSmic {
            smicOverride = PayMath.double(gross)
        }
        dismiss()
    }
}
