---
description: "Audit the current diff for restraint-ladder violations and list outstanding restraint: markers"
argument-hint: "[path]"
---

Run the restraint marker scan, then review the current diff against the restraint ladder yourself — the marker scan is mechanical, the over-engineering review is model work.

1. Run `nu plugins/core/skills/restraint/scripts/restraint-audit.nu` (optionally with `--path $ARGUMENTS` when a path is given) to list every existing `restraint:` marker in the repository. Report the results.
2. Read the current `git diff` (staged and unstaged) against the restraint ladder from `/core:restraint`: for each NEW symbol (function, class, config, dependency), check whether it needs to exist, whether it duplicates an existing helper/stdlib/dependency, and whether a smaller form would do.
3. Flag speculative abstractions and unrequested features as findings. Where a deliberate simplification is intentional and worth keeping, suggest adding a `restraint:` marker naming the ceiling and upgrade path rather than silently leaving it undocumented.
