---
name: resolve
description: Fetch a behavioral spec for an epic from the Allium-db database
---

# /allium-db:resolve

Retrieve the registered behavioral specification for a given VantageEx epic.

## Command

```
/allium-db:resolve <epic-slug>
```

## When to Use

- Before implementing a feature (propagate phase) to load the spec
- During code review to cross-reference implementation against original design
- To verify what specification is currently registered for an epic
- When verifying epic completion criteria

## Arguments

- `<epic-slug>` (required): VantageEx epic slug (e.g., VIN-52, VIN-72)

## Returns

A record with:
- `epic_slug`: The requested epic slug
- `spec_content`: Full `.allium` specification as TOML text
- `registered_at`: ISO 8601 timestamp of original registration
- `git_sha`: Git commit SHA from when spec was registered

## Example

```bash
/allium-db:resolve VIN-72
```

Output:
```
epic_slug  spec_content                          registered_at
VIN-72     [title]
           name = "Allium-db Plugin Scaffold"
           description = "..."
           success_criteria = [...]
           git_sha: abc1def2ghi3jkl4mno5pqr
```

## Errors

- **Not found**: Epic slug not in Allium-db database
- **Database error**: Cannot connect to Allium-db Dolt repository
- **Invalid slug**: Malformed epic slug

## References

- See `SKILL.md` for Allium workflow overview
- See `references/commands.md` for detailed command reference
