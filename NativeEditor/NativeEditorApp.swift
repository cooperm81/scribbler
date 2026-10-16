import SwiftUI
import AppKit

extension Notification.Name {
    static let scribblerFindCommand = Notification.Name("ScribblerFindCommand")
    static let scribblerWorkspaceCommand = Notification.Name("ScribblerWorkspaceCommand")
}

final class ScribblerAppDelegate: NSObject, NSApplicationDelegate {
    weak var store: WorkspaceStore?
    func applicationDidResignActive(_ notification: Notification) {
        store?.flushRecovery()
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard store?.canQuit() ?? true else { return .terminateCancel }
        store?.finishCleanQuit()
        return .terminateNow
    }
}

@main
struct NativeEditorApp: App {
    @NSApplicationDelegateAdaptor(ScribblerAppDelegate.self) private var appDelegate
    @StateObject private var store = WorkspaceStore()
    @AppStorage("shortcutRevision") private var shortcutRevision = 0

    var body: some Scene {
        let _ = shortcutRevision
        Window("Scribbler", id: "workspace") {
            EditorView(store: store)
                .onAppear { appDelegate.store = store }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                SettingsLink { Text("Settings…") }
                    .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Scribbler") { ScribblerAboutWindow.show() }
            }
            CommandGroup(replacing: .newItem) {
                Button("New") { sendWorkspace("new") }.keyboardShortcut(KeyboardPreferences.shortcut("new"))
                Button("Open…") { sendWorkspace("open") }.keyboardShortcut(KeyboardPreferences.shortcut("open"))
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { sendWorkspace("save") }.keyboardShortcut(KeyboardPreferences.shortcut("save"))
                Button("Save As…") { sendWorkspace("saveAs") }.keyboardShortcut(KeyboardPreferences.shortcut("saveAs"))
            }
            CommandMenu("Find") {
                Button("Find…") { sendFind("find") }.keyboardShortcut(KeyboardPreferences.shortcut("find"))
                Button("Find and Replace…") { sendFind("replace") }.keyboardShortcut(KeyboardPreferences.shortcut("replace"))
                Divider()
                Button("Find Next") { sendFind("next") }.keyboardShortcut(KeyboardPreferences.shortcut("next"))
                Button("Find Previous") { sendFind("previous") }.keyboardShortcut(KeyboardPreferences.shortcut("previous"))
                Button("Use Selection for Find") { sendFind("selection") }.keyboardShortcut(KeyboardPreferences.shortcut("selection"))
            }
            CommandMenu("View") {
                Button("Toggle Markdown Preview") { sendWorkspace("togglePreview") }
                    .keyboardShortcut(KeyboardPreferences.shortcut("togglePreview"))
            }
            CommandMenu("Documents") {
                Button("Close Current Document") { sendWorkspace("close") }.keyboardShortcut(KeyboardPreferences.shortcut("close"))
                Button("Show/Hide Open Documents") { sendWorkspace("togglePane") }.keyboardShortcut(KeyboardPreferences.shortcut("togglePane"))
            }
        }
        Settings {
            KeyboardSettingsView()
        }
    }
    private func sendFind(_ command: String) {
        NotificationCenter.default.post(name: .scribblerFindCommand, object: command)
    }
    private func sendWorkspace(_ command: String) {
        NotificationCenter.default.post(name: .scribblerWorkspaceCommand, object: command)
    }
}

private struct ScribblerAboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().interpolation(.high)
                .frame(width: 100, height: 100)
            Text("Scribbler").font(.system(size: 26, weight: .bold))
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.4.3")")
                .font(.system(size: 14))
        }
        .frame(width: 380, height: 260)
    }
}

private enum ScribblerAboutWindow {
    static var window: NSWindow?

    static func show() {
        if window == nil {
            let panel = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 260),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "About Scribbler"
            panel.center()
            panel.contentView = NSHostingView(rootView: ScribblerAboutView())
            panel.isReleasedWhenClosed = false
            window = panel
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
