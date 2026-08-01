---
name: documentation
description: Guide for writing technical documentation. Use when creating README files, API documentation, guides, or inline code documentation.
---

# Technical Documentation Writing

This skill activates when writing or improving technical documentation, including README files, API documentation, user guides, and inline code documentation.

## When to Use This Skill

Activate when:
- Writing README files
- Creating API documentation
- Writing user guides or tutorials
- Documenting code with comments or docstrings
- Creating architecture or design documents
- Writing changelogs or release notes

## Anti-fabrication

This skill follows `core:anti-fabrication`. Most of it is house convention — README
structure, ADR templates, changelog format, comment style — not claims that can go stale
against an upstream. The one real claim area is the "Documentation Tools" section's
generator commands (`mix docs` for ExDoc, `cargo doc` for rustdoc, Sphinx, MkDocs, JSDoc,
TypeDoc): verify the invocation against the tool's current docs before asserting it,
rather than repeating it from memory — these are stable but not immune to CLI changes.

## README Files

### Essential README Structure

Every README should cover: overview, features, installation, quick start, usage, configuration, API reference, development setup, contributing, license, acknowledgments, and support. A complete worked template with all these sections: [references/templates.md](references/templates.md).

### README Best Practices

- **Start with a clear one-liner**: Immediately tell readers what the project does
- **Include badges**: Build status, coverage, version, license
- **Show, don't tell**: Use code examples liberally
- **Keep it scannable**: Use headers, lists, and code blocks
- **Make examples runnable**: Readers should be able to copy-paste and run
- **Include visual aids**: Screenshots, diagrams, GIFs when appropriate
- **Update regularly**: Keep documentation in sync with code
- **Think about newcomers**: Write for someone seeing the project for the first time

## API Documentation

Document functions with language-native doc comments (Elixir `@doc`/`@spec`, JSDoc, Python docstrings, Rust doc comments), document modules/classes with their purpose and public API, and document REST endpoints with method, auth, request/response bodies, and error responses. Worked examples for all three: [references/api-documentation.md](references/api-documentation.md).

## User Guides and Tutorials

### Tutorial Structure

```markdown
# Tutorial: Building Your First [Feature]

## What You'll Build

Brief description of the end result.

## Prerequisites

- Knowledge requirement 1
- Installed tool 1
- Account/access requirement

## Step 1: [First Major Step]

Explanation of what we're doing and why.

```language
// Code for this step
```

**What's happening here:**
- Explanation of key line 1
- Explanation of key line 2

## Step 2: [Next Step]

Continue with incremental steps...

## Testing

How to verify it works.

## Next Steps

- Related tutorial 1
- Advanced topic 1
- Further reading
```

### Tutorial Best Practices

- **Show working code first**: Let readers see the goal before diving into details
- **Explain the 'why'**: Don't just show what to do, explain reasoning
- **Incremental steps**: Each step should build on the previous
- **Include checkpoints**: Ways to verify progress
- **Provide complete code**: Include a repository or final code snippet
- **Anticipate problems**: Address common mistakes
- **Link to references**: Point to relevant API docs and resources

## Inline Code Documentation

### When to Write Comments

**DO write comments for:**
- Complex algorithms or business logic
- Non-obvious decisions ("why" not "what")
- Workarounds for bugs or limitations
- Public APIs and exported functions
- Configuration and constants

**DON'T write comments for:**
- Obvious code
- What the code does (prefer clear naming)
- Outdated information
- Commented-out code (use version control)

### Good Comment Examples

```elixir
# Good: Explains WHY
# Use exponential backoff to avoid overwhelming the API after rate limit errors
defp retry_with_backoff(attempt) do
  :timer.sleep(:math.pow(2, attempt) * 1000)
end

# Bad: Explains WHAT (obvious from code)
# Multiply 2 to the power of attempt and multiply by 1000
defp retry_with_backoff(attempt) do
  :timer.sleep(:math.pow(2, attempt) * 1000)
end

# Good: Documents workaround
# NOTE: Using String.to_existing_atom because the Erlang VM limits atoms to ~1M.
# All valid status atoms are pre-defined in this module.
def parse_status(status_string) do
  String.to_existing_atom(status_string)
end

# Good: Explains business rule
# Users must be at least 13 years old per COPPA regulations
@minimum_age 13
```

## Architecture Documentation

### Architecture Decision Records (ADR)

Document significant architectural decisions:

