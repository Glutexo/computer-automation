# Project Rules

## Language

- Keep repository content in English unless there is a documented exception.
- Write documentation for future maintainers, not only for the current task.

## Documentation upkeep

- Update `README.md` when project scope or onboarding expectations change.
- Keep `README.md` focused on user-facing overview, running, and testing instructions.
- Keep user-facing documentation separate from development rules and internal working notes.
- Keep Mermaid architecture diagrams in sync with the current module structure.
- Append major decisions to `docs/decision-log.md` with date, context, and consequence.
- Append research findings, dead ends, and useful references to `docs/research-notes.md`.
- Commit and push every completed change set immediately after the update is verified.

## Engineering approach

- Treat the first architectural level as modules, typically representing an application or a service.
- Model each command as its own Swift type.
- Keep command implementation isolated in its own command directory.
- Share code across modules or commands only through an explicit shared library, type, or module.
- Start with the smallest useful automation slice and validate it end to end.
- Reuse established tools and protocols where possible before inventing custom abstractions.
- Keep code and documentation changes aligned in the same working session.

## Knowledge capture

- Record assumptions explicitly when requirements are still unclear.
- Preserve implementation notes that would save repeated investigation later.
- Prefer concise entries over polished essays so updates stay cheap.
