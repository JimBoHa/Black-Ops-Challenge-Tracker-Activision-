import Foundation

enum ActivisionServiceError: LocalizedError {
    case unsupported
    case invalidSession
    var errorDescription: String? {
        switch self {
        case .unsupported: "Activision does not expose challenge progress through a supported public API. Manual tracking remains available."
        case .invalidSession: "Activision session is invalid or expired."
        }
    }
}

actor ActivisionService {
    private let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func verifySession(token: String) async throws -> String {
        guard !token.isEmpty else { throw ActivisionServiceError.invalidSession }
        // Deliberately no private/undocumented endpoint call. Add an authorized API here when Activision grants access.
        throw ActivisionServiceError.unsupported
    }
}
