---
name: nickel
description: "Configuration language with gradual typing and contracts for schema validation. Use when defining typed configuration schemas, validating YAML/JSON/TOML inputs, merging configurations, or generating type-safe config from Nickel sources."
license: MIT
---

# Nickel Configuration Language

Nickel is a configuration language designed to automate generation of static configuration files (JSON, YAML, TOML, XML). It combines gradual typing with runtime contracts to provide both static checking for complex logic and flexible validation for configuration data.

## When to Use This Skill

Activate this skill when:
- Defining typed configuration schemas with validation contracts
- Validating YAML/JSON/TOML files against Nickel contract definitions
- Merging multiple configuration files using Nickel's merge semantics
- Converting between configuration formats (JSON ↔ YAML ↔ TOML)
- Generating type-safe configurations from a single Nickel source
- Creating reusable configuration templates with metadata
- Building configuration pipelines with validation and transformation

## Key Concepts

### Gradual Typing

Nickel supports both static and dynamic typing. Mix typed and untyped code within the same configuration:
- **Typed regions**: Functions with static type checking for complex logic
- **Dynamic regions**: Flexible configuration values validated at runtime with contracts
- Types are optional—choose when to use them

### Contracts

Contracts are runtime assertions that validate values satisfy specific properties. They act as schemas:
- **Built-in contracts**: `Number`, `String`, `Bool`, `Dyn`, `Array`, record contracts
- **Custom contracts**: Functions that check predicates and return values or errors
- **Composition**: Combine multiple contracts with boolean logic (`std.contract.one_of`, `std.contract.all_of`)
- **Metadata**: Contracts attach to fields using the `|` operator

### Merge System

The `&` operator merges records with symmetric semantics:
- **Symmetric merging**: Both sides contribute to the result
- **Recursive merging**: Nested records merge recursively
- **Metadata composition**: Documentation, defaults, and contracts merge together
- **Priorities and defaults**: Control override behavior with metadata

## Installation

### Using mise

Add to `mise.toml`:

```toml
[tools]
nickel = "latest"

[tasks.validate-config]
script = "nickel eval config.ncl"

[tasks.export-config]
script = "nickel export --format json config.ncl"
```

### Using Cargo

```bash
cargo install nickel-lang-cli
```

## CLI Usage

### Evaluate Nickel Files

```bash
nickel eval config.ncl
nickel eval config.ncl --output result.json
```

### Export to Different Formats

```bash
# Export to JSON
nickel export config.ncl --format json

# Export to YAML
nickel export config.ncl --format yaml

# Export to TOML
nickel export config.ncl --format toml

# Merge and export
nickel export base.json overrides.ncl --format yaml
```

### Format Code

```bash
nickel format config.ncl
nickel format --check config.ncl  # Check without modifying
```

### Interactive REPL

```bash
nickel repl
```

## Basic Syntax

### Records (Objects)

```nickel
{
  field1 = "value",
  field2 = 42,
  nested = {
    key = "data",
  }
}
```

### String Interpolation

```nickel
let name = "app" in
let port = 8080 in
"Starting %{name} on port %{port}"
```

### Arrays

```nickel
let ports = [8000, 8001, 8002] in
ports
```

### Functions

```nickel
let add = fun x y => x + y in
let result = add 2 3 in
result
```

### Let Bindings

```nickel
let base_port = 8000 in
let debug = true in
{
  port = base_port,
  debug = debug,
}
```

## Contracts and Validation

### Applying Contracts with the Pipe Operator

Attach contracts to fields using `|`:

```nickel
{
  port | Number = 8080,
  name | String = "my-service",
  debug | Bool = false,
}
```

### Built-in Contracts

Nickel provides contracts for basic types:

```nickel
# Number contract
value | Number

# String contract
value | String

# Boolean contract
value | Bool

# Dyn (dynamic) contract - never fails
value | Dyn

# Array contract
items | Array Number  # Array of numbers

# Record contract
config | {port: Number, host: String}
```

