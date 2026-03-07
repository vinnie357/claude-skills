# Import and Export Workflows in Nickel

Guide for converting between configuration formats and validating imported data.

## Importing Configurations

### Import YAML Files

```nickel
# Basic import
let config = import "application.yaml" in
config

# Import into specific field
{
  app_config = import "app.yaml",
  db_config = import "database.yaml",
}
```

### Import JSON Files

```nickel
# Import JSON configuration
let settings = import "settings.json" in
{
  settings = settings,
  debug = false,
}
```

### Import TOML Files

```nickel
# Import TOML configuration
let deploy_config = import "Cargo.toml" in
deploy_config
```

### Import Multiple Formats

```nickel
# Combine configurations from different formats
{
  # From YAML
  app = import "app.yaml",

  # From JSON
  secrets = import "secrets.json",

  # From TOML
  build = import "build.toml",
}
```

## Validation During Import

### Apply Contract to Imported Data

```nickel
let AppSchema = {
  name | String,
  version | String,
  port | Number,
} in

# Validate import against schema
(import "app.yaml") | AppSchema
```

### Multi-Field Validation

```nickel
let DatabaseSchema = {
  host | String,
  port | Number,
  database | String,
  username | String,
  password | String,
} in

# Validate database configuration
{
  database = (import "database.yaml") | DatabaseSchema,
}
```

### Nested Validation

```nickel
let ServerConfig = {
  host | String,
  port | Number,
  ssl = {
    enabled | Bool,
    cert_path | String,
  }
} in

(import "server.yaml") | ServerConfig
```

## Export Operations

### Export as JSON

```bash
nickel export config.ncl --format json
nickel export config.ncl --format json --output config.json
```

### Export as YAML

```bash
nickel export config.ncl --format yaml
nickel export config.ncl --format yaml --output config.yaml
```

### Export as TOML

```bash
nickel export config.ncl --format toml
nickel export config.ncl --format toml --output config.toml
```

## Complete Workflows

### Workflow: Import YAML, Validate, Export JSON

Nickel source (`convert.ncl`):

```nickel
let Config = {
  service_name | String,
  port | Number,
  debug | Bool,
} in

let imported = import "input.yaml" in
imported | Config
```

Command:

```bash
nickel export convert.ncl --format json --output output.json
```

Result: Validates YAML against schema and exports as JSON.

### Workflow: Merge Multiple Sources, Validate, Export

Nickel source (`merged.ncl`):

```nickel
let DefaultConfig = {
  port | default = 8080,
  log_level | default = "info",
  debug | default = false,
} in

let EnvConfig = {
  port = 3000,
  log_level = "warn",
} in

DefaultConfig & EnvConfig
```

Command:

```bash
nickel export merged.ncl --format yaml --output final.yaml
```

Result: Merges defaults with environment config and exports as YAML.

### Workflow: Import, Transform, Validate, Export

Nickel source (`transform.ncl`):

```nickel
let PortSchema = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in

let imported = import "raw.json" in

let transformed = {
  service_name = imported.app_name,
  port | PortSchema = imported.port,
  environment = std.string.uppercase imported.env,
} in

transformed
```

Command:

```bash
nickel export transform.ncl --format json --output final.json
```

Result: Imports JSON, transforms fields, applies validation, exports as JSON.

### Workflow: Multi-Format Generation from Single Source

Nickel source (`config.ncl`):

```nickel
let AppConfig = {
  app_name | String = "my-service",
  version | String = "1.0.0",
  port | Number = 8080,
  features = {
    auth | Bool = true,
    logging | Bool = true,
  }
} in

AppConfig
```

Commands:

```bash
# Generate all three formats
nickel export config.ncl --format json --output config.json
nickel export config.ncl --format yaml --output config.yaml
nickel export config.ncl --format toml --output config.toml
```

Result: Single source generates three compatible config formats.

## Import with Contract Inheritance

### Extend Imported Configuration

```nickel
# Base configuration
let base = import "base.yaml" in

# Schema for extension
let ExtendedSchema = {
  # Keep original fields
  app_name | String,
  port | Number,

  # Add new required fields
  version | String,
  environment | String,
} in

base & {
  version = "2.0.0",
  environment = "production",
} | ExtendedSchema
```

## Error Handling in Imports

### Validation Errors

When import validation fails, Nickel reports the contract violation:

```nickel
let StrictPort = std.contract.from_predicate (
  fun x => x == 8080 || x == 443
) in

# This fails if port is not 8080 or 443
(import "config.yaml") | {port | StrictPort}
```

Error output includes:
- Field name that failed validation
- Expected constraint
- Actual value
- Location in source file

### Partial Validation

Skip strict validation by using `Dyn` contract:

```nickel
# Import without validation
let partial = import "config.yaml" in

# Access specific fields with validation later
{
  port | Number = partial.port,
  name = partial.name,
}
```

## Complex Import Patterns

### Conditional Imports

```nickel
let env = std.env.get "APP_ENV" in

let config =
  if env == "prod" then
    import "prod.yaml"
  else if env == "staging" then
    import "staging.yaml"
  else
    import "dev.yaml"
in

config
```

### Import with Defaults

```nickel
let defaults = {
  log_level | default = "info",
  timeout | default = 30,
} in

let user_config = import "user.yaml" in

defaults & user_config
```

### Schema Validation with Detailed Messages

```nickel
let ValidPort = fun label value =>
  if value >= 1 && value <= 65535 then
    value
  else
    std.contract.blame (label ++ ": port must be 1-65535, got " ++ value)
in

let ValidEnv = fun label value =>
  if std.array.elem value ["dev", "prod"] then
    value
  else
    std.contract.blame (label ++ ": must be 'dev' or 'prod'")
in

let Schema = {
  port | ValidPort,
  environment | ValidEnv,
} in

(import "config.yaml") | Schema
```

## CLI Workflow Examples

### Merge Two Configurations

```bash
# Merge base and overrides, output as YAML
nickel export base.json overrides.ncl --format yaml
```

### Validate YAML Against Nickel Schema

Create `schema.ncl`:

```nickel
{
  name | String,
  version | String,
  port | Number,
}
```

Then validate:

```bash
# Create validation wrapper
cat > validate.ncl << 'EOF'
let schema = import "schema.ncl" in
(import "input.yaml") | schema
EOF

nickel eval validate.ncl
```

### Bulk Format Conversion

```bash
# Convert all YAML files to JSON
for file in *.yaml; do
  nickel export "$file" --format json --output "${file%.yaml}.json"
done
```

## Integration with Build Tools

### mise Task for Validation

```toml
[tasks.config:validate]
description = "Validate all configurations"
script = """
for file in configs/*.yaml; do
  nickel export "$file" --format json > /dev/null && echo "✓ $file"
done
"""
```

### mise Task for Export

```toml
[tasks.config:export]
description = "Export configurations to JSON"
script = """
mkdir -p build/config
for file in src/*.ncl; do
  nickel export "$file" --format json --output "build/config/$(basename $file .ncl).json"
done
"""
```