```markdown
# ADR 001: Use PostgreSQL for Primary Database

## Status

Accepted

## Context

We need to choose a database for our application that supports:
- ACID transactions
- Complex queries with joins
- JSON data storage
- Full-text search
- Horizontal scalability (future requirement)

## Decision

We will use PostgreSQL as our primary database.

## Consequences

### Positive

- Mature, stable, well-documented
- Excellent JSON support with JSONB
- Built-in full-text search
- Strong consistency guarantees
- Large ecosystem of tools and extensions
- Can scale with read replicas and partitioning

### Negative

- More complex to operate than simpler databases
- Vertical scaling has limits (though sufficient for our needs)
- Requires more server resources than lighter alternatives

### Neutral

- Team needs to learn PostgreSQL-specific features
- May need to hire PostgreSQL expertise as we scale

## Alternatives Considered

- **MySQL**: Weaker JSON support, less feature-rich
- **MongoDB**: No ACID guarantees, eventual consistency issues
- **SQLite**: Not suitable for multi-user web applications
```

## Changelog Documentation

Follow Keep a Changelog format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- New feature in development

## [1.2.0] - 2024-01-15

### Added
- User profile pictures
- Email notification preferences
- Dark mode support

### Changed
- Improved search performance by 40%
- Updated UI to match new brand guidelines

### Fixed
- Login redirect loop on Safari
- Memory leak in background sync process

### Deprecated
- Old `/v1/users` endpoint (use `/v2/users` instead)

## [1.1.0] - 2024-01-01

### Added
- Two-factor authentication
- Export user data to JSON

### Security
- Fixed XSS vulnerability in comment rendering

## [1.0.0] - 2023-12-15

### Added
- Initial release
- User registration and authentication
- Basic user profiles
```

## Documentation Tools

### Documentation Generators

- **Elixir**: ExDoc - `mix docs`
- **JavaScript**: JSDoc, TypeDoc
- **Python**: Sphinx, MkDocs
- **Rust**: rustdoc - `cargo doc`
- **Static sites**: VitePress, Docusaurus, GitBook

### Diagram Tools

- **Mermaid**: Diagrams in Markdown
  ```markdown
  ```mermaid
  graph TD
      A[User] -->|Requests| B[Load Balancer]
      B --> C[Web Server 1]
      B --> D[Web Server 2]
      C --> E[Database]
      D --> E
  ```
  ```

- **PlantUML**: UML diagrams as code
- **Excalidraw**: Hand-drawn style diagrams
- **Draw.io**: Flowcharts and diagrams

## Documentation Style Guide

### Writing Style

- **Use active voice**: "The function returns" not "The value is returned"
- **Be concise**: Remove unnecessary words
- **Use present tense**: "Returns" not "Will return"
- **Be specific**: "Timeout in milliseconds" not "Timeout value"
- **Avoid jargon**: Or explain it when necessary
- **Use examples**: Show, don't just tell

### Formatting Conventions

- **Code**: Use `backticks` for inline code
- **Commands**: Show with `$` prefix or in code blocks
- **File paths**: Use `code formatting`
- **Emphasis**: Use **bold** for important points, *italic* for slight emphasis
- **Lists**: Use bullets for unordered, numbers for sequential steps
- **Headers**: Use sentence case, not title case

### Code Examples

- **Complete**: Include all necessary imports and setup
- **Runnable**: Readers should be able to copy and run
- **Realistic**: Use meaningful variable names and realistic data
- **Commented**: Explain non-obvious parts
- **Tested**: Ensure examples actually work
- **Current**: Keep in sync with latest API

## Documentation Maintenance

### Keeping Docs Updated

- Update documentation in the same PR as code changes
- Review docs during code review
- Set up doc linting (broken links, outdated examples)
- Schedule regular documentation audits
- Use version tags in examples when API changes
- Mark deprecated features clearly

### Documentation Testing

```elixir
# Elixir doctests - examples in docs are actual tests
defmodule Math do
  @doc """
  Adds two numbers.

  ## Examples

      iex> Math.add(2, 3)
      5

  """
  def add(a, b), do: a + b
end
```

```rust
/// Adds two numbers.
///
/// # Examples
///
/// ```
/// assert_eq!(add(2, 3), 5);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

## Key Principles

- **Write for your audience**: Tailor complexity to reader's experience level
- **Show examples**: Code examples are worth a thousand words
- **Keep it current**: Outdated docs are worse than no docs
- **Make it scannable**: Use headers, lists, code blocks, and white space
- **Explain the 'why'**: Help readers understand reasoning, not just steps
- **Start simple**: Begin with quickstart, then go deeper
- **Test documentation**: Ensure examples run and links work
- **Iterate based on feedback**: Improve based on user questions and confusion
