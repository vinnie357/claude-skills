# Nushell language basics

Data types, variables, strings, control flow, error handling, and scope rules. Load when writing non-trivial Nu logic beyond simple pipelines.

## Contents

- [Data Types](#data-types)
- [Variables](#variables)
- [String Operations](#string-operations)
- [Conditionals](#conditionals)
- [Loops](#loops)
- [Error Handling](#error-handling)
- [Scope and Bare-Word Pitfalls](#scope-and-bare-word-pitfalls)

## Data Types

### Basic Types

```nu
# Integers
42
-10

# Floats
3.14
-2.5

# Strings
"hello"
'world'

# Booleans
true
false

# Null
null
```

### Collections

```nu
# Lists
[1 2 3 4 5]
["apple" "banana" "cherry"]

# Records (like objects/dicts)
{name: "Alice", age: 30, city: "NYC"}

# Tables (list of records)
[
  {name: "Alice", age: 30}
  {name: "Bob", age: 25}
]
```

### Ranges

```nu
# Number ranges
1..10
1..2..10  # Step by 2

# Use in commands
1..5 | each { |i| $i * 2 }
```

## Variables

### Variable Assignment

```nu
# Let (immutable by default)
let name = "Alice"
let age = 30
let colors = ["red" "green" "blue"]

# Mut (mutable)
mut counter = 0
$counter = $counter + 1
```

### Using Variables

```nu
# Reference with $
let name = "Alice"
print $"Hello, ($name)!"

# In pipelines
let threshold = 1mb
ls | where size > $threshold
```

### Environment Variables

```nu
# Get environment variable
$env.PATH
$env.HOME

# Set environment variable
$env.MY_VAR = "value"

# Load from file
load-env { API_KEY: "secret" }
```

## String Operations

### String Interpolation

```nu
# String interpolation with ()
let name = "Alice"
print $"Hello, ($name)!"

# With expressions
let x = 5
print $"Result: (5 * $x)"
```

### String Methods

```nu
# Case conversion
"hello" | str upcase  # HELLO
"WORLD" | str downcase  # world

# Trimming
"  spaces  " | str trim

# Replace
"hello world" | str replace "world" "nu"

# Contains
"hello world" | str contains "world"  # true

# Split
"a,b,c" | split row ","
```

## Conditionals

### If Expressions

```nu
# If-else
if $age >= 18 {
  print "Adult"
} else {
  print "Minor"
}

# If-else if-else
if $score >= 90 {
  "A"
} else if $score >= 80 {
  "B"
} else {
  "C"
}

# Ternary-style with if as an expression
let status = if $is_active { "active" } else { "inactive" }
```

### Match (Pattern Matching)

```nu
# Match expression
match $value {
  1 => "one"
  2 => "two"
  _ => "other"
}

# With conditions
match $age {
  0..17 => "minor"
  18..64 => "adult"
  _ => "senior"
}
```

## Loops

### For Loop

```nu
# Loop over range
for i in 1..5 {
  print $i
}

# Loop over list
for name in ["Alice" "Bob" "Charlie"] {
  print $"Hello, ($name)"
}

# Loop over files
for file in (ls | where type == file) {
  print $file.name
}
```

### While Loop

```nu
# While loop
mut i = 0
while $i < 5 {
  print $i
  $i = $i + 1
}
```

### Each (Functional)

```nu
# Transform each item
1..5 | each { |i| $i * 2 }

# With index
["a" "b" "c"] | enumerate | each { |item|
  print $"($item.index): ($item.item)"
}
```

## Error Handling

### Try-Catch

```nu
# Try expression
try {
  open missing.txt
} catch {
  print "File not found"
}

# With error value
try {
  open missing.txt
} catch { |err|
  print $"Error: ($err)"
}
```

### Null Handling

```nu
# Default value
let value = ($env.MY_VAR? | default "default_value")

# Null propagation
let length = ($value | get name? | str length)
```

## Scope and Bare-Word Pitfalls

### String vs Bare Words

```nu
# Bare word (interpreted as string in some contexts)
echo hello

# Explicit string (clearer)
echo "hello"
```

### Variable Scope

```nu
# Variables are scoped to blocks
if true {
  let x = 5
}
# $x not available here

# Use mut outside for wider scope
mut x = 0
if true {
  $x = 5
}
print $x  # Works
```
