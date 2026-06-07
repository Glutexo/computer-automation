# Architecture

## Module layout

```mermaid
flowchart TD
    App["computer-automation executable"]
    Foundation["AutomationFoundation shared module"]
    Zsh["zsh completion script"]
    ZshInstaller["zsh completion installer"]
    Safari["Safari module"]
    SafariApplication["SafariApplication model"]
    SafariProfile["SafariProfile model"]
    Launch["launch command"]
    Running["running command"]
    Quit["quit command"]
    Profiles["profiles command"]

    App --> Foundation
    Zsh --> App
    ZshInstaller --> App
    App --> Safari
    Safari --> Foundation
    Safari --> SafariApplication
    Safari --> SafariProfile
    SafariApplication --> Launch
    SafariApplication --> Running
    SafariApplication --> Quit
    SafariProfile --> Profiles
```

## Notes

- The first architectural level is the module.
- Modules typically represent an application or a service boundary.
- Models represent distinct parts of a module's domain.
- Commands are the next architectural level inside a module.
- Each command belongs to a model and owns its own implementation directory.
- Commands and modules may share code only through an explicit shared type, library, or module boundary.
- Module and command models publish completion metadata that the CLI consumes.
- Shell completion scripts stay thin and delegate to the CLI completion endpoint.
- Shell completion installers stay thin and write generated scripts into shell completion paths.
- The current executable is a thin entry point over the `Safari` module and its application and profile models.
