# Nushell data pipelines

File operations, pipeline transformations, structured data formats, and worked pipeline patterns. Load when processing JSON/CSV/YAML/TOML, transforming tables, or building multi-stage pipelines.

## Contents

- [Working with Files and Directories](#working-with-files-and-directories)
- [Pipeline Operations](#pipeline-operations)
- [Structured Data Formats](#structured-data-formats)
- [Working with Tables](#working-with-tables)
- [Common Patterns](#common-patterns)

## Working with Files and Directories

### Navigation

```nu
# Change directory
cd /path/to/dir

# List files (returns structured table)
ls

# List with details
ls | select name size modified

# Filter files
ls | where type == file
ls | where size > 1mb
ls | where name =~ "\.txt$"
```

### File Operations

```nu
# Create file
"hello" | save hello.txt

# Read file
open hello.txt

# Append to file
"world" | save -a hello.txt

# Copy
cp source.txt dest.txt

# Move/rename
mv old.txt new.txt

# Remove
rm file.txt
rm -r directory/

# Create directory
mkdir new-dir
```

### File Content

```nu
# Read as string
open file.txt

# Read structured data
open data.json
open config.toml
open data.csv

# Write structured data
{name: "Alice", age: 30} | to json | save user.json
[{a: 1} {a: 2}] | to csv | save data.csv
```

## Pipeline Operations

### Filtering

```nu
# Filter with where
ls | where size > 1mb
ls | where type == dir
ls | where name =~ "test"

# Multiple conditions
ls | where size > 1kb and type == file
```

### Selecting Columns

```nu
# Select specific columns
ls | select name size

# Rename columns
ls | select name size | rename file bytes
```

### Sorting

```nu
# Sort by column
ls | sort-by size
ls | sort-by modified

# Reverse sort
ls | sort-by size | reverse

# Multiple columns
ls | sort-by type size
```

### Transforming Data

```nu
# Map over items with each
1..5 | each { |i| $i * 2 }

# Update column
ls | update name { |row| $row.name | str upcase }

# Insert column
ls | insert size_kb { |row| $row.size / 1000 }

# Upsert (update or insert)
ls | upsert type_upper { |row| $row.type | str upcase }
```

### Aggregation

```nu
# Count items
ls | length

# Sum
[1 2 3 4 5] | math sum

# Average
[1 2 3 4 5] | math avg

# Min/Max
ls | get size | math max
ls | get size | math min

# Group by
ls | group-by type
```

## Structured Data Formats

### JSON

```nu
# Read JSON
let data = open data.json

# Parse JSON string
let obj = '{"name": "Alice", "age": 30}' | from json

# Write JSON
{name: "Alice", age: 30} | to json | save user.json

# Pretty print JSON
{name: "Alice", age: 30} | to json -i 2
```

### CSV

```nu
# Read CSV
let data = open data.csv

# Convert to CSV
[{a: 1, b: 2} {a: 3, b: 4}] | to csv

# Save CSV
ls | select name size | to csv | save files.csv
```

### YAML/TOML

```nu
# Read YAML
let config = open config.yaml

# Read TOML
let config = open config.toml

# Write YAML
{key: "value"} | to yaml | save config.yaml

# Write TOML
{key: "value"} | to toml | save config.toml
```

## Working with Tables

```nu
# Create table
let users = [
  {name: "Alice", age: 30, city: "NYC"}
  {name: "Bob", age: 25, city: "LA"}
  {name: "Charlie", age: 35, city: "NYC"}
]

# Query table
$users | where age > 25
$users | where city == "NYC"
$users | select name age

# Add column
$users | insert country { "USA" }

# Group and count
$users | group-by city | transpose city users
```

## Common Patterns

### File Processing

```nu
# Process all JSON files
ls *.json | each { |file|
  let data = open $file.name
  print $"Processing ($file.name): ($data | length) items"
}

# Batch rename files
ls *.txt | each { |file|
  let new_name = ($file.name | str replace ".txt" ".md")
  mv $file.name $new_name
}
```

### Data Transformation

```nu
# CSV to JSON
open data.csv | to json | save data.json

# Filter and transform
open users.json
| where active == true
| select name email
| to csv
| save active_users.csv

# Merge data
let users = open users.json
let orders = open orders.json
$users | merge $orders
```

### HTTP Requests

```nu
# GET request
http get https://api.example.com/users

# POST request
http post https://api.example.com/users {
  name: "Alice"
  email: "alice@example.com"
}

# With headers
http get -H [Authorization "Bearer token"] https://api.example.com/data
```

### System Commands

```nu
# Run external command
^ls -la

# Capture output
let output = (^git status)

# Check if command exists
which git

# Get command path
which git | get path
```
