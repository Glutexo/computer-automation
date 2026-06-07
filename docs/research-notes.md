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
- Safari's scripting dictionary does not expose profile-aware window creation directly, so profile-specific window opening uses GUI scripting over Safari's File menu.
- Safari keeps the File menu in menu bar position `3` on the current build, which is a better automation anchor than the localized menu title.
- Profile-specific new-window items still expose the user profile name in the menu item title, so matching by profile-name suffix avoids dependence on the localized command prefix.
- Open window profile names can be resolved from `SafariTabs.db` by joining `windows.active_profile_id` to `bookmarks.title`.
- Safari GUI scripting should live outside the `Safari` domain module in a dedicated `SafariUserInterface` module.

### Open questions

- Should the first implementation focus on desktop UI automation, shell automation, or hybrid flows?
- What level of observability and recovery is required for failed automation steps?
