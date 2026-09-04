import XCTest
@testable import MarkPad

/// Test altyapisinin ayakta oldugunu dogrular.
final class SmokeTests: XCTestCase {

    func testTestHedefiCalisiyor() {
        XCTAssertEqual(2 + 2, 4)
    }

    /// Uygulama hedefinin sembollerine erisebildigimizi dogrular.
    func testUygulamaSembolleriGorunuyor() {
        XCTAssertFalse(MarkdownDocument.starterText.isEmpty)
    }
}
