import Foundation

enum ConflictPaneSelectionSide {
    case incoming
    case current

    var title: String {
        switch self {
        case .incoming:
            return "Incoming"
        case .current:
            return "Current"
        }
    }
}
