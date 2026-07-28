# Configuration Common Patterns

## Pattern 1: Environment Variables in Runtime

**Correct approach:**

```elixir
# config/runtime.exs
import Config

config :my_app,
  api_url: System.get_env("API_URL") || "http://localhost:4000",
  api_key: System.fetch_env!("API_KEY")  # Required in production
```

**Access in code:**

```elixir
defmodule MyApp.Client do
  def call(endpoint) do
    api_url = Application.fetch_env!(:my_app, :api_url)
    api_key = Application.fetch_env!(:my_app, :api_key)
    HTTPoison.get("#{api_url}/#{endpoint}", [{"Authorization", api_key}])
  end
end
```

## Pattern 2: Development vs Production Config

**config/config.exs:**

```elixir
import Config

# Shared configuration for all environments
config :my_app, :shared_setting, "value"

# Import environment-specific config
import_config "#{config_env()}.exs"
```

**config/dev.exs:**

```elixir
import Config

config :my_app, MyApp.Repo,
  database: "my_app_dev",
  show_sensitive_data_on_connection_error: true
```

**config/runtime.exs:**

```elixir
import Config

# Runtime config for all environments
if config_env() == :prod do
  # Production-specific runtime config
  database_url = System.fetch_env!("DATABASE_URL")

  config :my_app, MyApp.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")
end
```

## Pattern 3: Storing config_env() for Runtime Access

**Problem:** Can't call `config_env()` at runtime.

**Solution:** Store it in config:

```elixir
# config/config.exs
import Config

config :my_app, :environment, config_env()

# Then in your code:
defmodule MyApp do
  def environment do
    Application.fetch_env!(:my_app, :environment)
  end

  def development? do
    environment() == :dev
  end
end
```

## Pattern 4: Optional Features Based on Config

```elixir
defmodule MyApp.Telemetry do
  def setup do
    case Application.fetch_env(:my_app, :telemetry_backend) do
      {:ok, :datadog} -> setup_datadog()
      {:ok, :prometheus} -> setup_prometheus()
      :error -> :ok  # Telemetry disabled
    end
  end
end
```

## Pattern 5: Child Spec with Runtime Config

```elixir
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.Repo,
      {MyApp.Worker, Application.fetch_env!(:my_app, :worker_opts)},
      MyAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```
