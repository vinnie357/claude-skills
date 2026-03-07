---
name: topiary
description: "Universal code formatter leveraging Tree-sitter queries. Use when formatting code in languages without dedicated formatters, writing custom .scm query files, or configuring Topiary via languages.ncl."
license: MIT
---

# Topiary

Topiary is a universal code formatter that uses Tree-sitter grammars and queries to define formatting rules. Rather than implementing language-specific formatting logic, Topiary uses declarative Tree-sitter query files (.scm) to specify how code should be formatted.

## When to Use This Skill

Activate this skill when:
- Formatting code in languages without dedicated formatters (JSON, TOML, Bash, Nickel, OCaml, OCamllex, CSS, OpenSCAD, SDML, WIT, or custom languages)
- Writing or debugging Tree-sitter query files (.scm)
- Configuring Topiary via languages.ncl for custom languages or indentation settings
- Setting up Topiary as part of a development workflow or CI/CD pipeline
- Learning Tree-sitter query syntax for code analysis

## Key Concepts

### Tree-Sitter Queries

Tree-sitter is a parser generator that creates language parsers from grammar definitions. Topiary uses Tree-sitter queries to analyze code structures and apply formatting rules. Queries match patterns in the syntax tree using S-expression syntax and decorate matched nodes with capture names (prefixed with `@`) that describe formatting actions.

### Query Files and Capture Names

Language formatting is defined in `.scm` (Scheme) query files. Each capture name instructs Topiary how to format the matched node:

- **Line breaks**: `@prepend_hardline`, `@append_hardline` (always insert newline), `@prepend_empty_softline`, `@append_empty_softline` (newline or nothing), `@prepend_spaced_softline`, `@append_spaced_softline` (newline or space)
- **Indentation**: `@prepend_indent_start`, `@append_indent_start`, `@prepend_indent_end`, `@append_indent_end` (mark indentation scopes)
- **Spacing**: `@prepend_space`, `@append_space` (add single space)
- **Control**: `@delete` (remove matched node), `@do_nothing` (suppress default behavior), `@leaf` (prevent formatting within node)
- **Input-aware**: `@prepend_input_softline`, `@append_input_softline` (preserve original line break presence)

### Idempotency

Topiary formatting is idempotent—running the formatter repeatedly on already-formatted code produces identical output. This guarantee allows safe integration into version control hooks and CI pipelines.

### Author Intent Preservation

Topiary respects the structural intent of code by preserving language-specific semantics. It focuses on whitespace, indentation, and line breaks rather than restructuring code. This approach works especially well with languages whose semantics are simple and whitespace-independent.

## Installation

### Via Mise

Add Topiary to your `mise.toml`:

```toml
[tools]
topiary = "latest"

[tasks]
fmt = "topiary fmt"
fmt:check = "topiary fmt --check"
```

### Via Cargo

Install directly from crates.io:

```bash
cargo install topiary-cli
```

### Verify Installation

Check the installed version and available languages:

```bash
topiary --version
topiary config show-sources
```

## CLI Usage

### Format Files

Format files in place by detected file extension:

```bash
topiary fmt src/main.ml
topiary fmt config.json
topiary fmt *.toml
```

Add `--check` to verify formatting without modifications:

```bash
topiary fmt --check src/
```

### Format Standard Input

Format piped input by specifying language and optional query file:

```bash
echo '{"name":"example"}' | topiary format --language json
cat script.sh | topiary format --language bash
```

### Visualize Parse Trees

Use `visualise` to debug queries by inspecting the syntax tree:

```bash
topiary visualise script.json
topiary visualise --language bash script.sh
```

This outputs the Tree-sitter parse tree, useful for understanding node structure when writing `.scm` queries.

### Query Configuration

Override the default query file for a language:

```bash
topiary fmt --language nickel --query custom.scm script.ncl
```

### Show Current Configuration

Display the active configuration including registered languages and indentation settings:

```bash
topiary config show-sources
```

## Configuration

### languages.ncl Format

Create a `.topiary/languages.ncl` file in your project root to customize language registration, indentation, and grammar sources. This file uses Nickel syntax:

```nickel
{
  languages = {
    json = {
      extensions = ["json"],
      indent = "  ",
    },
    bash = {
      extensions = ["sh", "bash"],
      indent = "  ",
    }
  }
}
```

### Configuration Search Order

Topiary searches for configuration in this order (first found wins):
1. `--configuration` CLI argument
2. `.topiary/languages.ncl` in current directory or parent directories
3. User configuration directory (OS-specific): `~/.config/topiary/languages.ncl` (Linux), `~/Library/Application Support/topiary/languages.ncl` (macOS), `%APPDATA%\topiary\languages.ncl` (Windows)
4. Built-in defaults compiled into Topiary

