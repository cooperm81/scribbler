import SwiftUI
import AppKit

struct EditorView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var sidebarWidth: CGFloat = 230
    @State private var dragStartWidth: CGFloat?
    @State private var cursorLine = 1
    @State private var cursorColumn = 1
    @AppStorage("editorUseSpaces") private var useSpaces = true
    @AppStorage("editorIndentWidth") private var indentWidth = 4
    @AppStorage("editorTabBehavior") private var tabBehavior = "insert"

    @AppStorage("editorEmacsKeyBindings") private var emacsKeyBindings = false
    @AppStorage("editorAutoCapitalizeSentences") private var autoCapitalizeSentences = false
    @AppStorage("editorFontSize") private var fontSize = 13.0
    @AppStorage("editorLineWrap") private var lineWrap = true
    @AppStorage("editorShowLineNumbers") private var showLineNumbers = true
    @State private var language = "Auto"
    @AppStorage("editorMarkdownPreviewVisible") private var showMarkdownPreview = false
    @State private var showFindReplace = false
    @State private var showReplaceControls = false
    @FocusState private var findFieldFocused: Bool
    @State private var findText = ""
    @State private var replacementText = ""
    @State private var caseSensitive = false
    @State private var wholeWord = false
    @State private var regex = false
    @State private var searchAction = SearchAction.idle

    private func openSearch(replacing: Bool) {
        showFindReplace = true
        showReplaceControls = replacing
        // Focus is requested after the field enters the view hierarchy.
        DispatchQueue.main.async { findFieldFocused = true }
    }

    private func useSelectionForFind() {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView {
            let selected = editor.selectedRange()
            let source = editor.string as NSString
            if selected.length > 0, NSMaxRange(selected) <= source.length {
                findText = source.substring(with: selected)
            }
        }
        openSearch(replacing: false)
    }

    private func search(_ kind: SearchAction.Kind) {
        searchAction = SearchAction(id: UUID(), kind: kind, query: findText,
                                    replacement: replacementText, caseSensitive: caseSensitive,
                                    wholeWord: wholeWord, regex: regex)
    }

    private var activeText: String { store.active?.text ?? "" }
    private var wordCount: Int { activeText.split(whereSeparator: { $0.isWhitespace }).count }
    private var activeBinding: Binding<String> {
        let id = store.activeID
        return Binding(get: { guard let id = id else { return "" }; return store.documents.first(where: { $0.id == id })?.text ?? "" },
                       set: { value in if let id = id { store.updateText(value, id: id) } })
    }
    private func workspaceCommand(_ command: String) {
        switch command {
        case "new": store.newDocument()
        case "open": store.openDocument()
        case "save": _ = store.save()
        case "saveAs": _ = store.save(saveAs: true)
        case "close": if let id = store.activeID { store.close(id: id) }
        case "nextDocument": store.cycleDocument(1)
        case "previousDocument": store.cycleDocument(-1)
        case "togglePane": store.showDocuments.toggle()
        case "togglePreview": showMarkdownPreview.toggle()
        case "quit": NSApp.terminate(nil)
        default: break
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            if store.showDocuments {
                VStack(spacing: 0) {
                    HStack {
                        Text("Currently Open Documents")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button { store.showDocuments = false } label: { Image(systemName: "sidebar.left") }
                            .buttonStyle(.borderless).help("Hide Open Documents")
                    }
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    Divider()
                    List(selection: $store.activeID) {
                        ForEach(store.documents) { doc in
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.secondary)
                                Text(doc.title).lineLimit(1)
                                Spacer(minLength: 2)
                                if doc.modified { Circle().fill(Color.secondary).frame(width: 6, height: 6) }
                                Button { store.close(id: doc.id) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless).help("Close \(doc.title)")
                            }
                            .tag(doc.id)
                        }
                    }
                    .listStyle(.sidebar)
                }
                .frame(width: sidebarWidth)
                Rectangle().fill(Color(nsColor: .separatorColor))
                    .frame(width: 4)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragStartWidth == nil { dragStartWidth = sidebarWidth }
                            sidebarWidth = min(450, max(160, (dragStartWidth ?? 230) + value.translation.width))
                        }
                        .onEnded { _ in dragStartWidth = nil })
            }
            VStack(spacing: 0) {
                if !store.showDocuments {
                    HStack {
                        Button { store.showDocuments = true } label: { Image(systemName: "sidebar.left") }
                            .buttonStyle(.borderless).help("Show Open Documents")
                        Text(store.active?.title ?? "Untitled").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                    }.padding(.horizontal, 12).padding(.vertical, 5)
                }
                if showFindReplace {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            TextField("Find", text: $findText)
                                .textFieldStyle(.roundedBorder)
                                .focused($findFieldFocused)
                                .onSubmit { search(.next) }
                            Button("Previous") { search(.previous) }.disabled(findText.isEmpty)
                            Button("Next") { search(.next) }.disabled(findText.isEmpty)
                            Button { showFindReplace = false } label: { Image(systemName: "xmark") }
                                .buttonStyle(.borderless).help("Close Find and Replace")
                        }
                        if showReplaceControls {
                        HStack(spacing: 8) {
                            TextField("Replace with", text: $replacementText)
                                .textFieldStyle(.roundedBorder)
                            Button("Replace") { search(.replace) }.disabled(findText.isEmpty)
                            Button("Replace All") { search(.replaceAll) }.disabled(findText.isEmpty)
                        }
                        }
                        HStack(spacing: 14) {
                            Toggle("Match case", isOn: $caseSensitive)
                            Toggle("Whole word", isOn: $wholeWord)
                            Toggle("Regular expression", isOn: $regex)
                        }
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    }
                    .padding(10)
                    Divider()
                }
                HStack(spacing: 0) {
                    NativeTextEditor(text: activeBinding, line: $cursorLine, column: $cursorColumn,
                                 useSpaces: useSpaces, indentWidth: indentWidth, tabBehavior: tabBehavior, emacsKeyBindings: emacsKeyBindings,
                                 autoCapitalizeSentences: autoCapitalizeSentences,
                                 fontSize: fontSize, lineWrap: lineWrap, showLineNumbers: showLineNumbers,
                                 language: language == "Auto" ? SyntaxHighlighter.detect(store.active?.url) : language,
                                 searchAction: searchAction,
                                 onOpen: { workspaceCommand("open") },
                                 onSave: { workspaceCommand("save") },
                                 onSaveAs: { workspaceCommand("saveAs") },
                                 onQuit: { workspaceCommand("quit") },
                                 onNextDocument: { workspaceCommand("nextDocument") },
                                 onPreviousDocument: { workspaceCommand("previousDocument") })
                    .id(store.activeID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if showMarkdownPreview {
                        Divider()
                        MarkdownPreviewView(source: activeText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .clipped()
                Divider()
                HStack(spacing: 14) {
                    Text("Ln \(cursorLine), Col \(cursorColumn)")
                    Text("\(wordCount) words")
                    Text("\(activeText.count) characters")
                    Spacer()
                    Menu {
                        Toggle("Indent using spaces", isOn: $useSpaces)
                        Picker("Indent width", selection: $indentWidth) {
                            Text("2").tag(2)
                            Text("4").tag(4)
                            Text("8").tag(8)
                        }
                    } label: {
                        Text(useSpaces ? "Spaces: \(indentWidth)" : "Tabs")
                    }.menuStyle(.borderlessButton)
                    Menu {
                        ForEach(SyntaxHighlighter.languages, id: \.self) { name in
                            Button(name) { language = name }
                        }
                    } label: {
                        Text(language == "Auto" ? SyntaxHighlighter.detect(store.active?.url) : language)
                    }.menuStyle(.borderlessButton)
                    Text("UTF-8")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .zIndex(2)
            }
        }
        .frame(minWidth: 560, minHeight: 360)
        .onReceive(NotificationCenter.default.publisher(for: .scribblerWorkspaceCommand)) { notification in
            guard let command = notification.object as? String else { return }
            workspaceCommand(command)
        }
        .onReceive(NotificationCenter.default.publisher(for: .scribblerFindCommand)) { notification in
            guard let command = notification.object as? String else { return }
            switch command {
            case "find": openSearch(replacing: false)
            case "replace": openSearch(replacing: true)
            case "next": search(.next)
            case "previous": search(.previous)
            case "selection": useSelectionForFind()
            default: break
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { showMarkdownPreview.toggle() } label: {
                    Image(systemName: "rectangle.split.2x1")
                }.help(showMarkdownPreview ? "Hide Markdown Preview" : "Show Markdown Preview")
                Button { openSearch(replacing: false) } label: {
                    Image(systemName: "magnifyingglass")
                }.help("Find (⌘F)")
                Menu {
                    Toggle("Show Line Numbers", isOn: $showLineNumbers)
                    Toggle("Wrap Lines", isOn: $lineWrap)
                    Toggle("Emacs Key Bindings", isOn: $emacsKeyBindings)
                    Divider()
                    Button("Increase Font Size") { fontSize = min(36, fontSize + 1) }
                    Button("Decrease Font Size") { fontSize = max(9, fontSize - 1) }
                    Text("Font: \(Int(fontSize)) pt")
                } label: { Image(systemName: "textformat.size") }
                .help("Editor Appearance")
            }
            ToolbarItem(placement: .navigation) {
                Button { store.showDocuments.toggle() } label: { Image(systemName: "sidebar.left") }
                    .help(store.showDocuments ? "Hide Open Documents" : "Show Open Documents")
            }
        }
    }
}

