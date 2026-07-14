# Computer Automation

Minimal Swift application for computer automation experiments.

## Overview

- The repository is organized by top-level modules.
- The current modules are `Safari`, `SafariDatabase`, `SafariUserInterface`, and `SafariAppleScript`.
- The current runnable slice covers Safari application lifecycle commands, profile listing and lookup, browser window operations, saved tab-group create/reuse/read/delete flows, ordered tab-list reads, URL reconciliation, and URL-order reordering for windows and saved groups, window-level tab-group switching, and tab lookup by URL.
- The CLI also exposes Safari UI inspection commands for the application menu bar and File menu.
- Saved tab-group create/delete is driven by accessibility:
  - the target group is resolved through the opened Safari sidebar; a matching saved group identifier is authoritative, a different exposed identifier is a definitive mismatch, and display-name fallback is allowed only when the sidebar exposes no stable group identifiers
  - create uses Safari's File-menu action identified by `NewEmptyTabGroupMenuItem`
  - create relies on Safari's post-create inline edit field for naming the newly created group
  - create rolls back newly created groups when profile validation or rename/readback verification fails
  - delete uses the selected group's context menu item `DeleteTabGroupMenuItem`
  - standalone rename is currently not exposed because the visible Safari sidebar rename affordance is not available through a stable accessibility trigger
  - replacing a group by creating a new one and deleting the old one is documented as a possible future workaround, but it is not implemented because it would change the stable group identifier and may lose Safari metadata
- Module and command models expose metadata for CLI tab completion.

## Current app

- Built with Swift Package Manager.
- The runnable stack currently includes the `Safari`, `SafariDatabase`, `SafariUserInterface`, and `SafariAppleScript` modules.
- The `Safari` module exposes application, profile, window, saved tab-group, tab-list, and tab commands.
- Requires macOS with Safari installed.

## Run

```bash
swift run computer-automation safari launch
swift run computer-automation safari running
swift run computer-automation safari quit
swift run computer-automation safari profiles
swift run computer-automation safari find-profile Twisto
swift run computer-automation safari resolve-profile Twisto
swift run computer-automation safari windows
swift run computer-automation safari open-window
swift run computer-automation safari open-window Twisto
swift run computer-automation safari close-window
swift run computer-automation safari close-window --window-id 42
swift run computer-automation safari open-tab-group-window 1000
swift run computer-automation safari set-window-tab-group 1 1000
swift run computer-automation safari create-tab-group 1 Inbox
swift run computer-automation safari ensure-tab-group Twisto Inbox
swift run computer-automation --json safari ensure-tab-group Twisto Inbox
swift run computer-automation safari tab-groups
swift run computer-automation safari find-tab-group Twisto Focus
swift run computer-automation safari resolve-tab-group Twisto Focus
swift run computer-automation safari tab-group-tabs 1000
swift run computer-automation safari delete-tab-group 1000
swift run computer-automation safari ensure-tab-list-urls --window-index 1 https://example.com https://openai.com
swift run computer-automation safari ensure-tab-list-urls --window-id 42 https://example.com https://openai.com
swift run computer-automation safari ensure-tab-list-urls --tab-group-profile Twisto --tab-group-name Inbox https://example.com
swift run computer-automation --json safari ensure-tab-list-urls --tab-group-profile Twisto --tab-group-name Inbox https://example.com
swift run computer-automation safari reorder-tab-list-urls --window-index 1 https://openai.com https://example.com
swift run computer-automation safari reorder-tab-list-urls --window-id 42 https://openai.com https://example.com
swift run computer-automation safari reorder-tab-list-urls --tab-group-profile Twisto --tab-group-name Inbox https://openai.com https://example.com
swift run computer-automation --json safari reorder-tab-list-urls --window-index 1 https://openai.com https://example.com
swift run computer-automation safari open-tab 1 https://example.com
swift run computer-automation safari open-tab --window-id 42 https://example.com
swift run computer-automation safari tabs
swift run computer-automation safari find-tab https://example.com
swift run computer-automation safari find-tab https://example.com --prefix --window-id 42 --profile Twisto
swift run computer-automation --json safari find-tab https://example.com --prefix
swift run computer-automation safari resolve-tab https://example.com --window-id 42
swift run computer-automation --json safari resolve-tab https://example.com --window-id 42
swift run computer-automation safari window-tabs 1
swift run computer-automation safari window-tabs --window-id 42
swift run computer-automation safari execute-tab-javascript 42 2 'document.title'
printf 'document.readyState' | swift run computer-automation safari execute-tab-javascript 42 2 --stdin
swift run computer-automation safari execute-tab-javascript 42 2 --file script.js
swift run computer-automation --json safari execute-tab-javascript 42 2 'document.readyState'
swift run computer-automation safari set-tab-url 1 1 https://example.com
swift run computer-automation safari set-tab-url --window-id 42 1 https://example.com
swift run computer-automation safari close-tab 1 1
swift run computer-automation safari close-tab --window-id 42 1
swift run computer-automation safari-ui menu-bar-items
swift run computer-automation safari-ui menu-items 3
swift run computer-automation safari-ui file-menu-items
swift run computer-automation safari-ui menu-item-children 3 27
```

