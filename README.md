# Computer Automation

Minimal Swift application for computer automation experiments.

## Overview

- The repository is organized by top-level modules.
- The first module is `Safari`.
- The current runnable slice launches Safari.
- Module and command models expose metadata for CLI tab completion.

## Current app

- Built with Swift Package Manager.
- The executable currently depends on the `Safari` module.
- The first command is `SafariLaunchCommand`.
- Requires macOS with Safari installed.

## Run

```bash
swift run computer-automation safari launch
```

Running the executable launches Safari on macOS.

## Completion

```bash
swift run computer-automation --complete
swift run computer-automation --complete safari
swift run computer-automation --complete safari la
```

The CLI reads completion candidates from module and command metadata.

## Test

```bash
swift test
```
