# Decision Log

## 2026-07-14

### Explicit Safari window identities and disabled menu actions

- `safari windows` and `safari tabs` now expose fixed text columns for both the stable Safari `windowId` and the owning `processId`; JSON uses the same explicit names instead of encoding window identity as generic `identifier` and `index` keys.
- `windowId` remains the address accepted by mutation commands, while repeated `processId` values correctly mean that several windows belong to one Safari process.
- File-menu tab-group mutations inspect `AXEnabled` before `AXPress`. A false value fails immediately with a dedicated diagnostic, preventing a disabled action from being mistaken for a successful request followed by a missing database write.

## 2026-07-13

### PID-targeted Safari window and tab reads

- The literal `safari windows` and `safari tabs` read commands enumerate running Safari processes instead of relying on the bundle-level AppleScript target.
- `SafariUserInterface` owns the per-process `AXWindows` inventory, `SafariAppleScript` owns PID-targeted ScriptingBridge reads, and the `Safari` module intersects both sources by PID and title multiplicity to exclude stale scripting objects.
- Window indexes are reassigned globally after the intersection, while process-local Safari window identifiers remain unchanged in command output.
- Mutation commands keep their existing transports in this slice; the change is intentionally limited to the two read commands reported by issue #44.
- If Accessibility permission is unavailable, these reads retain the legacy single-process AppleScript fallback.

### Explicit injectable Safari Accessibility backend

- Production menu, File-menu, sidebar, and focused-window operations select the native Accessibility backend explicitly; executor-taking overloads select the AppleScript transport explicitly and never infer a backend from the executor's concrete type.
- `SafariAccessibilityBackend` centralizes running-application lookup, attribute reads and writes, actions, and polling so the production control flow can be exercised with synthetic AX element graphs.
- Native lookup scans the available Safari application elements for the relevant menu bar or focused window, avoiding an unconditional dependency on the first `com.apple.Safari` process.
- Unit tests cover native menu discovery and timeout, stable File-menu selection, sidebar reveal and identifier/name selection, rename discovery and confirmation, context-menu deletion and sheet confirmation, and focused-window close fallback without launching or mutating Safari.

### Authoritative saved tab-group identifiers

- Exact saved tab-group identifiers remain unambiguous even when multiple groups in one profile share a display name.
- Across sidebar rows, window readiness, and delete fallback checks, a matching stable identifier is authoritative and a different exposed identifier is a definitive mismatch.
- Display-name fallback is permitted only when the observed surface exposes no stable saved group identifier.

### Operation-owned windows for saved tab-group mutations

- Saved-group-backed `ensure-tab-list-urls` and `reorder-tab-list-urls` must never select their target group in a pre-existing Safari window, even when that window already belongs to the requested profile or currently shows the target group.
- A missing group carries the stable identifier of the new profile window opened by `ensure-tab-group`; a reused group opens another brand-new profile window before any sidebar selection or tab mutation.
- Both mutation commands carry that operation-owned stable window identifier through tab reads and writes.
- Failure cleanup deletes only a group created by the operation and closes only the operation-owned window, leaving all baseline windows and their selected groups unchanged.

## 2026-07-10

### Profile-window fallback after unresolved menu opens

- Added a shared Safari-domain fallback for profile-targeted new-window creation when Safari's profile File-menu item returns successfully but no new AppleScript window id becomes visible.
- The fallback focuses an already open non-private window that matches the requested profile through persisted profile metadata or profile-prefixed title, then asks Safari to `make new document` so Safari creates the new window in that focused profile context.
- Kept wrong-profile windows on the existing mismatch path: if Safari exposes a new window for another profile, commands still roll it back and report the profile mismatch instead of trying the fallback.
- Reused the fallback from both `safari open-window <profile>` and saved-tab-group creation, preserving the rule that profile-targeted saved-tab-group creation mutates only a newly opened window.

## 2026-07-01

### Command usage metadata and shared Safari argument parsing

- Added optional usage metadata to command descriptors so help output can describe mutually exclusive address forms and options with values without changing command execution semantics.
- Added shared Safari argument parsers for `--window-id`, `--window-index`, addressed tab arguments, and tab-list URL contexts.
- Kept each command responsible for its domain-specific validation and error types while moving repeated option scanning and positive-integer parsing into shared Safari helpers.
- Exposed `safari close-window --window-id <id>` so cleanup and rollback flows can close a concrete Safari window without relying on the volatile front-window order.

### Polling-based Safari accessibility reads

