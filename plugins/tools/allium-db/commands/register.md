---
name: register
description: Register a behavioral spec file into the Allium-db database
---

# /allium-db:register

Ingest a `.allium` behavioral specification file into the Allium-db database.

## Command

```
/allium-db:register <spec-path>
```

## When to Use

- After writing a new `.allium` spec file in ADR documentation
- When seeding the database with baseline specs from existing epics
- During CI/CD to version-lock specs alongside code
- Before agents begin implementation (propagate phase of Allium workflow)

## Arguments

- `<spec-path>` (required): Relative or absolute path to `.allium` file

## Returns

A record with:
- `epic_id`: VantageEx epic identifier (e.g., VIN-72)
- `spec_hash`: SHA-256 hash of spec file content
- `registered_at`: ISO 8601 timestamp
- `git_sha`: Git commit SHA at registration time

## Example

```bash
/allium-db:register ./docs/adr/ADR-035-deployment.allium
```

Output:
```
epic_id    spec_hash                    registered_at            git_sha
VIN-52     a7f2d8e1c4b9f3e6a2d5c8b1f4  2026-04-18T10:30:00Z     abc1def2ghi3jkl4mno5pqr
```

## Errors

- **File not found**: `<spec-path>` does not exist
- **Parse error**: `.allium` file is malformed (invalid TOML)
- **Database error**: Cannot connect to Allium-db Dolt repository
- **Invalid spec**: Missing required fields in `.allium` file

## References

- See `SKILL.md` for Allium workflow overview
- See `references/commands.md` for detailed command reference
