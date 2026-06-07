# Safari Models

## Overview

- The `Safari` module currently exposes one model: `SafariApplication`.
- `SafariApplication` represents Safari as an application and owns its lifecycle commands.

## CRUD matrix

| Model | Command | CRUD | Description |
| --- | --- | --- | --- |
| `SafariApplication` | `launch` | `C` | Start the Safari application. |
| `SafariApplication` | `running` | `R` | Report whether Safari is currently running. |
| `SafariApplication` | `quit` | `D` | Request Safari to terminate. |

## Model architecture

```mermaid
flowchart TD
    SafariModule["Safari module"]
    SafariApplication["SafariApplication model"]
    Launch["SafariApplicationLaunchCommand (C)"]
    Running["SafariApplicationRunningCommand (R)"]
    Quit["SafariApplicationQuitCommand (D)"]

    SafariModule --> SafariApplication
    SafariApplication --> Launch
    SafariApplication --> Running
    SafariApplication --> Quit
```

## Notes

- `launch` is the create operation for the application lifecycle.
- `running` is the read operation for the application lifecycle.
- `quit` is the delete operation for the application lifecycle.
- No update operation is currently defined because it does not fit the application lifecycle at this level.
