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

    func testConflictSelectionCanUseCurrentIncomingOrBoth() {
        var section = ConflictResolutionSection.conflict(
            current: "current\n",
            incoming: "incoming\n"
        )

        XCTAssertTrue(section.isCurrentSelected)
        XCTAssertFalse(section.isIncomingSelected)
        XCTAssertEqual(section.resolvedText, "current\n")

        section.setIncomingSelected(true)

        XCTAssertTrue(section.isCurrentSelected)
        XCTAssertTrue(section.isIncomingSelected)
        XCTAssertEqual(section.resolution, .both)
        XCTAssertEqual(section.resolvedText, "current\nincoming\n")

        section.setCurrentSelected(false)

        XCTAssertFalse(section.isCurrentSelected)
        XCTAssertTrue(section.isIncomingSelected)
        XCTAssertEqual(section.resolution, .incoming)
        XCTAssertEqual(section.resolvedText, "incoming\n")

        section.setCurrentSelected(true)
        section.setIncomingSelected(false)

        XCTAssertTrue(section.isCurrentSelected)
        XCTAssertFalse(section.isIncomingSelected)
        XCTAssertEqual(section.resolution, .current)
        XCTAssertEqual(section.resolvedText, "current\n")
    }

    func testConflictSelectionCanClearBothSides() {
        var section = ConflictResolutionSection.conflict(
            current: "current\n",
            incoming: "incoming\n"
        )

        section.setCurrentSelected(false)

        XCTAssertFalse(section.isCurrentSelected)
        XCTAssertFalse(section.isIncomingSelected)
        XCTAssertEqual(section.resolution, .manual)
        XCTAssertEqual(section.resolvedText, "")
    }
}