### Custom Contracts

Define contracts as functions that validate and return values:

```nickel
# Port number validation (1-65535)
let Port = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in
{
  port | Port = 8080,
}
```

### Contract with Error Messages

```nickel
let LogLevel =
  fun label value =>
    if std.array.elem value ["debug", "info", "warn", "error"]
    then value
    else std.contract.blame label
in
{
  log_level | LogLevel = "info",
}
```

### Combining Contracts

Use boolean contract combinators from `std.contract`:

```nickel
# One of multiple contracts must match
value | std.contract.one_of [Contract1, Contract2]

# All contracts must match
value | std.contract.all_of [Contract1, Contract2]

# Negation
value | std.contract.not SomeContract
```

## Importing and Validating Formats

### Import YAML

```nickel
let config = import "config.yaml" in
config
```

### Import JSON

```nickel
let data = import "data.json" in
data
```

### Import TOML

```nickel
let settings = import "settings.toml" in
settings
```

### Apply Validation Contract to Import

```nickel
let AppConfig = {
  port | Number,
  name | String,
  debug | Bool,
} in

(import "app.yaml") | AppConfig
```

### Full Validation Workflow

```nickel
# Define schema
let ConfigSchema = {
  app_name | String,
  port | Number,
  log_level | String,
  database = {
    host | String,
    port | Number,
  }
} in

# Import and validate
let imported = import "config.yaml" in
let validated = imported | ConfigSchema in

# Export as JSON
validated
```

## Merge System

### Basic Merge

```nickel
let base = {
  app_name = "service",
  port = 8080,
} in

let overrides = {
  port = 443,
} in

# Result: port = 443 (overrides takes precedence)
base & overrides
```

### Recursive Merge

```nickel
let base = {
  database = {
    host = "localhost",
    port = 5432,
  }
} in

let env_overrides = {
  database = {
    host = "prod.example.com",
  }
} in

# Nested database.host overridden, port preserved
base & env_overrides
```

### Defaults and Optional Fields

```nickel
let defaults = {
  port | default = 8080,
  log_level | default = "info",
} in

let user_config = {
  port = 3000,
} in

defaults & user_config  # port = 3000, log_level = "info"
```

## Anti-Fabrication Notes

When using Nickel configurations:
- **Verify contract behavior** by running `nickel eval file.ncl` to confirm validation works as expected
- **Test import validation** using `nickel eval` with actual data files to ensure format imports succeed
- **Validate merge results** by examining output with `nickel export --format json` to confirm merge semantics
- **Check CLI flags** against current Nickel version documentation, as CLI may have changed since this skill was written

## Ecosystem Tools

### json-schema-to-nickel

Convert JSON Schema specifications to Nickel contracts:

```bash
# Generates Nickel contract from JSON Schema
json-schema-to-nickel schema.json > schema.ncl
```

### Topiary Integration

Nickel is Topiary's configuration language. Topiary's language configuration uses `languages.ncl`:

```nickel
# Topiary language configuration with Nickel
{
  language = "rust",
  formatting_rules = {
    indent = 2,
  }
}
```

## mise Task Examples

Define validation and export tasks in `mise.toml`:

```toml
[tasks.config:validate]
description = "Validate configuration against schema"
script = "nickel eval config.ncl --output /dev/null && echo 'Valid'"

[tasks.config:export-json]
description = "Export configuration as JSON"
script = "nickel export config.ncl --format json --output config.json"

[tasks.config:export-all]
description = "Export in all formats"
script = """
nickel export config.ncl --format json --output config.json
nickel export config.ncl --format yaml --output config.yaml
nickel export config.ncl --format toml --output config.toml
"""
```

## Additional Resources

- [Nickel Official Documentation](https://nickel-lang.org)
- [Contracts Guide](https://nickel-lang.org/user-manual/contracts/)
- [Typing Guide](https://nickel-lang.org/user-manual/typing/)
- [GitHub Repository](https://github.com/tweag/nickel)
