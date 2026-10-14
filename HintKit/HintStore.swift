import Foundation

public struct HintStatus: Codable, Equatable, Sendable {
    public internal(set) var presentationCount = 0
    public internal(set) var isDismissed = false
    public internal(set) var isCompleted = false

    public init() {}
}

/// Device-local history, isolated by namespace and UserDefaults domain.
@MainActor
public final class HintStore {
    private let defaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, namespace: String = "default") {
        defaults = userDefaults
        key = "HintKit.history.v1." + namespace
    }

    public func status(for id: String) -> HintStatus {
        history()[id] ?? HintStatus()
    }

    public func shouldDisplay(_ id: String, policy: HintDisplayPolicy) -> Bool {
        let status = status(for: id)
        switch policy {
        case .always: return true
        case .once: return status.presentationCount == 0
        case .untilDismissed: return !status.isDismissed && !status.isCompleted
        case .untilCompleted: return !status.isCompleted
        }
    }

    public func markCompleted(_ id: String) {
        update(id) { $0.isCompleted = true }
    }

    public func markDismissed(_ id: String) {
        update(id) { $0.isDismissed = true }
    }

    public func reset(_ id: String) {
        var values = history()
        values.removeValue(forKey: id)
        save(values)
    }

    /// Removes only the history belonging to this store's namespace.
    public func resetAll() {
        defaults.removeObject(forKey: key)
    }

    internal func recordPresentation(_ id: String) {
        update(id) { $0.presentationCount += 1 }
    }

    private func history() -> [String: HintStatus] {
        guard let data = defaults.data(forKey: key),
              let values = try? JSONDecoder().decode([String: HintStatus].self, from: data)
        else { return [:] }
        return values
    }

    private func update(_ id: String, change: (inout HintStatus) -> Void) {
        var values = history()
        var status = values[id] ?? HintStatus()
        change(&status)
        values[id] = status
        save(values)
    }

    private func save(_ values: [String: HintStatus]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: key)
    }
}
