import Foundation

struct ConflictCodeLine: Equatable {
    let lineNumber: Int?
    let text: String
    let isConflict: Bool
    let isPlaceholder: Bool
    let conflictSectionIndex: Int?
    let startsConflict: Bool

    static func actual(
        lineNumber: Int,
        text: String,
        isConflict: Bool,
        conflictSectionIndex: Int? = nil,
        startsConflict: Bool = false
    ) -> ConflictCodeLine {
        ConflictCodeLine(
            lineNumber: lineNumber,
            text: text,
            isConflict: isConflict,
            isPlaceholder: false,
            conflictSectionIndex: conflictSectionIndex,
            startsConflict: startsConflict
        )
    }

    static func placeholder(
        isConflict: Bool,
        conflictSectionIndex: Int? = nil,
        startsConflict: Bool = false
    ) -> ConflictCodeLine {
        ConflictCodeLine(
            lineNumber: nil,
            text: "",
            isConflict: isConflict,
            isPlaceholder: true,
            conflictSectionIndex: conflictSectionIndex,
            startsConflict: startsConflict
        )
    }
}