Running the executable launches Safari on macOS.

Safari window-creation commands print a human-readable success line followed by a stable machine-readable window identifier line:

```text
Safari window opened.
window-id|42
```

`open-window`, `open-private-window`, and `open-tab-group-window` all resolve and report the exact newly created window as `window-id|<id>` in text mode and `windowId` in JSON mode. Profile opening verifies the requested profile. Private opening verifies private state when Safari database metadata is available. Saved-group opening carries the exact id through focus and sidebar selection, verifies the selected group by readback, and rolls back only its operation-owned window on failure.

`safari find-tab <url>` searches open Safari tabs by exact URL. Add `--prefix` for prefix matching, `--window-id <id>` or `--window-index <index>` to limit the search to one window, and `--profile <name>` to limit matches to a Safari profile when window profile metadata is available. It prints one machine-readable row per match:

```text
windowId|windowIndex|tabIndex|url|title
```

`safari resolve-tab <url>` uses the same filters as `find-tab`, but it must resolve exactly one tab. It prints the same single row shape as `find-tab`, fails when no tab matches, and fails when the query is ambiguous.

`safari ensure-tab-group <profile> <name>` creates or reuses a saved Safari tab group. When creating a missing profile-specific group, it opens a brand-new window for the requested profile and mutates only that new window. Text mode reports whether the group was `created` or `reused` and prints the resolved group row. JSON mode returns a stable summary with `status` and `tabGroup`. If Safari exposes the required File-menu action as disabled, the command fails immediately with an actionable error instead of waiting for a database mutation that cannot occur.

Saved tab-group outputs report the Safari profile display name. Safari may store default-profile groups with an empty profile field internally, but the CLI maps that storage detail back to the default profile name.

`safari delete-tab-group <identifier>` deletes a saved Safari tab group and verifies through readback that the group disappeared before returning success.

`safari ensure-tab-list-urls` adds missing URLs to a window-backed or saved-tab-group-backed tab list and skips URLs already present in that list. Use `--window-id <id>` for stable live-window writes, `--window-index <index>` only when you have just re-read the current window order, or `--tab-group-profile <profile> --tab-group-name <name>` for a saved tab group. For saved groups, the command creates a missing group in its newly opened profile window or opens a brand-new profile window when reusing an existing group, then selects the group through the Safari sidebar by saved group id and reports the operation window id in text and JSON output. It never repurposes a pre-existing Safari window. If selection or mutation fails, the command deletes a group created by the operation and closes only the operation-owned window before failing.

`safari reorder-tab-list-urls` reorders existing matching tabs in a window-backed or saved-tab-group-backed tab list so the requested URL occurrences become the ordered prefix. Use `--window-id <id>` for stable live-window writes; Safari window indexes can change after focus, open-window, and tab-group switching operations. It does not create missing URLs and does not delete extra tabs; text and JSON output report moved, unchanged, missing, and extra entries. The saved-group path follows the same operation-owned-window rule as URL reconciliation: it opens a new window when reusing a group and leaves pre-existing windows unchanged. On failure it deletes any group created by the operation and closes only the operation-owned window.

