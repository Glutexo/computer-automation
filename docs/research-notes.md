# Research Notes

## 2026-06-14

### Safari database access stabilization

- Direct reads from `SafariTabs.db` can fail on macOS when the caller lacks Full Disk Access to Safari's container data.
- `safari windows` can still provide useful partial data without the database because Safari AppleScript exposes window ids and names.
- Saved profile and saved tab-group records still require the database in the current model; no verified AppleScript or accessibility source exposes equivalent stable identifiers.
- A short SQLite busy timeout is enough to keep DB-backed commands from waiting indefinitely when Safari is actively writing or locking the database.

## 2026-06-08

### Safari tab-group sidebar findings

- With Safari's sidebar open, the browser window exposes the sidebar as:
  - `AXSplitGroup`
  - child `AXScrollArea`
  - child `AXOutline` with identifier `Sidebar`
- The tab-group section header appears as an `AXRow` whose cell description is `Gruppi di pannelli di <profile>`.
- Saved tab groups appear as `AXRow` items with inner cell descriptions like `<name>, gruppo con <n> pannelli`.
- The currently open group's live tabs appear immediately after the selected group row in the same outline, so a tab-group sidebar model must distinguish group rows from live tab rows structurally.
- `System Events` can select sidebar rows structurally with `select row <index> of outline`.
- The row and cell accessibility attributes are readable enough to identify group rows, disclosure state, and selection state.
- The outline itself exposes the `AXShowMenu` action and rows expose `AXShowDefaultUI` and `AXShowAlternateUI`.
- Direct AppleScript inspection did not surface a contextual menu tree for the selected row after `AXShowMenu`.
- Native AX inspection also did not reveal a popup menu as a simple extra `AXMenu` child of the Safari window or application tree after a sidebar right click.
- Native AX inspection does provide accurate row frames, but pointer-event automation is outside project rules.
- The next implementation step must continue through accessibility only, not through coordinate clicks.
- The File-menu `Save As` action is not a reliable rename entrypoint for saved tab groups:
  - for the currently open group it opens the normal page-save sheet
  - for another selected group it did not produce a verified rename state
- The verified inline text-field path is narrower:
  - Safari exposes an editable inline field immediately after `NewEmptyTabGroupMenuItem`
  - that field can be written and confirmed through accessibility
- A create-new-and-delete-old workaround could approximate rename only as a replacement operation:
  - it would change the saved tab-group identifier
  - it could lose Safari metadata beyond the URLs currently exposed by `tab-group-tabs`
  - it should therefore remain documentation-only unless the product explicitly accepts those semantics

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
- Safari submenu traversal is available through `menu 1 of menu item <index>`, so submenu reads can stay structural as well.
- The same structural technique works for any top-level Safari menu, so menu inspection should live in a general menu model rather than only in a File-specific model.
- Open window profile names can be resolved from `SafariTabs.db` by joining `windows.active_profile_id` to `bookmarks.title`.
- Safari GUI scripting should live outside the `Safari` domain module in a dedicated `SafariUserInterface` module.
- Safari private windows appear to represent a virtual window profile rather than a normal persisted Safari profile, so profile-mapping logic must not assume every window profile has a `SafariTabs.db` bookmark row.
- Safari's active tab-group picker appears in the front-window toolbar as an `AXMenuButton` with an accessibility identifier that starts with `TabGroupPickerButton`.
- The picker menu lists saved tab groups by display name, includes a mark character on the current group, and does not expose the saved-group bookmark identifier directly.
- Because the picker menu is name-based, duplicate saved tab-group names inside one profile are not safely distinguishable through the current accessibility surface.

### Open questions

- Should the first implementation focus on desktop UI automation, shell automation, or hybrid flows?
- What level of observability and recovery is required for failed automation steps?
