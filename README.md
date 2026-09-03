# Computer Automation

Minimal Swift application for computer automation experiments.

## Overview

- The repository is organized by top-level modules.
- The application modules are `Safari`, `SafariDatabase`, `SafariUserInterface`, and `SafariAppleScript`; `ComputerAutomationKit` and `ComputerAutomationMCP` provide the CLI and MCP adapters.
- The current runnable slice covers Safari application lifecycle commands, profile listing and lookup, browser window operations, saved tab-group create/reuse/read/delete flows, ordered tab-list reads, URL reconciliation, and URL-order reordering for windows and saved groups, window-level tab-group switching, and tab lookup by URL.
- The CLI also exposes Safari UI inspection commands for the application menu bar and File menu.
- A local stdio MCP server exposes the same command inventory as typed tools, with mutation tools disabled by default.
- Saved tab-group create/delete is driven by accessibility:
  - the target group is resolved through the opened Safari sidebar; a matching saved group identifier is authoritative, a different exposed identifier is a definitive mismatch, and display-name fallback is allowed only when the sidebar exposes no stable group identifiers
  - create captures the operation window's current tabs through Safari's File-menu action identified by `NewTabGroupWithTabsMenuItem`; this path remains persisted after the operation window closes
  - create relies on Safari's post-create inline edit field for naming the newly created group
  - create rolls back newly created groups when profile validation or rename/readback verification fails
  - delete uses the selected group's context menu item `DeleteTabGroupMenuItem`
  - standalone rename is currently not exposed because the visible Safari sidebar rename affordance is not available through a stable accessibility trigger
  - replacing a group by creating a new one and deleting the old one is documented as a possible future workaround, but it is not implemented because it would change the stable group identifier and may lose Safari metadata
  - when database-backed inventory is unavailable, an explicit sidebar fallback lists or exactly deletes groups in a brand-new operation-owned profile window without cycling through unrelated groups
- Module and command models expose metadata for CLI tab completion.

## Current app

- Built with Swift Package Manager.
- The runnable stack includes the Safari modules plus `ComputerAutomationKit` for CLI routing and `ComputerAutomationMCP` for local MCP adaptation.
- The `Safari` module exposes application, profile, window, saved tab-group, tab-list, and tab commands.
- Requires macOS 13 or newer with Safari installed.

## MCP server

`computer-automation-mcp` exposes the existing command inventory as Model Context Protocol tools over standard input/output. Tool names combine the module and command names with underscores, such as `safari_windows`, `safari_find_tab`, and `safari_ui_menu_items`. Arguments use typed camel-case JSON properties, and successful calls return both JSON text content and MCP structured content.

Build the executable that an MCP client will launch:

```bash
swift build -c release --product computer-automation-mcp
```

The server is read-only by default. It omits every command whose metadata says it can change state, including `execute-tab-javascript`, because arbitrary page JavaScript is not guaranteed to be read-only even though the command is a CRUD read operation. It also omits `sidebar-tab-groups`, whose fallback inventory temporarily opens and closes a profile window.

```bash
swift run computer-automation-mcp
```

To expose the full current command inventory, configure the client to pass the explicit mutation flag:

```bash
swift run computer-automation-mcp --allow-mutations
```

A generic local MCP client configuration for the release binary has this shape:

```json
{
  "mcpServers": {
    "computer-automation": {
      "command": "/absolute/path/to/.build/release/computer-automation-mcp",
      "args": []
    }
  }
}
```

Add `"--allow-mutations"` to `args` only when the client should be able to launch or quit Safari, open, update, or close windows and tabs, create or delete saved tab groups, or execute JavaScript. MCP tool calls are serialized so concurrent requests cannot race each other while operating Safari.

The MCP transport owns standard input, so the `safari_execute_tab_javascript` tool accepts inline JavaScript only; the CLI-only `--stdin` and `--file` source forms are not MCP arguments. The MCP client or the process that launches the server may need the same Automation, Accessibility, and Full Disk Access permissions described for the CLI.

Profile-scoped `find-tab` and `resolve-tab` calls collect one consistent cross-process window-and-tab snapshot instead of repeating Safari discovery for each filter. PID-targeted scripting requests use bounded Apple-event timeouts and return an actionable timeout error if one Safari process stops responding.

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
swift run computer-automation safari sidebar-tab-groups Twisto
swift run computer-automation safari sidebar-tab-groups Twisto Inbox
swift run computer-automation safari find-tab-group Twisto Focus
swift run computer-automation safari resolve-tab-group Twisto Focus
swift run computer-automation safari tab-group-tabs 1000
swift run computer-automation safari delete-tab-group 1000
swift run computer-automation safari delete-tab-group --profile Twisto --name Inbox
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

