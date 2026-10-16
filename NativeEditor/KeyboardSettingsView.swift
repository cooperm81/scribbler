import SwiftUI
import AppKit

enum KeyboardPreferences {
    static let commands: [(id: String, title: String, key: String, modifiers: String)] = [
        ("new", "New Document", "n", "command"),
        ("open", "Open…", "o", "command"),
        ("save", "Save", "s", "command"),
        ("saveAs", "Save As…", "s", "command,shift"),
        ("close", "Close Document", "w", "command"),
        ("find", "Find…", "f", "command"),
        ("replace", "Find and Replace…", "f", "command,option"),
        ("next", "Find Next", "g", "command"),
        ("previous", "Find Previous", "g", "command,shift"),
        ("selection", "Use Selection for Find", "e", "command"),
        ("togglePreview", "Toggle Markdown Preview", "p", "command,option"),
        ("togglePane", "Show/Hide Open Documents", "1", "command,option"),
        ("wordForward", "Move Forward One Word", "f", "option"),
        ("wordBackward", "Move Backward One Word", "b", "option"),
        ("nextDocument", "Next Open Document", "right", ""),
        ("previousDocument", "Previous Open Document", "left", "")
    ]

    static func defaultKey(_ id: String) -> String {
        commands.first(where: { $0.id == id })?.key ?? ""
    }
    static func defaultModifiers(_ id: String) -> String {
        commands.first(where: { $0.id == id })?.modifiers ?? "command"
    }
    static func key(_ id: String) -> String {
        UserDefaults.standard.string(forKey: "shortcut.\(id).key") ?? defaultKey(id)
    }
    static func modifiers(_ id: String) -> EventModifiers {
        let raw = UserDefaults.standard.string(forKey: "shortcut.\(id).modifiers") ?? defaultModifiers(id)
        var result: EventModifiers = []
        for item in raw.split(separator: ",") {
            switch item {
            case "command": result.insert(.command)
            case "shift": result.insert(.shift)
            case "option": result.insert(.option)
            case "control": result.insert(.control)
            default: break
            }
        }
        return result
    }
    static func conflicts(id: String, key: String, modifiers: EventModifiers) -> [String] {
        commands.filter { $0.id != id && self.key($0.id) == key && self.modifiers($0.id) == modifiers }
            .map(\.title)
    }
    static func matches(_ event: NSEvent, id: String) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        var expected: NSEvent.ModifierFlags = []
        let wanted = modifiers(id)
        if wanted.contains(.command) { expected.insert(.command) }
        if wanted.contains(.shift) { expected.insert(.shift) }
        if wanted.contains(.option) { expected.insert(.option) }
        if wanted.contains(.control) { expected.insert(.control) }
        let stored = key(id)
        let keyMatches: Bool
        switch stored {
        case "right": keyMatches = event.keyCode == 124
        case "left": keyMatches = event.keyCode == 123
        case "up": keyMatches = event.keyCode == 126
        case "down": keyMatches = event.keyCode == 125
        default: keyMatches = event.charactersIgnoringModifiers?.lowercased() == stored
        }
        return flags == expected && keyMatches
    }
    static func matchesChordSuffix(_ event: NSEvent, id: String) -> Bool {
        matches(event, id: id)
    }
    static func shortcut(_ id: String) -> KeyboardShortcut {
        KeyboardShortcut(KeyEquivalent(key(id).first ?? " "), modifiers: modifiers(id))
    }
}

struct KeyboardSettingsView: View {
    @AppStorage("editorTabBehavior") private var tabBehavior = "insert"
    @AppStorage("editorIndentWidth") private var indentWidth = 4
    @AppStorage("editorUseSpaces") private var useSpaces = true
    @AppStorage("editorEmacsKeyBindings") private var emacs = false
    @AppStorage("editorAutoCapitalizeSentences") private var autoCapitalize = false

