---
name: weed
description: Compare code against stored behavioral spec and report divergence
---

# /allium-db:weed

Compare code in a given path against the registered behavioral specification, detecting implementation misalignments.

## Command

```
/allium-db:weed <code-path>
```

## When to Use

- During the weed phase of TDD to detect code-spec misalignment
- At PR time to verify implementation matches original design intent
- When auditing implementation against behavioral spec
- To catch scope creep or unintended feature additions

## Arguments

- `<code-path>` (required): Path to code file or directory (relative or absolute)

## Returns

A record with:
- `status`: Overall result (pass, mismatch, missing, extra)
- `violations`: Count of divergences found
- `severity`: high, medium, or low
- `details`: List of specific violations with locations
- `remediation`: Suggested fixes or implementation steps

## Example

```bash
/allium-db:weed ./lib/allium_db/register.ex
```

Output:
```
status       violations  severity  comment
mismatch     3           high      Code implements features not in spec
```

## Errors

- **File not found**: Invalid `<code-path>`
- **No spec**: No registered spec found for detected epic
- **Parse error**: Code file is unparseable
- **Database error**: Cannot connect to Allium-db Dolt repository

## References

- See `SKILL.md` for Allium workflow overview
- See `references/commands.md` for detailed command reference
