import XCTest
@testable import macgit

final class ConflictResolutionModelsTests: XCTestCase {
    func testConflictSectionsSplitCurrentIncomingAndContext() throws {
        let text = """
        intro
        <<<<<<< HEAD
        current line
        =======
        incoming line
        >>>>>>> feature
        outro
        """

        let document = try ConflictResolutionDocument.parse(text)

        XCTAssertEqual(document.sections.count, 3)
        XCTAssertEqual(document.sections[0].resolvedText, "intro\n")
        XCTAssertEqual(document.sections[1].currentText, "current line\n")
        XCTAssertEqual(document.sections[1].incomingText, "incoming line\n")
        XCTAssertEqual(document.sections[2].resolvedText, "outro")
    }

    func testConflictChoiceUpdatesResolvedOutput() throws {
        let text = """
        <<<<<<< HEAD
        current line
        =======
        incoming line
        >>>>>>> feature
        """

        var document = try ConflictResolutionDocument.parse(text)
        document.sections[0].resolution = .incoming

        XCTAssertEqual(document.resolvedText, "incoming line\n")
    }

    func testConflictManualEditOverridesPresetChoice() throws {
        let text = """
        <<<<<<< HEAD
        alpha
        =======
        beta
        >>>>>>> branch
        """

        var document = try ConflictResolutionDocument.parse(text)
        document.sections[0].manualResult = "alpha\nbeta"

        XCTAssertEqual(document.sections[0].resolvedText, "alpha\nbeta")
        XCTAssertEqual(document.resolvedText, "alpha\nbeta")
    }
}