    var body: some View {
        Form {
            Section("Tab Key") {
                Picker("Behavior", selection: $tabBehavior) {
                    Text("Insert at cursor").tag("insert")
                    Text("Indent entire line").tag("line")
                }
                Picker("Tab width", selection: $indentWidth) {
                    ForEach([2, 4, 8], id: \.self) { width in Text("\(width)").tag(width) }
                }
                Toggle("Indent using spaces instead of tab characters", isOn: $useSpaces)
                Text(tabBehavior == "insert"
                     ? "Tab inserts indentation at the cursor. Shift-Tab does nothing."
                     : "Tab indents the current line; Shift-Tab removes one indentation level.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Editing") {
                Toggle("Automatically capitalize the first letter of sentences", isOn: $autoCapitalize)
            }
            Section("Key Mappings") {
                Toggle("Enable Emacs key bindings", isOn: $emacs)
                Text("Edit menu shortcuts below. Changes take effect after reopening the Settings window or updating the menu.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Document cycling uses a two-key sequence: Control+X, then the configurable second key below. Arrow keys are supported.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(KeyboardPreferences.commands, id: \.id) { command in
                    if command.id == "nextDocument" || command.id == "previousDocument" {
                        DocumentChordSettingRow(id: command.id, title: command.title)
                    } else {
                        ShortcutSettingRow(id: command.id, title: command.title)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 570, minHeight: 650)
    }
}

private struct ShortcutSettingRow: View {
    let id: String
    let title: String
    @State private var key: String = ""
    @State private var command = true
    @State private var shift = false
    @State private var option = false
    @State private var control = false
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
        HStack {
            Text(title).frame(width: 175, alignment: .leading)
            TextField("Key", text: $key)
                .frame(width: 38)
                .onChange(of: key) { value in
                    let normalized = String(value.lowercased().prefix(1))
                    if key != normalized { key = normalized }
                    save()
                }
            Toggle("⌘", isOn: $command).help("Command")
            Toggle("⇧", isOn: $shift).help("Shift")
            Toggle("⌥", isOn: $option).help("Option")
            Toggle("⌃", isOn: $control).help("Control")
            Button("Reset") {
                UserDefaults.standard.removeObject(forKey: "shortcut.\(id).key")
                UserDefaults.standard.removeObject(forKey: "shortcut.\(id).modifiers")
                load()
                bumpRevision()
            }
            .controlSize(.small)
        }
        if !conflictingTitles.isEmpty {
            Text("Shortcut conflicts with: " + conflictingTitles.joined(separator: ", "))
                .font(.caption).foregroundStyle(.red)
        }
        }
        .toggleStyle(.checkbox)
        .onAppear { load() }
        .onChange(of: command) { _ in save() }
        .onChange(of: shift) { _ in save() }
        .onChange(of: option) { _ in save() }
        .onChange(of: control) { _ in save() }
    }

    private func load() {
        isLoading = true
        key = KeyboardPreferences.key(id)
        let modifiers = KeyboardPreferences.modifiers(id)
        command = modifiers.contains(.command)
        shift = modifiers.contains(.shift)
        option = modifiers.contains(.option)
        control = modifiers.contains(.control)
        DispatchQueue.main.async { isLoading = false }
    }
    private func bumpRevision() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "shortcutRevision") + 1, forKey: "shortcutRevision")
    }
    private var currentModifiers: EventModifiers {
        var value: EventModifiers = []
        if command { value.insert(.command) }
        if shift { value.insert(.shift) }
        if option { value.insert(.option) }
        if control { value.insert(.control) }
        return value
    }
    private var conflictingTitles: [String] {
        KeyboardPreferences.conflicts(id: id, key: key, modifiers: currentModifiers)
    }
    private func save() {
        guard !isLoading, key.count == 1, conflictingTitles.isEmpty else { return }
        UserDefaults.standard.set(key, forKey: "shortcut.\(id).key")
        let names = [(command, "command"), (shift, "shift"), (option, "option"), (control, "control")]
            .filter { $0.0 }.map { $0.1 }
        UserDefaults.standard.set(names.joined(separator: ","), forKey: "shortcut.\(id).modifiers")
        bumpRevision()
    }
}

private struct DocumentChordSettingRow: View {
    let id: String
    let title: String
    @State private var suffix = "right"
    @State private var command = false
    @State private var shift = false
    @State private var option = false
    @State private var control = false
    @State private var loaded = false

    private var modifiers: EventModifiers {
        var result: EventModifiers = []
        if command { result.insert(.command) }
        if shift { result.insert(.shift) }
        if option { result.insert(.option) }
        if control { result.insert(.control) }
        return result
    }
    private var conflicts: [String] {
        KeyboardPreferences.conflicts(id: id, key: suffix, modifiers: modifiers)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).frame(width: 175, alignment: .leading)
                Text("⌃X →").foregroundStyle(.secondary)
                Picker("Second key", selection: $suffix) {
                    Text("→").tag("right")
                    Text("←").tag("left")
                    Text("↑").tag("up")
                    Text("↓").tag("down")
                    ForEach("abcdefghijklmnopqrstuvwxyz".map(String.init), id: \.self) { letter in
                        Text(letter.uppercased()).tag(letter)
                    }
                }
                .labelsHidden()
                .frame(width: 72)
                Toggle("⌘", isOn: $command).help("Command")
                Toggle("⇧", isOn: $shift).help("Shift")
                Toggle("⌥", isOn: $option).help("Option")
                Toggle("⌃", isOn: $control).help("Control")
                Button("Reset") {
                    let defaults = UserDefaults.standard
                    defaults.removeObject(forKey: "shortcut.\(id).key")
                    defaults.removeObject(forKey: "shortcut.\(id).modifiers")
                    load()
                    bumpRevision()
                }.controlSize(.small)
            }
            if !conflicts.isEmpty {
                Text("Shortcut conflicts with: " + conflicts.joined(separator: ", "))
                    .font(.caption).foregroundStyle(.red)
            }
        }
        .toggleStyle(.checkbox)
        .onAppear { load() }
        .onChange(of: suffix) { _ in save() }
        .onChange(of: command) { _ in save() }
        .onChange(of: shift) { _ in save() }
        .onChange(of: option) { _ in save() }
        .onChange(of: control) { _ in save() }
    }
    private func load() {
        loaded = false
        suffix = KeyboardPreferences.key(id)
        let flags = KeyboardPreferences.modifiers(id)
        command = flags.contains(.command)
        shift = flags.contains(.shift)
        option = flags.contains(.option)
        control = flags.contains(.control)
        DispatchQueue.main.async { loaded = true }
    }
    private func bumpRevision() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "shortcutRevision") + 1, forKey: "shortcutRevision")
    }
    private func save() {
        guard loaded, conflicts.isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(suffix, forKey: "shortcut.\(id).key")
        let names = [(command, "command"), (shift, "shift"), (option, "option"), (control, "control")]
            .filter { $0.0 }.map { $0.1 }
        defaults.set(names.joined(separator: ","), forKey: "shortcut.\(id).modifiers")
        bumpRevision()
    }
}
