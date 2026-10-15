# Scribbler 0.4.4 — Recovery-first stabilization

Based on the validated v0.4.3.2 project. No automatic writes to original documents.

## Recovery behavior
- After editing, modified document contents are snapshotted to `~/Library/Application Support/Scribbler/Recovery.json` after ~0.7 seconds of inactivity. Snapshots also flush when the app loses focus.
- Recovery uses atomic file replacement. Snapshots include the text, original saved text, and display filename for each modified document.
- On next launch, if recovery data exists, Scribbler offers **Restore** or **Discard**. Restored files are unsaved copies (not directly linked to their old disk paths), so use Save/Save As to keep them.
- Manual Save still writes the original file. A clean Quit runs the existing Save/Cancel/Don't Save prompts and clears recovery after successful termination approval.
- Untitled modified documents are included. Unmodified documents are not snapshotted.

## Testing
1. Build and launch. Edit a saved file, wait a second, then force-quit Scribbler using Activity Monitor. Relaunch and choose Restore. Confirm the original file on disk was *not* changed.
2. Save the recovered document to a new filename. Check the text and that the recovery indicator clears.
3. Repeat with an untitled document and with two modified documents.
4. Edit and quit normally. Verify Save/Cancel/Don't Save prompts still work and clean quitting doesn't prompt to restore on next launch.
5. Verify Markdown preview, find/replace, Emacs commands, and the document pane still work.

## Important limitations
- This is a recovery-first beta, not macOS-native document autosave. It does **not** automatically write edits to original files.
- An OS crash or power loss during the ~0.7-second debounce window can lose the most recent keystrokes.
- Recovery writes may fail (e.g., full disk); failures are logged but not yet displayed to users.
- Recovery snapshots are plain text in the user's Application Support directory; do not use for sensitive secrets.
- Restored documents require Save/Save As to reconnect to files on disk.
- Full macOS build/runtime validation must occur in Xcode.
