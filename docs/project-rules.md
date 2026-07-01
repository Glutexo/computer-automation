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
- Represent distinct parts of each module with explicit models.
- Model each command as its own Swift type.
- Attach each command to the model that owns the underlying behavior.
- Require module and command models to publish the metadata needed for CLI completion.
- Require every user-facing CLI command to support the global `--json` output mode. Text output may remain the default, but structured JSON must be available without parsing text rows back into records.
- Keep `find-*` and `resolve-*` read commands paired on models that support record lookup. If a model exposes one, it must expose the other with the same lookup criteria. `find-*` returns a collection of matches and treats zero matches as data; `resolve-*` returns exactly one entity and fails clearly on zero or ambiguous matches.
- Keep generated shell completion scripts driven by shared completion metadata rather than duplicated command lists.
- Keep shell completion installers as thin filesystem helpers over generated completion scripts.
- Keep command implementation isolated in its own command directory.
- Share code across modules or commands only through an explicit shared library, type, or module.
- Keep related operations on the same product feature as similar as practical at the automation level.
- Keep automation independent of the macOS and Safari language setting.
- Prefer structural identifiers such as indexes, stable attributes, and explicit data sources over localized UI labels.
- Never implement profile-targeted saved-tab-group creation by reusing an existing Safari window. Open a brand-new window for the requested profile, record its stable window identifier, and mutate only that newly created window.
- Treat Safari window indexes as volatile across focus, open-window, and tab-group switching. For writes after any such operation, carry stable window identifiers through the command path or re-read windows immediately before using an index.
- Saved-tab-group deletion must confirm Safari's follow-up sheet through an explicit destructive button identity or inspected button record, and the command must verify by readback instead of trusting that the menu press succeeded.
- Build new features primarily on general models before introducing specialized convenience models.
- Keep specialized models when an operation truly belongs to a specific UI surface rather than to the general structure.
- Keep direct `SafariTabs.db` access inside the `SafariDatabase` module and represent persisted database entities with `SafariDatabase` models.
- When an automation flow depends on a Safari accessibility surface such as a toolbar, sidebar, menu, or child menu, add that surface as an explicit reusable model in `SafariUserInterface` and add the matching low-level AppleScript model in `SafariAppleScript`.
- Do not introduce one-off AX helpers that bypass those module models from `Safari` commands or other high-level orchestration code.
- For related operations such as CRUD, avoid mixing fundamentally different automation surfaces unless the product itself forces that split.
- For supported Safari tab-group create/read/delete operations, use the opened sidebar tab-group surface consistently as the primary targeting surface rather than combining database writes with unrelated menu or toolbar paths.
- Do not script UI by synthetic coordinate clicks. Use accessibility elements, attributes, and actions only.
- Cover every model with robust parameterized tests, including UI and AppleScript models.
- Test not only concrete user-story cases but also general behavior, invariants, and edge conditions.
- Use mocks freely when they improve coverage, isolation, or reproducibility without weakening the contract being tested.
- Keep test files organized by module or model under `Tests/computer-automationTests/`, and keep reusable fixtures, builders, and mocks in clearly named test support files.
- Start with the smallest useful automation slice and validate it end to end.
- Reuse established tools and protocols where possible before inventing custom abstractions.
- Apply YAGNI consistently: do not add new models, commands, or AX surfaces until a concrete current workflow needs them.
- Keep code and documentation changes aligned in the same working session.
- After every completed change, run appropriate verification, commit the verified work, and push it immediately.

## Knowledge capture

- Keep an internal overview of module models and their CRUD coverage.
- Record assumptions explicitly when requirements are still unclear.
- Preserve implementation notes that would save repeated investigation later.
- Prefer concise entries over polished essays so updates stay cheap.
