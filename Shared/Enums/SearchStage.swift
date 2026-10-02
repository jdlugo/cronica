import Foundation

enum SearchStage: String {
    var id: String { rawValue }
    case none, failure, empty, success, searching
}
