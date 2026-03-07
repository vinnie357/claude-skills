# Basic Application Configuration
# Simple typed configuration example with Nickel

{
  # Application metadata
  app_name | String = "my-service",
  version | String = "1.0.0",

  # Server configuration
  server = {
    host | String = "localhost",
    port | Number = 8080,
    debug | Bool = false,
  },

  # Logging configuration
  logging = {
    level | String = "info",
    format | String = "json",
    output | String = "stdout",
  },

  # Database configuration
  database = {
    type | String = "postgres",
    host | String = "localhost",
    port | Number = 5432,
    name | String = "myapp_db",
    username | String = "postgres",
    password | String = "changeme",
  },

  # Feature flags
  features = {
    authentication | Bool = true,
    cors | Bool = false,
    compression | Bool = true,
  },
}