- Added shared Safari accessibility helpers for typed attribute reads, element arrays, string/boolean conversion, and bounded polling.
- Replaced fixed sleeps in menu, sidebar, and profile-window UI flows with retry loops that wait for the concrete accessibility element or action result needed by the next step.
- Kept the automation surface accessibility-only: polling observes accessibility structures and invokes accessibility actions, never pointer coordinates.

### Terminal-owned live Safari regression runner

- Moved the live Safari critical-flow regression out of Swift Testing execution.
- Kept the Swift test entrypoint disabled with instructions because `swiftpm-testing-helper` is not a reliable macOS TCC responsible process for Safari Automation permissions.
- Added `computer-automation-live-safari-regression` as a standalone executable that should be launched from an authorized terminal.
- The standalone runner executes each CLI step in a timeout-controlled child process and can optionally target a prebuilt `computer-automation` executable through `SAFARI_LIVE_TEST_CLI`.

### Default-profile saved tab-group normalization

- Kept `SafariDatabaseTabGroup` faithful to Safari's storage shape, where root/default saved groups can have an empty profile name.
- Mapped those empty saved-group profile names to the first persisted Safari profile in the higher-level `SafariTabGroup` model.
- Command text and JSON output now report the default profile display name instead of leaking the empty storage field.

## 2026-06-30

### Stable Safari window mutation targeting

- Added `--window-id` targeting to live tab-list and tab mutation commands that previously accepted only volatile `window-index` addresses.
- Saved-tab-group-backed URL reconciliation and reorder flows now carry the focused Safari window id through follow-up tab opens, tab reads, and tab moves after sidebar or window-focus UI work.
- `open-tab-group-window` and `set-window-tab-group` now select existing saved groups through identifier-aware sidebar selection by passing the resolved `SafariTabGroupRecord`, superseding the older toolbar-picker switching path for high-level commands.
- Window indexes remain accepted for backward compatibility and immediate-read workflows, but stable window ids are the preferred write address after any Safari UI operation that can reorder windows.

### Command argument preflight safety

- Added command-level argument preflight before command dispatch.
- `--help` is handled from command metadata before any command implementation can mutate Safari state.
- Unknown `--...` options are rejected before dispatch, and no-argument commands reject unexpected positional arguments before execution.
- This prevents diagnostic invocations such as `safari close-window --help` from reaching destructive command behavior.

### Profile-targeted open-window validation

- Tightened `safari open-window <profile>` so it accepts only a newly created window that matches the requested profile.
- The command first uses profile-prefixed window titles, then profile-aware `SafariWindow` readback, to resolve the new stable window id.
- If Safari opens no resolvable window or only a wrong-profile window, the command closes newly created window ids before surfacing the failure.
- Added stable-id AppleScript window closing as a reusable low-level operation so rollback does not depend on volatile front-window state.

### Stable saved tab-group sidebar targeting

- Changed saved tab-group sidebar selection to prefer Safari's `SidebarLibraryItemTabGroup` accessibility identifiers when a persisted saved group id is available.
- Kept display-name matching as a fallback for flows that do not yet have a saved group id or for Safari surfaces that expose no stable group identifiers.
- Routed saved tab-group delete and saved-group-backed tab-list operations through the resolved `SafariTabGroupRecord` so localized unnamed groups and duplicate display names across profiles do not rely on name-only targeting.
- Added AppleScript fallback support for the same identifier-first matching contract.

### Saved tab-group rollback after partial creation

- Added rollback for saved tab-group creation failures after Safari creates a new group but before the command can verify the expected profile/name result.
- `create-tab-group` now tracks pre-existing saved group identifiers and deletes newly created groups when expected-profile validation or rename/readback verification fails.
- `ensure-tab-group` closes the newly opened profile window when delegated creation fails.
- Saved-group-backed `ensure-tab-list-urls` and `reorder-tab-list-urls` delete a newly created group if later focusing, selection, mutation, or persistence verification fails.

## 2026-06-14

### Safari tab-list virtual model

- Added `SafariTabList` as a virtual model for ordered tab lists backed by either live Safari windows or saved Safari tab groups.
- Moved the model ownership of `window-tabs` and `tab-group-tabs` to `SafariTabList` while keeping the public CLI command names unchanged.
- Kept URL values as properties of individual tabs or stored tab records, with `SafariTabList` owning collection-level operations over ordered tab items.
- This supersedes the earlier split where `tab-group-tabs` was owned by `SafariTabGroup` and `window-tabs` was owned by `SafariTab`.

