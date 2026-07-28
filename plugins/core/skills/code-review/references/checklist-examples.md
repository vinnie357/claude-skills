# Checklist BAD/GOOD Examples

Worked BAD/GOOD Elixir pairs for the checklist criteria in `SKILL.md`. Consult the section matching the checklist item under review.

## Security

**Common security issues:**

```elixir
# BAD: SQL injection vulnerability
query = "SELECT * FROM users WHERE id = #{user_id}"

# GOOD: Use parameterized queries
query = from u in User, where: u.id == ^user_id

# BAD: XSS vulnerability
raw("<div>#{user_input}</div>")

# GOOD: Escape user input
<div><%= user_input %></div>

# BAD: Hardcoded secrets
api_key = "sk_live_123456789"

# GOOD: Use environment variables
api_key = System.get_env("API_KEY")

# BAD: Mass assignment vulnerability
User.changeset(%User{}, params)

# GOOD: Whitelist allowed fields
User.changeset(%User{}, params)
# Where changeset only casts allowed fields:
# cast(user, attrs, [:name, :email])
```

## Performance

**Common performance issues:**

```elixir
# BAD: N+1 query
posts = Repo.all(Post)
Enum.map(posts, fn post ->
  author = Repo.get(User, post.author_id)  # Query for each post!
  {post, author}
end)

# GOOD: Preload associations
posts = Post |> preload(:author) |> Repo.all()

# BAD: Loading entire dataset
users = Repo.all(User)  # Loads all millions of users
Enum.filter(users, & &1.active)

# GOOD: Query in database
users = User |> where(active: true) |> Repo.all()

# BAD: Inefficient data structure
list = [1, 2, 3, 4, 5]
if 3 in list do  # O(n) lookup in list
  # ...
end

# GOOD: Use set/map for lookups
set = MapSet.new([1, 2, 3, 4, 5])
if MapSet.member?(set, 3) do  # O(1) lookup
  # ...
end
```

## Code Quality

**Code quality issues:**

```elixir
# BAD: Unclear names
def calc(x, y, z) do
  r = x * y / z
  r * 1.2
end

# GOOD: Clear names
def calculate_discounted_price(quantity, unit_price, discount_percentage) do
  subtotal = quantity * unit_price
  discount_amount = subtotal * (discount_percentage / 100)
  subtotal - discount_amount
end

# BAD: Long function with multiple responsibilities
def process_order(order) do
  # Validate order (responsibility 1)
  # Calculate totals (responsibility 2)
  # Update inventory (responsibility 3)
  # Send email (responsibility 4)
  # Log analytics (responsibility 5)
end

# GOOD: Single responsibility functions
def process_order(order) do
  with {:ok, order} <- validate_order(order),
       {:ok, order} <- calculate_totals(order),
       {:ok, order} <- update_inventory(order),
       :ok <- send_confirmation_email(order),
       :ok <- log_order_analytics(order) do
    {:ok, order}
  end
end

# BAD: Magic numbers
if user.age >= 13 do
  # ...
end

# GOOD: Named constants
@minimum_age_coppa 13

if user.age >= @minimum_age_coppa do
  # ...
end
```

## Error Handling

**Error handling patterns:**

```elixir
# BAD: Silent failure
try do
  dangerous_operation()
rescue
  _ -> nil  # Error is swallowed!
end

# GOOD: Handle errors explicitly
case dangerous_operation() do
  {:ok, result} -> result
  {:error, reason} ->
    Logger.error("Operation failed: #{inspect(reason)}")
    {:error, reason}
end

# BAD: Generic error message
{:error, "failed"}

# GOOD: Specific error
{:error, :invalid_email_format}
{:error, {:validation_failed, errors}}

# BAD: Let it crash when shouldn't
def parse_config(path) do
  File.read!(path)  # Crashes if file missing
  |> Jason.decode!()  # Crashes if invalid JSON
end

# GOOD: Handle expected errors
def parse_config(path) do
  with {:ok, content} <- File.read(path),
       {:ok, config} <- Jason.decode(content) do
    {:ok, config}
  else
    {:error, :enoent} -> {:error, :config_file_not_found}
    {:error, %Jason.DecodeError{}} -> {:error, :invalid_config_format}
  end
end
```

## Testing

**Testing concerns:**

```elixir
# BAD: Unclear test name
test "test1" do
  # ...
end

# GOOD: Descriptive test name
test "create_user/1 returns error when email is invalid" do
  # ...
end

# BAD: Testing too much at once
test "user workflow" do
  # Creates user
  # Updates user
  # Deletes user
  # All in one test!
end

# GOOD: Focused tests
test "create_user/1 creates user with valid attributes" do
  # ...
end

test "update_user/2 updates user name" do
  # ...
end

test "delete_user/1 removes user from database" do
  # ...
end

# BAD: Non-deterministic test
test "async operation completes" do
  start_async_operation()
  Process.sleep(100)  # Race condition!
  assert operation_completed?()
end

# GOOD: Deterministic test
test "async operation completes" do
  start_async_operation()
  assert_receive {:completed, _result}, 1000
end
```
