import Foundation
import Observation

/// Choix d'apparence de l'utilisateur. "Noir pur" = ThemeMode.amoled.
enum ThemeChoice: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark
    case amoled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Clair"
        case .dark: return "Sombre"
        case .amoled: return "Noir pur"
        }
    }

    /// Mode de palette généré. En Auto, suit le réglage du système (clair ou sombre, jamais noir pur).
    func themeMode(systemIsDark: Bool) -> ThemeMode {
        switch self {
        case .auto: return systemIsDark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        case .amoled: return .amoled
        }
    }

    /// Vrai si le fond de l'app est sombre pour ce choix.
    func isDark(systemIsDark: Bool) -> Bool {
        return themeMode(systemIsDark: systemIsDark) != .light
    }
}

enum Density: String, CaseIterable, Identifiable {
    case comfortable
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .comfortable: return "Confortable"
        case .compact: return "Compacte"
        }
    }
}

/// Une devise de la courte liste proposée.
struct Currency: Identifiable, Equatable {
    let code: String
    let symbol: String
    let name: String
    let fractionDigits: Int

    var id: String { code }

    static let all: [Currency] = [
        Currency(code: "EUR", symbol: "€", name: "Euro", fractionDigits: 2),
        Currency(code: "CHF", symbol: "CHF", name: "Franc suisse", fractionDigits: 2),
        Currency(code: "CAD", symbol: "$ CA", name: "Dollar canadien", fractionDigits: 2),
        Currency(code: "USD", symbol: "$", name: "Dollar américain", fractionDigits: 2),
        Currency(code: "GBP", symbol: "£", name: "Livre sterling", fractionDigits: 2),
        Currency(code: "XOF", symbol: "F CFA", name: "Franc CFA", fractionDigits: 0),
        Currency(code: "MAD", symbol: "MAD", name: "Dirham marocain", fractionDigits: 2),
        Currency(code: "TND", symbol: "DT", name: "Dinar tunisien", fractionDigits: 2)
    ]

    static let euro: Currency = all[0]

    /// Devise du code donné, euro si le code est inconnu.
    static func find(code: String) -> Currency {
        for c in all where c.code == code { return c }
        return euro
    }
}

/// Réglages de l'app, stockés dans UserDefaults. À injecter avec `.environment(settings)`
/// et à lire avec `@Environment(AppSettings.self)`. Pour un Picker ou un Toggle :
/// `@Bindable var settings = settings` puis `$settings.themeChoice`.
@Observable
final class AppSettings {
    enum Key {
        static let theme = "plt.settings.theme"
        static let currency = "plt.settings.currency"
        static let base = "plt.settings.calculationBase"
        static let density = "plt.settings.density"
        static let reduceAnimations = "plt.settings.reduceAnimations"
        static let onboardingDone = "plt.settings.onboardingDone"
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults.standard) {
        self.defaults = defaults
    }

    // Les réglages sont des propriétés calculées lues et écrites dans UserDefaults.
    // access(keyPath:) et withMutation(keyPath:_:) sont générés par @Observable : SwiftUI se met à jour à chaque changement.

    var themeChoice: ThemeChoice {
        get {
            access(keyPath: \.themeChoice)
            return ThemeChoice(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .auto
        }
        set {
            withMutation(keyPath: \.themeChoice) {
                defaults.set(newValue.rawValue, forKey: Key.theme)
            }
        }
    }

    /// Code de devise (EUR par défaut). Utilise `currency` pour le symbole.
    var currencyCode: String {
        get {
            access(keyPath: \.currencyCode)
            return defaults.string(forKey: Key.currency) ?? "EUR"
        }
        set {
            withMutation(keyPath: \.currencyCode) {
                defaults.set(newValue, forKey: Key.currency)
            }
        }
    }

    var calculationBase: CalculationBase {
        get {
            access(keyPath: \.calculationBase)
            return CalculationBase(rawValue: defaults.string(forKey: Key.base) ?? "") ?? .fullHours
        }
        set {
            withMutation(keyPath: \.calculationBase) {
                defaults.set(newValue.rawValue, forKey: Key.base)
            }
        }
    }

    var density: Density {
        get {
            access(keyPath: \.density)
            return Density(rawValue: defaults.string(forKey: Key.density) ?? "") ?? .comfortable
        }
        set {
            withMutation(keyPath: \.density) {
                defaults.set(newValue.rawValue, forKey: Key.density)
            }
        }
    }

    var reduceAnimations: Bool {
        get {
            access(keyPath: \.reduceAnimations)
            return defaults.bool(forKey: Key.reduceAnimations)
        }
        set {
            withMutation(keyPath: \.reduceAnimations) {
                defaults.set(newValue, forKey: Key.reduceAnimations)
            }
        }
    }

    var hasCompletedOnboarding: Bool {
        get {
            access(keyPath: \.hasCompletedOnboarding)
            return defaults.bool(forKey: Key.onboardingDone)
        }
        set {
            withMutation(keyPath: \.hasCompletedOnboarding) {
                defaults.set(newValue, forKey: Key.onboardingDone)
            }
        }
    }

    var currency: Currency { return Currency.find(code: currencyCode) }

    /// "1 234,50 €" : virgule décimale, espace fine insécable pour les milliers, symbole après une espace insécable.
    func formatMoney(_ amount: Double) -> String {
        let c = currency
        return MoneyFormat.format(amount: amount, symbol: c.symbol, fractionDigits: c.fractionDigits)
    }

    /// Remet l'apparence, la devise, la base, la densité et les animations par défaut (ne touche pas aux données ni à l'onboarding).
    func resetToDefaults() {
        themeChoice = .auto
        currencyCode = "EUR"
        calculationBase = .fullHours
        density = .comfortable
        reduceAnimations = false
    }
}
