import XCTest
@testable import PersonalLifeTracker

final class LastStartStoreTests: XCTestCase {
    func testEmptyStoreHasNothing() {
        let made = makeIsolatedDefaults()
        defer { made.defaults.removePersistentDomain(forName: made.name) }
        let store = LastStartStore(defaults: made.defaults)
        XCTAssertNil(store.activity)
        XCTAssertNil(store.placeUID)
    }

    func testRememberAndReadBack() {
        let made = makeIsolatedDefaults()
        defer { made.defaults.removePersistentDomain(forName: made.name) }
        let store = LastStartStore(defaults: made.defaults)
        let uid: UUID = UUID()
        store.remember(activity: .education, placeUID: uid)
        XCTAssertEqual(store.activity, .education)
        XCTAssertEqual(store.placeUID, uid)
    }

    func testRememberWithoutPlaceClearsThePreviousPlace() {
        let made = makeIsolatedDefaults()
        defer { made.defaults.removePersistentDomain(forName: made.name) }
        let store = LastStartStore(defaults: made.defaults)
        store.remember(activity: .work, placeUID: UUID())
        store.remember(activity: .work, placeUID: nil)
        XCTAssertEqual(store.activity, .work)
        XCTAssertNil(store.placeUID)
    }

    func testGarbageValuesReadAsNil() {
        let made = makeIsolatedDefaults()
        defer { made.defaults.removePersistentDomain(forName: made.name) }
        made.defaults.set("pas une activité", forKey: LastStartStore.activityKey)
        made.defaults.set("pas un uuid", forKey: LastStartStore.placeKey)
        let store = LastStartStore(defaults: made.defaults)
        XCTAssertNil(store.activity)
        XCTAssertNil(store.placeUID)
    }

    func testClear() {
        let made = makeIsolatedDefaults()
        defer { made.defaults.removePersistentDomain(forName: made.name) }
        let store = LastStartStore(defaults: made.defaults)
        store.remember(activity: .work, placeUID: UUID())
        store.clear()
        XCTAssertNil(store.activity)
        XCTAssertNil(store.placeUID)
    }

    func testRowTitle() {
        XCTAssertEqual(LastStartStore.rowTitle(activity: .work, placeName: "Supérette du Canal"),
                       "Comme la dernière fois : Taf, Supérette du Canal")
        XCTAssertEqual(LastStartStore.rowTitle(activity: .education, placeName: nil),
                       "Comme la dernière fois : Cours")
        XCTAssertEqual(LastStartStore.rowTitle(activity: .work, placeName: ""),
                       "Comme la dernière fois : Taf")
    }
}
