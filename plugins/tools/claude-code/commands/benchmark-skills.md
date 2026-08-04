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
Skill            | Plugin   | Desc | Lines | Refs | Examples | Score
─────────────────┼──────────┼──────┼───────┼──────┼──────────┼──────
git              | core     | Pass | X/Y   | Pass | Pass     | X/N
claude-skills    | cl-code  | Pass | X/Y   | Pass | Pass     | X/N
```

`X/Y` and `X/N` above are placeholders — copy the real line count and score from the `mise run test:skills-quality` scorecard. `Y` is the validator's line cap and `N` is its `check_count`; neither is a fixed number restated here, so this table will not go stale as either changes. The validator takes no `--plugin` filter, so run the full suite and read the rows you need.

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
3. For each skill, read `SKILL.md` and note, as a reading aid for the narrative — not the authoritative check list (see step 5) — the trigger-quality of the description, name compliance, bounded body size, presence of examples, one-level reference depth, and anti-fabrication rules. Skill-to-`sources.toml` coverage is a separate check, owned by `test/validate-sources.nu`, not this validator.
4. Classify each skill as Capability Uplift or Encoded Preference
5. Read each skill's score from `mise run test:skills-quality` rather than computing one — `test/validate-skills-quality.nu` is the single source of truth for both the check list and `check_count`. Copy the printed value verbatim; do not hand-count checks or write a fixed denominator
6. Present results as a formatted scorecard table
7. Summarize: total skills, average score, skills needing attention

If `--plugin=<name>` is provided, only benchmark skills in that plugin.

**Important:**
- Read actual SKILL.md files — do not fabricate content or results
- Report actual line counts and check results
- Mark any checks that cannot be performed as "N/A" with explanation
- Use the `claude-skills-benchmark` skill for methodology reference
- The anti-fabrication check is SKILL.md-only by design (claude-skills-202): it does not scan `references/`, so a skill routing unverified, version-gated claims through a reference file is not flagged by this check. A wider scan was tried and reverted — it let a reference file merely mentioning "fabrication" satisfy the check for a SKILL.md carrying zero anti-fabrication content, which is more lenient, not stricter. Per-file reference scrutiny is tracked separately as claude-skills-141; until it lands, treat a skill's reference files as outside this check's coverage when narrating results
