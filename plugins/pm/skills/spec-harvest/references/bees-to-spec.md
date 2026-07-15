# Bees to Spec

Read-only bees surface for pm-discovery's bees-map shard and the provenance citations pm-spec-writer attaches to feature-inventory entries. Source: `plugins/core/skills/bees/SKILL.md` (repo path, cited as source).

## Read-Only Commands

The bees-map shard and pm-spec-writer use only these commands:

- `bees list --status open|closed --labels <tag> --assignee <name> --json`
- `bees show <id> [--json]`
- `bees ready [--json --labels <tag>]`
- `bees prime [--status open --labels <tag>]` — markdown export, LLM-ready
- `bees dep list <id>`
- `bees comment list <id>`
- `bees config get <key>`

jq examples for scripted reads:

```bash
bees ready --json | jq -r '.[0].id'
bees list --json | jq 'length'
```

## Prohibited Writes

No phase of `/pm:spec-harvest` calls any write command against the prototype's bees tracker:

- `bees create` / `bees new`
- `bees close`
- `bees update`
- `bees label add` / `bees label remove`
- `bees dep add` / `bees dep remove`
- `bees comment add`
- `bees config set`
- `bees init`
- `bees sync`

Spec harvesting reads the prototype's existing tracker state; it never mutates it.

## Detection

Check for a `.bees/` directory at the prototype root before running the bees-map shard. A bees repository contains `bees.db` (SQLite, WAL mode), `issues.jsonl`, `metadata.json`, `config.json`, and a `.beads` compatibility symlink.

When `.bees/` is absent:
- Skip the bees-map shard entirely.
- Note the absence in the feature inventory ("no bees tracker found at prototype root").
- Never fabricate roadmap claims, feature status, or work history in its place.

## Mapping Workflow

1. **Open issues → roadmap intent.** An open issue describes planned work with no guarantee it exists in code yet. Tag any feature-inventory entry built solely from an open issue `[inferred — needs verification]` unless the described behavior is also confirmed in code.
2. **Closed issues → completed-work provenance.** A closed issue whose described behavior matches an observed feature is evidence the behavior shipped intentionally, not by accident. Cite the issue ID alongside the code evidence, e.g. `[seen-in-code: lib/store/cart.ex] (bees#42)`.
3. **Labels → feature-area mapping.** `type:`, `priority:`, `epic:`, `skill:`, and `complexity:` labels group issues by feature area; use them to decide which PRD a feature belongs under in phase 4.
4. **`bees dep list <id>` → dependency ordering.** Trace blocking relationships between issues to infer feature build order — a dependency edge is evidence a feature area has an internal sequencing constraint, not evidence of what the feature does.
5. **`bees comment list <id>` → work history.** Comments provide narrative context (why a decision was made, what was tried) that rarely belongs in the spec itself but can resolve ambiguity between two competing readings of the code.

## Citing Bees Provenance in the Feature Inventory

Every feature-inventory entry that draws on bees data includes a "Bees provenance" line listing the relevant issue IDs and whether each is open (roadmap) or closed (shipped). This keeps the confidence tags on discovery claims traceable back to a specific, re-checkable source.

## Worked Example

A prototype has `.bees/` at its root. `bees list --status closed --json | jq -r '.[] | "\(.id): \(.title)"'` returns `bees#42: add guest checkout flow`. The bees-map shard reads `bees show 42` and finds the description matches the checkout behavior pm-discovery already found in `lib/store/cart.ex`. The feature-inventory entry for guest checkout then carries:

```
**Evidence**:
- Checkout flow processes a cart with no account required. `[seen-in-code: lib/store/cart.ex] (bees#42)`

**Bees provenance**: bees#42 (closed — shipped)
```

A second issue, `bees#51: add saved-address book`, is still open. No file in the prototype implements a saved-address book. The corresponding entry (if the separation phase decides it is in scope for the spec at all) reads:

```
**Bees provenance**: bees#51 (open — roadmap intent, not present in code) `[inferred — needs verification]`
```

## Why Read-Only

pm-discovery and pm-spec-writer read the prototype's own `.bees/` tracker, not the workspace's own issue tracker. Bees is single-writer per `plugins/core/skills/bees/SKILL.md` (cited source) — concurrent writers against the same SQLite database raise `SQLITE_CONSTRAINT` or `daemon.lock` failures. A spec-harvesting run has no business writing to a prototype's tracker in the first place: its job is to read what exists and report it, not to reshape someone else's backlog. Treat any temptation to file a bees issue against the prototype during discovery as scope creep — findings belong in the feature inventory and SDLC assessment, not in a new bees row.
