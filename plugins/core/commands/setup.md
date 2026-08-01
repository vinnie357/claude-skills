---
description: "Bootstrap a new project with bees task tracking (default) or beads (--beads), mise tooling, CI, and gitleaks security"
argument-hint: "[--beads] [--stealth] [--contributor]"
---

Bootstrap a new project with a standardized development workflow. Initializes bees task tracking by default (or beads with `--beads`), discovers project languages and tools, then creates tracker issues with dependencies for configuring mise, CI, and gitleaks.

**What it does:**

1. **Configure tracker** — Initialize bees (default) or beads (`--beads`) task tracking (or detect existing setup)
2. **Discover project** — Scan for languages, frameworks, tooling, and package managers
3. **Create tasks** — Generate 4 tracker issues with dependency graph:
   - Document project discovery results
   - Configure mise development environment (depends on discovery)
   - Configure GitHub Actions CI workflow (depends on mise)
   - Configure gitleaks secret detection (depends on discovery)
4. **Output summary** — Display created tasks, dependencies, and next steps

**Options:**
- `--beads` — Use beads instead of the bees default
- `--stealth` — (beads only, requires `--beads`) Initialize beads in local-only mode (no remote sync)
- `--contributor` — (beads only, requires `--beads`) Initialize beads in pull-only mode (read-only from remote)

**Examples:**
```
/core:setup
/core:setup --beads
/core:setup --beads --stealth
/core:setup --beads --contributor
```

**Task Instructions:**
Use the `setup` subagent to perform project bootstrapping.
