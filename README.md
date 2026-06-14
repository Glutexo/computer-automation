# Computer Automation

Minimal Swift application for computer automation experiments.

## Overview

- The repository is organized by top-level modules.
- The current modules are `Safari`, `SafariDatabase`, `SafariUserInterface`, and `SafariAppleScript`.
- The current runnable slice covers Safari application lifecycle commands, profile listing, browser window operations, saved tab-group create/read/delete flows, and window-level tab-group switching.
- The CLI also exposes Safari UI inspection commands for the application menu bar and File menu.
- Saved tab-group create/delete is driven by accessibility:
  - the target group is resolved through the opened Safari sidebar
  - create uses Safari's File-menu action identified by `NewEmptyTabGroupMenuItem`
  - create relies on Safari's post-create inline edit field for naming the newly created group
  - delete uses the selected group's context menu item `DeleteTabGroupMenuItem`
  - standalone rename is currently not exposed because the visible Safari sidebar rename affordance is not available through a stable accessibility trigger
  - replacing a group by creating a new one and deleting the old one is documented as a possible future workaround, but it is not implemented because it would change the stable group identifier and may lose Safari metadata
- Module and command models expose metadata for CLI tab completion.

## Current app

- Built with Swift Package Manager.
- The runnable stack currently includes the `Safari`, `SafariDatabase`, `SafariUserInterface`, and `SafariAppleScript` modules.
- The `Safari` module exposes application, profile, window, saved tab-group, and tab commands.
- Requires macOS with Safari installed.

## Run

```bash
swift run computer-automation safari launch
swift run computer-automation safari running
swift run computer-automation safari quit
swift run computer-automation safari profiles
swift run computer-automation safari windows
swift run computer-automation safari open-window
swift run computer-automation safari open-window Twisto
swift run computer-automation safari close-window
swift run computer-automation safari open-tab-group-window 1000
swift run computer-automation safari set-window-tab-group 1 1000
swift run computer-automation safari create-tab-group 1 Inbox
swift run computer-automation safari tab-groups
swift run computer-automation safari tab-group-tabs 1000
swift run computer-automation safari delete-tab-group 1000
swift run computer-automation safari open-tab 1 https://example.com
swift run computer-automation safari tabs
swift run computer-automation safari window-tabs 1
swift run computer-automation safari set-tab-url 1 1 https://example.com
swift run computer-automation safari close-tab 1 1
swift run computer-automation safari-ui menu-bar-items
swift run computer-automation safari-ui menu-items 3
swift run computer-automation safari-ui file-menu-items
swift run computer-automation safari-ui menu-item-children 3 27
```

Running the executable launches Safari on macOS.

## Safari database access

Some Safari read commands use Safari's local `SafariTabs.db` for profile, saved tab-group, private-window, and selected tab-group metadata. Direct access to that database is isolated in the `SafariDatabase` module. On recent macOS versions, the terminal or app running `computer-automation` may need Full Disk Access to read that file.

When the database is unavailable, `safari windows` still returns the window fields that Safari exposes through AppleScript: window index, private state as `false`, empty profile and tab-group fields, and window name. Commands that require saved Safari database records fail quickly with an actionable database access error instead of waiting indefinitely.

## Completion

```bash
swift run computer-automation --complete
swift run computer-automation --complete safari
swift run computer-automation --complete safari-ui
swift run computer-automation --complete safari la
```

The CLI reads completion candidates from module and command metadata.

## Zsh completion

```bash
swift run computer-automation --completion-script zsh > _computer-automation
source ./_computer-automation
```

The generated script delegates suggestions back to `computer-automation --complete`.

## Install zsh completion

```bash
swift run computer-automation --install-completion zsh
```

The installer writes `_computer-automation` into the user's zsh completion directory and reports whether `fpath` still needs an update.

## Test

```bash
swift test
```
