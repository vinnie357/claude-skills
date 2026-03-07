# Contract Patterns in Nickel

Common contract syntax and validation patterns for configuration schemas.

## Basic Contract Annotations

### Type Contracts with Pipe Operator

```nickel
# Single contract
value | String

# Multiple sequential contracts
value | String | SomeCustomContract
```

## Built-in Type Contracts

### Primitive Types

```nickel
# Number (arbitrary precision rational)
quantity | Number = 42

# String (UTF-8)
message | String = "hello"

# Boolean
enabled | Bool = true

# Dynamic (accepts any value, never fails)
value | Dyn = anything
```

### Array Contracts

```nickel
# Homogeneous array
numbers | Array Number = [1, 2, 3]

# Array of strings
tags | Array String = ["dev", "prod"]

# Array of records
items | Array {id: Number, name: String}
```

### Record Contracts

```nickel
# Typed record
config | {
  port: Number,
  host: String,
  debug: Bool,
}

# Open record (allows additional fields)
settings | {
  timeout: Number,
  ...,
}
```

## Custom Contract Functions

### Predicate-Based Contracts

```nickel
# Range validation
let PortNumber = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in

{
  port | PortNumber = 8080,
}
```

### Enumeration Contracts

```nickel
# Enum-like constraint
let Environment = std.contract.from_predicate (
  fun x => std.array.elem x ["dev", "staging", "prod"]
) in

{
  env | Environment = "prod",
}
```

### Custom Contract with Error Message

```nickel
let ValidEmail = fun label value =>
  if std.string.contains "@" value then
    value
  else
    std.contract.blame label
in

{
  email | ValidEmail = "user@example.com",
}
```

## Combining Contracts

### One Of Multiple Contracts

```nickel
let Port = std.contract.from_predicate (fun x => x > 1000 && x < 65535) in
let HighPort = std.contract.from_predicate (fun x => x >= 49152 && x <= 65535) in

{
  # Accept either port range
  server_port | std.contract.one_of [Port, HighPort] = 8080,
}
```

### All Of Multiple Contracts

```nickel
let IsPositive = std.contract.from_predicate (fun x => x > 0) in
let IsEven = std.contract.from_predicate (fun x => x % 2 == 0) in

{
  # Must be both positive AND even
  count | std.contract.all_of [IsPositive, IsEven] = 4,
}
```

### Negation

```nickel
let NotZero = std.contract.not (
  std.contract.from_predicate (fun x => x == 0)
) in

{
  divisor | NotZero = 5,
}
```

## Field Validation Patterns

### Nested Record Validation

```nickel
{
  database = {
    host | String = "localhost",
    port | Number = 5432,
    pool_size | Number = 10,
    credentials = {
      username | String = "admin",
      password | String = "secret",
    }
  }
}
```

### Optional Fields with Defaults

```nickel
{
  port | Number | default = 8080,
  timeout | Number | default = 30,
  log_level | String | default = "info",
}
```

### Required vs Optional

```nickel
let config = {
  # Required field
  service_name | String,

  # Optional with default
  port | Number | default = 8080,
} in

config
```

## Common Validation Patterns

### Port Number Validation

```nickel
let ValidPort = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in

{
  http_port | ValidPort = 80,
  https_port | ValidPort = 443,
  app_port | ValidPort = 8080,
}
```

### Email-like String

```nickel
let Email = fun label value =>
  if std.string.contains "@" value &&
     std.string.contains "." value then
    value
  else
    std.contract.blame label
in

{
  contact_email | Email = "admin@example.com",
}
```

### Log Level Enumeration

```nickel
let LogLevel = std.contract.from_predicate (
  fun x => std.array.elem x ["debug", "info", "warn", "error", "critical"]
) in

{
  log_level | LogLevel = "info",
  console_level | LogLevel = "warn",
}
```

### Version String Pattern

```nickel
let SemVer = fun label value =>
  let parts = std.string.split "." value in
  if std.array.length parts == 3 then
    value
  else
    std.contract.blame label
in

{
  version | SemVer = "1.2.3",
}
```

### URL String

```nickel
let URL = fun label value =>
  if std.string.starts_with "http://" value ||
     std.string.starts_with "https://" value then
    value
  else
    std.contract.blame label
in

{
  api_endpoint | URL = "https://api.example.com",
}
```

### Positive Integer

```nickel
let Positive = std.contract.from_predicate (fun x => x > 0) in

{
  max_retries | Positive = 3,
  timeout_seconds | Positive = 30,
  pool_size | Positive = 10,
}
```

### Non-Empty String

```nickel
let NonEmpty = fun label value =>
  if std.string.length value > 0 then
    value
  else
    std.contract.blame label
in

{
  app_name | NonEmpty = "my-app",
  description | NonEmpty = "Application description",
}
```

## Error Handling

### Blame for Invalid Values

```nickel
let StrictPort = fun label value =>
  if value == 8080 || value == 443 then
    value
  else
    std.contract.blame label
in

# This will error if port is not 8080 or 443
config = {
  port | StrictPort = 9000,  # Error!
}
```

### Custom Error Context

```nickel
let ValidHTTPStatus = fun label value =>
  if (value >= 100 && value < 600) then
    value
  else
    std.contract.blame (
      label ++ ": HTTP status codes must be 100-599"
    )
in

{
  status_code | ValidHTTPStatus = 200,
}
```

## Complex Schema Examples

### Database Connection Schema

```nickel
let DBPort = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in

let DBType = std.contract.from_predicate (
  fun x => std.array.elem x ["postgres", "mysql", "sqlite"]
) in

{
  type | DBType,
  host | String,
  port | DBPort,
  database | String,
  username | String,
  password | String,
  pool = {
    min_size | Number = 1,
    max_size | Number = 10,
  }
}
```

### API Server Configuration

```nickel
let ValidPort = std.contract.from_predicate (
  fun x => x >= 1 && x <= 65535
) in

let LogLevel = std.contract.from_predicate (
  fun x => std.array.elem x ["debug", "info", "warn", "error"]
) in

{
  name | String,
  server = {
    host | String = "localhost",
    port | ValidPort = 8080,
    timeout_seconds | Number = 30,
  },
  logging = {
    level | LogLevel = "info",
    format | String = "json",
  },
  features = {
    auth | Bool = true,
    cors | Bool = true,
    compression | Bool = true,
  }
}
```
