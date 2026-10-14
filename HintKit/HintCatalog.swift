import Foundation

public enum HintCatalogError: Error, Equatable {
    case emptyIdentifier
    case duplicateIdentifier(String)
}

/// Loads the same JSON array format used by Space Wildfires.
public struct HintCatalog {
    public let hints: [Hint]
    private let byID: [String: Hint]

    public init(hints: [Hint]) throws {
        var values: [String: Hint] = [:]
        for hint in hints {
            guard !hint.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw HintCatalogError.emptyIdentifier }
            guard values[hint.id] == nil
            else { throw HintCatalogError.duplicateIdentifier(hint.id) }
            values[hint.id] = hint
        }
        self.hints = hints
        byID = values
    }

    public init(data: Data) throws {
        try self.init(hints: JSONDecoder().decode([Hint].self, from: data))
    }

    public init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    public subscript(id: String) -> Hint? { byID[id] }
}
