# Situational-skills activation benchmark — frozen design (claude-skills-295, Part 2)

**Status: FROZEN, UNVALIDATED.** This artifact designs a `claude plugin eval` benchmark for
the six situational core skills (`tdd`, `twelve-factor`, `mise`, `nushell`, `agent-loop`,
`bees`). It has NOT been run against the actual benchmark tool, has NOT been validated by a
pilot gate, and produces NO activation-rate numbers. Every prompt, threshold, and decision
rule below is a design artifact only — unvalidated until a pilot gate runs, and the pilot
gate itself is execution, which is out of scope for this issue.

## Why this is frozen instead of executed

`claude plugin eval init --bare` exits 1 with `plugin eval` is currently in early access — —
independently reconfirmed by re-running the exact command in this environment (see also the
Test Reviewer's prior confirmation). Per `/core:anti-fabrication`, no activation-rate claim, no
drop/keep decision, and no change to the six skills' mandatory status may ship without an
actual measurement. Because the tool that would produce that measurement is gated, this issue
authors the design and stops — see the follow-up bees issue described in the writer's report
(295c) for execution once the tool becomes available.

Until 295c runs and produces real numbers, all six situational skills stay
**mandatory-with-citation-requirement** (the AC's own explicit fallback).

## Prompt-authoring rule

No prompt may contain the skill name, the plugin name, or a distinctive phrase lifted from the
skill's `description` field — doing so would measure keyword-matching against the description,
not real activation from task shape. Full pass verified against all 48 targeted and 10 ambient
prompts: none name `tdd`, `twelve-factor`, `mise`, `nushell`, `agent-loop`, or `bees`, nor
phrases like "test-driven", "12-factor", "structured data pipelines", or "Forge". Two
initial leakage instances (nushell "cross-platform automation", bees "local-first tracker")
were identified and corrected by rewording to preserve task intent.

## Prompt sets

Two categories per skill: **coding-shaped** (task drives toward writing/modifying code,
running tests, or ops work) and **doc-shaped** (task drives toward documentation, planning, or
research with no code changes expected). 4 prompts per category per skill × 6 skills × 2
categories = 48 targeted prompts, plus 5 ambient prompts per category (10 total) that name no
skill and are not expected to reliably trigger any one situational skill — they establish a
false-positive baseline.

### TDD

**Coding-shaped:**
1. "Add a `retry_with_backoff` function to `lib/http_client.py` that retries a failing request up to 3 times with exponential backoff. Make sure it's properly covered before you call it done."
2. "This `parse_duration()` helper has no coverage and I'm about to change its behavior for negative inputs. Sort that out first, then make the change."
3. "I want to add a rate limiter to the API middleware. Build it up incrementally rather than dropping the whole thing in at once."
4. "Fix the off-by-one in `paginate()` — and I don't want to see the fix land without something that would have caught it."

**Doc-shaped:**
1. "Write the ADR for our new retry policy, and include how we'll know it works."
2. "Draft the acceptance criteria for this epic so an implementer can turn each one into a check."
3. "Write the section of our contributing guide that explains what 'done' means for a change."
4. "Review this issue description — it says 'add caching'. Make it verifiable."

### Twelve-factor

**Coding-shaped:**
1. "The service reads its DB password from a checked-in `config/production.yaml`. Move it somewhere sane for a container deploy."
2. "We're about to run three copies of this worker behind a load balancer. It currently writes session state to a local temp dir — what has to change?"
3. "Write the Dockerfile and deployment manifest for this Go service so it runs on our cluster."
4. "The app opens a DB connection at import time and caches it in a module global. That's biting us on redeploy — restructure it."

**Doc-shaped:**
1. "Write the README's deployment section for a service that runs in containers across three environments."
2. "Document how this project handles configuration across dev, staging, and prod."
3. "Draft an ADR on where secrets live for our container deployments."
4. "Write the operations runbook section covering how the service should be started, stopped, and scaled."

### Mise

**Coding-shaped:**
1. "This repo has a `.tool-versions` and a Makefile. Consolidate the toolchain pinning and the task running into one place."
2. "Add a single command that runs format, lint, and tests together, so CI and local dev use the exact same entry point."
3. "The Node version in CI is 18 but everyone locally is on 22. Pin it so both match."
4. "Set up this project so a new contributor can clone it and get every required binary at the right version with one command."

**Doc-shaped:**
1. "Write the 'Getting started' section of the README, covering how a new contributor installs the toolchain."
2. "Document the project's task commands so someone can run the same checks CI runs."
3. "Draft an ADR proposing we standardize toolchain pinning across all repos."
4. "Write the CONTRIBUTING.md section on local environment setup."

### Nushell

**Coding-shaped:**
1. "Write a script that reads every `plugin.json` under `plugins/`, pulls out name and version, and prints them as a table sorted by version."
2. "This bash script breaks on Windows and chokes on filenames with spaces. Rewrite it so it works everywhere and handles the JSON properly instead of with grep and cut."
3. "Add a script that queries the GitHub API for open PRs and filters to ones older than 7 days, outputting structured records the CI job can consume."
4. "Convert `scripts/collect-stats.sh` to something that doesn't need jq and awk to parse its own output."

**Doc-shaped:**
1. "Write the section of our style guide that says which scripting language new automation should use and why."
2. "Document the validation scripts in `test/` — what each one checks and how to run it."
3. "Draft an ADR on replacing our bash test harness."
4. "Write a skill that teaches an agent how to write scripts that run reliably on any OS and handle edge cases like spaces in filenames."

### Agent-loop

**Coding-shaped:**
1. "Work the top item off the ready queue."
2. "This change touches four files across two packages and has acceptance criteria. Set it up so the person writing the tests isn't the person making them pass."
3. "Take this feature request through to a PR: add OAuth device-flow login to the CLI."
4. "Split this epic into independently deliverable slices and decide who runs each one."

**Doc-shaped:**
1. "Plan out how we'd deliver this epic — who does what, in what order."
2. "Write the prompt template our team leads use when spawning implementation workers."
3. "Draft an ADR describing our multi-agent review pipeline."
4. "Research how other teams structure adversarial test-authoring and write up a recommendation."

### Bees

**Coding-shaped:**
1. "Before I start coding, find out what's actually unblocked in this repo's tracker."
2. "File the three follow-ups this refactor is leaving behind, and make the second one wait on the first."
3. "I finished the auth work — close it out and get the tracker state committed."
4. "Show me the dependency graph for the current epic so I know what's blocking what."

**Doc-shaped:**
1. "Write the section of CONTRIBUTING.md that explains how we track work in this repo."
2. "Plan this epic and file the resulting slices."
3. "Draft an ADR comparing our on-premises issue tracker against a cloud-hosted alternative."
4. "Document the labels we use on issues and what each one drives."

### Ambient (false-positive baseline, no skill named or implied as primary target)

**Coding-shaped (5):**
1. "CI fails about one run in eight with no obvious pattern — figure out why."
2. "Add a `--dry-run` flag to the import command that shows what would happen without writing anything."
3. "This 200-line function does three unrelated things. Break it up."
4. "Bump the JSON parser dependency to its 3.x line and fix whatever breaks."
5. "The report generator is slow on large inputs — find out where the time goes."

**Doc-shaped (5):**
1. "Our README hasn't been touched in a year and doesn't match the current setup. Refresh it."
2. "Summarize the last 20 commits into something that reads like a release note."
3. "Compare these two proposals and recommend one, with reasoning."
4. "Write onboarding docs for a new team member joining next week."
5. "Review this skill's description — does it actually describe when it should trigger?"

## Decision table

Applied per skill, per category, once real activation and necessity data exist. `necessity`
(needed / not-needed) is a human/reviewer judgment made against the task category — whether
the skill's guidance materially changes correct behavior for that category — recorded
alongside the measured activation rate, not derived from it.

| Activation rate | Necessity | Verdict | Follow-up |
|---|---|---|---|
| ≥ 90% | needed | DROP from mandatory (activation is already reliable without forcing) | — |
| ≤ 33% | needed | KEEP mandatory | — |
| 34–89% | needed | KEEP mandatory (gray band) | file a description-tuning follow-up |
| ≥ 90% | not-needed | DROP from mandatory | file an over-broad-description follow-up |
| ≤ 89% | not-needed | DROP from mandatory | — |

The 90% figure is not invented for this issue — it is
`claude-code:claude-skills-benchmark`'s own documented target: "Target: 90%+ true positive
rate, <5% false positive rate" (`plugins/tools/claude-code/skills/claude-skills-benchmark/SKILL.md`).

## Required invocation

`--ablation none` MUST be passed explicitly when this suite is eventually run:

```
claude plugin eval --ablation none ...
```

`claude plugin eval --help` documents the default as `with-without` whenever a plugin
resolves — it adds a no-plugin baseline arm and reports a score delta against it. That baseline
arm is meaningless here: every prompt in this suite runs inside a workspace where the six
situational skills are already installed as part of `core`/other marketplace plugins, and
nothing in the task set can fire a skill without the plugin installed in the first place.
`--ablation with-without`'s comparison arm would measure "plugin installed vs. not", not
"skill activates vs. doesn't" — the wrong axis for this benchmark.

## Validity-threat mitigation: the SessionStart hook

`plugins/core/hooks/session-start.sh` force-invokes all ten core skills' *names* into every
session's turn-1 context as a command contract (see item 2: "invoke each of these by exact
name" followed by the ten-skill list). If this suite runs inside a workspace where that hook
fires unmodified, every case trivially reports the skill as "activated" — not because the task
shape triggered it, but because the hook told the agent to invoke it regardless of the prompt.
A naive activation-rate run under this condition would read 100% for every skill in every
category, which is not a measurement, it's an artifact of the harness.

Mitigation required before any real run counts as evidence:

1. **Strip the hook for the run.** Execute the suite in a workspace/plugin configuration where
   `plugins/core/hooks/session-start.sh` (or any equivalent SessionStart injection) is disabled
   — a hooks-free workspace, or a `claude plugin eval` invocation that does not load the core
   plugin's hooks alongside the skill(s) under test.
2. **Assert a specific marker string is absent from every transcript.** The hook's injected
   block is bounded by literal markers (`[CORE PLUGIN — SESSION-START COMMAND CONTRACT]` /
   `[END CORE SESSION-START CONTRACT]`, see `plugins/core/hooks/session-start.sh`). Grep every
   case transcript for either marker string; any match voids that run — the hook fired and the
   result cannot be trusted as an unprompted activation measurement.
3. Only runs that pass step 2 (marker absent) count toward the decision table in the previous
   section.

## Scope explicitly excluded from this artifact

This design does not run the benchmark, does not report any activation rate, and does not
change any of the six skills' mandatory status. Execution is 295c (see the writer's report for
this issue) — blocked on `claude plugin eval` general availability, or a funded fallback
harness.