### Safari tab-list URL reconciliation

- Added `safari ensure-tab-list-urls` as an update operation on the virtual `SafariTabList` model.
- The command works for both window-backed and saved-tab-group-backed tab lists, adding only missing requested URLs and skipping URLs that already exist in the target list.
- Saved-tab-group reconciliation first delegates to `ensure-tab-group`, preserves the created/reused status in its summary, then focuses/selects the ensured group before opening missing URLs.
- The operation intentionally does not reorder existing tabs, delete extra tabs, or move URL ownership away from individual tab records.

### Safari tab-list URL-order reordering

- Added `safari reorder-tab-list-urls` as a second update operation on the virtual `SafariTabList` model.
- The command reorders existing matching tabs for both window-backed and saved-tab-group-backed tab lists, while keeping URL ownership on individual tabs.
- Requested URL duplicates are matched by occurrence from left to right; surplus requested occurrences are reported as missing and surplus existing occurrences are reported as extra.
- Extra tabs are not deleted. Matched requested tabs become the ordered prefix and unmatched tabs keep their previous relative order after that prefix.
- Saved-tab-group reorder focuses/selects the group in a compatible live window, moves the live tabs, and verifies that `tab-group-tabs` exposes the persisted reordered saved-group order before reporting success.

### Saved tab-group ensure summary

- Added `safari ensure-tab-group <profile> <name>` as the first high-level slice of the saved tab-group create/reuse workflow.
- The command reuses exactly one existing saved group or creates a missing group through the existing profile-window and `create-tab-group` flow.
- The initial structured summary reports `status` as `created` or `reused` plus the resolved `tabGroup`; URL reconciliation and cleanup fields are left for later issues.

### Find and resolve command semantics

- Documented `find-*` and `resolve-*` as separate read command forms rather than separate CRUD categories.
- `find-*` commands return zero, one, or many matches and represent zero matches as an empty result.
- `resolve-*` commands share the same lookup criteria but must return exactly one entity, failing clearly when no entity matches or when the lookup is ambiguous.
- Models that support public record lookup must expose `find-*` and `resolve-*` as a pair so callers do not see divergent lookup semantics across models.
- Added `safari resolve-tab` as the single-entity counterpart to `safari find-tab`.
- Added `safari find-tab-group` and `safari resolve-tab-group` as the paired lookup surface for saved Safari tab groups by profile and name.
- Added `safari find-profile` and `safari resolve-profile` as the paired lookup surface for Safari profiles by name.

### Concrete Safari tab JavaScript execution

- Added `safari execute-tab-javascript <window-id> <tab-index> <javascript>` as the supported high-level way to evaluate JavaScript in a concrete live Safari tab.
- Targeting uses Safari's stable AppleScript window id plus the tab index within that window, avoiding front-document-only execution.
- Kept the public CLI command in the `SafariTab` model and the direct `do JavaScript` transport in `SafariAppleScriptTab`, matching the existing rule that direct AppleScript access stays inside `SafariAppleScript`.
- Missing target windows and tabs are mapped to explicit command errors, while JavaScript/runtime failures are sanitized so browser state and page details are not emitted in CLI errors.
- JSON output returns the target address and result as `windowId`, `tabIndex`, and `result`.
- JavaScript source can be supplied as an inline argument, from standard input with `--stdin`, or from a UTF-8 file with `--file`; the command rejects multiple simultaneous script sources.

### CLI JSON output mode

- Added a global `--json` command output mode before module commands, for example `computer-automation --json safari find-tab https://example.com`.
- Kept existing text output unchanged and implemented JSON as a parallel command output path in `AutomationFoundation` instead of parsing pipe-delimited text back into records.
- Commands with structured records return JSON objects or arrays, while simple status and mutation commands fall back to a JSON `message` object.
- This gives callers a delimiter-safe way to consume URLs, titles, menu labels, and tab-group names that may contain `|`.

### Safari tab lookup by URL

- Added `safari find-tab <url>` as the supported high-level way to locate open Safari tabs by URL instead of duplicating AppleScript loops in callers.
- Kept exact URL matching as the default and added explicit `--prefix`, `--window-id`, `--window-index`, and `--profile` filters.
- The command returns stable machine-readable rows as `windowId|windowIndex|tabIndex|url|title`, combining AppleScript tab data with Safari window ids from the window model.
- `SafariAppleScriptTab.list()` now returns structured Apple event list items so tab titles and URLs containing separators can be parsed without relying on ad hoc string splitting.

