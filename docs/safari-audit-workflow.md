# Safari Audit Workflow

Use this checklist for recurring Safari automation audits before filing issues or making audit-driven changes. Keep the audit read-only unless the user explicitly approves a narrower task.

## Safety gate

- Do not touch the user's real Safari application or Safari data during an audit.
- Do not run CLI commands that launch, quit, focus, inspect, mutate, or read from real Safari or `SafariTabs.db` unless the user first approves the exact action and affected data.
- Automated tests and static source scans are the default audit tools. If a finding needs live Safari confirmation, file that as follow-up work instead of performing it during the audit.

## Preparation

- Read the workspace `AGENTS.md`, then this package's `AGENTS.md`, `README.md`, `docs/project-rules.md`, `docs/architecture.md`, and relevant model docs.
- Check `docs/decision-log.md` and `docs/research-notes.md` for prior decisions, failed approaches, and Safari-specific constraints.
- Check the working tree before editing: `git status --short`.
- Search existing issues before filing new ones: `gh issue list --repo Glutexo/computer-automation --state all --search "<keywords>"`.

## Verification commands

- Run `swift test` as the baseline verification command.
- For documentation-only changes, also run `git diff --check`.
- Safe metadata checks may include `swift run computer-automation --complete` or command `--help` paths, because help and completion are preflighted before command execution.
- Do not run real Safari commands such as `swift run computer-automation safari launch`, `windows`, `profiles`, tab-group commands, tab mutation commands, or Safari UI inspection commands without explicit approval.

## Static scans

Run focused `rg` scans and inspect each hit in context. Useful starting points:

```bash
rg -n "as!|try!|fatalError|preconditionFailure|TODO|FIXME" Sources Tests
rg -n "Thread\\.sleep|sleep\\(" Sources Tests
rg -n "CGEvent|mouse|cursor|coordinate|position|click at" Sources Tests docs
rg -n "SafariTabs\\.db|System Events|AXIdentifier|NewEmptyTabGroupMenuItem|DeleteTabGroupMenuItem" Sources docs
rg -n "--json|--complete|CompletionSuggestion|usage|abstract" Sources Tests README.md docs
rg -n "window-index|window-id|selectedTabGroupIdentifier|tabGroup" Sources Tests README.md docs
```

While reviewing hits, compare implementation against the documented rules:

- direct AppleScript access stays in `SafariAppleScript`
- direct `SafariTabs.db` access stays in `SafariDatabase`
- Safari GUI scripting flows through explicit `SafariUserInterface` models
- UI automation uses accessibility structures and actions, never coordinate clicks
- writes after Safari focus, window creation, or tab-group switching use stable window identifiers or re-read window order
- user-facing commands have JSON output, completion metadata, help text, and focused tests
- `find-*` and `resolve-*` commands stay paired when a model supports lookup

## Issue filing checklist

File one issue per actionable finding. Before filing:

- Search for duplicates with `gh issue list --state all --search "<module or symptom>"`.
- Include evidence: commands run, relevant output, file paths, and the documented rule or invariant involved.
- Name affected files or modules.
- Describe the user or maintenance risk.
- Propose a small scope of work.
- Add acceptance criteria that can be verified without touching real Safari whenever possible.
- State whether live Safari confirmation is still needed and what approval would be required.

If this workflow keeps being reused outside this repository, promote it into a local Codex skill and keep this document as the repository-specific policy reference.
