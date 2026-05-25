# Migrations audit — repeatable template

Loaded when auditing an existing repo's Ecto migrations for `/elixir:ecto`
compliance (no inline raw SQL, snapshot-schema discipline, reversibility).
Pairs with the [Migrations](../SKILL.md#migrations) and
[When raw SQL IS appropriate](../SKILL.md#when-raw-sql-is-appropriate)
sections in the parent skill.

The template runs as a two-phase agent dispatch — a cheap haiku indexer
followed by an opus reviewer with this skill loaded — and reuses across
any Ecto-using repo by swapping the app namespace.

## When to run

- Pre-release sweep of a repo before a v1 / public-API freeze.
- After a multi-repo refactor that touched schemas in flight.
- Onboarding a new repo into a strict `/elixir:ecto` posture.
- Periodically (quarterly works) on long-lived schemas to catch drift.

## Inputs

- `<repo_root>` — absolute path to the repo root.
- `<app_namespace>` — the Elixir module namespace whose live schemas
  must NOT be `alias`ed inside migrations (e.g. `MyApp`).
- `<date>` — `YYYY-MM-DD`, used in output filenames.
- `<output_dir>` — relative to `<repo_root>`. Common choices: `research/`,
  `docs/audits/`, or `priv/repo/audits/`. Pick whichever the repo already
  uses for ad-hoc reports.
- `<migrations_dir>` — usually `priv/repo/migrations/`. Repos with
  multiple Ecto repos have `priv/<name>_repo/migrations/`; run the audit
  once per directory.

## Pre-flight grep (lead runs this before dispatch)

Run from `<repo_root>/<migrations_dir>/`. Captures the baseline so you
can spot-check Phase A's report.

```bash
echo "=== Total .exs files ==="
ls *.exs | wc -l

echo "=== Raw SQL via execute (BOTH paren and paren-less forms) ==="
# CRITICAL: Elixir allows function calls without parens.
# grep -l "execute(" misses `execute "..."` and `execute """..."""`.
grep -nE "execute[ (\"]" *.exs 2>/dev/null || echo "(none)"

echo "=== Raw SQL via Ecto.Adapters.SQL ==="
grep -nl "Ecto.Adapters.SQL" *.exs 2>/dev/null || echo "(none)"

echo "=== Raw SQL via repo.query / Repo.query ==="
grep -nlE "repo\(\)\.query|repo\.query|Repo\.query" *.exs 2>/dev/null || echo "(none)"

echo "=== Live-schema aliases (replace <AppNamespace> with the repo's namespace) ==="
grep -nl "alias <AppNamespace>\." *.exs 2>/dev/null || echo "(none)"

echo "=== flush() — DDL + data in same migration ==="
grep -nl "flush()" *.exs 2>/dev/null || echo "(none)"

echo "=== fragment() — legitimate escape hatch worth surfacing ==="
grep -nl "fragment(" *.exs 2>/dev/null || echo "(none)"

echo "=== @disable_ddl_transaction (CONCURRENTLY indexes) ==="
grep -nl "@disable_ddl_transaction" *.exs 2>/dev/null || echo "(none)"
```

**Known pitfall — paren-less `execute`:** the naïve pattern
`grep -l "execute("` reports zero hits even when `execute """..."""`
heredocs and `execute "UPDATE ..."` paren-less calls exist. Elixir
permits omitting parens on function calls, so both heredoc-string and
plain-string forms are common in real migrations. Always use
`grep -nE "execute[ (\"]"` (paren OR space OR opening quote) — the
extra two characters catch a whole class of violations the simpler
pattern misses.

## Phase A — Haiku indexer

One haiku Agent. Skill loads: `/core:anti-fabrication`. The work is
mechanical; judgment belongs to Phase B.

### Deliverable

A markdown file at `<repo_root>/<output_dir>/migrations-audit-<date>.md`:

```markdown
# <AppNamespace> Migrations Audit — Phase A index (<date>)

## Summary
- Total migrations: N
- Date range: YYYY-MM-DD to YYYY-MM-DD
- Flagged files: N
- Category counts: ddl-create-table: N, ddl-alter-table: N, ...

## Flagged files (need Phase B verdict)
| filename | date | summary | categories | flags |
|---|---|---|---|---|

## Full index (N rows, chronological)
| filename | date | summary | categories | flags |
|---|---|---|---|---|
```

### Column rules

- **categories** — comma-separated, drawn from this fixed set only:
  `ddl-create-table`, `ddl-alter-table`, `ddl-drop-table`, `ddl-index`,
  `ddl-constraint`, `ddl-rename`, `ddl-type-change`, `data-backfill`,
  `data-cleanup`, `extension`, `trigger-or-function`.
- **flags** — raised when the file contains ANY of:

  | Flag | Trigger |
  |---|---|
  | `raw-sql-execute` | `execute(`, `execute "`, or `execute """` |
  | `raw-sql-adapter` | `Ecto.Adapters.SQL` |
  | `raw-sql-repo-query` | `repo().query`, `repo.query`, or `Repo.query` |
  | `alias-live-schema` | `alias <AppNamespace>.` (literal `alias`, not `defmodule`) |
  | `flush-data-mix` | `flush()` |
  | `fragment` | `fragment(` |
  | `no-down` | `def up` exists but no `def down` AND not `def change` |
  | `disable-ddl-tx` | `@disable_ddl_transaction true` |
  | `other-category` | does something not covered by the fixed category set |

### Indexer discipline (prevents hallucinated flags)

Before emitting any flag, the indexer MUST run `grep -n <pattern> <file>`
and cite the line number in its report. Haiku indexers have been
observed hallucinating `alias-live-schema` flags on files that contain
no `alias` lines at all — confusing the GOOD local-snapshot pattern
`defmodule MigrationUser do ... use Ecto.Schema ... end` with an alias
of the live schema. Bake this distinction into the prompt:

> "`defmodule X do ... use Ecto.Schema` inside a migration is the
> local-snapshot pattern (good). Only flag `alias-live-schema` for
> literal `alias <AppNamespace>.X` lines that you have grep-verified
> by line number."

Similarly, the indexer should grep-verify EVERY flag (not just
alias-live-schema) and include the matching line number in the
flag-table column. No line number, no flag.

## Phase B — Opus reviewer with `/elixir:ecto`

One opus Agent. Skill loads: `/core:anti-fabrication`, `/elixir:ecto`,
`/elixir:style`. Receives the Phase A output path. All three skills
must be quoted-back as proof of loading before the audit work begins.

### Deliverable

A markdown file at `<repo_root>/<output_dir>/migrations-audit-<date>-findings.md`:

```markdown
# <AppNamespace> Migrations Audit — Phase B findings (<date>)

## Headline verdict
[ONE of: `clean` | `minor follow-ups` | `remediation needed`]

[2-3 sentence summary.]

## Method
[Skills loaded with one-sentence quote each; files read in full;
files sampled; independent re-grep results.]

## Verdicts on flagged migrations
### `<filename>` — <flag>
**Verdict:** [`pass` | `pass-with-note` | `fail`]
[Reasoning citing /elixir:ecto section names.]

## Non-flagged sample verification
[Table: 5+ sampled migrations × Phase A categorization × verified?]

## Quality observations (NOT audit failures)
[Stylistic / future-cleanup notes.]

## Recommendation
[Concrete next steps, ordered by aggressiveness.]
```

### Reviewer tasks

1. Read every **flagged** migration in full.
2. Independently re-run the pre-flight grep set. Phase A can miss
   flags; the reviewer is the second line of defense.
3. Sample 5+ **non-flagged** migrations across the date range and
   verify Phase A's categorization. If the indexer mislabeled even
   one, note it as a confidence issue.
4. For each flag, render a verdict per `/elixir:ecto`:
   - `raw-sql-execute` / `raw-sql-adapter` / `raw-sql-repo-query` →
     does it match an [escape-hatch criterion](../SKILL.md#when-raw-sql-is-appropriate)
     (PostGIS, CTE, `CREATE EXTENSION`, `CREATE INDEX CONCURRENTLY`)?
     Or is it gratuitous?
   - `flush-data-mix` → is the backfill using the
     [local snapshot schema](../SKILL.md#migrations) (preferred), a
     string-table query (acceptable), or aliasing a live schema
     (forbidden)?
   - `fragment` → is the SQL operator genuinely missing from the DSL?
     Confirm parameterization (no string interpolation).
   - `no-down` → reversibility risk; OK only when documented as
     irreversible (e.g. data loss).
   - `disable-ddl-tx` → confirm paired with `concurrently: true` on
     the index, and that the migration contains only that operation
     (DDL-tx-disabled migrations cannot wrap other DDL).
5. Write the findings doc. Headline verdict in the first paragraph
   so the operator does not have to read the whole file to act.

### Verdict semantics

- **`pass`** — the migration is idiomatic Ecto per `/elixir:ecto`.
- **`pass-with-note`** — passes, but a future migration touching this
  area should use a cleaner pattern. No remediation needed.
- **`fail`** — violates `/elixir:ecto` and warrants either a
  remediation issue or a documented "we accept this" decision.

## Orchestration

Dispatched serially (Phase B depends on Phase A's output). Per
`/core:agent-loop`'s lead-never-runs-shell rule, both phases go to
spawned Agents — the lead reads the outputs and reports verdicts to
the operator. The lead does NOT modify migrations inline; remediation
is filed as a separate issue.

## Reusability across repos

Substitute `<AppNamespace>` (the Elixir namespace) and `<repo_root>`
(the path) and the template runs unchanged. The pre-flight grep, the
indexer schema, and the reviewer skill loads do not change between
repos.

If a repo has multiple Ecto repos (e.g. `priv/main_repo/migrations/`
AND `priv/event_repo/migrations/`), run the audit once per repo dir
and produce one findings doc per repo.

## Output retention

Both output files are durable audit artifacts — commit them to the
repo. The pattern `<output_dir>/migrations-audit-<date>.md` makes
historical audits trivially diffable across time.
