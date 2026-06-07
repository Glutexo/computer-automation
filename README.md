# Computer Automation

Minimal Swift application for computer automation experiments.

## Overview

- The repository is organized by top-level modules.
- The current modules are `Safari`, `SafariUserInterface`, and `SafariAppleScript`.
- The current runnable slice covers Safari application lifecycle commands, profile listing, and browser window operations.
- The CLI also exposes Safari UI inspection commands for the application menu bar and File menu.
- Module and command models expose metadata for CLI tab completion.

## Current app

- Built with Swift Package Manager.
- The executable currently depends on the `Safari`, `SafariUserInterface`, and `SafariAppleScript` modules.
- The `Safari` module currently exposes application lifecycle commands.
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
swift run computer-automation safari-ui menu-bar-items
swift run computer-automation safari-ui menu-items 3
swift run computer-automation safari-ui file-menu-items
swift run computer-automation safari-ui menu-item-children 3 27
```

Running the executable launches Safari on macOS.

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
