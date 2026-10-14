import XCTest
@testable import HintKit

final class HintStoreTests: XCTestCase {
    @MainActor
    func testHistorySurvivesNewStoreInstances() async throws {
        let suite = "HintKitTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HintStore(userDefaults: defaults)
        store.recordPresentation("photo")
        store.markDismissed("photo")
        store.markCompleted("photo")
        let restored = HintStore(userDefaults: defaults)
        XCTAssertEqual(restored.status(for: "photo").presentationCount, 1)
        XCTAssertTrue(restored.status(for: "photo").isDismissed)
        XCTAssertTrue(restored.status(for: "photo").isCompleted)
    }

    @MainActor
    func testPoliciesDistinguishDismissalFromFeatureUse() async throws {
        let suite = "HintKitTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HintStore(userDefaults: defaults)
        store.recordPresentation("photo")
        store.markDismissed("photo")
        XCTAssertFalse(store.shouldDisplay("photo", policy: .once))
        XCTAssertFalse(store.shouldDisplay("photo", policy: .untilDismissed))
        XCTAssertTrue(store.shouldDisplay("photo", policy: .untilCompleted))
        store.markCompleted("photo")
        XCTAssertFalse(store.shouldDisplay("photo", policy: .untilCompleted))
        XCTAssertTrue(store.shouldDisplay("photo", policy: .always))
    }

    @MainActor
    func testResetDoesNotRemoveOtherHintsNamespacesOrAppData() async throws {
        let suite = "HintKitTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("keep", forKey: "appSetting")
        let first = HintStore(userDefaults: defaults, namespace: "first")
        let second = HintStore(userDefaults: defaults, namespace: "second")
        first.markCompleted("photo")
        first.markCompleted("painting")
        second.markCompleted("photo")
        first.reset("photo")
        XCTAssertFalse(first.status(for: "photo").isCompleted)
        XCTAssertTrue(first.status(for: "painting").isCompleted)
        first.resetAll()
        XCTAssertTrue(second.status(for: "photo").isCompleted)
        XCTAssertEqual(defaults.string(forKey: "appSetting"), "keep")
    }
}
