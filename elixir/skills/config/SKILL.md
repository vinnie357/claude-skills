---
name: elixir-config
description: Guide for Elixir application configuration. Use when configuring runtime vs compile-time settings, managing config.exs/runtime.exs, or using Application.get_env.
license: MIT
---

# Elixir Configuration

Guide for proper application configuration in Elixir, with emphasis on understanding and correctly using runtime vs compile-time configuration.

## When to Activate

Use this skill when:
- Setting up or modifying application configuration
- Choosing between `config.exs` and `runtime.exs`
- Deciding between `Application.compile_env` and `Application.get_env`
- Debugging configuration-related issues
- Working with releases or deployment configuration
- Migrating from `use Mix.Config` to `import Config`
- Writing libraries that need configuration

## Critical Principle

> **Runtime configuration is the preferred approach.** Only use compile-time configuration when values must affect compilation itself.

## Configuration Files

### config/config.exs (Compile-Time)

Evaluated during project compilation, before your application starts.

```elixir
import Config

# Basic configuration
config :my_app, MyApp.Repo,
  database: "my_app_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost"

# Environment-specific config
config :my_app,
  environment: config_env()

# Import environment-specific config files
import_config "#{config_env()}.exs"
```

**Key characteristics:**
- Runs at compile time
- Uses `import Config` (not `use Mix.Config`)
- Can use `config_env()` and `config_target()`
- Can import other config files with `import_config/1`
- Deep-merges keyword lists
- **Library config.exs is NOT evaluated when used as a dependency**

### config/runtime.exs (Runtime)

Evaluated right before applications start in both Mix and releases.

```elixir
import Config

# Read from environment variables
config :my_app, MyApp.Repo,
  database: System.get_env("DATABASE_NAME") || "my_app_dev",
  username: System.get_env("DATABASE_USER") || "postgres",
  password: System.get_env("DATABASE_PASSWORD") || "postgres",
  hostname: System.get_env("DATABASE_HOST") || "localhost",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# Conditional runtime configuration
if config_env() == :prod do
  config :my_app, MyAppWeb.Endpoint,
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE"),
    http: [port: String.to_integer(System.fetch_env!("PORT"))]
end
```

**Key characteristics:**
- Runs at application startup (both dev and prod)
- Executes in both Mix projects and releases
- Perfect for environment variables and runtime values
- **Does NOT support `import_config/1`**
- Can use `System.get_env` and `System.fetch_env!`

### config/dev.exs, config/test.exs, config/prod.exs

Environment-specific compile-time configuration, typically imported from `config.exs`:

```elixir
# config/config.exs
import_config "#{config_env()}.exs"

# config/dev.exs
import Config

config :my_app, MyApp.Repo,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# config/test.exs
import Config

config :my_app, MyApp.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# config/prod.exs
import Config

# Production-specific compile-time config only
config :my_app, MyAppWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json"
```

## Accessing Configuration

### Runtime Access (Preferred)

Use in function bodies to read configuration at runtime:

#### Application.get_env/3

```elixir
defmodule MyApp.Service do
  def start_link do
    # Get with default value
    timeout = Application.get_env(:my_app, :timeout, 5000)
    GenServer.start_link(__MODULE__, timeout, name: __MODULE__)
  end
end
```

**When to use:**
- Reading config in function bodies (most common)
- When a sensible default exists
- When config might change between environments

#### Application.fetch_env!/2

```elixir
defmodule MyApp.Mailer do
  def deliver(email) do
    # Raise if not configured (for required config)
    api_key = Application.fetch_env!(:my_app, :mailgun_api_key)
    send_email(email, api_key)
  end
end
```

**When to use:**
- Required configuration that must exist
- When you want explicit errors for missing config
- When no sensible default exists

#### Application.fetch_env/2

```elixir
defmodule MyApp.Cache do
  def get(key) do
    case Application.fetch_env(:my_app, :cache_adapter) do
      {:ok, adapter} -> adapter.get(key)
      :error -> nil  # No caching configured
    end
  end
end
```

