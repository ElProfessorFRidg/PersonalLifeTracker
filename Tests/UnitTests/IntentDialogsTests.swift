import XCTest
@testable import PersonalLifeTracker

final class IntentDialogsTests: XCTestCase {
    func testStartedWithPlace() {
        XCTAssertEqual(IntentDialogs.started(activity: .work, placeName: "Supérette du Canal"),
                       "C'est parti, Taf démarré à Supérette du Canal.")
    }

    func testStartedWithoutPlaceOrWithEmptyName() {
        XCTAssertEqual(IntentDialogs.started(activity: .education, placeName: nil), "C'est parti, Cours démarré.")
        XCTAssertEqual(IntentDialogs.started(activity: .work, placeName: ""), "C'est parti, Taf démarré.")
    }

    func testAlreadyRunningGivesStartTimeInTheSessionCalendar() {
        let text: String = IntentDialogs.alreadyRunning(activity: .work,
                                                        since: makeDate(TestCalendar.paris, 2026, 11, 16, 17, 56),
                                                        calendar: TestCalendar.paris)
        XCTAssertEqual(text, "Une session tourne déjà : Taf depuis 17:56. Arrête-la d'abord.")
    }

    func testStoppedShowsExactDuration() {
        XCTAssertEqual(IntentDialogs.stopped(activity: .work, seconds: 3 * 3600 + 4 * 60 + 59),
                       "Session arrêtée : Taf, 3 h 04.")
    }

    func testNothingRunning() {
        XCTAssertEqual(IntentDialogs.nothingRunning, "Aucune session en cours, rien à arrêter.")
    }

    func testTodayWithWorkAndStudy() {
        XCTAssertEqual(IntentDialogs.today(workSeconds: 3 * 3600 + 4 * 60, studySeconds: 3 * 3600 + 57 * 60, isRunning: false),
                       "Aujourd'hui : Taf 3 h 04, Cours 3 h 57.")
    }

    func testTodayWithOnlyWork() {
        XCTAssertEqual(IntentDialogs.today(workSeconds: 25 * 60, studySeconds: 0, isRunning: false),
                       "Aujourd'hui : Taf 25 min.")
    }

    func testTodayEmpty() {
        XCTAssertEqual(IntentDialogs.today(workSeconds: 0, studySeconds: 0, isRunning: false), "Rien de noté aujourd'hui.")
    }

    func testTodayMentionsARunningSession() {
        XCTAssertEqual(IntentDialogs.today(workSeconds: 3600, studySeconds: 0, isRunning: true),
                       "Aujourd'hui : Taf 1 h 00. Une session tourne encore.")
        XCTAssertEqual(IntentDialogs.today(workSeconds: 0, studySeconds: 0, isRunning: true),
                       "Pas encore d'heure comptée aujourd'hui. Une session tourne encore.")
    }

    func testNoTextContainsAnEmDash() {
        let all: [String] = [
            IntentDialogs.storeUnavailable, IntentDialogs.failure, IntentDialogs.nothingRunning,
            IntentDialogs.started(activity: .work, placeName: "A"),
            IntentDialogs.today(workSeconds: 60, studySeconds: 60, isRunning: true)
        ]
        for text in all {
            XCTAssertFalse(text.contains("\u{2014}"), text)
        }
    }
}
