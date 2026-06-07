# Safari User Interface Models

## Overview

- The `SafariUserInterface` module owns Safari GUI scripting and menu-level automation.
- It currently exposes four models: `SafariApplicationMenuBar`, `SafariMenu`, `SafariFileMenu`, and `SafariMenuItem`.
- `SafariApplicationMenuBar` represents Safari's top-level application menu bar.
- `SafariMenu` represents an arbitrary top-level Safari application menu addressed by structure.
- `SafariFileMenu` represents a thin specialization of `SafariMenu` for Safari's `File` menu.
- `SafariMenuItem` represents an individual menu item addressable through GUI scripting.

## CRUD matrix

| Model | Command | CRUD | Description |
| --- | --- | --- | --- |
| `SafariApplicationMenuBar` | `menu-bar-items` | `R` | List top-level Safari menu bar items. |
| `SafariMenu` | `menu-items` | `R` | List items for a top-level Safari menu chosen by menu bar item index. |
| `SafariFileMenu` | `file-menu-items` | `R` | List items currently exposed by Safari's `File` menu. |
| `SafariFileMenu` | Internal `openWindow` API | `C` | Open a new Safari window, optionally for a specific profile. |
| `SafariMenuItem` | `menu-item-children` | `R` | List the child items of a specific Safari menu item. |

## Model architecture

```mermaid
flowchart TD
    SafariUI["SafariUserInterface module"]
    SafariMenuBar["SafariApplicationMenuBar model"]
    SafariMenu["SafariMenu model"]
    SafariFileMenu["SafariFileMenu model"]
    SafariMenuItem["SafariMenuItem model"]
    MenuBarItems["menu-bar-items command (R)"]
    MenuItems["menu-items command (R)"]
    FileMenuItems["file-menu-items command (R)"]
    MenuItemChildren["menu-item-children command (R)"]
    OpenWindow["openWindow(profileName:) API (C)"]

    SafariUI --> SafariMenuBar
    SafariUI --> SafariMenu
    SafariUI --> SafariFileMenu
    SafariUI --> SafariMenuItem
    SafariMenuBar --> SafariMenu
    SafariMenu --> MenuItems
    SafariMenu --> SafariFileMenu
    SafariMenuBar --> MenuBarItems
    SafariFileMenu --> SafariMenu
    SafariFileMenu --> FileMenuItems
    SafariFileMenu --> OpenWindow
    SafariMenu --> SafariMenuItem
    SafariMenuItem --> MenuItemChildren
```

## Notes

- `SafariUserInterface` is a separate module so GUI scripting does not mix with Safari domain models.
- `SafariWindow` in the `Safari` module currently depends on `SafariFileMenu` through an explicit module boundary.
- `SafariMenu` is the primary general-purpose menu model for future UI automation work.
- `SafariFileMenu.openWindow(profileName:)` is the current create operation in this module.
- UI automation must remain independent of the macOS and Safari language setting.
- The module identifies Safari's `File` menu by menu bar position instead of by localized title text.
- `SafariFileMenu` is intentionally a thin specialization rather than the primary abstraction for menu automation.
- `SafariMenuItem` addresses concrete menu items by structural coordinates: `menu-bar-item-index` plus `menu-item-index`.
- No update or delete command surface is defined for these UI models yet.

## Current implementation

- `menu-bar-items` returns one line per top-level menu in the form `index|title`.
- `menu-items <menu-bar-item-index>` returns one line per item in the selected top-level menu in the form `index|title|commandCharacter|commandModifiers`.
- `file-menu-items` returns one line per File menu item in the form `index|title|commandCharacter|commandModifiers`.
- `menu-item-children <menu-bar-item-index> <menu-item-index>` returns one line per child item in the form `index|title|commandCharacter|commandModifiers`.
- `SafariMenu` owns the shared implementation for reading top-level menu items.
- `SafariFileMenu.openWindow(profileName:)` uses AppleScript to activate Safari and create a new document when no profile is requested.
- When a profile name is provided, it first reads the File menu structure, finds the item whose title ends with the requested profile name, and then clicks that item by index.
- `SafariMenuItem` now serves both as the shared representation type and as the model for structured submenu inspection.
