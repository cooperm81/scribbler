import Foundation

@main
struct RecoveryVaultTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScribblerRecoveryTests-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let vault = RecoveryVault(fileURL: root.appendingPathComponent("nested/Recovery.json"))

        // Fresh installation must have no recovery state.
        precondition(vault.read() == nil, "Empty recovery vault should return nil")

        // Multiple edited documents survive a new vault instance (simulated restart).
        let original = RecoverySnapshot(documents: [
            RecoveryEntry(title: "Untitled", text: "draft alpha", savedText: ""),
            RecoveryEntry(title: "notes.md", text: "saved\nnew text", savedText: "saved")
        ])
        try vault.write(original)
        let reopened = RecoveryVault(fileURL: root.appendingPathComponent("nested/Recovery.json"))
        guard let restored = reopened.read() else { fatalError("Recovery data missing") }
        precondition(restored.documents.count == 2, "Expected two restored documents")
        precondition(restored.documents[0].text == "draft alpha", "Untitled content changed")
        precondition(restored.documents[1].savedText == "saved", "Saved baseline changed")
        precondition(restored.documents[1].text == "saved\nnew text", "Unsaved changes lost")

        // New snapshots replace old ones, rather than appending stale documents.
        try vault.write(RecoverySnapshot(documents: [
            RecoveryEntry(title: "notes.md", text: "second revision", savedText: "saved")
        ]))
        precondition(reopened.read()?.documents.count == 1, "Snapshot replacement failed")
        precondition(reopened.read()?.documents.first?.text == "second revision",
                     "Most recent snapshot not persisted")

        // A normal, completed quit or explicit discard clears recovery copies.
        reopened.clear()
        precondition(vault.read() == nil, "Recovery snapshot was not cleared")

        // Invalid data must not crash startup; it remains available for diagnostics.
        let file = root.appendingPathComponent("nested/Recovery.json")
        try Data("invalid JSON".utf8).write(to: file)
        precondition(vault.read() == nil, "Invalid snapshot should not decode")
        precondition(FileManager.default.fileExists(atPath: file.path),
                     "Unreadable recovery data should not be silently deleted")

        print("PASS: 5 recovery vault checks")
    }
}
