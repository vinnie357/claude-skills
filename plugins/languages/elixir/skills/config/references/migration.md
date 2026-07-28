# Migration Guide

## From `use Mix.Config` to `import Config`

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

## Moving Runtime Config to runtime.exs

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
