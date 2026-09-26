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

- Prefer native macOS accessibility with the live PID from `pgrep -x LinkRouter`. If name-based lookup points at a dead process, use that PID explicitly; refresh it after relaunch.
- Rules and Profiles row labels may be exposed as checkboxes because the row contains an Enabled toggle. Click the text portion to open the editor, not the toggle. Right-click by coordinates if AXShowMenu fails.
- Popover/sheet animations may make an immediate query empty; query the sheet again after the animation rather than clicking twice.
- For recording, maximize Settings with its native zoom control. Keep the menu bar visible when testing icon insertion.
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
