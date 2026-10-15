import SwiftUI
import UniformTypeIdentifiers

struct PlainTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText, .utf8PlainText, .text] }
    static var writableContentTypes: [UTType] { [.plainText, .utf8PlainText] }
    var text = ""
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        guard let value = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
        text = value
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
