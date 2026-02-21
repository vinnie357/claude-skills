---
description: "Bootstrap a new project with beads task tracking, mise tooling, CI, and gitleaks security"
argument-hint: "[--stealth] [--contributor]"
---

Bootstrap a new project with a standardized development workflow. Initializes beads task tracking, discovers project languages and tools, then creates beads tasks with dependencies for configuring mise, CI, and gitleaks.

**What it does:**

1. **Configure beads** — Initialize beads task tracking (or detect existing setup)
2. **Discover project** — Scan for languages, frameworks, tooling, and package managers
3. **Create tasks** — Generate 4 beads tasks with dependency graph:
   - Document project discovery results
   - Configure mise development environment (depends on discovery)
   - Configure GitHub Actions CI workflow (depends on mise)
   - Configure gitleaks secret detection (depends on discovery)
4. **Output summary** — Display created tasks, dependencies, and next steps

**Options:**
- `--stealth` — Initialize beads in local-only mode (no remote sync)
- `--contributor` — Initialize beads in pull-only mode (read-only from remote)

**Examples:**
```
/core:setup
/core:setup --stealth
/core:setup --contributor
```

**Task Instructions:**
Use the `setup` subagent to perform project bootstrapping.
