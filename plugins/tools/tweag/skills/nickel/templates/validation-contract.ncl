# Configuration Schema with Validation Contracts
# Demonstrates contract-based validation patterns

# Define reusable validation contracts
let ValidPort = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in

let LogLevel = std.contract.from_predicate (
  fun x => std.array.elem x ["debug", "info", "warn", "error"]
) in

let DatabaseType = std.contract.from_predicate (
  fun x => std.array.elem x ["postgres", "mysql", "sqlite", "mongodb"]
) in

let NonEmptyString = fun label value =>
  if std.string.length value > 0 then
    value
  else
    std.contract.blame (label ++ ": string cannot be empty")
in

# Define the configuration schema with contracts
{
  # Service metadata
  app_name | NonEmptyString,
  version | NonEmptyString,

  # Server configuration with port validation
  server = {
    host | String = "0.0.0.0",
    port | ValidPort = 8080,
    timeout_seconds | Number = 30,
    ssl_enabled | Bool = false,
  },

  # Logging with level enumeration
  logging = {
    level | LogLevel = "info",
    format | String = "json",
    file_path | String = "/var/log/app.log",
  },

  # Database configuration with type validation
  database = {
    type | DatabaseType = "postgres",
    host | String = "localhost",
    port | ValidPort = 5432,
    name | NonEmptyString,
    username | NonEmptyString,
    password | NonEmptyString,
    pool = {
      min_size | Number | default = 1,
      max_size | Number | default = 10,
    }
  },

  # Features with defaults
  features = {
    auth | Bool | default = true,
    api | Bool | default = true,
    cache | Bool | default = false,
  },
}
