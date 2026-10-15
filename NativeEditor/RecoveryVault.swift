import Foundation

// Recovery copies never overwrite the user's original files.
// Documents restored from recovery are untitled until explicitly saved.
struct RecoveryEntry: Codable {
    let title: String
    let text: String
    let savedText: String
}
struct RecoverySnapshot: Codable {
    let documents: [RecoveryEntry]
}

final class RecoveryVault {
    private let overrideURL: URL?

    init(fileURL: URL? = nil) {
        overrideURL = fileURL
    }

    private var fileURL: URL {
        if let overrideURL { return overrideURL }
        let directory = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
            .appendingPathComponent("Scribbler", isDirectory: true)
        return directory.appendingPathComponent("Recovery.json")
    }

    func read() -> RecoverySnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(RecoverySnapshot.self, from: data)
    }

    func write(_ snapshot: RecoverySnapshot) throws {
        let url = fileURL
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
