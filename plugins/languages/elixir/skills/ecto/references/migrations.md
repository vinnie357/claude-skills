# Ecto Migrations — Deep Dive

Loaded on demand when authoring or reviewing an Ecto migration. Pairs with the [Migrations](../SKILL.md#migrations) section in the parent skill.

## Table of contents

- [Local snapshot schema pattern (the rule)](#local-snapshot-schema-pattern-the-rule)
- [Reversible vs irreversible migrations](#reversible-vs-irreversible-migrations)
- [Common DDL recipes](#common-ddl-recipes)
- [`@disable_ddl_transaction` and concurrent indexes](#disable_ddl_transaction-and-concurrent-indexes)
- [Backfilling large tables in batches](#backfilling-large-tables-in-batches)
- [`execute/2` for reversible raw SQL](#execute2-for-reversible-raw-sql)
- [Ordering rules](#ordering-rules)

## Local snapshot schema pattern (the rule)

Data migrations transform existing rows. The rule is: **never `alias` the live application schema inside a migration**. The live schema evolves; the migration is a historical artifact. Coupling them breaks replay.

```elixir
defmodule MyApp.Repo.Migrations.BackfillUserDisplayName do
  use Ecto.Migration
  import Ecto.Query

  # Local snapshot — frozen to this migration's point in history.
  # Never `alias MyApp.Accounts.User`.
  defmodule User do
    use Ecto.Schema

    schema "users" do
      field :first_name, :string
      field :last_name, :string
      field :display_name, :string
    end
  end

  def change do
    repo = repo()

    from(u in User, where: is_nil(u.display_name))
    |> repo.all()
    |> Enum.each(fn user ->
      user
      |> Ecto.Changeset.change(display_name: "#{user.first_name} #{user.last_name}")
      |> repo.update!()
    end)
  end
end
```

Why this works when the live `User` schema later drops `first_name`:
- The migration's local `User` still references `first_name` (frozen in time).
- Replay reads the column that existed at this migration's point, not what HEAD looks like now.
- New developers running migrations from scratch get a working backfill.

## Reversible vs irreversible migrations

`change/0` covers the common case — Ecto infers the rollback. Use `up/0` + `down/0` when the rollback isn't auto-derivable, or when the migration is data-only.

```elixir
def up do
  alter table(:users) do
    add :role, :string, default: "member", null: false
  end
end

def down do
  alter table(:users) do
    remove :role
  end
end
```

Mark genuinely-irreversible data migrations:

```elixir
def up do
  # ... data transformation ...
end

def down do
  raise Ecto.MigrationError, "irreversible: backfill cannot be undone safely"
end
```

## Common DDL recipes

### Add a NOT NULL column with a default

```elixir
def change do
  alter table(:epics) do
    add :priority, :integer, default: 10, null: false
  end
end
```

Postgres rewrites the table on default-with-NOT-NULL on older versions. Postgres 11+ handles this without rewrite when the default is a constant.

### Add a NOT NULL column to a populated table without a default

Three steps across migrations:

```elixir
# Migration 1: add nullable
alter table(:epics) do: add :owner_id, :binary_id

# Migration 2: backfill (local snapshot pattern)
# ... see above ...

# Migration 3: enforce
alter table(:epics) do: modify :owner_id, :binary_id, null: false
```

### Rename a column

```elixir
def change do
  rename table(:epics), :slug, to: :handle
end
```

Postgres handles this without table rewrite. Application code referencing the old name breaks at runtime — coordinate with a deploy.

### Composite unique index

```elixir
def change do
  create unique_index(:epics, [:tenant_id, :slug], name: :epics_tenant_slug_index)
end
```

Pair with `unique_constraint(:slug, name: :epics_tenant_slug_index)` in the changeset.

### Foreign key with cascade

```elixir
def change do
  alter table(:tasks) do
    add :epic_id, references(:epics, type: :binary_id, on_delete: :delete_all), null: false
  end
  create index(:tasks, [:epic_id])
end
```

Always create an index on FK columns — Postgres does not auto-index them.

## `@disable_ddl_transaction` and concurrent indexes

Postgres `CREATE INDEX CONCURRENTLY` cannot run inside a transaction. Disable the migration-wrapping transaction:

```elixir
defmodule MyApp.Repo.Migrations.AddIndexConcurrently do
  use Ecto.Migration
  @disable_ddl_transaction true
  @disable_migration_lock true

  def change do
    create index(:epics, [:status], concurrently: true)
  end
end
```

`@disable_migration_lock true` is required when the migration runs against a hot table — the default lock blocks writes.

## Backfilling large tables in batches

A single `Repo.update_all` over millions of rows holds locks too long. Batch by primary key:

```elixir
def change do
  batch_size = 1_000
  stream_batches(batch_size, fn ids ->
    from(u in User, where: u.id in ^ids and is_nil(u.display_name))
    |> repo().update_all(set: [display_name: ""])
  end)
end

defp stream_batches(size, fun) do
  # Iterate by max(id) cursor — see HexDocs Ecto.Repo.stream/2
end
```

For very large tables, use `Repo.stream/2` inside a transaction with `:max_rows` set, or process in an external worker. Migrations are the wrong place for multi-hour backfills — separate the schema change from the data change.

## `execute/2` for reversible raw SQL

`execute/1` runs one direction. `execute/2` provides up + down strings for reversibility:

```elixir
def change do
  execute(
    "CREATE EXTENSION IF NOT EXISTS pgcrypto",
    "DROP EXTENSION IF EXISTS pgcrypto"
  )
end
```

## Ordering rules

- One migration per schema change. Mixing column adds, data backfill, and NOT NULL enforcement in one migration creates a non-recoverable state on partial failure.
- File names are timestamps — `20260507120000_add_priority_to_epics.exs`. The timestamp is the order; never edit it after merge.
- `mix ecto.migrate` is idempotent when migrations are pure. Side effects (file writes, HTTP calls, queue publishes) inside `change/0` break that — keep migrations DB-only.
