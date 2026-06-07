# Architecture

## Module layout

```mermaid
flowchart TD
    App["computer-automation executable"]
    Foundation["AutomationFoundation shared module"]
    Zsh["zsh completion script"]
    Safari["Safari module"]
    Launch["SafariLaunchCommand"]

    App --> Foundation
    Zsh --> App
    App --> Safari
    Safari --> Foundation
    Safari --> Launch
```

## Notes

- The first architectural level is the module.
- Modules typically represent an application or a service boundary.
- Commands are the next architectural level inside a module.
- Each command owns its own implementation directory.
- Commands and modules may share code only through an explicit shared type, library, or module boundary.
- Module and command models publish completion metadata that the CLI consumes.
- Shell completion scripts stay thin and delegate to the CLI completion endpoint.
- The current executable is a thin entry point over the `Safari` module and its launch command.
