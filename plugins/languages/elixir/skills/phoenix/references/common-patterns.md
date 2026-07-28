# Phoenix Common Patterns

## Loading Associations

Preload associations efficiently:

```elixir
def list_posts do
  Post
  |> preload([:author, comments: :author])
  |> Repo.all()
end
```

## Pagination

Use Scrivener or custom pagination:

```elixir
def list_users(page \\ 1) do
  User
  |> order_by(desc: :inserted_at)
  |> Repo.paginate(page: page, page_size: 20)
end
```

## File Uploads

Handle uploads in LiveView:

```elixir
def mount(_params, _session, socket) do
  {:ok,
   socket
   |> assign(:uploaded_files, [])
   |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png), max_entries: 1)}
end

def handle_event("save", _params, socket) do
  uploaded_files =
    consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
      dest = Path.join("priv/static/uploads", Path.basename(path))
      File.cp!(path, dest)
      {:ok, "/uploads/" <> Path.basename(dest)}
    end)

  {:noreply, update(socket, :uploaded_files, &(&1 ++ uploaded_files))}
end
```
