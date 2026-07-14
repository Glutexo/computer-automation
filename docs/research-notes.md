# Research Notes

## 2026-07-14

### Disabled tab-group actions and ambiguous window output

- GitHub issue #48 showed that Safari can expose both `NewEmptyTabGroupMenuItem` and `NewTabGroupWithTabsMenuItem` with `AXEnabled=false` in a newly opened profile window.
- `AXPress` alone is not an adequate success precondition for those items: the command must reject an explicitly disabled item before waiting for a saved-group database mutation.
- The issue's apparent repeated window id was the newly appended `processId` in text output; `safari windows` did not include `SafariWindowRecord.identifier` at all. Fixed field positions and explicit JSON names are required so operation-owned `windowId` values can be correlated with later reads without confusing them with an owning process id.

## 2026-07-13

### Safari read discovery must target and cross-check each process

- GitHub issue #44 showed that the bundle-level `tell application "Safari"` target can return no windows or stale windows while another `com.apple.Safari` process owns populated profile windows.
- PID-targeted ScriptingBridge exposes the process-local window and tab objects, but those results can also retain stale objects after their Accessibility windows disappear.
- Reliable read discovery intersects PID-targeted scripting windows with each process's `AXWindows` inventory and title multiplicity, then assigns one global CLI window order across the surviving process-local records.
- Safari may omit `AXVisible` even on a real window, so membership in `AXWindows`, rather than that optional attribute, is the structural source for this cross-check.

### Sidebar discovery must qualify the structural outline

- GitHub issue #30 reproduced saved-tab-group selection failures when Safari exposed accessibility outlines other than the actual `AXOutline` with identifier `Sidebar`.
- Safari reports `AXVisible=false` even for an open, populated sidebar outline, so sidebar state must be determined by structural presence rather than that attribute.
- Sidebar selection, rename, and deletion must recursively resolve the outline by role and identifier instead of accepting the first outline or assuming a fixed three-element hierarchy.
- When several Safari processes exist, the process owning the focused window must be activated before revealing or mutating its sidebar; activating Safari generically can target a different process with no windows.
- The System Events fallback must resolve the focused window structurally, reveal the sidebar through `SidebarButton`, and poll for the qualified outline because Safari can publish it after the button action returns.

### Reused saved groups can repurpose unrelated profile windows

- GitHub issue #29 captured a saved-tab-group kickoff that reused an existing group, focused the only open Twisto window, and switched that unrelated window from `⏳ TSD-9309` to `🧾 TSD-9500`.
- `ensure-tab-list-urls` and `reorder-tab-list-urls` both delegated reused groups to `focusWindowForTabGroup`, whose fallback intentionally selected an existing window with the same profile before selecting the target sidebar row.
- The existing unit tests encoded that behavior by asserting that a reused group did not open a new profile window.
- Saved-tab-group mutation safety requires explicit ownership, not best-match window lookup: carry the exact newly created window from group creation, and open a separate new profile window for every reused-group mutation.

## 2026-07-11

### Profile File-menu clicks can block profile-window fallback

- GitHub issue #28 captured a `safari open-window Twisto` hang while a review helper tried to update an existing saved tab group.
- The command already used the profile keyboard shortcut first and bounded the follow-up window polling, so an indefinite block most likely came from the later File-menu fallback that clicked the profile window item through System Events AppleScript.
- The profile File-menu fallback should use the native accessibility `AXPress` path already used by other real File-menu actions, leaving AppleScript menu-item clicking only for injected test executors.

## 2026-07-10

### Safari profile menu can succeed without a resolvable new window id

- GitHub issue #27 captured a Twisto profile failure where `safari open-window Twisto` reported that Safari opened a window but no new window id could be resolved.
- In the same Safari session, focusing an existing Twisto-profile window and running AppleScript `make new document` created a resolvable Twisto window named `Twisto — Pagina di apertura`.
- Treat a successful profile File-menu press followed by no new AppleScript id as a recoverable no-new-window case when an existing matching profile window is available.
- Do not use this fallback for observed wrong-profile windows; those remain a mismatch and should be rolled back.
- A later live regression against Twisto still failed when no Twisto window was already open. The File menu contained `Nuova finestra di Twisto` as item 2 with shortcut metadata `N|0`, so the profile item existed. This points to the native AX press path being insufficient even when it reports success; the System Events indexed click path is the next verified candidate because it targets the same structural menu item.
- Switching to the System Events indexed click path alone still left `open-window Twisto` unresolved. The remaining likely factor is delayed profile-window or database metadata propagation beyond the original 1-second `open-window` polling window, so profile-targeted window creation needs a longer bounded poll than unprofiled AppleScript document creation.
- Extending the profile-window poll still failed when no Twisto window was open. In the same session, Command-N created a default-profile `Glutexo` window, Command-Option-Shift-2 created no window, and Command-Option-Shift-1 created a `Twisto — Pagina di apertura` window. Safari's profile shortcuts therefore map `0` to the default profile and `1...9` to additional profiles in persisted profile order.
- Later live Twisto runs showed that the System Events File-menu click path can hang inside `NSAppleScript` before returning control to fallback logic. Prefer the profile keyboard shortcut before File-menu profile opening when profile order is known.
- A manual live regression passed after switching profile-window creation paths to shortcut-first: saved-group URL ensure added both URLs, reorder reported no missing URLs, persisted order matched the request, and delete readback removed the temporary group.

