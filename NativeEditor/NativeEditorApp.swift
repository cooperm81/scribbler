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

    var body: some Scene {
        Window("Scribbler", id: "workspace") {
            EditorView(store: store)
                .onAppear { appDelegate.store = store }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Scribbler") { ScribblerAboutWindow.show() }
            }
            CommandGroup(replacing: .newItem) {
                Button("New") { sendWorkspace("new") }.keyboardShortcut("n")
                Button("Open…") { sendWorkspace("open") }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") { sendWorkspace("save") }.keyboardShortcut("s")
                Button("Save As…") { sendWorkspace("saveAs") }.keyboardShortcut("s", modifiers: [.command, .shift])
            }
            CommandMenu("Find") {
                Button("Find…") { sendFind("find") }.keyboardShortcut("f", modifiers: [.command])
                Button("Find and Replace…") { sendFind("replace") }.keyboardShortcut("f", modifiers: [.command, .option])
                Divider()
                Button("Find Next") { sendFind("next") }.keyboardShortcut("g", modifiers: [.command])
                Button("Find Previous") { sendFind("previous") }.keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { sendFind("selection") }.keyboardShortcut("e", modifiers: [.command])
            }
            CommandMenu("View") {
                Button("Toggle Markdown Preview") { sendWorkspace("togglePreview") }
                    .keyboardShortcut("p", modifiers: [.command, .option])
            }
            CommandMenu("Documents") {
                Button("Close Current Document") { sendWorkspace("close") }.keyboardShortcut("w")
                Button("Show/Hide Open Documents") { sendWorkspace("togglePane") }.keyboardShortcut("1", modifiers: [.command, .option])
            }
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
