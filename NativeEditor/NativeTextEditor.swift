import AppKit
import SwiftUI

/// AppKit-backed text editor: the gutter is an actual vertical ruler on the scroll view.
struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var line: Int
    @Binding var column: Int
    var useSpaces: Bool
    var indentWidth: Int
    var tabBehavior: String
    var emacsKeyBindings: Bool
    var fontSize: Double
    var lineWrap: Bool
    var showLineNumbers: Bool
    var language: String
    var searchAction: SearchAction
    var onOpen: () -> Void
    var onSave: () -> Void
    var onSaveAs: () -> Void
    var onQuit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = !lineWrap
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder

        let storage = NSTextStorage()
        let manager = NSLayoutManager()
        storage.addLayoutManager(manager)
        let container = NSTextContainer(size: NSSize(width: 1000, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = lineWrap
        manager.addTextContainer(container)

        let editor = IndentingTextView(frame: .zero, textContainer: container)
        editor.isRichText = false
        editor.importsGraphics = false
        editor.isEditable = true
        editor.isSelectable = true
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: NSFont.Weight.regular)
        editor.textColor = NSColor.textColor
        editor.backgroundColor = NSColor.textBackgroundColor
        editor.drawsBackground = true
        editor.textContainerInset = NSSize(width: 10, height: 10)
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = !lineWrap
        editor.autoresizingMask = NSView.AutoresizingMask.width
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.delegate = context.coordinator
        editor.string = text
        editor.useSpaces = useSpaces
        editor.indentWidth = indentWidth
        editor.tabBehavior = tabBehavior
        editor.emacsKeyBindings = emacsKeyBindings
        editor.onOpen = onOpen
        editor.onSave = onSave
        editor.onSaveAs = onSaveAs
        editor.onQuit = onQuit
        scroll.documentView = editor

        let ruler = LineNumberRuler(textView: editor, scrollView: scroll)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = showLineNumbers
        context.coordinator.editor = editor
        context.coordinator.ruler = ruler
        context.coordinator.updateCursor()
        context.coordinator.highlight()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = context.coordinator.editor else { return }
        editor.useSpaces = useSpaces
        editor.indentWidth = indentWidth
        editor.tabBehavior = tabBehavior
        editor.emacsKeyBindings = emacsKeyBindings
        editor.onOpen = onOpen
        editor.onSave = onSave
        editor.onSaveAs = onSaveAs
        editor.onQuit = onQuit
        editor.font = NSFont.monospacedSystemFont(ofSize: CGFloat(fontSize), weight: .regular)
        scroll.rulersVisible = showLineNumbers
        scroll.hasHorizontalScroller = !lineWrap
        editor.textContainer?.widthTracksTextView = lineWrap
        editor.isHorizontallyResizable = !lineWrap
        if !lineWrap { editor.textContainer?.containerSize = NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude) }
        if editor.string != text {
            let oldSelection = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(oldSelection.location, (text as NSString).length), length: 0))
            context.coordinator.ruler?.needsDisplay = true
        }
        if context.coordinator.lastSearchID != searchAction.id {
            context.coordinator.lastSearchID = searchAction.id
            context.coordinator.executeSearch(searchAction)
        }
        context.coordinator.highlight()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        weak var editor: IndentingTextView?
        weak var ruler: LineNumberRuler?
        var lastSearchID = UUID()
        init(_ parent: NativeTextEditor) { self.parent = parent }

        func executeSearch(_ action: SearchAction) {
            guard let editor, !action.query.isEmpty else { return }
            let original = editor.string as NSString
            let pattern = (action.wholeWord ? "\\b(?:" : "") +
                (action.regex ? action.query : NSRegularExpression.escapedPattern(for: action.query)) +
                (action.wholeWord ? ")\\b" : "")
            let options: NSRegularExpression.Options = action.caseSensitive ? [] : [.caseInsensitive]
            guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
                NSSound.beep()
                return
            }
            let matches = expression.matches(in: editor.string, range: NSRange(location: 0, length: original.length))
            let selected = editor.selectedRange()
            switch action.kind {
            case .next, .previous:
                guard !matches.isEmpty else { NSSound.beep(); return }
                let chosen: NSTextCheckingResult?
                if action.kind == .next {
                    chosen = matches.first(where: { $0.range.location >= NSMaxRange(selected) }) ?? matches.first
                } else {
                    chosen = matches.last(where: { NSMaxRange($0.range) <= selected.location }) ?? matches.last
                }
                if let chosen {
                    editor.setSelectedRange(chosen.range)
                    editor.scrollRangeToVisible(chosen.range)
                    editor.window?.makeFirstResponder(editor)
                }
            case .replace:
                guard let match = matches.first(where: { $0.range == selected }) else {
                    // First find a match; do not replace unrelated selected text.
                    if let next = matches.first(where: { $0.range.location >= NSMaxRange(selected) }) ?? matches.first {
                        editor.setSelectedRange(next.range)
                        editor.scrollRangeToVisible(next.range)
                    }
                    return
                }
                let replacement = action.regex ? expression.replacementString(for: match, in: editor.string, offset: 0, template: action.replacement) : action.replacement
                if editor.shouldChangeText(in: match.range, replacementString: replacement) {
                    editor.textStorage?.replaceCharacters(in: match.range, with: replacement)
                    editor.didChangeText()
                    let newPos = match.range.location + (replacement as NSString).length
                    editor.setSelectedRange(NSRange(location: newPos, length: 0))
                }
            case .replaceAll:
                guard !matches.isEmpty else { return }
                // One full-document edit gives a single undoable replacement transaction.
                let newText: String
                if action.regex {
                    newText = expression.stringByReplacingMatches(in: editor.string, range: NSRange(location: 0, length: original.length), withTemplate: action.replacement)
                } else {
                    let mutable = NSMutableString(string: editor.string)
                    for match in matches.reversed() { mutable.replaceCharacters(in: match.range, with: action.replacement) }
                    newText = mutable as String
                }
                let range = NSRange(location: 0, length: original.length)
                if editor.shouldChangeText(in: range, replacementString: newText) {
                    editor.textStorage?.replaceCharacters(in: range, with: newText)
                    editor.didChangeText()
                }
            }
        }
        func textDidChange(_ notification: Notification) {
            guard let editor else { return }
            parent.text = editor.string
            ruler?.needsDisplay = true
            highlight()
            updateCursor()
        }
        func highlight() {
            guard let editor, let layout = editor.layoutManager else { return }
            let full = NSRange(location: 0, length: (editor.string as NSString).length)
            layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
            SyntaxHighlighter.apply(to: editor, language: parent.language)
        }
        func textViewDidChangeSelection(_ notification: Notification) { updateCursor() }
        func updateCursor() {
            guard let editor else { return }
            let source = editor.string as NSString
            let index = min(editor.selectedRange().location, source.length)
            let prefix = source.substring(to: index)
            let pieces = prefix.components(separatedBy: "\n")
            let newLine = pieces.count
            let newColumn = (pieces.last ?? "" as String).count + 1
            if parent.line != newLine { parent.line = newLine }
            if parent.column != newColumn { parent.column = newColumn }
        }
    }
}

