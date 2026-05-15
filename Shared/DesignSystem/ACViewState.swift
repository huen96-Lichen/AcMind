import Foundation

enum ACViewState: Equatable {
    case idle
    case loading
    case empty
    case error(message: String)
    case content

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var isEmpty: Bool {
        if case .empty = self { return true }
        return false
    }
}