### Safari saved tab-group selection can lag behind AX row selection

- The Twisto live regression later reached saved tab-group URL operations, but `reorder-tab-list-urls` could report both just-added URLs as missing immediately after `ensure-tab-list-urls`.
- The likely race is that AX sidebar row selection returns before Safari has loaded the selected saved group into the focused window and before `SafariTabs.db` exposes that window as selected for the group.
- Saved-group-backed tab-list writes should wait until `safari windows` reports the target group for the stable window id and the live window tabs represent the saved tab-group rows before adding or reordering URLs.

## 2026-07-01

### SwiftPM live Safari test TCC behavior

- Passive TCC inspection showed Air had AppleEvents permissions for Safari and System Events, Accessibility, and Full Disk Access.
- Terminal had AppleEvents and Accessibility permissions, but its Full Disk Access TCC record was denied.
- `swiftpm-testing-helper`, which hosts Swift Testing bundles, had no visible AppleEvents permission for Safari or System Events.
- The live Safari regression stalled inside an `NSAppleScript` call reached through `SafariAppleScriptWindow.list()` before any Safari mutation.
- Live Safari regression should run from a process launched by an explicitly authorized terminal, or from another standalone runner whose responsible process can receive the needed TCC permissions.
- After Terminal Full Disk Access was corrected, `SAFARI_LIVE_TEST_PROFILE=Glutexo swift run computer-automation-live-safari-regression` completed successfully from Terminal.
- The same standalone regression also completed successfully from the Air shell against the `Glutexo` profile, confirming that the standalone executable path avoids the `swiftpm-testing-helper` TCC stall for the current environment.

## 2026-06-30

### Safari default-profile tab-group creation

- In a Safari setup with the default profile named `Glutexo` and another profile named `Twisto`, saved tab groups created for the default profile can be persisted in `SafariTabs.db` with an empty `profileName`.
- Treat the empty stored profile name as an alias for the first available Safari profile when finding, creating, and ensuring profile-scoped saved tab groups.
- Profile-specific new-window automation should press only items in Safari's top-level File menu. Recursive application-wide menu searches can find the wrong profile action and create the tab group in another profile.
- If Safari opens a new window for the wrong profile or creates a saved tab group with a mismatched stored profile, the command should roll back the new window and any created tab group before reporting failure.
- Safari AppleScript window targeting by stable `id` is more reliable when iterating over `every window` and comparing `id of currentWindow`; direct filtered expressions such as `every window whose id is ...` can fail with invalid-index errors after profile-window creation.

## 2026-06-25

### Safari localization and root tab-group behavior

- The current macOS language preference list starts with `ja-CZ`, and Safari exposes localized menu titles such as `ファイル` for the File menu.
- File-menu addressing by menu bar index `3` remains valid under that localization.
- `NewEmptyTabGroupMenuItem` and `DeleteTabGroupMenuItem` remain stable `AXIdentifier` values under the Japanese Safari UI.
- The private-window menu item can still be identified through shortcut metadata (`N` with modifier value `1`) rather than localized title text.
- Safari may persist a newly created empty tab group as a root `bookmarks` row with `parent = 0`, `type = 1`, `subtype = 0`, and a `TopScopedBookmarkList` child, exposing no profile name in `SafariTabs.db`.
- The default localized name for that root group was observed as `名称未設定`.
- The create flow must tolerate delayed Safari database writes after inline rename confirmation; a short one-second poll can report failure even though Safari later persists the expected name.
- When a saved group is already the current front-window group but the sidebar row is not found, File-menu deletion through `DeleteTabGroupMenuItem` is a verified structural fallback.

## 2026-06-14

### Safari database access stabilization

- Direct reads from `SafariTabs.db` can fail on macOS when the caller lacks Full Disk Access to Safari's container data.
- `safari windows` can still provide useful partial data without the database because Safari AppleScript exposes window ids and names.
- Saved profile and saved tab-group records still require the database in the current model; no verified AppleScript or accessibility source exposes equivalent stable identifiers.
- A short SQLite busy timeout is enough to keep DB-backed commands from waiting indefinitely when Safari is actively writing or locking the database.
- The database stabilization code now belongs in `SafariDatabase`, because the tables represent persisted Safari entities rather than command-level Safari behavior.

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
- The executable toolbar-picker model stack was removed after saved-tab-group selection moved to identifier-aware sidebar rows; these findings remain as historical evidence rather than a supported automation path.

### Open questions

- Should the first implementation focus on desktop UI automation, shell automation, or hybrid flows?
- What level of observability and recovery is required for failed automation steps?
