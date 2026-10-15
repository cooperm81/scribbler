import AppKit

/// Uses NSLayoutManager temporary attributes: syntax colors never change saved text or undo history.
enum SyntaxHighlighter {
    static let languages = ["Auto", "Plain Text", "JSON", "XML", "Markdown", "Swift", "Python", "JavaScript", "HTML", "CSS"]

    static func detect(_ url: URL?) -> String {
        switch url?.pathExtension.lowercased() ?? "" {
        case "json", "jsonl": return "JSON"
        case "xml", "plist", "svg": return "XML"
        case "md", "markdown": return "Markdown"
        case "swift": return "Swift"
        case "py": return "Python"
        case "js", "mjs", "ts", "jsx", "tsx": return "JavaScript"
        case "html", "htm": return "HTML"
        case "css", "scss": return "CSS"
        default: return "Plain Text"
        }
    }

    static func apply(to editor: NSTextView, language: String) {
        guard language != "Plain Text", let layout = editor.layoutManager else { return }
        let source = editor.string as NSString
        let whole = NSRange(location: 0, length: source.length)
        func mark(_ pattern: String, color: NSColor, options: NSRegularExpression.Options = []) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return }
            for match in regex.matches(in: editor.string, range: whole) {
                layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: match.range)
            }
        }
        let blue = NSColor.systemBlue
        let red = NSColor.systemRed
        let purple = NSColor.systemPurple
        let gray = NSColor.secondaryLabelColor
        let keywords = #"\b(?:func|let|var|if|else|guard|return|class|struct|enum|import|public|private|static|for|while|in|def|from|as|elif|pass|lambda|async|await|try|except|finally|raise|with|yield|const|function|new|export|default|switch|case|break|continue|throw|catch)\b"#
        switch language {
        case "JSON":
            mark(#"\b(?:true|false|null)\b"#, color: purple)
            mark(#"-?\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b"#, color: purple)
            mark(#""(?:\\.|[^"\\])*""#, color: red)
            mark(#""(?:\\.|[^"\\])*"(?=\s*:)"#, color: blue)
        case "XML", "HTML":
            mark(#"<!--[\s\S]*?-->"#, color: gray)
            mark(#"</?[A-Za-z][\w:.-]*"#, color: blue)
            mark(#"\b[A-Za-z_:][\w:.-]*(?=\s*=)"#, color: purple)
            mark(#""[^"\n]*"|'[^'\n]*'"#, color: red)
        case "Markdown":
            mark(#"(?m)^\s{0,3}#{1,6}\s+.*$"#, color: blue)
            mark(#"(?m)^\s{0,3}(?:>|[-*+]\s|\d+\.\s)"#, color: purple)
            mark(#"`[^`\n]+`"#, color: red)
            mark(#"\[[^]\n]+\]\([^)\n]+\)"#, color: blue)
        case "CSS":
            mark(#"/\*[\s\S]*?\*/"#, color: gray)
            mark(#"(?m)[\w-]+(?=\s*:)"#, color: blue)
            mark(#"#[0-9a-fA-F]{3,8}\b|\b\d+(?:px|em|rem|%)?\b"#, color: purple)
            mark(#""[^"\n]*"|'[^'\n]*'"#, color: red)
        default:
            mark(keywords, color: blue)
            mark(#"\b(?:true|false|nil|None|True|False|null|undefined|self|this)\b|\b\d+(?:\.\d+)?\b"#, color: purple)
            mark(#""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#, color: red)
            mark(#"(?m)//.*$|#.*$"#, color: gray)
            if language == "Swift" || language == "JavaScript" { mark(#"/\*[\s\S]*?\*/"#, color: gray) }
        }
    }
}
