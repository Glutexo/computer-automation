# AGENTS

## Scope

This file applies to the whole repository.

## Project summary

- Swift Package Manager project for macOS computer automation experiments.
- Current top-level modules: `AutomationFoundation`, `Safari`, `SafariDatabase`, `SafariUserInterface`, and `SafariAppleScript`.
- Main executable target: `computer-automation`.

## Start here

- Read `README.md` for the current user-facing scope, run commands, and test commands.
- Read `docs/project-rules.md` before making architectural or documentation changes.
- Read `docs/architecture.md` when changing module boundaries, models, or command ownership.
- Check `docs/decision-log.md` and `docs/research-notes.md` when prior tradeoffs or failed approaches may matter.
- Use `docs/safari-audit-workflow.md` for recurring Safari audits before filing issues or making audit-driven changes.

## Working rules

- Keep repository content in English unless a documented exception exists.
- Keep changes aligned with the module-first architecture described in `docs/architecture.md`.
- Treat commands as model-owned Swift types in their own command directories.
- Reuse shared behavior through explicit shared types or modules instead of ad hoc duplication.
- Keep related operations on the same feature as structurally similar as the product allows.
- Apply YAGNI: add new models, commands, and AX surfaces only when a concrete current use case needs them.
- Keep UI automation independent of the macOS and Safari language setting.
- Before any action that touches the user's real Safari application or Safari data, warn the user what will be affected and wait for explicit approval; after that real-Safari work finishes, report that it is finished and wait for explicit approval before continuing.
- Never implement profile-targeted saved-tab-group creation by reusing an existing Safari window. Open a brand-new window for the requested profile, record its stable window identifier, and mutate only that newly created window.
- Treat Safari window indexes as volatile across focus, open-window, and tab-group switching. For writes after any such operation, carry stable window identifiers through the command path or re-read windows immediately before using an index.
- Saved-tab-group deletion must confirm Safari's follow-up sheet through an explicit destructive button identity or inspected button record, and the command must verify by readback instead of trusting that the menu press succeeded.
- Prefer structural identifiers and explicit data sources over localized UI labels.
- Keep direct AppleScript access inside `SafariAppleScript`.
- Keep direct `SafariTabs.db` access inside `SafariDatabase`.
- When automation depends on a Safari accessibility structure, model that structure explicitly in `SafariUserInterface` and add the matching AppleScript transport model in `SafariAppleScript` instead of introducing one-off AX helpers at the command layer.
- When a feature offers multiple related operations such as CRUD, prefer one consistent automation surface for the whole set instead of mixing database writes, menu commands, toolbar pickers, and other unrelated mechanisms.
- For supported Safari tab-group create/read/delete operations, use the opened sidebar tab-group surface as the primary targeting surface rather than direct database mutation or unrelated menu surfaces.
- Never script user interfaces through synthetic coordinate-based clicking; use accessibility structures and actions only.
- Keep shell completion behavior driven by shared completion metadata.
- After every completed change, run appropriate verification, commit the verified work, and push it immediately.

## Documentation upkeep

- Update `README.md` when user-facing scope, usage, or onboarding changes.
- Keep user-facing docs separate from internal development guidance.
- Keep the Mermaid diagram in `docs/architecture.md` in sync with the code.
- Append major decisions to `docs/decision-log.md` with date, context, and consequence.
- Append research findings, dead ends, and useful references to `docs/research-notes.md`.

## Testing and verification

- Prefer focused automated tests for each affected model and command.
- Cover invariants and edge conditions, not only happy-path examples.
- Run `swift test` after code changes when the environment allows it.

## Delivery

- Keep code and documentation updates in the same working session.
- Keep changes small, explicit, and consistent with the existing repository structure.
- Commit and push every completed, verified change immediately.
