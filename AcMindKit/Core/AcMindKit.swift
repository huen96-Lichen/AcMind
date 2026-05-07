import Foundation

public final class AcMindKit {
    public static let shared = AcMindKit()

    public let storageService: StorageServiceProtocol

    private init() {
        self.storageService = StorageService()
    }
}
