# Ecto Changesets — Deep Dive

Loaded on demand for non-trivial changeset work: associations, custom validations, prepare hooks. Pairs with the [Writes — changesets](../SKILL.md#writes--changesets) section in the parent skill.

## Table of contents

- [The cast pipeline](#the-cast-pipeline)
- [Built-in validations](#built-in-validations)
- [Constraint mapping](#constraint-mapping)
- [Custom validations](#custom-validations)
- [`cast_assoc` and `cast_embed`](#cast_assoc-and-cast_embed)
- [`prepare_changes/2`](#prepare_changes2)
- [Multiple changesets per schema](#multiple-changesets-per-schema)
- [Inspecting changesets](#inspecting-changesets)

## The cast pipeline

`cast/4` extracts permitted fields from a params map. `validate_*` functions add errors. Constraint functions (`unique_constraint`, `foreign_key_constraint`, `check_constraint`) translate DB errors to changeset errors when the changeset hits the Repo.

```elixir
def changeset(struct, attrs) do
  struct
  |> cast(attrs, [:title, :slug, :status])         # extract
  |> validate_required([:title, :slug])             # validate
  |> validate_length(:title, max: 200)              # validate
  |> unique_constraint(:slug)                       # constraint mapping
end
```

Order matters for readability: cast → validate → constraint mapping. `cast/4` only adds fields listed in `permitted` — anything else is silently dropped. That is the security property: untrusted params can't set arbitrary columns.

## Built-in validations

Verified against ecto 3.13.5 (`deps/ecto/lib/ecto/changeset.ex`):

| Function | Checks |
|---|---|
| `validate_required(cs, fields, opts)` | All fields are non-nil and non-blank |
| `validate_length(cs, field, opts)` | `:min`, `:max`, `:is`, `:count` (`:graphemes`/`:codepoints`/`:bytes`) |
| `validate_format(cs, field, regex, opts)` | Regex match |
| `validate_inclusion(cs, field, list, opts)` | Value in list |
| `validate_exclusion(cs, field, list, opts)` | Value not in list |
| `validate_subset(cs, field, list, opts)` | Field (a list) is subset of list |
| `validate_number(cs, field, opts)` | `:less_than`, `:greater_than`, `:less_than_or_equal_to`, `:greater_than_or_equal_to`, `:equal_to`, `:not_equal_to` |
| `validate_acceptance(cs, field, opts)` | Field is `true` (terms-of-service style) |
| `validate_confirmation(cs, field, opts)` | `field_confirmation` matches `field` |
| `validate_change(cs, field, validator)` | Custom validator function |

Every validation accepts `:message` to override the default error string. Errors accumulate on the changeset — multiple validation failures all surface to the caller.

## Constraint mapping

Constraints translate Postgres errors into changeset errors at insert/update time. Without these, a constraint violation raises an exception instead of returning `{:error, changeset}`.

```elixir
|> unique_constraint(:email)
|> foreign_key_constraint(:owner_id)
|> check_constraint(:age, name: :age_must_be_positive)
|> exclusion_constraint(:reserved, name: :no_overlapping_reservations)
|> assoc_constraint(:owner)              # FK on a belongs_to assoc
|> no_assoc_constraint(:posts)           # blocks delete if children exist
```

The `:name` option matches the actual Postgres constraint name. Default conventions:
- `unique_index(:users, [:email])` → constraint name `users_email_index` → `unique_constraint(:email)` works without `:name`.
- Custom-named constraints require `:name`.

## Custom validations

```elixir
def changeset(struct, attrs) do
  struct
  |> cast(attrs, [:start_date, :end_date])
  |> validate_required([:start_date, :end_date])
  |> validate_date_range()
end

defp validate_date_range(changeset) do
  start_date = get_field(changeset, :start_date)
  end_date = get_field(changeset, :end_date)

  if start_date && end_date && Date.compare(start_date, end_date) == :gt do
    add_error(changeset, :end_date, "must be after start_date")
  else
    changeset
  end
end
```

`get_field/2` reads from changes-or-data; `get_change/2` reads only from changes (returns `nil` if unchanged). Use `get_field` for cross-field validations.

## `cast_assoc` and `cast_embed`

For nested data (associations or embedded schemas), use `cast_assoc/3` / `cast_embed/3` instead of cascading `cast/4` calls.

```elixir
schema "orders" do
  field :total, :decimal
  has_many :line_items, MyApp.LineItem
end

def changeset(order, attrs) do
  order
  |> cast(attrs, [:total])
  |> cast_assoc(:line_items, with: &MyApp.LineItem.changeset/2, required: true)
end
```

`cast_assoc` handles inserts (new children), updates (existing children matched by primary key), and deletes (set `:replace_assoc_with` or pass an `__delete__` flag depending on version). It runs the child's changeset for each item.

`cast_embed/3` is the same pattern for embedded schemas (`embeds_one` / `embeds_many`). Embeds live inside the parent's row; associations are separate tables.

## `prepare_changes/2`

Runs a function during `Repo.insert/update/delete`, after validations but before hitting the database, inside the same transaction. Useful for derived fields that need a DB query:

```elixir
def changeset(post, attrs) do
  post
  |> cast(attrs, [:title, :content])
  |> validate_required([:title, :content])
  |> prepare_changes(fn changeset ->
    case get_change(changeset, :title) do
      nil -> changeset
      title -> put_change(changeset, :slug, slugify(title))
    end
  end)
end
```

Code inside `prepare_changes` runs against the transaction's repo — `repo.insert(...)` inside it would commit to the same transaction.

## Multiple changesets per schema

Different write paths often need different validation rules. Define multiple changeset functions:

```elixir
def changeset(epic, attrs) do
  epic
  |> cast(attrs, [:title, :slug, :status])
  |> validate_required([:title, :slug])
end

def admin_changeset(epic, attrs) do
  epic
  |> changeset(attrs)
  |> cast(attrs, [:priority, :auto_merge])  # admin-only fields
end

def status_transition(epic, new_status) do
  epic
  |> change(status: new_status)
  |> validate_inclusion(:status, @valid_statuses)
end
```

`change/2` builds a changeset directly without going through `cast/4` — use it when the input is already trusted (internal code, not user params).

## Inspecting changesets

```elixir
%Ecto.Changeset{
  valid?: false,
  changes: %{title: "New"},
  errors: [slug: {"can't be blank", [validation: :required]}],
  data: %Epic{...},
  changeset_fields: [...]
}
```

- `valid?` — false if any errors accumulated
- `changes` — only the fields cast that differ from `data`
- `errors` — keyword list of `{field, {message, metadata}}`
- `data` — the original struct

`Ecto.Changeset.traverse_errors/2` flattens errors for rendering:

```elixir
Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
  Enum.reduce(opts, msg, fn {key, value}, acc ->
    String.replace(acc, "%{#{key}}", to_string(value))
  end)
end)
# => %{slug: ["can't be blank"]}
```