`open-window`, `open-private-window`, and `open-tab-group-window` all resolve and report the exact newly created window as `window-id|<id>` in text mode and `windowId` in JSON mode. Profile opening verifies the requested profile. Private opening verifies private state when Safari database metadata is available. Saved-group opening carries the exact id through focus and sidebar selection, verifies both the selected group and requested profile through cross-process readback, and rolls back only its operation-owned window on failure.

`safari find-tab <url>` searches open Safari tabs by exact URL. Add `--prefix` for prefix matching, `--window-id <id>` or `--window-index <index>` to limit the search to one window, and `--profile <name>` to limit matches to a Safari profile when window profile metadata is available. It prints one machine-readable row per match:

```text
windowId|windowIndex|tabIndex|url|title
```

`safari resolve-tab <url>` uses the same filters as `find-tab`, but it must resolve exactly one tab. It prints the same single row shape as `find-tab`, fails when no tab matches, and fails when the query is ambiguous.

`safari ensure-tab-group <profile> <name>` creates or reuses a saved Safari tab group. When creating a missing profile-specific group, it opens a brand-new window for the requested profile and mutates only that new window. Text mode reports whether the group was `created` or `reused` and prints the resolved group row. JSON mode returns a stable summary with `status` and `tabGroup`. Safari can expose the required File-menu action as briefly disabled while a new window is becoming ready, so the command dismisses and reopens the owning process's File menu until that exact structural item becomes enabled. A persistently disabled action fails with an actionable error instead of being mistaken for a successful request followed by a missing database mutation.

Missing-group creation replaces the operation window's Start Page with a normal blank tab before invoking Safari's with-tabs action, so the action is enabled and the resulting group persists after the operation window closes. `ensure-tab-list-urls` uses the requested URLs themselves instead: it replaces the Start Page with the first missing URL, opens the remaining URLs, and only then creates the saved group. File menus opened during inspection are structurally dismissed on every failure path.

Saved tab-group outputs report the Safari profile display name. Safari may store default-profile groups with an empty profile field internally, but the CLI maps that storage detail back to the default profile name.

`safari sidebar-tab-groups <profile> [name]` is the explicit fallback when `SafariTabs.db` cannot be read. It opens a brand-new window for the requested profile, reads saved-group rows from that window's sidebar without activating any group, optionally filters by one exact display name, and closes the operation window before returning. Because the fallback temporarily changes Safari UI state, it is marked non-read-only for MCP publication even though its domain operation is a read. Rows whose current Safari surface exposes no stable identifier report `null` in JSON and an empty first text column.

`safari delete-tab-group --profile <profile> --name <name>` performs the matching sidebar-only delete flow. It requires exactly one exact-name row and a stable sidebar identifier, selects only that row, confirms Safari's destructive sheet, verifies through sidebar readback that the identifier disappeared, and closes its operation-owned window. Missing, ambiguous, unidentified, or unavailable rows fail closed. The original identifier form remains available for database-backed deletion.

`safari delete-tab-group <identifier>` deletes a saved Safari tab group and verifies through readback that the group disappeared before returning success.

`safari ensure-tab-list-urls` adds missing URLs to a window-backed or saved-tab-group-backed tab list and skips URLs already present in that list. Use `--window-id <id>` for stable live-window writes, `--window-index <index>` only when you have just re-read the current window order, or `--tab-group-profile <profile> --tab-group-name <name>` for a saved tab group. For a missing saved group, the command loads the requested URLs into its new profile window before creating the persistent group. For a reused group, it opens another brand-new profile window and selects the group through the Safari sidebar by saved group id. Menu and sidebar operations are constrained to that window's owning Safari process, and text and JSON output report the operation window id. The command never repurposes a pre-existing Safari window. If selection or mutation fails, it deletes a group created by the operation and closes only the operation-owned window before failing.

`safari reorder-tab-list-urls` reorders existing matching tabs in a window-backed or saved-tab-group-backed tab list so the requested URL occurrences become the ordered prefix. Use `--window-id <id>` for stable live-window writes; Safari window indexes can change after focus, open-window, and tab-group switching operations. It does not create missing URLs and does not delete extra tabs; text and JSON output report moved, unchanged, missing, and extra entries. The saved-group path follows the same operation-owned-window rule as URL reconciliation: it opens a new window when reusing a group and leaves pre-existing windows unchanged. On failure it deletes any group created by the operation and closes only the operation-owned window.

