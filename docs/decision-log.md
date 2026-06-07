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
