# Skill Examples

> Reference file for the `claude-skills` skill. Contains annotated examples of skill structures.

## Table of Contents

- [Simple Skill: Capability Uplift](#simple-skill-capability-uplift)
- [Complex Skill: Encoded Preference](#complex-skill-encoded-preference)
- [Common Pitfalls](#common-pitfalls)

## Simple Skill: Capability Uplift

**Category**: Capability Uplift — enhances Claude's core abilities (coding, analysis) without encoding user-specific preferences. Stable across model versions.

```markdown
---
name: git
description: Guide for Git operations including commits, branches, rebasing, and conflict resolution. Use when working with version control or the user mentions git, commits, or branches.
license: MIT
---

# Git Operations

## When to Use

Activate when:
- Creating commit messages
- Managing branches
- Resolving conflicts
- Rebasing or merging

## Conventional Commits

Follow the format: `type(scope): description`

Types: feat, fix, docs, style, refactor, test, chore

Example: `feat(auth): add OAuth2 login support`

## Branch Naming

Use format: `type/description`

Examples:
- `feature/user-authentication`
- `fix/memory-leak`
- `docs/api-reference`

## Rebasing Workflow

1. Update main: `git checkout main && git pull`
2. Rebase feature: `git checkout feature-branch && git rebase main`
3. Resolve conflicts if needed
4. Force push: `git push --force-with-lease`
```

**Why this works**: Clear activation triggers in description, imperative language, concrete examples, focused scope.

## Complex Skill: Encoded Preference

**Category**: Encoded Preference — encodes team-specific workflows, formatting, and conventions. May need updates when models change.

```markdown
---
name: phoenix
description: Guide for building Phoenix web applications with LiveView, contexts, and best practices. Use when developing Elixir Phoenix apps, implementing LiveView, or designing contexts.
license: MIT
---

# Phoenix Framework

## When to Use

Activate for:
- Phoenix application development
- LiveView implementations
- Context design
- Channel setup

## Project Structure

Phoenix apps follow:
```
lib/
├── my_app/          # Business logic (contexts)
├── my_app_web/      # Web interface
└── my_app.ex
```

## Contexts

Group related functionality:

```elixir
defmodule MyApp.Accounts do
  def list_users, do: Repo.all(User)
  def get_user!(id), do: Repo.get!(User, id)
  def create_user(attrs), do: ...
end
```

For detailed context patterns, see references/contexts.md

## LiveView

For real-time interfaces, see references/liveview-guide.md
```

**Why this works**: Uses progressive disclosure — core patterns inline, detailed references separate. Description includes "Use when" triggers.

## Common Pitfalls

### Too Generic

A skill that is too broad activates when it should not (false positives) and provides unfocused guidance.

```yaml
# Bad
name: programming
description: Helps with programming
```

```yaml
# Good
name: elixir-phoenix
description: Guide for building Phoenix web applications with LiveView, contexts, and Elixir best practices. Use when developing Phoenix apps or implementing LiveView.
```

### Too Much in SKILL.md

Loading entire API references into SKILL.md wastes context window space for every activation.

- Keep core patterns and decision logic in SKILL.md
- Move detailed reference material to `references/`
- Keep SKILL.md under 500 lines (Anthropic recommendation)

### Missing Activation Criteria

Without a "When to Use" section and description triggers, Claude cannot determine when to activate the skill.

```markdown
# Bad — no activation guidance
# My Skill

This skill helps with stuff.
```

```markdown
# Good — clear activation criteria
# My Skill

## When to Use

Activate when:
- Specific scenario 1
- Specific scenario 2
- Specific scenario 3
```

### Missing "Use when" in Description

The description is the ONLY text visible during discovery (Level 1). Body content loads only after activation.

```yaml
# Bad — missing triggers
description: Guide for Git operations including commits, branches, rebasing, and conflict resolution

# Good — includes triggers
description: Guide for Git operations including commits, branches, rebasing, and conflict resolution. Use when working with version control or the user mentions git, commits, or branches.
```