**When to use:**
- Optional configuration
- When you need pattern matching on result
- When absence of config is a valid state

### Compile-Time Access (Use Sparingly)

Use only when configuration must affect compilation:

#### Application.compile_env/3

```elixir
defmodule MyApp.JSONEncoder do
  # Only use compile_env when the value affects compilation
  @json_library Application.compile_env(:my_app, :json_library, Jason)

  def encode(data) do
    # The specific library is compiled into the module
    @json_library.encode(data)
  end
end
```

**When to use:**
- Configuration affects which code gets compiled
- Performance-critical paths where indirection is costly
- Compile-time optimizations or code generation

**Warning:** Mix tracks compile-time config and raises errors if values diverge between compile and runtime.

#### Application.compile_env!/2

```elixir
defmodule MyApp.Adapter do
  # Raises at compile time if not configured
  @adapter Application.compile_env!(:my_app, :storage_adapter)

  def store(data) do
    @adapter.put(data)
  end
end
```

**When to use:**
- Required compile-time configuration
- Adapters or behaviors selected at compile time

## Common Patterns

### Pattern 1: Environment Variables in Runtime

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

### Pattern 2: Development vs Production Config

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

### Pattern 3: Storing config_env() for Runtime Access

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

### Pattern 4: Optional Features Based on Config

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

### Pattern 5: Child Spec with Runtime Config

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

## Anti-Patterns to Avoid

### ❌ Using compile_env for Runtime Values

```elixir
# DON'T: Using compile_env for environment variables
defmodule MyApp.Service do
  @api_key Application.compile_env(:my_app, :api_key)

  def call do
    # This won't work correctly in releases!
    HTTPoison.get(url, [{"Authorization", @api_key}])
  end
end
```

**Why it's wrong:** Environment variables aren't available at compile time in releases.

**Correct approach:**

```elixir
defmodule MyApp.Service do
  def call do
    # Read at runtime
    api_key = Application.fetch_env!(:my_app, :api_key)
    HTTPoison.get(url, [{"Authorization", api_key}])
  end
end
```

### ❌ Reading Other Application's Config

```elixir
# DON'T: Directly access other app's configuration
defmodule MyApp do
  def logger_level do
    Application.get_env(:logger, :level)  # Fragile coupling
  end
end
```

**Why it's wrong:** Creates tight coupling and breaks encapsulation.

**Correct approach:**

```elixir
# Configure it in your own app
# config/config.exs
config :my_app, :log_level, :info

# Then read your own config
defmodule MyApp do
  def log_level do
    Application.get_env(:my_app, :log_level, :info)
  end
end
```

### ❌ Using Application Config in Libraries

```elixir
# DON'T: In a library
defmodule MyLibrary do
  def process(data) do
    # Library reading its own application environment
    timeout = Application.get_env(:my_library, :timeout, 5000)
    do_work(data, timeout)
  end
end
```

**Why it's wrong:** Library `config.exs` is not evaluated when used as a dependency.

**Correct approach:**

```elixir
# DO: Accept options as arguments
defmodule MyLibrary do
  def process(data, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 5000)
    do_work(data, timeout)
  end
end

# Users configure in their application
defmodule MyApp.Worker do
  def run do
    opts = Application.get_env(:my_app, :my_library_opts, [])
    MyLibrary.process(data, opts)
  end
end
```

### ❌ Using Mix Module in Application Code

```elixir
# DON'T: Use Mix.env() in application code
defmodule MyApp do
  def environment do
    Mix.env()  # Won't work in releases!
  end
end
```

**Why it's wrong:** `Mix` is not available in production releases.

**Correct approach:**

```elixir
# Store it in config
# config/config.exs
config :my_app, :environment, config_env()

# Access from application environment
defmodule MyApp do
  def environment do
    Application.fetch_env!(:my_app, :environment)
  end
end
```

## Config Functions Reference

### In Configuration Files

