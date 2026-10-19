# NumberedPasteSlots — specification

**Tagline:** Ten permanent paste slots you fill once and fire anywhere with a hotkey plus a number.

**Category:** Clipboard

**Inspired by (paid):** CleanClip ($12.99 one-time)

**Frameworks:** SwiftUI, AppKit, Carbon, ApplicationServices, UniformTypeIdentifiers, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does and evidence of demand. CleanClip is a paid Mac clipboard manager with a free tier and a 12.99 dollar one-time upgrade, and it appears in several 2024 and 2026 best clipboard manager reviews alongside Paste, Copy 'Em, and CopyClip. A recurring need among clipboard users is quick access to a handful of items that never change, such as an email address, a mailing address, a short bio, or a license key, without scrolling through history. Our clean-room version, NumberedPasteSlots, deliberately avoids a history list and instead offers ten fixed slots.

Feature set. The app provides ten slots numbered one through zero. Each slot holds one item, either text or an image, with an optional label. Slots are filled in two ways: by pressing a global capture hotkey followed by a digit while something is on the pasteboard, which saves the current clipboard into that slot, or by editing the slot directly in the settings window. A second global modifier combination, default Control plus Option plus the digit, pastes the slot contents into the frontmost app immediately. Slots can be cleared, swapped by drag and drop, and marked as plain text only so formatting is dropped. An optional overview popover shows all ten slots at once and lets the user click to paste. Slot contents persist across launches.

UI spec. The app is a MenuBarExtra whose menu lists the ten slots as items showing the number, the label or a 30 character preview, and a keyboard shortcut hint. Clicking a slot pastes it. Empty slots show Empty in a dimmed style and clicking them opens the editor. Below the list are Capture Clipboard Into Slot as a submenu of ten entries, Edit Slots, Settings, and Quit. The Edit Slots window is a grid of ten rows. Each row has the digit, a label text field, a multi-line text editor or an image well, a plain-text toggle, a copy button, and a clear button. Settings fields: paste modifier keys selector, capture modifier keys selector, play feedback sound toggle, show HUD toggle, and Launch at login. A small HUD confirms Saved to slot 3 or Pasted slot 3.

Technical approach. Register twenty Carbon hotkeys with RegisterEventHotKey, ten for paste and ten for capture, using the key codes for the digit row and the user's selected modifiers, and unregister and re-register them when settings change. Capture reads the current NSPasteboard contents, preferring string and falling back to PNG or TIFF image data. Paste writes the slot to the pasteboard, then posts Command plus V with CGEvent after a 50 millisecond delay, and later restores the previous pasteboard contents if the user enables that setting. This requires Accessibility permission, requested using AXIsProcessTrustedWithOptions with an explanation view, and without it the app only copies and shows the HUD telling the user to press Command V. Persist text slots in a JSON file and image slots as PNG files in Application Support. Use UniformTypeIdentifiers to validate dropped images in the editor. Launch at login is done with SMAppService.mainApp.

Edge cases and error handling. If a chosen modifier combination is already used by the system, show a conflict warning, since registration may fail and returns an error code that the app checks. Prevent paste and capture modifiers from being identical. Limit text slots to 100 kilobytes and images to 5 megabytes. If the pasteboard is empty during capture, show a HUD saying Nothing to capture. Replacing an existing slot asks for confirmation unless the user disabled that prompt. Corrupt files are backed up and the slots reset. Ensure digit shortcuts work on keyboards with different layouts by using key codes rather than characters.
