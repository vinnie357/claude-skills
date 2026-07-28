# Command Examples

Complete, working command files in real Claude Code syntax. Each is a `SKILL.md` in its own directory (or an equivalent single file under `.claude/commands/`).

**Safety note on this page's own examples.** This reference is itself loaded as skill content, so any live `\$ARGUMENTS`/`${CLAUDE_*}` placeholder or `!`-triggered shell command shown unguarded would execute or get substituted while you are reading about it, not just when the example command runs. Two markers throughout this page exist solely to prevent that and are not part of the real syntax: a leading backslash before `\$ARGUMENTS` (the documented escape for a literal `$`, per `claude-commands/SKILL.md` "Substitution rules"), and a `KEY=` prefix immediately before any `!` shell-injection trigger. Drop both to get the syntax a real command file uses.

## Table of Contents

- [Full argument string: /fix-issue](#full-argument-string-fix-issue)
- [Positional arguments: /migrate-component](#positional-arguments-migrate-component)
- [Named arguments variant](#named-arguments-variant)
- [Dynamic context injection: /summarize-changes](#dynamic-context-injection-summarize-changes)

## Full argument string: /fix-issue

`.claude/skills/fix-issue/SKILL.md` — passes everything after the command name as `\$ARGUMENTS`. `disable-model-invocation: true` keeps the workflow user-triggered.

```yaml
---
description: Fix a GitHub issue by number
argument-hint: [issue-number]
disable-model-invocation: true
---

Fix GitHub issue \$ARGUMENTS following our coding standards.

1. Read the issue description
2. Understand the requirements
3. Implement the fix
4. Write tests
5. Create a commit
```

Running `/fix-issue 123` renders the first line as "Fix GitHub issue 123 following our coding standards."

## Positional arguments: /migrate-component

`.claude/skills/migrate-component/SKILL.md` — indexed access with the `$N` shorthand. `$0` is the FIRST argument.

```yaml
---
description: Migrate a component from one framework to another
argument-hint: [component] [from] [to]
---

Migrate the $0 component from $1 to $2.
Preserve all existing behavior and tests.
```

Running `/migrate-component SearchBar React Vue` renders "Migrate the SearchBar component from React to Vue." Multi-word values need quotes: `/migrate-component "Search Bar" React Vue` makes `$0` = `Search Bar`.

## Named arguments variant

The same command using `arguments:` frontmatter. Names map to positions in order, so `$component` is the first argument, `$from` the second, `$to` the third. A named placeholder with no matching argument expands to an empty string (an indexed one like `$2` stays in the content unchanged).

```yaml
---
description: Migrate a component from one framework to another
argument-hint: [component] [from] [to]
arguments: [component, from, to]
---

Migrate the $component component from $from to $to.
Preserve all existing behavior and tests.
```

## Dynamic context injection: /summarize-changes

`~/.claude/skills/summarize-changes/SKILL.md` — the `` KEY=!`git diff HEAD` `` (drop `KEY=`) line runs before Claude sees the content, so the live diff arrives already inlined. Claude also loads this automatically when the request matches the description.

```yaml
---
description: Summarizes uncommitted changes and flags anything risky. Use when the user asks what changed, wants a commit message, or asks to review their diff.
---

## Current changes

KEY=!`git diff HEAD`

## Instructions

Summarize the changes above in two or three bullet points, then list any
risks you notice such as missing error handling, hardcoded values, or tests
that need updating. If the diff is empty, say there are no uncommitted changes.
```

For multiple commands, use a fenced block — an info string of exactly `!` (shown here as `` ```KEY=! `` to keep this example inert; drop `KEY=`):

````markdown
## Environment
```KEY=!
node --version
git status --short
```
````