| Function | Description | Where to Use |
|----------|-------------|--------------|
| `config/2` | Configure app with keyword list | All config files |
| `config/3` | Configure app key with value | All config files |
| `config_env/0` | Get current environment (`:dev`, `:test`, `:prod`) | All config files |
| `config_target/0` | Get build target | All config files |
| `import_config/1` | Import other config files | Not in `runtime.exs` |

### In Application Code

| Function | Return Type | Use Case |
|----------|-------------|----------|
| `Application.get_env/3` | `value \| default` | Runtime with default |
| `Application.fetch_env/2` | `{:ok, value} \| :error` | Runtime with pattern matching |
| `Application.fetch_env!/2` | `value` (raises if missing) | Required runtime config |
| `Application.compile_env/3` | `value` | Compile-time with default |
| `Application.compile_env!/2` | `value` (raises if missing) | Required compile-time config |

## Migration Guide

### From `use Mix.Config` to `import Config`

**Old (deprecated):**

```elixir
use Mix.Config

config :my_app, :key, "value"

if Mix.env() == :prod do
  config :my_app, :production, true
end

import_config "#{Mix.env()}.exs"
```

**New:**

```elixir
import Config

config :my_app, :key, "value"

if config_env() == :prod do
  config :my_app, :production, true
end

import_config "#{config_env()}.exs"
```

**Changes:**
1. Replace `use Mix.Config` with `import Config`
2. Replace `Mix.env()` with `config_env()`
3. Remove wildcard imports (not supported)

### Moving Runtime Config to runtime.exs

**Before (all in config.exs):**

```elixir
# config/config.exs
import Config

config :my_app,
  api_key: System.get_env("API_KEY"),  # Wrong place!
  static_value: "something"
```

**After (split correctly):**

```elixir
# config/config.exs
import Config

config :my_app,
  static_value: "something"

# config/runtime.exs
import Config

config :my_app,
  api_key: System.get_env("API_KEY") || raise("API_KEY not set")
```

## Best Practices Summary

1. **Default to Runtime Configuration**: Use `Application.get_env/3` in function bodies
2. **Use runtime.exs for Environment Variables**: Never read env vars in `config.exs`
3. **Use compile_env Only When Necessary**: Only when config affects compilation
4. **Libraries Should Not Use Application Config**: Accept options as function arguments
5. **Never Use Mix in Application Code**: Use `config_env()` in config files, store result
6. **Validate Required Config Early**: Use `fetch_env!/2` in application start for required values
7. **Provide Sensible Defaults**: Use `get_env/3` with defaults for optional config
8. **Document Configuration**: Add comments explaining what each config key does
9. **Use runtime.exs for Releases**: Essential for Elixir releases and deployments
10. **Store config_env() for Runtime Use**: Can't call `config_env()` outside config files

## Debugging Configuration

### Check Current Configuration

```elixir
# In IEx
Application.get_all_env(:my_app)

# Check specific key
Application.fetch_env(:my_app, :some_key)

# See all applications
Application.loaded_applications()
```

### Common Issues

**Problem:** Config not available in tests

```elixir
# config/test.exs
import Config

config :my_app, :test_value, "configured"
```

**Problem:** Different values in dev vs release

Check that `runtime.exs` is being used and environment variables are set correctly.

**Problem:** Compile-time config not updating

```bash
# Clean and recompile
mix clean
mix compile
```

## Resources

- **Config Module Docs**: https://hexdocs.pm/elixir/Config.html
- **Application Module Docs**: https://hexdocs.pm/elixir/Application.html
- **Runtime Configuration Guide**: https://hexdocs.pm/mix/Mix.Tasks.Release.html#module-runtime-configuration

## Key Insights

> "Reading the application environment at runtime is the preferred approach."

> "If you are writing a library to be used by other developers, it is generally recommended to avoid the application environment, as the application environment is effectively a global storage."

> "config/config of a library is not evaluated when the library is used as a dependency, as configuration is always meant to configure the current project."

Configuration is a cross-cutting concern. Default to runtime configuration with `Application.get_env/3`, and only reach for compile-time configuration when you have a specific need for it that justifies the trade-offs.