### Open window returns created window id

- Extended `safari open-window` to report the newly created Safari window id as a stable `window-id|<id>` line after the existing human-readable success message.
- Kept window creation owned by `SafariWindowOpenCommand` and resolved the id by comparing AppleScript-visible window ids before and after opening.
- Preserved the profile-open error contract while adding a distinct failure for cases where Safari opens a window but its id cannot be resolved.

### Safari database access moved to its own module

- Split direct `SafariTabs.db` access out of the `Safari` domain module into a dedicated `SafariDatabase` module.
- Modeled persisted database entities separately as `SafariDatabaseProfile`, `SafariDatabaseWindow`, and `SafariDatabaseTabGroup`.
- Kept CLI command ownership and user-facing records in `Safari`; that module now maps database records into Safari domain records.
- Preserved the existing database access behavior: readability preflight, short SQLite busy timeout, `safari windows` degradation when the database is unavailable, and actionable Full Disk Access errors.

### Safari database access fails fast and windows degrades

- Added a shared Safari database opener for direct `SafariTabs.db` access.
- The opener preflights file readability and installs a short SQLite busy timeout so unreadable or locked Safari databases fail quickly instead of hanging command execution.
- Kept saved profile and tab-group list operations DB-backed because there is no equivalent verified non-DB source for those records yet.
- Allowed `safari windows` to degrade when `SafariTabs.db` is unavailable: it still returns AppleScript window identity, index, and name, while DB-derived private/profile/tab-group fields are left empty or defaulted.
- Documented Full Disk Access as the current permission requirement for complete DB-backed Safari metadata.

### Commit and push after every completed change

- Tightened the delivery rule from committing completed change sets to committing and pushing every completed verified change immediately.
- Kept verification explicit as part of the rule so commits represent checked work, not just local edits.

### Saved tab-group rename remains unsupported

- Kept standalone saved tab-group rename out of the public CLI surface because Safari's visible sidebar rename affordance is not currently exposed through a verified stable accessibility trigger.
- Documented create-new-and-delete-old as a possible future replacement workflow rather than a rename implementation.
- Recorded the replacement tradeoff explicitly: it would change the saved tab-group identifier and may lose Safari-owned metadata that the current model does not read or reproduce.
- Updated current docs to describe supported saved tab-group operations as create/read/delete instead of full CRUD.
- This supersedes the earlier full-CRUD direction for tab groups until Safari exposes a verified accessibility path for true rename.

## 2026-06-08

### Accessibility-first UI scripting

- Added a standing rule that UI automation must use accessibility elements, attributes, and actions rather than synthetic coordinate-based clicking.
- Synthetic coordinate clicking is explicitly disallowed, including as a fallback.
- This tightens the Safari tab-group CRUD direction further: the sidebar surface should be automated structurally through accessibility, not by pointer coordinates.

### Consistent automation surface for related operations

- Added a standing rule that related operations should use one primary automation surface whenever the product allows it.
- Applied that rule explicitly to Safari tab-group CRUD.
- Safari tab-group create, read, update, and delete should converge on the opened sidebar tab-group surface instead of mixing direct database mutation, File-menu commands, and toolbar pickers.

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
- Added `window-tabs` as a second read surface on `SafariTab` for one concrete window.
- Kept the selected-group relation as window-scoped read metadata instead of treating it as an intrinsic tab property.

### Window-level saved tab-group switching

- Added `open-tab-group-window` as a create command on `SafariWindow`.
- Added `set-window-tab-group` as an update command on `SafariWindow`.
- Kept both commands on the window model because the selected saved tab group is a window-scoped state, not a property of an individual tab.
- Added reusable `SafariToolbar` and `SafariToolbarItem` models in `SafariUserInterface`.
- Added matching `SafariAppleScriptToolbar` and `SafariAppleScriptToolbarItem` infrastructure models in `SafariAppleScript`.
- Implemented live switching by composing those reusable toolbar models rather than by keeping a one-off tab-group picker helper.
- Identified the picker structurally through an accessibility identifier that starts with `TabGroupPickerButton`.
- Reused existing profile-aware `open-window` behavior for new-window creation, then switched the new front window to the target saved tab group.
- Rejected private windows for saved tab-group switching because Safari private windows do not own saved tab-group state.
- Rejected duplicate saved tab-group names within one profile because the picker UI currently exposes only display names, not stable bookmark identifiers.