### Custom Grammar Sources

Register custom Tree-sitter grammars by specifying Git source or local path:

```nickel
{
  languages = {
    my-lang = {
      extensions = ["ml"],
      grammar.source.git = {
        git = "https://github.com/example/tree-sitter-my-lang",
        rev = "abc123def456"
      }
    }
  }
}
```

Or reference a pre-compiled grammar on disk:

```nickel
{
  languages = {
    my-lang = {
      extensions = ["ml"],
      grammar.source.path = "./grammars/my-lang.so"
    }
  }
}
```

## Adding Custom Languages

Add formatting support for new languages by following these steps:

### Step 1: Register the Grammar

Create `.topiary/languages.ncl` in your project with the grammar source:

```nickel
{
  languages = {
    my-lang = {
      extensions = ["ml"],
      indent = "  ",
      grammar.source.git = {
        git = "https://github.com/my-org/tree-sitter-my-lang",
        rev = "main"
      }
    }
  }
}
```

Verify the grammar source URL points to a valid Tree-sitter grammar repository.

### Step 2: Create Query File

Create `.topiary/queries/my-lang.scm` with formatting rules. Start minimal:

```scm
; Format binary operators with surrounding spaces
((binary_op) @op
 (#match? @op "^(+|-|=)$"))
@prepend_space
@append_space

; Hard line after statements
((statement) @stmt)
@append_hardline
```

Use `topiary visualise` to inspect the parse tree and understand node names and structure.

### Step 3: Test Formatting

Test the formatter on sample files:

```bash
topiary fmt --language my-lang test-file.ml
topiary visualise --language my-lang test-file.ml
```

Iterate on the query file until formatting behaves as expected. Run `topiary fmt` on actual code to verify formatting is idempotent (run twice, should produce identical output).

## Writing Formatting Queries

### Query Syntax Overview

Tree-sitter queries use S-expression syntax. A basic query matches nodes and captures them:

```scm
; Match a function definition and capture its name
(function_def
  name: (identifier) @func-name)
```

The `@func-name` is a capture; `function_def`, `name`, and `identifier` are node types. Field names like `name:` link to specific children.

### Common Capture Patterns

Format operators with spaces on both sides:

```scm
((binary_op operator: _ @op))
@prepend_space
@append_space
```

Indent function bodies:

```scm
(function_def
  body: (block) @body)
@append_indent_start
@prepend_indent_end
```

Insert line breaks between statements:

```scm
((statement) @stmt)
@append_hardline
```

Preserve input line breaks (single line or multi-line lists):

```scm
(list
  "[" @open
  _ @item
  "]" @close)
@append_spaced_softline
```

### Predicates and Matching

Use predicates to refine matches:

```scm
; Match only specific operators
((binary_op operator: _ @op)
 (#match? @op "^(=|==|!=)$"))
@prepend_space
@append_space

; Match nodes that are NOT in comments
((statement) @stmt
 (#not-eq? @stmt comment))
```

Available predicates: `#match?` (regex), `#eq?` (equality), `#not-eq?` (inequality).

## Supported Languages

### Official Languages

Topiary actively maintains formatting for:
- **Bash** - Shell scripting
- **JSON** - Data serialization
- **Nickel** - Configuration language
- **OCaml** - Functional programming (implementations and interfaces)
- **OCamllex** - Lexer definitions
- **TOML** - Configuration file format
- **Tree-sitter Queries** - Query file formatting

### Community-Contributed Languages

External maintainers provide formatters for:
- **CSS** - Stylesheets
- **OpenSCAD** - 3D modeling language
- **SDML** - Semantic Data Modeling Language
- **WIT** - WebAssembly Interface Types

### Language Limitations

Topiary works best with languages where formatting is independent of semantics. Whitespace-sensitive languages (Python, Haskell) present challenges and are not officially supported, as formatting changes could alter code meaning.

## Mise Task Examples

Define formatting tasks in `mise.toml`:

```toml
[tasks.fmt]
description = "Format all code"
run = """
topiary fmt src/
"""

[tasks.fmt:check]
description = "Check formatting without modifying"
run = """
topiary fmt --check src/
"""

[tasks.fmt:debug]
description = "Visualize parse tree for debugging"
run = """
topiary visualise {file}
"""
```

Run tasks with:

```bash
mise run fmt
mise run fmt:check
mise run fmt:debug -- script.ncl
```

## Anti-Fabrication Note

Before claiming that Topiary formats a language or query correctly, verify behavior by running `topiary fmt` on actual code files and inspecting the output. Do not assume query behavior without testing; use `topiary visualise` to inspect the parse tree and confirm node names and structure match the query. Test idempotency by running the formatter twice and confirming output is identical.