Window-level tab commands accept either the original positional `window-index` form or `--window-id <id>`. Prefer `--window-id` for `open-tab`, `window-tabs`, `set-tab-url`, and `close-tab` when the command follows any Safari UI operation that may reorder windows.

`safari close-window` closes Safari's front window by default. Use `--window-id <id>` to close a specific window by stable Safari window identifier. Identifier-targeted close verifies that the exact focused Accessibility window is no longer visible; if Safari leaves a visible zero-tab window, it presses that window's structural close button and verifies again before reporting success.

`safari windows` and `safari tabs` enumerate every running Safari process. They cross-check each process's Accessibility window inventory with PID-targeted scripting data, which excludes stale scripting objects from processes that own no Accessibility windows while preserving tabs from profile-specific Safari processes. When Accessibility permission is unavailable, the commands fall back to the legacy single-process AppleScript read.

Window rows expose both identities explicitly:

```text
windowId|windowIndex|isPrivate|profile|selectedTabGroupIdentifier|tabGroup|name|processId
```

Tab rows use the corresponding fixed shape:

```text
windowId|windowIndex|tabIndex|url|processId
```

`windowId` is the stable Safari window address used by `--window-id`. `processId` identifies the owning Safari process, so the same process id normally appears on several different window rows. JSON uses the explicit keys `windowId`, `windowIndex`, and `processId` as well.

Prefix a module command with `--json` to get structured JSON instead of line-oriented text. Commands backed by structured records return arrays or objects; simple status commands return a JSON message object.

```bash
swift run computer-automation --json safari find-tab https://example.com --prefix
```

Append `--help` to a module command to print its usage without running the command.

CLI failures use human-readable messages for validation, Safari state, permissions, UI availability, database access, and AppleScript transport errors. Unexpected internal errors use a generic fallback instead of exposing Swift enum case names or sensitive JavaScript/transport details.

`safari execute-tab-javascript <window-id> <tab-index> <javascript>` runs JavaScript in a concrete Safari tab addressed by stable window id and tab index. The JavaScript source can be an inline argument, `--stdin`, or `--file <path>` / `--file=<path>`. Provide exactly one source. Text mode prints the JavaScript result as stdout. JSON mode returns the target address and result:

```json
{"windowId":42,"tabIndex":2,"result":"complete"}
```

Primitive JavaScript results are returned as text. Object and array results are serialized with `JSON.stringify(...)` before being returned.

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

The default test suite is safe for normal development: it does not opt in to live
Safari regression tests.

### Opt-in live Safari regression

Live Safari regression is not run through `swift test`. SwiftPM executes tests
inside `swiftpm-testing-helper`, which is not a reliable macOS TCC responsible
process for Safari Automation permissions. Run the standalone executable from
an authorized terminal instead.

Run it only against a disposable or test Safari profile because it creates
temporary windows, saved tab groups, and tabs, then attempts to delete or close
those artifacts during cleanup.

Prerequisites:

- Automation permission from the terminal to Safari and System Events.
- Accessibility permission for the terminal.
- Full Disk Access for the terminal so commands can read `SafariTabs.db`.
- Safari's Develop setting that allows JavaScript from Apple Events when
  exercising JavaScript execution.

```bash
SAFARI_LIVE_TEST_PROFILE=Automation \
swift run computer-automation-live-safari-regression
```

Optional environment variables:

- `SAFARI_LIVE_TEST_CLI` points to a prebuilt `computer-automation`
  executable. When unset, the regression runner executes the same CLI router in
  a timeout-controlled child process of the standalone runner.
- `SAFARI_LIVE_TEST_COMMAND_TIMEOUT_SECONDS` controls the per-command timeout
  used by the live regression subprocess runner. The default is 120 seconds.
- `SAFARI_LIVE_TEST_GROUP_PREFIX` controls the temporary saved-tab-group name
  prefix. The regression runner appends a UUID token.
- `SAFARI_LIVE_TEST_URL_1` and `SAFARI_LIVE_TEST_URL_2` override the two test
  URLs used for window-id tab mutation and saved-group URL ensure/reorder.
