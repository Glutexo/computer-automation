# Decision Log

## 2026-06-07

### Initial repository bootstrap

- Created the repository as `computer-automation`.
- Started documentation-first with explicit project rules and persistent notes.
- Chose a lightweight structure so early implementation can evolve without cleanup overhead.

### Repository visibility and delivery rule

- Changed the GitHub repository visibility to public.
- Added a standing rule to commit and push each verified change set immediately.

### Initial Swift app scaffold

- Bootstrapped the codebase as a Swift Package Manager executable.
- Kept the first app intentionally minimal as a runnable `Ahoj světe!` baseline.
- Documented both run and test commands in the repository README.

### Documentation separation rule

- Development rules and internal notes must stay separate from user-facing documentation.
- Cleaned the README so it remains a user-facing quickstart instead of an internal process document.

### Module-first architecture

- Defined the first architectural level as modules, typically representing an application or a service.
- Started the modular structure with a dedicated `Safari` module.
- Added Mermaid architecture diagrams as a maintained part of the documentation.

### Command isolation within modules

- Chose commands as the next architectural level inside a module.
- Each command is represented by its own Swift type and isolated in its own directory.
- Cross-command and cross-module reuse must happen only through explicit shared code boundaries.
- Implemented `SafariLaunchCommand` as the first concrete command in the `Safari` module.

### Completion metadata contract

- Added a shared metadata contract for modules and commands in `AutomationFoundation`.
- Completion data is now owned by module and command models and consumed by the CLI.
- Added `zsh` completion script generation that delegates back to the shared completion endpoint.

### Safari application lifecycle model

- Structured the `Safari` module around a `SafariApplication` model that represents Safari as an application.
- Attached `launch`, `running`, and `quit` commands to that model as the current lifecycle CRUD surface.
- Recorded model architecture and CRUD coverage in dedicated internal documentation.

### Safari profile model

- Added a `SafariProfile` model for reading the Safari profile catalog.
- Implemented the initial read operation as a `profiles` command backed by Safari's local tabs database.
- Documented the concrete Safari database path and row selection rules used for profile loading.

### Safari window model

- Added a `SafariWindow` model for browser window CRUD operations.
- Implemented `open-window`, `windows`, and `close-window` as the initial create, read, and delete commands.
- Chose AppleScript as the execution layer for Safari window control.

### Zsh completion installer

- Added a CLI installer for `zsh` completion files.
- Kept installation logic separate from script rendering so completion metadata still has one source of truth.
