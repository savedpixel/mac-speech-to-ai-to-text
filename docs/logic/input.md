# Input System

<!-- Global shortcuts, wake phrase activation, text field insertion, and auto-submit. -->

<!-- Updated: 2026-03-26 -->

---

## Architecture

- **Global Shortcut:** Customizable hotkey (e.g., double-tap Control) via CGEvent tap or MASShortcut
- **Wake Phrase:** Always-listening "okay, voice" trigger using a lightweight speech recognizer
- **Text Insertion:** Accessibility API (AXUIElement) to locate active text field and insert text
- **Auto-Submit:** Simulated Enter key press via CGEvent after text insertion

## Key Behaviors

- Global shortcut works system-wide regardless of focused application
- Wake phrase runs a separate lightweight recognizer (not Whisper) for low-latency detection
- Text insertion targets the text field that was active when recording started
- Enter is sent automatically after text is inserted to submit the message

## Common Patterns

- Use Accessibility API permissions for text field detection and insertion
- Store the active element reference at recording start, restore focus before insertion
- CGEvent for simulating keyboard input (Enter key)
