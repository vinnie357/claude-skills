# Language-Specific Considerations

Per-language checklist items to check in addition to the general Code Review Checklist. Load the language's own style skill (e.g. `/elixir:style`) for anything this skill doesn't cover.

## Elixir

- Pattern matching is used effectively
- Functions leverage pipe operator for readability
- Atoms aren't created dynamically from untrusted input
- `with` statements handle errors properly
- Changesets validate all input
- No direct database queries in controllers/LiveViews (use contexts)

## JavaScript/TypeScript

- Types are properly defined (TypeScript)
- Promises are handled with .catch() or try/catch
- == vs === is used correctly
- Arrays/objects aren't mutated unexpectedly
- this binding is correct
- Async operations are properly awaited

## Python

- Type hints are used
- List comprehensions aren't overly complex
- Exceptions are specific (not bare except:)
- Resources are closed (use with statements)
- Code follows PEP 8

## Rust

- Ownership and borrowing are correct
- Error handling uses Result/Option properly
- Unsafe blocks are justified and minimal
- Clone/copy is used appropriately
- Lifetimes are correctly specified
