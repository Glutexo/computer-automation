# Research Notes

## 2026-06-07

### Initial observations

- The project starts from an empty workspace, so repository conventions can be defined cleanly.
- GitHub CLI is available locally and authenticated for the `Glutexo` account.
- Swift 6.3.2 is installed locally, so a native Swift baseline can be built and run without extra setup.

### Implementation notes

- The first code scaffold uses Swift Package Manager with an executable target.
- This keeps the initial app portable and easy to verify from the command line before adding UI or automation layers.

### Open questions

- Which operating systems should be targeted first for automation workflows?
- Should the first implementation focus on desktop UI automation, shell automation, or hybrid flows?
- What level of observability and recovery is required for failed automation steps?