final class IndentingTextView: NSTextView {
    var useSpaces = true
    var indentWidth = 4
    var tabBehavior = "insert"
    var emacsKeyBindings = false
    var onOpen: (() -> Void)?
    var onSave: (() -> Void)?
    var onSaveAs: (() -> Void)?
    var onQuit: (() -> Void)?
    private var killedText = ""
    private var awaitingControlXCommand = false

    // Emacs mode is opt-in. Only unmodified Control+letter shortcuts are
    // intercepted. Command/Option shortcuts continue through AppKit unchanged.
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if !emacsKeyBindings { awaitingControlXCommand = false }
        if emacsKeyBindings && awaitingControlXCommand {
            awaitingControlXCommand = false
            if flags == .control, let key = event.charactersIgnoringModifiers?.lowercased() {
                switch key {
                case "f": onOpen?() // C-x C-f
                case "s": onSave?() // C-x C-s
                case "w": onSaveAs?() // C-x C-w
                case "c": onQuit?() // C-x C-c
                default: NSSound.beep()
                }
            } else {
                NSSound.beep()
            }
            return
        }
        if emacsKeyBindings && flags == .control,
           let key = event.charactersIgnoringModifiers?.lowercased() {
            switch key {
            case "x": awaitingControlXCommand = true
            case "a": moveToBeginningOfLine(nil)
            case "e": moveToEndOfLine(nil)
            case "f": moveForward(nil)
            case "b": moveBackward(nil)
            case "n": moveDown(nil)
            case "p": moveUp(nil)
            case "d": deleteForward(nil)
            case "h": deleteBackward(nil)
            case "k": killToEndOfLine()
            case "y": yank()
            default: super.keyDown(with: event); return
            }
            return
        }
        super.keyDown(with: event)
    }

    private func killToEndOfLine() {
        let source = string as NSString
        let selection = selectedRange()
        guard selection.location <= source.length else { return }
        var range = selection
        if range.length == 0 {
            let lineRange = source.lineRange(for: NSRange(location: range.location, length: 0))
            let lineEnd = NSMaxRange(lineRange)
            var contentEnd = lineEnd
            // First kill the rest of the current line; if already at the end,
            // kill the line break (Emacs' familiar two-stage Ctrl-K behavior).
            while contentEnd > lineRange.location {
                let c = source.character(at: contentEnd - 1)
                if c == 10 || c == 13 { contentEnd -= 1 } else { break }
            }
            let end = range.location < contentEnd ? contentEnd : lineEnd
            range = NSRange(location: range.location, length: max(0, end - range.location))
        }
        guard range.length > 0 else { return }
        let value = source.substring(with: range)
        guard shouldChangeText(in: range, replacementString: "") else { return }
        killedText = value
        textStorage?.replaceCharacters(in: range, with: "")
        didChangeText()
        setSelectedRange(NSRange(location: range.location, length: 0))
    }

    private func yank() {
        guard !killedText.isEmpty else { return }
        insertText(killedText, replacementRange: selectedRange())
    }

    override func insertNewline(_ sender: Any?) {
        let ns = string as NSString
        let caret = min(selectedRange().location, ns.length)
        let preceding = ns.substring(to: caret)
        let line = preceding.components(separatedBy: "\n").last ?? ""
        let indentation = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
        insertText("\n" + indentation, replacementRange: selectedRange())
    }
    override func insertTab(_ sender: Any?) {
        if tabBehavior == "line" {
            changeLineIndent(outdent: false)
        } else {
            insertText(useSpaces ? String(repeating: " ", count: max(1, indentWidth)) : "\t",
                       replacementRange: selectedRange())
        }
    }

    override func insertBacktab(_ sender: Any?) {
        if tabBehavior == "line" { changeLineIndent(outdent: true) }
        // In insert mode Shift-Tab deliberately does nothing.
    }

    private func changeLineIndent(outdent: Bool) {
        let source = string as NSString
        let selection = selectedRange()
        let caret = min(selection.location, source.length)
        let line = source.lineRange(for: NSRange(location: caret, length: 0))
        let prefix = source.substring(with: line)
        let width = max(1, indentWidth)
        let replacement: String
        let range: NSRange
        if outdent {
            if prefix.hasPrefix("\t") {
                range = NSRange(location: line.location, length: 1)
            } else {
                let spaces = prefix.prefix(while: { $0 == " " }).count
                guard spaces > 0 else { return }
                range = NSRange(location: line.location, length: min(spaces, width))
            }
            replacement = ""
        } else {
            range = NSRange(location: line.location, length: 0)
            replacement = useSpaces ? String(repeating: " ", count: width) : "\t"
        }
        guard shouldChangeText(in: range, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
        let delta = (replacement as NSString).length - range.length
        let newLocation = max(line.location, selection.location + delta)
        setSelectedRange(NSRange(location: newLocation, length: selection.length))
    }

}

