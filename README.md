# Computer Automation

Minimal Swift application for computer automation experiments.

## Overview

- The repository is organized by top-level modules.
- The first module is `Safari`.
- The current runnable slice covers Safari application lifecycle commands and profile listing.
- Module and command models expose metadata for CLI tab completion.

## Current app

- Built with Swift Package Manager.
- The executable currently depends on the `Safari` module.
- The `Safari` module currently exposes application lifecycle commands.
- Requires macOS with Safari installed.

## Run

```bash
swift run computer-automation safari launch
swift run computer-automation safari running
swift run computer-automation safari quit
swift run computer-automation safari profiles
```

Running the executable launches Safari on macOS.

## Completion

```bash
swift run computer-automation --complete
swift run computer-automation --complete safari
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
