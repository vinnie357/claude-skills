---
name: nushell
description: Guide for using Nushell for structured data pipelines and scripting. Use when writing shell scripts, processing structured data, or working with cross-platform automation.
---

# Nushell - Modern Structured Shell

This skill activates when working with Nushell (Nu), writing Nu scripts, working with structured data pipelines, or configuring the Nu environment.

## What is Nushell?

Current stable: 0.113.1 (pre-1.0, breaking changes possible between minor versions)

Nushell is a modern shell that:
- Treats **data as structured** (not just text streams)
- Works **cross-platform** (Windows, macOS, Linux)
- Combines **shell and programming language** features
- Has **built-in data format support** (JSON, CSV, YAML, TOML, XML, etc.)

## When Nushell over bash

- **Nushell for scripts**: any multi-line script, structured-data pipeline, or cross-platform automation. Bash one-liners with `grep`/`awk`/`sed` chains lose type information Nu keeps.
- **`jq` for JSON one-liner parsing** in bash contexts; Nu's `open`/`from json`/`where`/`get` replace `jq` inside Nu scripts.
- Bash remains for shell-only operations with no Nu alternative, and for embedded commands inside CI runners that only speak POSIX shell.

## Installation

```bash
# Via mise (recommended for project-level management)
# mise.toml: [tools] → "github:nushell/nushell" = "latest"
mise install github:nushell/nushell

# macOS: brew install nushell | Linux: cargo install nu | Windows: winget install nushell
```

## Core model: everything is structured data

Commands output tables/records, not text. Pipelines transform structured data stage by stage:

```nu
# Bash greps text; Nu filters columns
ls | where name =~ ".txt"
ls | where size > 1kb and type == file | sort-by modified | reverse

# Read/write structured formats directly
open data.json | get users | where age > 25 | select name email
open data.csv | to json | save data.json
'{"name": "Alice"}' | from json
```

## Syntax essentials

```nu
# Variables: let (immutable), mut (mutable), $env for environment
let threshold = 1mb
mut counter = 0
$counter = $counter + 1
$env.MY_VAR = "value"

# String interpolation: $"..." with parens for expressions
let name = "Alice"
print $"Hello, ($name)! Result: (5 * 2)"

# Collections: lists, records, tables
let users = [{name: "Alice", age: 30} {name: "Bob", age: 25}]
$users | where age > 25 | get name

# Control flow: if/else and match are expressions
let status = if $is_active { "active" } else { "inactive" }
match $age {
  0..17 => "minor"
  _ => "adult"
}

# Iteration: each (functional), for (imperative)
1..5 | each { |i| $i * 2 }
for file in (ls | where type == file) { print $file.name }

# Custom commands: typed params, flags with defaults
def greet [
  name: string
  --loud (-l)            # Flag
  --repeat (-r): int = 1 # Named parameter with default
] {
  1..$repeat | each { print $"Hello, ($name)!" }
}

# Error handling
try { open missing.txt } catch { |err| print $"Error: ($err)" }
let value = ($env.MY_VAR? | default "fallback")

# HTTP built in
http get https://api.example.com/users
http post https://api.example.com/users {name: "Alice"}
```

## Scripts and `def main`

`nu script.nu` **auto-invokes `def main`** when the script defines one. `main`'s parameters become the script's CLI arguments and flags:

```nu
#!/usr/bin/env nu
def main [
  input: path
  --output (-o): path = "output.txt"
  --verbose (-v)
] {
  if $verbose { print $"Processing ($input)..." }
  open $input | save $output
}
```

Run as `nu script.nu data.csv --verbose` or `chmod +x script.nu && ./script.nu data.csv`.

## Critical gotchas

These have each caused real script failures. Check every Nu script against them.

### No `2>&1` — use `out+err>`

Bash-style file-descriptor redirection does not exist in Nushell. `2>&1` is not parsed as redirection. Use `out+err> file.log` (short form `o+e>`) to capture both streams:

```nu
# WRONG — nushell does not speak 2>&1
^some-command > out.log 2>&1

# CORRECT
^some-command out+err> out.log
```

Audit existing scripts with `grep -rn '2>&1' **/*.nu`.

### Bare `main` call after `def main` runs main TWICE

Because `nu script.nu` auto-invokes `def main`, a script that defines `def main` AND has a bare `main` line at the end runs `main` **twice**, silently doubling every side effect (HTTP posts, file writes, subprocess spawns, workflow submissions).

```nu
# WRONG — fires main twice
def main [] {
  http post $url $body
  print "done"
}

main  # ← Nushell already invoked this; the explicit call duplicates work
```

```nu
# CORRECT — Nushell handles the invocation
def main [] {
  http post $url $body
  print "done"
}
# (no bare `main` line — script ends with the def)
```

**Why it matters:** silent duplication is hard to debug. The classic symptom is "this single-step workflow somehow fired two HTTP requests." Confirmed via instrumented print counters: the file parses once but the `main` entry counter increments twice.

**Detection:** `grep -nE '^main(\s|$)' script.nu` flags any bare invocations at column 0. Add this as a CI lint rule for repos that contain multiple Nushell scripts — chained workflows multiply the impact (each chain hop doubles the next).

### External commands need the `^` prefix

```nu
# Wrong - Nu tries to parse as Nu command
ls -la

# Right - Explicitly call external command
^ls -la

# Capture output
let output = (^git status)
```

### Parens in string interpolation parse as expressions

`$"hello (world)"` tries to evaluate `world` as an expression. Escape the parens or lift the value into a variable first.

## Key principles

- **Structured data first**: think in tables and records, not text; leverage `where`/`select`/`get` over regex
- **Pipeline composition**: chain simple stages to build complex workflows
- **Type annotations**: add types to custom command parameters
- **Error handling**: use try-catch for operations that can fail
- **Modules for reuse**: organize shared commands in modules (`export def` + `use`)
- **Cross-platform**: same syntax works in REPL and scripts on all platforms

## References

- `references/language-basics.md` — data types, ranges, variables/env, string methods, conditionals, loops, try-catch and null handling, variable-scope and bare-word pitfalls
- `references/data-pipelines.md` — file/directory operations, filtering/selecting/sorting/transforming/aggregation, JSON/CSV/YAML/TOML round-trips, table queries, worked patterns (batch file processing, data transformation, HTTP, system commands)
- `references/commands-and-modules.md` — custom command definitions and parameter forms, pipeline-input commands, modules, script files and `def main` parameters, config.nu/env.nu setup
- `references/bash-migration.md` — side-by-side bash-to-Nu translations, redirection mapping
- `references/shell-interop.md` "Runex HTTP API response shape via nushell" — `.data` unwrap pattern, INT-to-string coercion for IDs, terminal-status set, `$env.HOME`, parens-in-interpolation, `sort-by -r` instability, `out+err>` instead of `2>&1`
- `references/shell-interop.md` "Bash logical-operator silent error mask" — `cmd1 && cmd2 || cmd3` is NOT if/else; use `if/else` to propagate exit codes; detection grep for the pattern
