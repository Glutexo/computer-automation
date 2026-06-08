# Decision Log

## 2026-06-08

### Model testing standard

- Recorded a standing rule that every model must be covered by robust parameterized tests.
- Extended that requirement explicitly to UI models and AppleScript models, not only domain models.
- Required tests to cover both user-story examples and general behavior, invariants, and edge conditions.
- Allowed mocks as a first-class tool when they improve coverage, isolation, or reproducibility.

### Model test coverage expansion

- Reviewed the existing model tests against the new testing standard and filled the main gaps.
- Added parameterized behavior tests across Safari, SafariUserInterface, and SafariAppleScript models.
- Introduced explicit dependency injection points for lifecycle and window commands so they can be tested with mocks instead of AppKit side effects.
- Extended the same testing discipline to the top-level CLI router, including error handling and completion entry points.
- Extracted the CLI router into a shared target so it can be tested directly without executable-only linkage limits.
- Added property-like parser and formatter tests for AppleScript descriptors, menu-item normalization, and window-list tolerance for malformed input.
- Added property-like coverage for SQLite-backed profile and window mapping, including missing databases, missing schema, NULL fields, and LEFT JOIN fallbacks.

## 2026-06-07

### Initial repository bootstrap

- Created the repository as `computer-automation`.
- Started documentation-first with explicit project rules and persistent notes.
- Chose a lightweight structure so early implementation can evolve without cleanup overhead.

### Repository visibility and delivery rule

- Changed the GitHub repository visibility to public.
- Added a standing rule to commit and push each verified change set immediately.

### Initial Swift app scaffold

- Bootstrapped the codebase as a Swift Package Manager executable.
- Kept the first app intentionally minimal as a runnable `Ahoj světe!` baseline.
- Documented both run and test commands in the repository README.

### Documentation separation rule

- Development rules and internal notes must stay separate from user-facing documentation.
- Cleaned the README so it remains a user-facing quickstart instead of an internal process document.

### Module-first architecture

- Defined the first architectural level as modules, typically representing an application or a service.
- Started the modular structure with a dedicated `Safari` module.
- Added Mermaid architecture diagrams as a maintained part of the documentation.

### Command isolation within modules

- Chose commands as the next architectural level inside a module.
- Each command is represented by its own Swift type and isolated in its own directory.
- Cross-command and cross-module reuse must happen only through explicit shared code boundaries.
- Implemented `SafariLaunchCommand` as the first concrete command in the `Safari` module.

### Completion metadata contract

- Added a shared metadata contract for modules and commands in `AutomationFoundation`.
- Completion data is now owned by module and command models and consumed by the CLI.
- Added `zsh` completion script generation that delegates back to the shared completion endpoint.

### Safari application lifecycle model

- Structured the `Safari` module around a `SafariApplication` model that represents Safari as an application.
- Attached `launch`, `running`, and `quit` commands to that model as the current lifecycle CRUD surface.
- Recorded model architecture and CRUD coverage in dedicated internal documentation.

### Safari profile model

- Added a `SafariProfile` model for reading the Safari profile catalog.
- Implemented the initial read operation as a `profiles` command backed by Safari's local tabs database.
- Documented the concrete Safari database path and row selection rules used for profile loading.

### Safari window model

- Added a `SafariWindow` model for browser window CRUD operations.
- Implemented `open-window`, `windows`, and `close-window` as the initial create, read, and delete commands.
- Chose AppleScript as the execution layer for Safari window control.
- Extended `open-window` with an optional Safari profile argument and included profile names in window listing output.

### Safari user interface module

- Split Safari GUI scripting into a separate `SafariUserInterface` module.
- Added explicit UI models for the application menu bar, the File menu, and menu items.
- Kept the `Safari` domain module dependent on that module through explicit API boundaries.
- Added dedicated internal model documentation for `SafariUserInterface`, including CRUD coverage and a Mermaid diagram.

### Locale-independent UI automation

