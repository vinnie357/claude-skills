---
name: ecto
description: Guide for Ecto schemas, changesets, queries, migrations, and Multi. Use when writing Ecto migrations, querying or mutating Ecto schemas, designing changesets, working with Ecto.Multi, or choosing between Ecto query DSL and raw SQL.
license: MIT
---

# Ecto

Canonical reference for Ecto data work in Elixir. Verified against ecto 3.13.5 / ecto_sql 3.13.5 (signatures pulled from installed dep source). Newer minor versions add APIs but keep these signatures stable.

## The default rule

**Ecto schemas + changesets are the default. Raw SQL via `Ecto.Adapters.SQL.query/4` is the fallback.**

Reads can use raw SQL when no Ecto query DSL covers the case. Writes go through changesets so validation and constraints run. Bypassing changesets silently ships malformed rows — bugs surface at read time, not write time.

Reach for raw SQL only when one of the [escape-hatch criteria](#when-raw-sql-is-appropriate) applies. Default to `Repo.all`, `Repo.insert`, `Repo.update`, `Repo.delete` and changesets.

## Reads — query DSL

Use the `Ecto.Query` DSL (`from`, `where`, `join`, `select`, `fragment`) over string SQL. The DSL composes, type-checks against the schema, and prevents SQL injection.

```elixir
import Ecto.Query

# Good — composable, type-safe
def list_open_epics(repo_filter) do
  from(e in Epic,
    where: e.status == "open" and e.target_repos == ^repo_filter,
    order_by: [desc: e.priority],
    select: e
  )
  |> Repo.all()
end

# Use fragment/1 only for SQL the DSL cannot express
def case_insensitive_search(term) do
  from(e in Epic,
    where: fragment("? ILIKE ?", e.title, ^"%#{term}%")
  )
  |> Repo.all()
end
```

```elixir
# Bad — string SQL, no schema typing, no composition
Ecto.Adapters.SQL.query!(Repo,
  "SELECT * FROM epics WHERE status = $1",
  ["open"]
)
```

`Repo.get/3` (single by primary key), `Repo.one/2` (assert single result), `Repo.all/2` (list), `Repo.exists?/2` (boolean) cover most read entry points.

## Writes — changesets

Every write builds a `%Ecto.Changeset{}` from a struct + attrs, then runs through `Repo.insert/2`, `Repo.update/2`, or `Repo.delete/2`.

Verified signatures (ecto 3.13.5):

```elixir
Ecto.Changeset.cast(data, params, permitted, opts \\ [])
Ecto.Changeset.validate_required(changeset, fields, opts \\ [])
Ecto.Changeset.unique_constraint(changeset, field_or_fields, opts \\ [])
Ecto.Changeset.validate_format(changeset, field, regex, opts \\ [])
```

Real exemplar from `Vantageex.Epics.Epic`:

```elixir
def changeset(epic, attrs) do
  epic
  |> cast(attrs, [:external_id, :title, :slug, :objective, :status, :priority])
  |> validate_required([:external_id, :title, :slug, :objective])
  |> validate_inclusion(:status, @valid_statuses)
  |> unique_constraint(:slug)
end
```

Return tuples are `{:ok, struct}` on success or `{:error, %Ecto.Changeset{}}` on validation/constraint failure. Pattern-match both branches:

```elixir
def create_epic(attrs) do
  %Epic{}
  |> Epic.changeset(attrs)
  |> Repo.insert()
end

case create_epic(attrs) do
  {:ok, epic} -> handle_success(epic)
  {:error, changeset} -> render_errors(changeset)
end
```

For bang-vs-non-bang and idiomatic error returns, see `/elixir:style`.

## Batch writes

`Repo.update_all/3` and `Repo.delete_all/2` skip changesets — no per-row validation, no `before_*`/`after_*` hooks. Use them for mass updates where validation is irrelevant or already enforced upstream.

```elixir
# Bulk: clear stale fields across many rows
from(e in Epic, where: e.status == "stale")
|> Repo.update_all(set: [last_peek_output: nil])
```

When validation matters, prefer N changeset updates inside a transaction over one `update_all`. Measure before bulk-updating "for performance" — Postgres handles thousands of indexed updates in milliseconds.

## Migrations

Schema changes use `add`, `alter`, `drop`, `create index`, `create table` macros. Verified signatures (ecto_sql 3.13.5):

```elixir
Ecto.Migration.add(column, type, opts \\ [])
Ecto.Migration.execute(command)  # binary, 0-arity fn, or list
defmacro create(object, do: block)  # for tables/indexes with column blocks
```

```elixir
defmodule MyApp.Repo.Migrations.AddPriorityToEpics do
  use Ecto.Migration

  def change do
    alter table(:epics) do
      add :priority, :integer, default: 10, null: false
    end
    create index(:epics, [:priority])
  end
end
```

### Data migrations — local snapshot schema pattern

Data migrations transform existing rows. Two rules:

1. **Never `alias` the live application schema.** The live schema evolves; a migration written against `MyApp.Epics.Epic` today breaks when fields get renamed or removed in a future migration. Replay from scratch fails.
2. **Define a local snapshot schema inside the migration module.** It captures the schema's shape at this point in history.

```elixir
defmodule MyApp.Repo.Migrations.BackfillEpicPriority do
  use Ecto.Migration
  import Ecto.Query

  defmodule Epic do
    use Ecto.Schema
    schema "epics" do
      field :priority, :integer
      field :status, :string
    end
  end

  def change do
    repo = repo()

    from(e in Epic, where: is_nil(e.priority))
    |> repo.all()
    |> Enum.each(fn epic ->
      epic
      |> Ecto.Changeset.change(priority: priority_for_status(epic.status))
      |> repo.update!()
    end)
  end

  defp priority_for_status("urgent"), do: 1
  defp priority_for_status(_), do: 10
end
```

This pattern dogfoods Ecto end-to-end: queries via DSL, writes via changesets, schemas frozen to migration time. See `references/migrations.md` for additional recipes.

### When `execute/1` is appropriate

`execute/1` runs raw SQL inside a migration. Use it for DB-specific DDL the macros do not cover:

- Postgres extensions: `execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")`
- Custom indexes: `execute("CREATE INDEX CONCURRENTLY ...")` (note: `CONCURRENTLY` requires `@disable_ddl_transaction true`)
- Trigger functions, materialized views, partitioning DDL

`execute/1` is **never** the right tool for data transformations. Use the local-snapshot pattern above.

## Multi-step atomic ops — Ecto.Multi

`Ecto.Multi` chains operations into one transaction. If any step fails, prior steps roll back. As of ecto 3.13, `Repo.transaction/2` is deprecated — use `Repo.transact/2`.

Verified signatures:

```elixir
Ecto.Multi.new()                              # empty %Ecto.Multi{}
Ecto.Multi.insert(multi, name, changeset_or_struct_or_fn, opts \\ [])
Ecto.Multi.update(multi, name, changeset_or_fn, opts \\ [])
Repo.transact(multi_or_fn, opts \\ [])
```

```elixir
def transfer_funds(from_id, to_id, amount) do
  Ecto.Multi.new()
  |> Ecto.Multi.update(:debit, debit_changeset(from_id, amount))
  |> Ecto.Multi.update(:credit, credit_changeset(to_id, amount))
  |> Ecto.Multi.insert(:audit, fn %{debit: debit} ->
    AuditLog.changeset(%AuditLog{}, %{from: debit.id, amount: amount})
  end)
  |> Repo.transact()
end
```

On success: `{:ok, %{debit: ..., credit: ..., audit: ...}}`. On failure: `{:error, failed_step_name, failed_value, changes_so_far}`. Pattern-match the four-tuple for the failed-step branch.

The third argument to `Multi.insert/4` and `Multi.update/4` accepts a 1-arity function `fn changes -> changeset end` — that is how downstream steps reference upstream results.

## When raw SQL IS appropriate

Escape hatch criteria. Each one requires evidence, not assumption.

- **Complex CTEs / window functions** Ecto's DSL does not expose. Document the missing DSL feature in a comment.
- **DB-specific features**: PostGIS spatial queries, full-text search ranking with custom dictionaries, advisory locks.
- **Perf-critical hot paths** with measured Ecto overhead. Benchmark first; "it feels slow" is not evidence.
- **One-off reads** in tidewave eval (single-cell exploration). Never one-off writes — those go through a changeset even at the REPL.

```elixir
# Acceptable: PostGIS — no DSL covers ST_DWithin
{:ok, %{rows: rows}} =
  Ecto.Adapters.SQL.query(
    Repo,
    "SELECT id FROM places WHERE ST_DWithin(location, ST_MakePoint($1, $2)::geography, $3)",
    [lng, lat, radius]
  )
```

## Anti-patterns

### `repo().query!("UPDATE ...")` in migrations

Bypasses Ecto, hides errors, locks the migration to the current row shape. Replace with the local-snapshot pattern.

```elixir
# Bad
def change do
  repo().query!("UPDATE epics SET priority = 1 WHERE status = 'urgent'")
end

# Good — snapshot schema + Repo.update_all (or Repo.update for per-row validation)
defmodule Epic do
  use Ecto.Schema
  schema "epics" do
    field :priority, :integer
    field :status, :string
  end
end

def change do
  from(e in Epic, where: e.status == "urgent")
  |> repo().update_all(set: [priority: 1])
end
```

### Bypassing changeset validation via `insert_all`

`Repo.insert_all/3` inserts raw maps without changesets. Use it only when you have already validated the data upstream OR when the rows are infrastructure (e.g. seed data). For user input, always go through a changeset.

### Importing live application schema into old migrations

```elixir
# Bad — couples migration N to whatever Epic looks like at HEAD
defmodule MyApp.Repo.Migrations.OldMigration do
  alias MyApp.Epics.Epic   # WRONG
  ...
end
```

A schema change six months from now breaks migration replay. Define a local snapshot schema instead (see [Migrations](#migrations) above).

### "Raw SQL because it's faster"

Without measurement, this is fabrication. Ecto's overhead vs raw SQL is microseconds per row. Most perceived "slow Ecto" is N+1 queries (fix with `Repo.preload/3` or a join), missing indexes, or unbounded result sets — not the DSL itself.

## References

- `references/migrations.md` — local snapshot schema deep dive, common DDL recipes, reversible migrations, `@disable_ddl_transaction` rules
- `references/changesets.md` — `cast_assoc`, `validate_*` catalog, custom validations, `prepare_changes/2`
- HexDocs: [Ecto](https://hexdocs.pm/ecto/), [Ecto.Changeset](https://hexdocs.pm/ecto/Ecto.Changeset.html), [Ecto.Query](https://hexdocs.pm/ecto/Ecto.Query.html), [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html), [Ecto.Migration](https://hexdocs.pm/ecto_sql/Ecto.Migration.html)
- `/elixir:tidewave` — runtime introspection of schemas via `mcp__tidewave__get_ecto_schemas` and live API doc lookup
- `/elixir:phoenix-framework` — context-pattern integration (changeset usage in Phoenix contexts)
- `/elixir:style` — bang-vs-non-bang return semantics, idiomatic error returns

## Anti-fabrication

Every API signature in this skill is verified from the installed source under `deps/ecto/` and `deps/ecto_sql/` (ecto 3.13.5). When this skill is loaded:

- Cite signatures from `mcp__tidewave__get_docs` or the installed dep source — not memory.
- Mark any unverified function as "requires investigation".
- See `/core:anti-fabrication` for the authoritative guide.
