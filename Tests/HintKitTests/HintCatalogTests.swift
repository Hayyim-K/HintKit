import XCTest
import HintKit

final class HintCatalogTests: XCTestCase {
    func testLegacyJSONAndRoundTrip() throws {
        let data = Data("""
        [{"id":"gravity","title":"Gravity","message":"Tap here.","imageName":"flame.fill","arrows":[3]}]
        """.utf8)
        let catalog = try HintCatalog(data: data)
        let hint = try XCTUnwrap(catalog["gravity"])
        XCTAssertEqual(hint.arrows, [3])
        XCTAssertEqual(try JSONDecoder().decode(Hint.self, from: JSONEncoder().encode(hint)), hint)
        XCTAssertNil(catalog["missing"])
    }

    func testOptionalContentFieldsUseDefaults() throws {
        let catalog = try HintCatalog(data: Data("[{\"id\":\"photo\",\"message\":\"Choose a photo.\"}]".utf8))
        XCTAssertEqual(catalog["photo"], Hint(id: "photo", message: "Choose a photo."))
    }

    func testDuplicateAndEmptyIDsAreRejected() {
        XCTAssertThrowsError(try HintCatalog(hints: [Hint(id: " ", message: "Text")])) {
            XCTAssertEqual($0 as? HintCatalogError, .emptyIdentifier)
        }
        let hint = Hint(id: "photo", message: "Text")
        XCTAssertThrowsError(try HintCatalog(hints: [hint, hint])) {
            XCTAssertEqual($0 as? HintCatalogError, .duplicateIdentifier("photo"))
        }
    }

    func testMalformedJSONDoesNotProduceAnEmptySuccessfulCatalog() {
        XCTAssertThrowsError(try HintCatalog(data: Data("invalid".utf8)))
    }
}
