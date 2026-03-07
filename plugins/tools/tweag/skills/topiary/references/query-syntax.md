# Tree-Sitter Query Syntax for Topiary

This document covers the S-expression query syntax used by Topiary to match code patterns and apply formatting rules.

## S-Expression Basics

Tree-sitter queries use S-expressions (symbolic expressions) to describe patterns in the parse tree.

### Node Matching

Match a specific node type:

```scm
(function_def)
```

Match nested structures:

```scm
(function_def
  name: (identifier))
```

Match anonymous nodes (literal tokens):

```scm
(binary_op
  operator: "=")
```

### Field Names

Use field names to match specific children:

```scm
(function_def
  name: (identifier) @func_name
  parameters: (parameter_list) @params
  body: (block) @body)
```

Field names vary by language grammar. Use `topiary visualise` to inspect the parse tree and identify field names for your language.

### Optional Matches

The `?` operator matches zero or one occurrence:

```scm
(function_def
  name: (identifier)?
  parameters: (parameter_list))
```

### Wildcards

Match any child node:

```scm
(function_call
  function: _
  arguments: _)
```

## Capture Names and Formatting Effects

Topiary recognizes specific capture names that instruct how to format matched nodes. Attach captures to nodes using `@capture_name` syntax.

### Hardline Captures

Force a line break before or after the matched node:

- **`@prepend_hardline`** — Insert newline before node (always)
- **`@append_hardline`** — Insert newline after node (always)

Hardlines are rendered regardless of context. Use for statements, function definitions, or structure boundaries that should always be on separate lines.

**Example:**

```scm
((statement) @stmt)
@append_hardline
```

### Softline Captures

Conditionally insert line breaks based on context.

#### Empty Softlines

- **`@prepend_empty_softline`** — Nothing (single-line) or newline (multi-line)
- **`@append_empty_softline`** — Nothing (single-line) or newline (multi-line)

Use for optional breaks that disappear on single-line constructs.

**Example:**

```scm
(list
  "[" @open
  _ @item
  "]" @close)
@append_empty_softline
```

#### Spaced Softlines

- **`@prepend_spaced_softline`** — Space (single-line) or newline (multi-line)
- **`@append_spaced_softline`** — Space (single-line) or newline (multi-line)

Use for separators (commas, operators) that should have spacing on single-line, but line breaks on multi-line.

**Example:**

```scm
(list
  "," @comma)
@append_spaced_softline
```

#### Input Softlines

- **`@prepend_input_softline`** — Preserves whether input had line break before
- **`@append_input_softline`** — Preserves whether input had line break after

Use to respect author formatting choices while normalizing spacing.

**Example:**

```scm
(record
  ";" @semicolon)
@append_input_softline
```

### Indentation Captures

Mark scope boundaries where indentation increases or decreases.

- **`@prepend_indent_start`** — Increase indent before matched node
- **`@append_indent_start`** — Increase indent after matched node
- **`@prepend_indent_end`** — Decrease indent before matched node
- **`@append_indent_end`** — Decrease indent after matched node

Indentation applies from the capture point until the corresponding `_end` is reached. If start and end occur on the same line, indentation has no effect (safe to use in single-line constructs).

**Example:**

```scm
(function_def
  body: (block
    "{" @open
    _ @contents
    "}" @close))
@append_indent_start
@prepend_indent_end
```

All lines after `@append_indent_start` are indented until `@prepend_indent_end` is encountered.

### Spacing Captures

Insert spaces around matched nodes:

- **`@prepend_space`** — Insert single space before node
- **`@append_space`** — Insert single space after node

Use for operators, keywords, and separators that require spacing.

**Example:**

```scm
((binary_op operator: _ @op)
 (#match? @op "^(=|==|!=|<|>)$"))
@prepend_space
@append_space
```

### Control Captures

Control formatting behavior:

- **`@delete`** — Remove the matched node entirely
- **`@do_nothing`** — Suppress default formatting for matched node
- **`@leaf`** — Prevent formatting within the node (treat as atomic unit)

**Example - Delete extra spaces:**

```scm
(whitespace) @ws
@delete
```

**Example - Prevent formatting in strings:**

```scm
(string) @str
@leaf
```

**Example - Suppress default behavior:**

```scm
(comment) @comment
@do_nothing
```

## Predicates

Refine query matches using predicates that evaluate conditions.

### Regex Matching

`#match? @capture "pattern"` — Match capture against regex pattern:

```scm
((binary_op operator: _ @op)
 (#match? @op "^(+|-|\\*|/)$"))
@prepend_space
@append_space
```

### Equality

`#eq? @capture "text"` — Match capture against exact string:

```scm
(binary_op
  operator: "=" @assign)
#eq? @assign "="
```

### Inequality

`#not-eq? @capture "text"` — Match if capture does NOT equal string:

```scm
((node) @n
 (#not-eq? @n "/*"))
```

## Common Formatting Patterns

### Function Definition Indentation

```scm
(function_def
  name: (identifier) @func_name
  body: (block) @body)
@append_hardline
```

Then handle the block body with indentation:

```scm
(block
  "{" @open
  _ @content
  "}" @close)
@append_indent_start
@prepend_indent_end
```

### List and Array Formatting

```scm
(list
  "[" @open
  _ @item
  "," @comma
  "]" @close)
@append_empty_softline
```

With indentation for multi-line:

```scm
(list
  "[" @open
  "]" @close)
@append_indent_start
@prepend_indent_end
```

### Record and Object Formatting

```scm
(record
  "{" @open
  (field) @field
  "," @comma
  "}" @close)
@append_hardline
```

Field-level spacing:

```scm
(field
  key: _ @key
  ":" @colon
  value: _ @value)
@prepend_space
@append_space
```

### Comma Handling

Keep commas attached to preceding element, with spacing after:

```scm
(list
  "," @comma)
@delete

(list
  _ @item
  (",")?
  _ @next)
@append_spaced_softline
```

Or use simple approach:

```scm
("," @comma)
@append_spaced_softline
```

### Comment Preservation

Prevent formatting changes in comments:

```scm
(comment) @comment
@leaf
```

Or allow spacing around comments:

```scm
(comment) @comment
@prepend_hardline
@append_hardline
```

## Debugging Queries

Use `topiary visualise` to inspect the parse tree and understand node structure:

```bash
topiary visualise code.json
topiary visualise --language bash script.sh
```

The output shows:

```
root
 source_file
  statement
   function_def
    keyword: def
    name: identifier "my_func"
    parameters: ...
```

Compare this structure against your query patterns. Adjust field names, node types, and captures based on the actual parse tree output.

## Resources

- [Topiary Query Reference](https://topiary.tweag.io/book/reference/capture-names/index.html)
- [Tree-sitter Queries Documentation](https://tree-sitter.github.io/tree-sitter/using-parsers#query-syntax)
- [Topiary Tutorial Part 1](https://www.tweag.io/blog/2025-01-30-topiary-tutorial-part-1/)