Window-level tab commands accept either the original positional `window-index` form or `--window-id <id>`. Prefer `--window-id` for `open-tab`, `window-tabs`, `set-tab-url`, and `close-tab` when the command follows any Safari UI operation that may reorder windows. Identifier-targeted `open-tab` waits for a newly created window to become addressable through Safari's scripting interface before creating the tab.

`safari close-window` closes Safari's front window by default. Use `--window-id <id>` to close a specific window by stable Safari window identifier. Identifier-targeted close sends the close event to an ID-based window object in its owning Safari process without focusing or capturing any Accessibility window. It never falls back to the current front window or an Accessibility close button. Final readback verifies that the stable id is gone and excludes Safari's zero-tab scripting ghosts; an already absent id is treated as successfully closed without sending a close event.

`safari windows`, `safari tabs`, and URL-based tab lookup enumerate every running Safari process. They cross-check PID-targeted scripting data with opaque layer-zero Safari windows from the macOS WindowServer by stable window id. The WindowServer inventory includes windows on other Spaces without relying on localized or duplicate titles, while hidden, stale, and zero-tab scripting objects are excluded before any tab content is read. Profile-sensitive mutation flows use the same inventory for readback. If the system window inventory itself is unavailable, commands fall back to the legacy single-process AppleScript read.

The `name` reported by `safari windows` comes from the window's current Safari tab when that tab exposes a title. Safari's separate window title is retained only for Accessibility reconciliation and as a fallback, so a stale title left behind by a closed saved-group window cannot misdescribe the surviving window's current content.

Window rows expose both identities explicitly:

```text
windowId|windowIndex|isPrivate|profile|selectedTabGroupIdentifier|tabGroup|name|processId
```

Tab rows use the corresponding fixed shape:

```text
windowId|windowIndex|tabIndex|url|processId
```

`windowId` is the stable Safari window address used by `--window-id`. `processId` identifies the owning Safari process, so the same process id normally appears on several different window rows. JSON uses the explicit keys `windowId`, `windowIndex`, and `processId` as well, while retaining `identifier` and `index` as compatibility aliases.

Prefix a module command with `--json` to get structured JSON instead of line-oriented text. Commands backed by structured records return arrays or objects; simple status commands return a JSON message object.

```bash
swift run computer-automation --json safari find-tab https://example.com --prefix
```

Append `--help` to a module command to print its usage without running the command.

CLI failures use human-readable messages for validation, Safari state, permissions, UI availability, database access, and AppleScript transport errors. Unexpected internal errors use a generic fallback instead of exposing Swift enum case names or sensitive JavaScript/transport details.

`safari execute-tab-javascript <window-id> <tab-index> <javascript>` runs a value-producing JavaScript expression in a concrete Safari tab addressed by stable window id and tab index. The JavaScript source can be an inline argument, `--stdin`, or `--file <path>` / `--file=<path>`. Provide exactly one source; wrap multi-statement programs in an immediately invoked function expression. The command evaluates the expression directly instead of calling page-level `eval`, so it works on pages whose content security policy forbids `unsafe-eval`. Text mode prints the JavaScript result as stdout. JSON mode returns the target address and result:

```json
{"windowId":42,"tabIndex":2,"result":"complete"}
```

Primitive JavaScript results are returned as text. Object and array results are serialized with `JSON.stringify(...)` before being returned.

## Safari database access

Some Safari read commands use Safari's local `SafariTabs.db` for profile, saved tab-group, private-window, and selected tab-group metadata. Direct access to that database is isolated in the `SafariDatabase` module. On recent macOS versions, the terminal or app running `computer-automation` may need Full Disk Access to read that file.

When the database is unavailable, `safari windows` still returns the window fields that Safari exposes through AppleScript: window index, private state as `false`, empty profile and tab-group fields, and window name. Commands that require saved Safari database records fail quickly with an actionable database access error instead of waiting indefinitely.

## Completion

Use `--help` at the top level, after a module, or after a command to discover the available modules, commands, and command-specific usage:

```bash
swift run computer-automation --help
swift run computer-automation safari --help
swift run computer-automation safari ensure-tab-list-urls --help
```

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
