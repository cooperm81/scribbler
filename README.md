# Scribbler

**Scribbler** is a lightweight, native macOS text editor built with SwiftUI and AppKit. The project is in active development and is not yet a polished or notarized public release.

## Features

- Multiple open documents with a document sidebar
- Plain-text editing with line numbers and syntax highlighting
- Find and replace, including regular expressions
- Markdown preview powered by [apple/swift-markdown](https://github.com/apple/swift-markdown)
- Configurable keyboard shortcuts, Tab behavior, indentation width, and optional Emacs bindings
- Word/character counts, cursor position, font size, and line wrapping
- Crash recovery for unsaved edits

## Requirements

- macOS 14 or later (as configured in the Xcode project)
- Xcode with macOS build support
- Swift Package Manager access to resolve `apple/swift-markdown`

## Build

Clone this repository, open `Scribbler.xcodeproj` in Xcode, select the `Scribbler` scheme, and build/run. Or use:

```sh
xcodebuild -project Scribbler.xcodeproj -scheme Scribbler \
  -configuration Debug -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions builds the application on macOS and uploads an **unsigned test app** as a workflow artifact. Those artifacts are not Developer ID signed or Apple notarized; macOS Gatekeeper may block them. Do not treat CI artifacts as verified distribution releases.

## Recovery and data handling

When a document is modified, Scribbler stores recovery copies in:

```text
~/Library/Application Support/Scribbler/Recovery.json
```

Changes are normally snapshotted after approximately 0.7 seconds of inactivity and when the application loses focus. If Scribbler is forcibly terminated, the next launch **automatically opens recovered content as unsaved copies** (typically titled `Recovered — …`). Save those copies explicitly to retain them. A normal quit presents Save / Cancel / Don't Save prompts and clears the recovery snapshot after quitting is approved.

**Important:** Recovery snapshots contain document text in plain JSON on the local computer. They are not encrypted, and the app does not automatically save changes back to original files. Avoid editing secrets in Scribbler if local plaintext recovery storage is unacceptable. A sudden power loss can still lose the most recent edits, and disk-write failures are currently logged rather than surfaced to users.

Markdown preview renders locally in a WebKit view with JavaScript disabled; however, Markdown referencing remote HTTP(S) images can cause network requests. Clicking external links opens them in the system browser.

## Keyboard settings

Choose **Scribbler → Settings…** (⌘,) to configure Tab behavior, tab width, spaces/tabs, Emacs key bindings, and Scribbler's menu shortcuts.

- **Insert at cursor:** Tab inserts the configured indentation at the caret; Shift-Tab has no action.
- **Indent entire line:** Tab indents the current line and Shift-Tab outdents it.

Shortcut collision detection is not implemented yet; see [the feature request](https://github.com/cooperm81/scribbler/issues/3).

## Tests

```sh
swiftc NativeEditor/RecoveryVault.swift Tests/RecoveryVaultTests.swift \
  -o /tmp/scribbler-recovery-tests
/tmp/scribbler-recovery-tests
```

The regression checks cover recovery-file persistence and cleanup. The full editor UI is not yet covered by automated tests.

## Contributing

Bug reports, feature ideas, and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md). Do not include private documents or recovery files in public reports.

## License

Scribbler is released under the [MIT License](LICENSE).