- Added a standing rule that automation must stay independent of the macOS and Safari language setting.
- Moved Safari File menu inspection to structural access by menu position and item index instead of localized menu titles.
- Added initial read commands for the Safari application menu bar and File menu so UI structure can be inspected directly.
- Added a `SafariMenuItem` read command for listing child items of a concrete menu item via structural coordinates.

### General menu model

- Added a general `SafariMenu` model for top-level Safari menus addressed by menu bar index.
- Kept `SafariFileMenu` as a thin specialization over `SafariMenu` instead of the primary abstraction.
- Chose the general menu model as the preferred base for future menu-oriented automation.
- Recorded a standing architecture rule that new features should be built primarily on general models before adding specialized convenience models.
- Recorded the matching exception: keep specialized models when the behavior truly belongs to a specific UI surface, such as `openWindow(profile:)` on Safari's File menu.

### Safari AppleScript module

- Split direct Safari AppleScript access into a dedicated `SafariAppleScript` module.
- Added explicit AppleScript-side models for the application, windows, menu bar, menus, and menu items.
- Kept `Safari` and `SafariUserInterface` dependent on that module through explicit model APIs.
- Added dedicated internal model documentation for the AppleScript module.

### Zsh completion installer

- Added a CLI installer for `zsh` completion files.
- Kept installation logic separate from script rendering so completion metadata still has one source of truth.

### Error contract coverage

- Expanded command-level error contract tests across the `Safari`, `SafariUserInterface`, and `SafariAppleScript` modules.
- Added explicit tests for unknown command routing and failure propagation from profile, window, and AppleScript command boundaries.
- Made `SafariAppleScriptError` equatable so error outcomes can be asserted directly in parameterized tests.

### Completion and installer coverage

- Added explicit error-contract tests for shell completion and completion installation.
- Covered missing `HOME`, configured versus missing `FPATH`, fallback completion directory resolution, and filesystem failure propagation during installation.
- Added a completion engine contract test for unknown modules returning no suggestions.

### Metadata and completion invariants

- Added explicit tests for metadata-layer invariants rather than leaving them implicit in implementation.
- Covered command argument descriptor defaults, command flattening order inside module descriptors, and concrete argument metadata exposed by command descriptors.
- Added completion engine contract tests for deeper input handling and command filtering by the second token.

### Safari tab model

- Added a `SafariTab` model for ordered browser tabs inside Safari windows.
- Implemented `open-tab`, `tabs`, `set-tab-url`, and `close-tab` as the initial tab CRUD surface.
- Added a matching `SafariAppleScriptTab` infrastructure model because Safari exposes tab URL inspection and mutation directly through AppleScript.
- Kept tab CRUD independent from `SafariUserInterface` because it does not require localized menu traversal or accessibility scripting.

### Virtual private-window profile

- Recorded that Safari private windows behave like a virtual window profile rather than a persisted Safari profile.
- Window and tab logic must therefore allow profile-like window states that are not present in the persisted profile catalog.

### Private-window create operation

- Added an explicit `open-private-window` create command on the `SafariWindow` model.
- Kept the operation specialized to `SafariFileMenu`, because opening a private window is a concrete File-menu behavior.
- Identified the private-window menu item through shortcut metadata instead of localized menu titles.

### Private mode ownership

- Recorded that private mode belongs to the window model, not to the tab model.
- Tabs inherit their containing window context, but they do not own a separate private-mode property.

### Safari saved tab-group model

- Added a `SafariTabGroup` model for saved Safari tab groups.
- Kept the first surface read-only as `tab-groups`, because create/update/delete semantics for saved groups were not yet specified.
- A saved group is detected structurally from `bookmarks` plus its `TopScopedBookmarkList` child, which excludes internal `Local` and `Private` groups.
- Extended `SafariWindow` read output with an optional active saved tab-group name when a window currently selects one.
- Extended `SafariWindow` read output further with an optional active saved tab-group identifier, so callers can address the selected saved group structurally instead of only by display name.
- Added `tab-group-tabs` as the next read surface for the model.
- Kept saved-group tab content separate from live `SafariTab`, because stored group tabs come from the bookmark database rather than from current Safari windows.
