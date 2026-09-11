# Adversary (r2)

Source-app and Safari private are already Defer. Attack the two Must launch contracts the Dispatcher will get wrong when the browser is already running.

## 1. Chrome profile/private via argv + `createsNewApplicationInstance` (FR-12, Dispatcher, ASM-2)

**Claim.** For `com.google.Chrome`, `OpenConfiguration.arguments` (`--profile-directory=<cache key>`, optional `--incognito`) plus `createsNewApplicationInstance = true` selects that profile/private window. The URL lives only in `open`’s URL array (ASM-2). Feature table notes Chromium “quit first”; v1 still Must-ships this path.

**Failure.** Chrome running (the usual state): Apple documents `arguments` as flags for a **new** app instance. Without a new instance, LS reuses Chrome and delivers a GURL Apple Event — URL only — so the link opens in the last-used profile. With a new instance, Chromium’s Mac POSIX singleton forwards the *command line* over a socket and separately forwards open-URL Apple Events (`WaitForAndForwardOpenURLEvent`). Profile flags and the URL take different channels. Result: wrong profile, blank profile window, or `PROFILE_IN_USE`. Q-1 is still open; Must cannot rest on it.

**For.** Chromium run-with-flags: quit first on macOS (https://www.chromium.org/developers/how-tos/run-chromium-with-flags/). Apple `arguments` (https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration/arguments). Chromium `process_singleton.h`: Mac still forwards GURL AEs (crbug 40546317). out-R2.md; ASM-2 unverified.

**Against.** Reports that `open -n -a "Google Chrome" --args --profile-directory=…` works; the POSIX singleton *can* notify `--profile-directory`. That recipe puts the URL **in argv**, which the spec forbids.

**Change.** Narrow FR-12 Chrome: do not Must-claim a running Chrome. Probe with `chrome://version`; put the URL in `arguments` beside `--profile-directory=` / `--incognito`. If Chrome is running and the probe fails, prompt to quit or open without a profile. Defer running-Chrome profile targeting until that probe is cited.

## 2. Firefox launch is `-P` + `Name`; `--profile` is out of v1 (FR-12, Dispatcher)

**Claim.** Parse `profiles.ini` (`Name`, `Path`, `IsRelative`) but launch only `-P` `<Name>`. Never `--profile`. Private: `--private-window`. Same `createsNewApplicationInstance = true` whenever argv is set.

**Failure.** Firefox remotes a second launch to the running instance and **ignores** `-P` (URL opens in the already-running profile). LS `createsNewApplicationInstance` is not Firefox `--new-instance` / `--no-remote`. `-P` is case-sensitive; missing/wrong `Name` opens Profile Manager. `Path` is parsed then discarded; `--profile` is the path flag. `--private-window [<url>]` takes the URL as a flag argument (Q-2), not only the LS URL array.

**For.** Mozilla CLI: `-P <profile>` vs `--profile <path>` vs `--new-instance` vs `--no-remote` (https://firefox-source-docs.mozilla.org/browser/CommandLineParameters.html). Wiki: `-P` case-sensitive; bare `-P` = Profile Manager (https://wiki.mozilla.org/Firefox/CommandLineOptions). Profile-per-install remoting (https://support.mozilla.org/kb/understanding-depth-profile-installation). out-R2.md.

**Against.** `-P` + `Name` is correct for a **cold** start. Passing a display string to `--profile` would be wrong — refuse that, not the path flag.

**Change.** Replace the launch rule: resolve `Path` (`IsRelative=1` → Firefox support dir) and pass `--profile` `<abs path>`. If Firefox is running, also pass `--new-instance` (not LS `-n` alone). Keep `-P` as a cold-start alias only. Defer “switch profile while Firefox is running” until probed. Close Q-2 by putting the URL on `--private-window` in argv.
