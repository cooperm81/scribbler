import Foundation

@main
struct SentenceCapitalizationTests {
    static func expect(_ condition: Bool, _ message: String) {
        if !condition { fatalError(message) }
    }
    static func main() {
        expect(SentenceCapitalization.shouldCapitalize(after: ""), "Start of document")
        expect(SentenceCapitalization.shouldCapitalize(after: "hello. "), "Period + space")
        expect(SentenceCapitalization.shouldCapitalize(after: "hello!  "), "Exclamation + spaces")
        expect(SentenceCapitalization.shouldCapitalize(after: "hello?\n"), "Question + newline")
        expect(SentenceCapitalization.shouldCapitalize(after: "paragraph\n"), "New paragraph")
        expect(!SentenceCapitalization.shouldCapitalize(after: "hello"), "Mid-word")
        expect(!SentenceCapitalization.shouldCapitalize(after: "3."), "Decimal point without space")
        expect(!SentenceCapitalization.shouldCapitalize(after: "Dr. "), "Abbreviation")
        expect(!SentenceCapitalization.shouldCapitalize(after: "J. "), "Initial")
        expect(!SentenceCapitalization.shouldCapitalize(after: "hello, "), "Comma")
        print("Sentence capitalization tests passed")
    }
}
