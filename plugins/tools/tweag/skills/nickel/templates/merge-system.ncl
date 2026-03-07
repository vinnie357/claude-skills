# Configuration Merging Example
# Demonstrates Nickel's merge system for composing configurations

# Base configuration with defaults
let base = {
  app_name | default = "my-service",
  version | default = "1.0.0",

  server = {
    host | default = "localhost",
    port | default = 8080,
    timeout_seconds | default = 30,
  },

  logging = {
    level | default = "info",
    format | default = "json",
  },

  database = {
    host | default = "localhost",
    port | default = 5432,
    pool_size | default = 5,
  },

  features = {
    auth | default = true,
    cache | default = false,
  },
} in

# Development overrides
let development = {
  server = {
    host = "127.0.0.1",
    timeout_seconds = 60,
  },

  logging = {
    level = "debug",
  },

  features = {
    cache = false,
  },
} in

# Production overrides
let production = {
  server = {
    host = "0.0.0.0",
    port = 443,
    timeout_seconds = 10,
  },

  logging = {
    level = "warn",
  },

  database = {
    host = "prod-db.example.com",
    pool_size = 20,
  },

  features = {
    auth = true,
    cache = true,
  },
} in

# Merge based on environment
let environment = std.env.get_or "APP_ENV" "development" in

if environment == "production" then
  base & production
else
  base & development
