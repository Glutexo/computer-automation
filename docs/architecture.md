# Architecture

## Module layout

```mermaid
flowchart TD
    App["computer-automation executable"]
    Foundation["AutomationFoundation shared module"]
    Zsh["zsh completion script"]
    ZshInstaller["zsh completion installer"]
    Safari["Safari module"]
    SafariUI["SafariUserInterface module"]
    SafariApplication["SafariApplication model"]
    SafariProfile["SafariProfile model"]
    SafariWindow["SafariWindow model"]
    SafariMenuBar["application-menu-bar model"]
    SafariMenu["menu model"]
    SafariFileMenu["file-menu model"]
    SafariMenuItem["menu-item model"]
    MenuBarItems["menu-bar-items command"]
    MenuItems["menu-items command"]
    FileMenuItems["file-menu-items command"]
    MenuItemChildren["menu-item-children command"]
    Launch["launch command"]
    Running["running command"]
    Quit["quit command"]
    Profiles["profiles command"]
    WindowOpen["open-window command"]
    Windows["windows command"]
    WindowClose["close-window command"]

    App --> Foundation
    Zsh --> App
    ZshInstaller --> App
    App --> Safari
    App --> SafariUI
    Safari --> Foundation
    Safari --> SafariUI
    SafariUI --> Foundation
    Safari --> SafariApplication
    Safari --> SafariProfile
    Safari --> SafariWindow
    SafariUI --> SafariMenuBar
    SafariUI --> SafariMenu
    SafariUI --> SafariFileMenu
    SafariUI --> SafariMenuItem
    SafariMenuBar --> MenuBarItems
    SafariMenu --> MenuItems
    SafariFileMenu --> FileMenuItems
    SafariMenuItem --> MenuItemChildren
    SafariMenu --> SafariMenuItem
    SafariFileMenu --> SafariMenu
    SafariApplication --> Launch
    SafariApplication --> Running
    SafariApplication --> Quit
    SafariProfile --> Profiles
    SafariWindow --> WindowOpen
    SafariWindow --> Windows
    SafariWindow --> WindowClose
    WindowOpen --> SafariFileMenu
```

## Notes

- The first architectural level is the module.
- Modules typically represent an application or a service boundary.
- Models represent distinct parts of a module's domain.
- Prefer general structural UI models before adding specialized models for concrete application areas.
- Keep specialized models for behaviors that are genuinely specific to one concrete UI surface.
- Commands are the next architectural level inside a module.
- Each command belongs to a model and owns its own implementation directory.
- Commands and modules may share code only through an explicit shared type, library, or module boundary.
- UI automation must remain independent of the macOS and Safari language setting.
- Module and command models publish completion metadata that the CLI consumes.
- Shell completion scripts stay thin and delegate to the CLI completion endpoint.
- Shell completion installers stay thin and write generated scripts into shell completion paths.
- The current executable is a thin entry point over the `Safari` and `SafariUserInterface` modules.
