# Epic Sizing and Dependency-Ordering Reference

Heuristics for decomposing epics into right-sized issues and ordering them correctly for autonomous worker sessions.

## Why Sizing Matters

Epics are executed by autonomous workers with finite per-session context/token budgets and time limits. An oversized epic yields issues that a single worker cannot finish in one session — context overflow, partial work, and dropped acceptance criteria result.

Decompose every epic into independently completable issues before it enters the queue.

## Epic-Sizing Heuristics

### Issue Count

- Target **3–8 issues** per epic.
- Fewer than 3 often signals the work is a single issue, not an epic.
- More than ~8 is a signal to split the epic into two or more independent epics.

### Issue Scope

Size each issue to one worker session:

- **Files**: roughly ≤ ~5–10 target files per issue.
- **Context**: completable in a single focused context window without reading the whole codebase.
- **Verification**: verifiable by one acceptance check at completion.
- **Deliverable**: one deliverable per issue. Titles joined by "and", "also", "then", or "plus" usually hide multiple issues — split them.
- **Subsystem**: one subsystem or repo per issue where possible. Cross-subsystem or cross-repo scope is a split candidate.

### Token-Budget Rule of Thumb

If an issue would require reading the entire codebase or generating thousands of lines of code, it exceeds a worker token budget — split it.

### Epic Objective Check

An epic objective with multiple deliverables joined by "and" or "separately" → split into multiple epics or clearly independent issues with explicit dependency declarations.

## Oversize Red Flags

Mechanically flag an epic or issue when any of these apply:

| Signal | Threshold |
|--------|-----------|
| Too many issues | > 8 issues in the epic |
| Oversized issue | > ~10 target files in one issue |
| Multi-deliverable title | Title contains "and", "also", "then", or "plus" joining distinct outcomes |
| Unverifiable acceptance | Acceptance criteria cannot be checked in a single worker session |
| Cross-repo/cross-subsystem scope | Single issue touches more than one subsystem or repository |

## Dependency-Ordering Conventions

### Declare Dependencies Explicitly

- Use Linear blocking relations (or `bees dep add`) to declare every dependency.
- Never rely on implicit ordering or convention — if it is not declared, workers may execute out of order.

### Topological Order

Materialize issues in topological order: **foundation → core → integration → verification**.

| Layer | Examples |
|-------|---------|
| Foundation | Schemas, reference docs, interfaces, shared types |
| Core | Business logic, primary implementations |
| Integration | Wiring components together, adapter layers |
| Verification | End-to-end tests, audit checks, documentation updates |

Foundational and shared artifacts come first; all consumers must declare a dependency on them.

### Cycle Prevention

- No cycles — if a cycle is detected, halt decomposition and re-decompose before queuing.
- A cycle means two or more issues block each other; the fix is to extract the shared dependency into a new foundation issue.

### Chain Depth

- Keep dependency chains shallow: fewer than 5 levels from root to leaf.
- Deep chains serialize workers unnecessarily and extend wall-clock time.

### No False Dependencies

- Independent issues must remain parallelizable.
- Do not serialize issues that could run concurrently — false dependencies reduce worker fan-out and slow delivery.

## Checklist (Quick Reference)

Before queueing an epic's issues:

- [ ] Issue count is 3–8
- [ ] Each issue scope: ≤ ~10 files, one deliverable, one subsystem
- [ ] No multi-deliverable titles (no "and/also/then/plus")
- [ ] Each acceptance criterion is verifiable in one session
- [ ] All dependencies declared explicitly (blocking relations or bees deps)
- [ ] Issues ordered topologically (foundation first)
- [ ] No dependency cycles
- [ ] Dependency chain depth < 5
- [ ] Independent issues are not falsely serialized
