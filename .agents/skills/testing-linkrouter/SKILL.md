---
name: testing-linkrouter-macos
description: Build and interactively test LinkRouter's native macOS settings, URL picker, and persisted browser catalog without changing the default browser.
---

# Local build and state safety

- Use a macOS host with Xcode and Accessibility/Screen Recording permissions.
- Build from repo root:
  `xcodebuild -project LinkRouter.xcodeproj -scheme LinkRouter -destination 'platform=macOS' -derivedDataPath build CODE_SIGN_IDENTITY="-" CODE_SIGNING_ALLOWED=NO build`
- Before any mutation, quit LinkRouter and back up `~/Library/Application Support/LinkRouter/state.json`. Preserve whether the file originally existed.
- App: `build/Build/Products/Debug/LinkRouter.app`. Open it, then use its menu-bar item > Settings to activate the regular app/window for interaction.
- Quit before manually editing state; it uses debounced saves and flushes on termination. Quit again before restoring the original file, then compare hashes.

# Native interaction

- Prefer native macOS accessibility with the live PID from `pgrep -x LinkRouter`. If name-based lookup points at a dead process, use that PID explicitly; refresh it after relaunch. On some hosts name lookup fails entirely — always resolve `pgrep -x LinkRouter` and pass the PID as `app`.
- Rules and Profiles row labels may be exposed as checkboxes because the row contains an Enabled toggle. Pressing the checkbox-labelled row opens the editor sheet anyway (it is not just a toggle) — the editor's own Delete button is the easiest delete path. Click the text portion when you only want selection. Right-click by coordinates if AXShowMenu fails.
- Popover/sheet animations may make an immediate query empty; query the sheet again after the animation rather than clicking twice.
- Menu-bar extra: clicking the status-icon coordinate is unreliable (icon position shifts with other extras). Open the menu deterministically with `osascript -e 'tell application "System Events" to tell process "LinkRouter" to click menu bar item 1 of menu bar 2'`. Its items are also queryable as role=menuitem on the app PID without opening it. Menu width ~200pt starting ~x=1270 (1600px display); submenu flies out to the LEFT.
- Save/Open panels (Export/Import Settings, Add browser): navigate via Cmd+Shift+G (macOS Go-to-folder) then type the absolute path. `key` syntax for Command is `super` (e.g. `super+shift+g`).
- `screencapture -x` works for evidence but captures the real display resolution (e.g. 1600x1200) while computer-tool coordinates use a scaled space (1024x768) — don't reuse pixel coordinates between the two.
- Browsers-pane row drag-reorder works via real pointer drag starting on the row's `≡` handle: mouse_down, hold ~0.5s, move in steps, hover the target row (dropEntered reorders live), release. Rules/Profiles use a plain `List.onMove` — a centre-row drag may not initiate under synthetic input; if it doesn't, verify reorder with real hardware or flag it.
- If `open -a` has reactivated Settings while a picker is already visible, click the picker header to focus before sending Escape. Distinguish a focus-only first click from a browser selection.

# URL routing and catalog fixtures

- Do not change the OS default browser for testing. Use `open -a <absolute app path> https://example.com`.
- Shipped rules prompt only running browsers when any are running, otherwise all enabled/available browsers. Quit browsers or explicitly force a prompt if testing exclusion from the all-browser list.
- Feed different hostnames to distinguish FIFO picker entries visually; test both Cancel and browser pick transitions.
- Browser path-repair fixtures retain the original browser record ID and bundle identifier but set its path to a nonexistent `.app`. Open Settings to trigger discovery/re-resolution, then check both the repaired path and browser/row counts for duplication.
- A truly missing-browser fixture needs both an unresolvable bundle identifier and nonexistent path. Verify red Missing text, disabled toggle, and exclusion from all-browser picker.
- Sample process CPU with `top -l 6 -s 1 -pid <PID> -stats pid,command,cpu,time` while the menu icon is hidden; do not infer absence of a publishing loop solely from a responsive screenshot.

## Devin Secrets Needed

None for local native UI and public example-domain routing tests.
