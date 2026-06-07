# Safari Models

## Overview

- The `Safari` module currently exposes three models: `SafariApplication`, `SafariProfile`, and `SafariWindow`.
- `SafariApplication` represents Safari as an application and owns its lifecycle commands.
- `SafariProfile` represents the profiles available in Safari.
- `SafariWindow` represents browser windows managed by Safari.

## CRUD matrix

| Model | Command | CRUD | Description |
| --- | --- | --- | --- |
| `SafariApplication` | `launch` | `C` | Start the Safari application. |
| `SafariApplication` | `running` | `R` | Report whether Safari is currently running. |
| `SafariApplication` | `quit` | `D` | Request Safari to terminate. |
| `SafariProfile` | `profiles` | `R` | List available Safari profiles. |
| `SafariWindow` | `open-window` | `C` | Open a new Safari browser window. |
| `SafariWindow` | `windows` | `R` | List open Safari browser windows. |
| `SafariWindow` | `close-window` | `D` | Close the front Safari browser window. |

## Model architecture

```mermaid
flowchart TD
    SafariModule["Safari module"]
    SafariApplication["SafariApplication model"]
    SafariProfile["SafariProfile model"]
    SafariWindow["SafariWindow model"]
    Launch["SafariApplicationLaunchCommand (C)"]
    Running["SafariApplicationRunningCommand (R)"]
    Quit["SafariApplicationQuitCommand (D)"]
    Profiles["SafariProfileListCommand (R)"]
    WindowOpen["SafariWindowOpenCommand (C)"]
    Windows["SafariWindowListCommand (R)"]
    WindowClose["SafariWindowCloseCommand (D)"]

    SafariModule --> SafariApplication
    SafariModule --> SafariProfile
    SafariModule --> SafariWindow
    SafariApplication --> Launch
    SafariApplication --> Running
    SafariApplication --> Quit
    SafariProfile --> Profiles
    SafariWindow --> WindowOpen
    SafariWindow --> Windows
    SafariWindow --> WindowClose
```

## Notes

- `launch` is the create operation for the application lifecycle.
- `running` is the read operation for the application lifecycle.
- `quit` is the delete operation for the application lifecycle.
- `profiles` is the read operation for the profile catalog.
- `open-window` is the create operation for the browser window model.
- `windows` is the read operation for the browser window model.
- `close-window` is the delete operation for the browser window model.
- No update operation is currently defined because it does not fit the application lifecycle at this level.

## Profile loading

- The `SafariProfile` model reads profiles from Safari's local tabs database:
  - `~/Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db`
- The `profiles` command queries the `bookmarks` table.
- A row is treated as a Safari profile when all of these conditions hold:
  - `parent = 0`
  - `type = 1`
  - `subtype = 2`
- The profile display name is read from `title`.
- The stable profile identifier is read from `external_uuid`.

### Query shape

```sql
SELECT title, external_uuid
FROM bookmarks
WHERE parent = 0 AND type = 1 AND subtype = 2
ORDER BY id;
```

### Output shape

- The CLI currently prints one profile name per line.
- Internally the model keeps both:
  - `name`
  - `identifier`

## Window operations

- The `SafariWindow` model delegates user interface work to the `SafariUserInterface` module.
- `open-window` uses the `SafariFileMenu` model in `SafariUserInterface`.
- `open-window` accepts an optional profile name argument.
- When a profile argument is provided, the command:
  - validates the profile name against the `SafariProfile` model
  - delegates to the `SafariFileMenu` model to activate Safari
  - clicks the matching profile-specific "new window" menu item
- `windows` enumerates `every window` and returns one line per window as:
  - `index|profile|name`
- The profile column is resolved by joining AppleScript window ids with Safari's local `windows` table and the active profile bookmark title in `SafariTabs.db`.
- `close-window` closes the current front window.

## Related module

- GUI scripting and menu-level automation live in the separate `SafariUserInterface` module.
- Its models are documented in `docs/safari-user-interface-models.md`.
- `SafariFileMenu` is the current integration point used by the `SafariWindow` model.