final class LineNumberRuler: NSRulerView {
    weak var editor: NSTextView?
    private let inset: CGFloat = 12

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.editor = textView
        super.init(scrollView: scrollView, orientation: NSRulerView.Orientation.verticalRuler)
        clientView = textView
        ruleThickness = 48
        NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSText.didChangeNotification, object: textView)
        let clip = scrollView.contentView
        do {
            clip.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(redraw), name: NSView.boundsDidChangeNotification, object: clip)
        }
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { NotificationCenter.default.removeObserver(self) }
    @objc private func redraw() { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        let text = editor.string as NSString
        let lineTotal = max(1, text.components(separatedBy: "\n").count)
        let digits = max(2, String(lineTotal).count)
        let newWidth = max(48, CGFloat(digits) * 9 + inset * 2)
        if abs(ruleThickness - newWidth) > 0.5 { ruleThickness = newWidth }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.secondaryLabelColor]
        // Draw each logical line once, including the empty line after a final newline.
        // Do not clamp the end-of-document index to the preceding glyph: doing so
        // paints the last two line numbers at the same vertical position.
        let visible = editor.visibleRect
        layout.ensureLayout(for: container)
        let source = editor.string as NSString
        let length = source.length
        var lineStart = 0
        var number = 1
        while lineStart <= length {
            let isTrailingEmptyLine = lineStart == length
            let lineRect: NSRect
            if isTrailingEmptyLine && (length == 0 || source.character(at: length - 1) == 10) {
                lineRect = layout.extraLineFragmentRect
            } else {
                let glyph = layout.glyphIndexForCharacter(at: lineStart)
                lineRect = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            }

            // NSTextView coordinates -> ruler coordinates. This also handles
            // scrolling and the text view's inset without manually subtracting
            // visibleRect origins (which can cause stale/overlapping labels).
            let originInRuler = convert(NSPoint(x: 0, y: lineRect.minY + editor.textContainerInset.height), from: editor)
            let y = originInRuler.y + (lineRect.height - font.ascender + font.descender) / 2
            if originInRuler.y + lineRect.height >= bounds.minY && originInRuler.y <= bounds.maxY {
                let label = String(number) as NSString
                let size = label.size(withAttributes: attrs)
                label.draw(at: NSPoint(x: bounds.maxX - inset - size.width, y: y), withAttributes: attrs)
            }
            if lineStart == length { break }
            let rest = NSRange(location: lineStart, length: length - lineStart)
            let newline = source.range(of: "\n", options: [], range: rest)
            if newline.location == NSNotFound { break }
            lineStart = NSMaxRange(newline)
            number += 1
        }
    }
}

// Search commands are immutable snapshots, so each button press runs once.
struct SearchAction {
    enum Kind { case next, previous, replace, replaceAll }
    let id: UUID
    let kind: Kind
    let query: String
    let replacement: String
    let caseSensitive: Bool
    let wholeWord: Bool
    let regex: Bool
    static let idle = SearchAction(id: UUID(), kind: .next, query: "", replacement: "", caseSensitive: false, wholeWord: false, regex: false)
}
