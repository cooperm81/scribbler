import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct OpenDocument: Identifiable {
    let id: UUID
    var url: URL?
    var text: String
    var savedText: String
    var hasSecurityScope: Bool
    var recoveryTitle: String?
    var title: String { url?.lastPathComponent ?? recoveryTitle ?? "Untitled" }
    var modified: Bool { text != savedText }
    init(url: URL? = nil, text: String = "", hasSecurityScope: Bool = false) {
        id = UUID()
        self.url = url
        self.text = text
        self.savedText = text
        self.hasSecurityScope = hasSecurityScope
        self.recoveryTitle = nil
    }
}

final class WorkspaceStore: ObservableObject {
    @Published var documents: [OpenDocument] = [OpenDocument()]
    @Published var activeID: UUID?
    @Published var showDocuments = UserDefaults.standard.object(forKey: "scribblerShowOpenDocuments") as? Bool ?? true {
        didSet { UserDefaults.standard.set(showDocuments, forKey: "scribblerShowOpenDocuments") }
    }

    private var pendingSnapshot: DispatchWorkItem?
    private let recovery = RecoveryVault()

    init() {
        activeID = documents.first?.id
        if let snapshot = recovery.read(), !snapshot.documents.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Recover unsaved Scribbler documents?"
            alert.informativeText = "Scribbler found locally preserved edits. Restore them as unsaved documents, or discard the recovery copies. Original files will not be overwritten."
            alert.addButton(withTitle: "Restore")
            alert.addButton(withTitle: "Discard")
            if alert.runModal() == .alertFirstButtonReturn {
                documents = snapshot.documents.map { item in
                    var doc = OpenDocument(text: item.text)
                    doc.recoveryTitle = "Recovered — " + item.title
                    doc.savedText = item.savedText
                    return doc
                }
                activeID = documents.first?.id
                scheduleRecovery()
            } else {
                recovery.clear()
            }
        }
    }

    private func scheduleRecovery() {
        pendingSnapshot?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.flushRecovery() }
        pendingSnapshot = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: task)
    }

    func flushRecovery() {
        pendingSnapshot?.cancel()
        pendingSnapshot = nil
        let entries = documents.filter(\.modified).map {
            RecoveryEntry(title: $0.title, text: $0.text, savedText: $0.savedText)
        }
        if entries.isEmpty { recovery.clear() }
        else {
            do { try recovery.write(RecoverySnapshot(documents: entries)) }
            catch { NSLog("Scribbler recovery write failed: %@", String(describing: error)) }
        }
    }

    func finishCleanQuit() {
        pendingSnapshot?.cancel()
        pendingSnapshot = nil
        recovery.clear()
    }

    var activeIndex: Int? { documents.firstIndex(where: { $0.id == activeID }) }
    var active: OpenDocument? { guard let i = activeIndex else { return nil }; return documents[i] }
    func updateText(_ value: String, id: UUID) {
        guard let i = documents.firstIndex(where: { $0.id == id }), documents[i].text != value else { return }
        documents[i].text = value
        scheduleRecovery()
    }
    func newDocument() {
        let doc = OpenDocument()
        documents.append(doc)
        activeID = doc.id
        scheduleRecovery()
    }
    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text, .utf8PlainText, .json, .xml, .sourceCode]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let existing = documents.first(where: { $0.url?.standardizedFileURL == url.standardizedFileURL }) {
                activeID = existing.id
                continue
            }
            let scoped = url.startAccessingSecurityScopedResource()
            do {
                let data = try Data(contentsOf: url)
                guard let value = String(data: data, encoding: .utf8) else {
                    throw CocoaError(.fileReadInapplicableStringEncoding)
                }
                let doc = OpenDocument(url: url, text: value, hasSecurityScope: scoped)
                documents.append(doc)
                activeID = doc.id
            } catch {
                if scoped { url.stopAccessingSecurityScopedResource() }
                NSAlert(error: error).runModal()
            }
        }
    }
    @discardableResult func save(id: UUID? = nil, saveAs: Bool = false) -> Bool {
        guard let id = id ?? activeID, let index = documents.firstIndex(where: { $0.id == id }) else { return false }
        let doc = documents[index]
        var target = doc.url
        if saveAs || target == nil {
            let panel = NSSavePanel()
            panel.nameFieldStringValue = doc.url?.lastPathComponent ?? "Untitled.txt"
            panel.allowedContentTypes = [.plainText]
            guard panel.runModal() == .OK, let selected = panel.url else { return false }
            if documents.contains(where: { $0.id != id && $0.url?.standardizedFileURL == selected.standardizedFileURL }) {
                let alert = NSAlert()
                alert.messageText = "This file is already open in Scribbler."
                alert.informativeText = "Close the other document before saving to this location."
                alert.runModal()
                return false
            }
            target = selected
        }
        guard let url = target else { return false }
        let newScope = (url != doc.url) ? url.startAccessingSecurityScopedResource() : false
        do {
            try Data(doc.text.utf8).write(to: url, options: .atomic)
            guard let updated = documents.firstIndex(where: { $0.id == id }) else { return false }
            if documents[updated].hasSecurityScope, let old = documents[updated].url, old != url {
                old.stopAccessingSecurityScopedResource()
            }
            documents[updated].url = url
            documents[updated].hasSecurityScope = url == doc.url ? doc.hasSecurityScope : newScope
            documents[updated].savedText = documents[updated].text
            documents[updated].recoveryTitle = nil
            scheduleRecovery()
            return true
        } catch {
            if newScope { url.stopAccessingSecurityScopedResource() }
            NSAlert(error: error).runModal()
            return false
        }
    }
    func canClose(id: UUID) -> Bool {
        guard let doc = documents.first(where: { $0.id == id }), doc.modified else { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(doc.title)?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")
        switch alert.runModal() {
        case .alertFirstButtonReturn: return save(id: id)
        case .alertThirdButtonReturn: return true
        default: return false
        }
    }
    func close(id: UUID) {
        guard canClose(id: id), let i = documents.firstIndex(where: { $0.id == id }) else { return }
        let doc = documents.remove(at: i)
        if doc.hasSecurityScope { doc.url?.stopAccessingSecurityScopedResource() }
        if activeID == id { activeID = documents.isEmpty ? nil : documents[min(i, documents.count - 1)].id }
        if documents.isEmpty { newDocument() }
        scheduleRecovery()
    }
    func canQuit() -> Bool {
        for doc in documents where doc.modified {
            if !canClose(id: doc.id) { return false }
        }
        return true
    }
}
