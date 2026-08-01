---
description: "Benchmark all skills across the marketplace with static analysis and quality assessment"
argument-hint: "[--plugin=<name>]"
---

Benchmark all Agent Skills in the marketplace, producing a quality scorecard with static analysis and category classification.

**What it does:**
- Discovers all skills across all plugins (reads marketplace.json + plugin.json files)
- Runs static analysis checks per skill (description, naming, line count, examples, anti-fabrication)
- Classifies each skill (Capability Uplift vs Encoded Preference)
- Assesses progressive disclosure usage (references, depth)
- Produces a scorecard table with pass/fail per check and overall score

**Output:**
A scorecard table showing quality metrics for each skill:

```
Skill            | Plugin   | Desc | Lines   | Refs | Examples | Score
─────────────────┼──────────┼──────┼─────────┼──────┼──────────┼──────
git              | core     | Pass | 120/500 | Pass | Pass     | X/N
claude-skills    | cl-code  | Pass | 380/500 | Pass | Pass     | X/N
```

Score is `X/N` exactly as `mise run test:skills-quality` prints it — `N` is the validator's `check_count`, not a fixed number, so it will not go stale as the check list grows.

**Examples:**
```
/benchmark-skills
# Benchmark all skills across all plugins

/benchmark-skills --plugin=core
# Benchmark only skills in the core plugin
```

**Task Instructions:**
Use Agent tool with subagent_type: "general-purpose" to:

1. Read `.claude-plugin/marketplace.json` to discover all plugins
2. For each local plugin, read its `.claude-plugin/plugin.json` to get skill paths
3. For each skill, read `SKILL.md` and analyze:
   - **Description quality**: Non-empty, ≤1024 chars, has "Use when", third person
   - **Name compliance**: Kebab-case, ≤64 chars, no reserved words
   - **Content quality**: ≤500 lines, has examples, imperative language
   - **Progressive disclosure**: Has references/, no nested references
   - **Anti-fabrication**: Contains anti-fab rules or references `core:anti-fabrication`
   - **Source coverage**: Skill is listed in one of the plugin's `sources.toml` entries' `skills` array
4. Classify each skill as Capability Uplift or Encoded Preference
5. Calculate score by running `mise run test:skills-quality` — `test/validate-skills-quality.nu` is the single source of truth for the check list and `check_count`, so report the score exactly as it prints (`X/N`); do not hand-count checks or print a fixed denominator
6. Present results as a formatted scorecard table
7. Summarize: total skills, average score, skills needing attention

If `--plugin=<name>` is provided, only benchmark skills in that plugin.

**Important:**
- Read actual SKILL.md files — do not fabricate content or results
- Report actual line counts and check results
- Mark any checks that cannot be performed as "N/A" with explanation
- Use the `claude-skills-benchmark` skill for methodology reference
