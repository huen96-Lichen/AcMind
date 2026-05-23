import Foundation

enum WorkbenchDocumentUtilities {
    static func loadDocuments(
        storageKey: String,
        fallbackDocuments: [WorkbenchDocument]
    ) -> [WorkbenchDocument] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WorkbenchDocument].self, from: data) else {
            return fallbackDocuments
        }

        return decoded.isEmpty ? fallbackDocuments : decoded
    }

    static func persistDocuments(_ documents: [WorkbenchDocument], storageKey: String) {
        if let encoded = try? JSONEncoder().encode(documents) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}
