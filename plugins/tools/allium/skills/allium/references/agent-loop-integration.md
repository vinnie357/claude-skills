# Agent-Loop Integration

How each tier of `/core:agent-loop`'s 6-tier hierarchy handles an attached `.allium` spec. All Allium steps are optional — epics with no `spec:` field behave exactly as without this plugin.

## Tier 1: Epic Author

**When a spec is needed:** new feature epic with observable state transitions, or refactor epic requiring a behavioral baseline.

**Steps:**

1. Run `/allium:elicit` for conversational spec authoring, or copy a template from `plugins/tools/allium/skills/allium/templates/`.
2. Save the spec to `docs/specs/<epic-slug>.allium`.
3. Add the `spec:` field to the epic markdown: `spec: ./docs/specs/<epic-slug>.allium`.
4. Commit the spec file on the feature branch before spawning the team.

**When not to attach a spec:** tooling-only epics (dependency bumps, CI config, version bumps) — these have no domain behavior to model.

## Tier 2: Team Leader

**On epic intake:**

1. Check the epic markdown for a `spec:` field.
2. If `spec:` is present: read the spec file and include the rule/entity list in every worker prompt so workers know what behaviors to implement.
3. If the epic has a `refactor` label and NO `spec:`: instruct Worker A to run `/allium:distill` on the modules being refactored before writing any code. The distilled spec becomes the behavioral baseline. Save to `docs/specs/<epic-slug>.allium` and commit.

**Worker prompt addendum (when spec is present):**

```
Spec attached: docs/specs/<epic-slug>.allium
Rules to implement: [list rule names from spec]
Before writing implementation: run /allium:propagate docs/specs/<epic-slug>.allium
Propagated tests become your failing test suite. Do not write tests from scratch.
```

## Tier 3: Sub-team Leader

No direct Allium action. Ensures that worker prompts forwarded from Tier 2 include the spec path and propagate instruction.

## Tier 4: Worker

**When spec is attached:**

1. Run `/allium:propagate <spec-path>` before writing any implementation code.
2. Confirm propagated tests are failing (they should be — no implementation yet).
3. Implement to make the propagated tests pass, one rule at a time (follows `/core:tdd` cycle).
4. Do not write additional tests that contradict spec rules.

**When spec is NOT attached:** standard TDD cycle per `/core:tdd`.

## Tier 5: Validator

**After `mise run ci` passes:**

1. Check the epic for a `spec:` field.
2. If present: run `/allium:weed <spec-path>`.
3. If weed reports divergences: treat them as CI failures — route to Tier 6 (fix-agent) with the weed output as the failure report.
4. If weed is clean: include "allium weed: clean" in the validation report.

**Weed output format (for fix-agent prompt):**

```
Allium weed divergences detected:
<paste verbatim weed output>
Spec: docs/specs/<epic-slug>.allium
Fix the implementation to match the spec rules listed above.
```

## Tier 6: Fix Agent

Receives weed divergence output same as any CI failure. Reads the spec, identifies the divergent rule, implements the fix, re-runs CI + weed. Reports back to Validator.

## Spec File Lifecycle

```
Epic authored → spec created (Tier 1)
              → committed to feature branch
              → included in worker prompts (Tier 2)
              → tests propagated from spec (Tier 4)
              → weed check post-CI (Tier 5)
              → merged to main with feature branch
              → lives at docs/specs/<epic-slug>.allium on main
```

Specs are not deleted after merge — they become the behavioral record of the epic and can be imported by future specs with `use`.
