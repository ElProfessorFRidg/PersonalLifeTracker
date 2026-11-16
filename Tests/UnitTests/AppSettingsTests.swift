import XCTest
@testable import PersonalLifeTracker

final class AppSettingsTests: XCTestCase {
    private let nnbsp = "\u{202F}"   // espace fine insécable (milliers)
    private let nbsp = "\u{00A0}"    // espace insécable avant le symbole

    private func eur(_ amount: Double) -> String {
        return MoneyFormat.format(amount: amount, symbol: "€", fractionDigits: 2)
    }

    // MARK: montants

    func testMoneySimple() {
        XCTAssertEqual(eur(12.5), "12,50\(nbsp)€")
        XCTAssertEqual(eur(0), "0,00\(nbsp)€")
    }

    func testMoneyThousandsGrouping() {
        XCTAssertEqual(eur(1234.5), "1\(nnbsp)234,50\(nbsp)€")
        XCTAssertEqual(eur(1234567.891), "1\(nnbsp)234\(nnbsp)567,89\(nbsp)€")
        XCTAssertEqual(eur(1005.07), "1\(nnbsp)005,07\(nbsp)€")
        XCTAssertEqual(eur(999), "999,00\(nbsp)€")
    }

    func testMoneyRoundsToCentsAndCarries() {
        XCTAssertEqual(eur(999.999), "1\(nnbsp)000,00\(nbsp)€")
        XCTAssertEqual(eur(2.5), "2,50\(nbsp)€")
    }

    func testMoneyNegativeAndNegligibleNegative() {
        XCTAssertEqual(eur(-3.5), "-3,50\(nbsp)€")
        XCTAssertEqual(eur(-0.001), "0,00\(nbsp)€")
    }

    func testMoneyWithoutDecimalsForCfa() {
        XCTAssertEqual(MoneyFormat.format(amount: 1500.4, symbol: "F CFA", fractionDigits: 0), "1\(nnbsp)500\(nbsp)F CFA")
    }

    func testFormatMoneyUsesSelectedCurrency() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let settings = AppSettings(defaults: iso.defaults)
        XCTAssertEqual(settings.formatMoney(1234.5), "1\(nnbsp)234,50\(nbsp)€")
        settings.currencyCode = "USD"
        XCTAssertEqual(settings.formatMoney(1234.5), "1\(nnbsp)234,50\(nbsp)$")
        settings.currencyCode = "GBP"
        XCTAssertEqual(settings.formatMoney(10), "10,00\(nbsp)£")
        settings.currencyCode = "XOF"
        XCTAssertEqual(settings.formatMoney(2500), "2\(nnbsp)500\(nbsp)F CFA")
    }

    func testUnknownCurrencyCodeFallsBackToEuro() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        iso.defaults.set("ZZZ", forKey: AppSettings.Key.currency)
        let settings = AppSettings(defaults: iso.defaults)
        XCTAssertEqual(settings.currency.code, "EUR")
        XCTAssertEqual(settings.formatMoney(1), "1,00\(nbsp)€")
    }

    func testCurrencyList() {
        XCTAssertEqual(Currency.all.map { $0.code }, ["EUR", "CHF", "CAD", "USD", "GBP", "XOF", "MAD", "TND"])
    }

    // MARK: valeurs par défaut et persistance

    func testDefaults() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let settings = AppSettings(defaults: iso.defaults)
        XCTAssertEqual(settings.themeChoice, .auto)
        XCTAssertEqual(settings.currencyCode, "EUR")
        XCTAssertEqual(settings.calculationBase, .fullHours)
        XCTAssertEqual(settings.density, .comfortable)
        XCTAssertFalse(settings.reduceAnimations)
        XCTAssertFalse(settings.hasCompletedOnboarding)
    }

    func testChangesArePersistedAndReloaded() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let settings = AppSettings(defaults: iso.defaults)
        settings.themeChoice = .amoled
        settings.currencyCode = "CHF"
        settings.calculationBase = .exact
        settings.density = .compact
        settings.reduceAnimations = true
        settings.hasCompletedOnboarding = true

        let reloaded = AppSettings(defaults: iso.defaults)
        XCTAssertEqual(reloaded.themeChoice, .amoled)
        XCTAssertEqual(reloaded.currencyCode, "CHF")
        XCTAssertEqual(reloaded.calculationBase, .exact)
        XCTAssertEqual(reloaded.density, .compact)
        XCTAssertTrue(reloaded.reduceAnimations)
        XCTAssertTrue(reloaded.hasCompletedOnboarding)
    }

    func testResetToDefaultsKeepsOnboardingFlag() {
        let iso = makeIsolatedDefaults()
        defer { UserDefaults.standard.removePersistentDomain(forName: iso.name) }
        let settings = AppSettings(defaults: iso.defaults)
        settings.themeChoice = .dark
        settings.currencyCode = "CAD"
        settings.hasCompletedOnboarding = true
        settings.resetToDefaults()
        XCTAssertEqual(settings.themeChoice, .auto)
        XCTAssertEqual(settings.currencyCode, "EUR")
        XCTAssertTrue(settings.hasCompletedOnboarding)
        XCTAssertEqual(AppSettings(defaults: iso.defaults).themeChoice, .auto)
    }

    // MARK: thème

    func testThemeChoiceMapsToGeneratedThemeMode() {
        XCTAssertEqual(ThemeChoice.auto.themeMode(systemIsDark: false), .light)
        XCTAssertEqual(ThemeChoice.auto.themeMode(systemIsDark: true), .dark)
        XCTAssertEqual(ThemeChoice.light.themeMode(systemIsDark: true), .light)
        XCTAssertEqual(ThemeChoice.dark.themeMode(systemIsDark: false), .dark)
        XCTAssertEqual(ThemeChoice.amoled.themeMode(systemIsDark: false), .amoled)
        XCTAssertEqual(ThemeChoice.amoled.themeMode(systemIsDark: true), .amoled)
    }

    func testThemeChoiceTitles() {
        XCTAssertEqual(ThemeChoice.allCases.map { $0.title }, ["Auto", "Clair", "Sombre", "Noir pur"])
    }
}
