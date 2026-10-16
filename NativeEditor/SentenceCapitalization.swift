import Foundation

/// Pure text-context logic used only for single-character keyboard insertion.
enum SentenceCapitalization {
    private static let abbreviations: Set<String> = [
        "mr", "mrs", "ms", "dr", "prof", "sr", "jr", "st", "vs",
        "etc", "e.g", "i.e", "fig", "no", "dept"
    ]

    static func shouldCapitalize(after prefix: String) -> Bool {
        if prefix.isEmpty { return true }
        // A new paragraph is a new sentence, even without a period.
        if let newline = prefix.lastIndex(of: "\n"),
           prefix[prefix.index(after: newline)...].allSatisfy({ $0.isWhitespace }) {
            return true
        }
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        // Only sentence punctuation followed by whitespace can trigger a change.
        guard prefix.last?.isWhitespace == true else { return false }
        let ending = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’)]}"))
        guard let punctuation = ending.last, ".!?".contains(punctuation) else { return false }
        if punctuation == "." {
            let beforeDot = ending.dropLast()
            let word = String(beforeDot.reversed().prefix(while: {
                $0.isLetter || $0 == "."
            }).reversed()).lowercased()
            if abbreviations.contains(word) { return false }
            // Avoid treating initials like "J. Smith" as a new sentence.
            if word.count == 1 { return false }
        }
        return true
    }
}
