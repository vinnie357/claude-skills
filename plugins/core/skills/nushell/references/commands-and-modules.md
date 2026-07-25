# Nushell custom commands, modules, and configuration

Defining commands with typed parameters and flags, organizing modules, script files, and configuring the Nu environment. Load when authoring reusable Nu commands, script entry points, or config.nu/env.nu.

## Contents

- [Custom Commands](#custom-commands)
- [Modules](#modules)
- [Script Files](#script-files)
- [Configuration](#configuration)

## Custom Commands

### Defining Commands

```nu
# Simple command
def greet [name: string] {
  print $"Hello, ($name)!"
}

greet "Alice"

# With return value
def add [a: int, b: int] {
  $a + $b
}

let result = add 5 3

# With default values
def greet [name: string = "World"] {
  print $"Hello, ($name)!"
}
```

### Command Parameters

```nu
# Required parameters
def copy [source: path, dest: path] {
  cp $source $dest
}

# Optional parameters
def greet [
  name: string
  --loud (-l)  # Flag
  --repeat (-r): int = 1  # Named parameter with default
] {
  let message = if $loud {
    $name | str upcase
  } else {
    $name
  }

  1..$repeat | each { print $"Hello, ($message)!" }
}

# Usage
greet "Alice"
greet "Bob" --loud
greet "Charlie" --repeat 3
```

### Pipeline Commands

```nu
# Accept pipeline input
def filter-large [] {
  where size > 1mb
}

# Usage
ls | filter-large

# Accept and transform pipeline
def double [] {
  each { |value| $value * 2 }
}

[1 2 3] | double
```

## Modules

### Creating Modules

```nu
# utils.nu
export def greet [name: string] {
  print $"Hello, ($name)!"
}

export def add [a: int, b: int] {
  $a + $b
}
```

### Using Modules

```nu
# Import module
use utils.nu

# Use exported commands
utils greet "Alice"
utils add 5 3

# Import specific commands
use utils.nu [greet add]

greet "Alice"
add 5 3

# Import with alias
use utils.nu *
```

## Script Files

`def main` is the script entry point — Nushell auto-invokes it when the script runs via `nu script.nu`. The double-invocation gotcha (a bare `main` line at the end of the file) is covered in the SKILL.md body.

```nu
#!/usr/bin/env nu

# Script: process_logs.nu
# Description: Process log files and generate report

def main [log_dir: path] {
  let errors = (
    ls $"($log_dir)/*.log"
    | each { |file| open $file.name | lines }
    | flatten
    | where $it =~ "ERROR"
  )

  print $"Found ($errors | length) errors"
  $errors | save error_report.txt
}
```

Make executable:
```bash
chmod +x process_logs.nu
./process_logs.nu /var/log
```

### Script Parameters

`def main` parameters become the script's CLI arguments and flags:

```nu
# With parameters
def main [
  input: path
  --output (-o): path = "output.txt"
  --verbose (-v)
] {
  if $verbose {
    print $"Processing ($input)..."
  }

  let data = open $input
  $data | save $output

  if $verbose {
    print "Done!"
  }
}
```

## Configuration

### Config File Location

```nu
# View config
config nu

# Edit config
config nu | open

# Config location
$nu.config-path
```

### Common Configurations

```nu
# config.nu
$env.config = {
  show_banner: false

  ls: {
    use_ls_colors: true
    clickable_links: true
  }

  table: {
    mode: rounded
    index_mode: auto
  }

  completions: {
    quick: true
    partial: true
  }

  history: {
    max_size: 10000
    sync_on_enter: true
    file_format: "sqlite"
  }
}
```

### Environment Setup

```nu
# env.nu
$env.PATH = ($env.PATH | split row (char esep) | append '/custom/bin')
$env.EDITOR = "nvim"

# Load completions
use completions/git.nu *
```
