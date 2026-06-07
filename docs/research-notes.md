# Research Notes

## 2026-06-07

### Initial observations

- The project starts from an empty workspace, so repository conventions can be defined cleanly.
- GitHub CLI is available locally and authenticated for the `Glutexo` account.
- Swift 6.3.2 is installed locally, so a native Swift baseline can be built and run without extra setup.

### Implementation notes

- The first code scaffold uses Swift Package Manager with an executable target.
- This keeps the initial app portable and easy to verify from the command line before adding UI or automation layers.
- The next structural step is a module-first layout, starting with a `Safari` module behind the executable entry point.
- The first Safari capability should be a dedicated launch command rather than a mixed module-level script.
- Launching Safari uses AppKit, so the package now declares a macOS 10.15+ minimum target.
- CLI completion needs to consume metadata from modules and commands rather than hardcoding names in the executable.
- Shell completion should stay a thin adapter over the CLI completion endpoint so command metadata has a single source of truth.
- The Safari module now needs an explicit application model so lifecycle commands stay grouped by the part of the app they control.
- A completion installer should handle only path selection and file writes, not duplicate script generation logic.
- Safari profile names can be read from `SafariTabs.db` bookmark rows with `parent = 0`, `type = 1`, and `subtype = 2`.
- Safari window creation and closing are better handled through AppleScript than by trying to infer them from local Safari state files.

### Open questions

- Should the first implementation focus on desktop UI automation, shell automation, or hybrid flows?
- What level of observability and recovery is required for failed automation steps?
