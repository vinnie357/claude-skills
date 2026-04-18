# Allium-db Command Reference

Detailed reference for the four Allium-db commands: `/allium-db:register`, `/allium-db:resolve`, `/allium-db:weed`, and `/allium-db:elicit`.

## register

Register a behavioral spec file into the Allium-db database.

**Signature:**
```
/allium-db:register <spec-path>
```

**Parameters:**
- `spec-path` (required): Path to `.allium` specification file (relative or absolute)

**Returns:**
Record with fields:
- `epic_id`: VantageEx epic identifier (e.g., VIN-72)
- `spec_hash`: SHA-256 hash of spec content
- `registered_at`: ISO 8601 timestamp
- `git_sha`: Current Git commit SHA

**Errors:**
- File not found: Invalid `spec-path`
- Parse error: Malformed `.allium` TOML
- Database error: Dolt connectivity issue

**Example:**
```bash
/allium-db:register ./docs/adr/ADR-035.allium
```

## resolve

Fetch a behavioral spec from the database for a given epic.

**Signature:**
```
/allium-db:resolve <epic-slug>
```

**Parameters:**
- `epic-slug` (required): VantageEx epic slug (e.g., VIN-52, VIN-72)

**Returns:**
Record with fields:
- `epic_slug`: The requested epic slug
- `spec_content`: Full `.allium` specification (TOML text)
- `registered_at`: ISO 8601 timestamp of registration
- `git_sha`: Git commit SHA from registration

**Errors:**
- Not found: Epic slug not in database
- Database error: Dolt connectivity issue

**Example:**
```bash
/allium-db:resolve VIN-72
```

## weed

Compare code in a given path against the stored behavioral spec.

**Signature:**
```
/allium-db:weed <code-path>
```

**Parameters:**
- `code-path` (required): Path to code file or directory (relative or absolute)

**Returns:**
Record with fields:
- `status`: Overall result (pass, mismatch, missing, extra)
- `violations`: Count of divergences
- `severity`: high, medium, low
- `details`: List of specific mismatches
- `remediation`: Suggested fixes

**Errors:**
- File not found: Invalid `code-path`
- No spec: No registered spec found for the detected epic
- Database error: Dolt connectivity issue

**Example:**
```bash
/allium-db:weed ./lib/allium_db/register.ex
```

## elicit

Interactive prompt for capturing behavioral specs.

**Signature:**
```
/allium-db:elicit
```

**Parameters:**
None (interactive)

**Returns:**
Draft `.allium` specification (TOML text) ready for editing and registration

**Flow:**
1. Prompt for epic slug
2. Prompt for feature name
3. Prompt for description
4. Prompt for success criteria (multi-line)
5. Prompt for edge cases
6. Prompt for dependencies
7. Generate and return draft spec

**Errors:**
- Prompt timeout: No input received within timeout window
- Database error: Dolt connectivity issue

**Example:**
```bash
/allium-db:elicit
```

Interactive prompts:
```
Epic slug? VIN-72
Feature name? Allium-db Plugin Scaffold
Description? Create Claude plugin structure for Allium-db CLI...
Success criteria? 
  1. ...
  2. ...
Edge cases?
  1. ...
Dependencies? /core:agent-loop
```

## Return Data Format

All commands return structured data in Nushell record format (internally converted to JSON for API transport).

Example return structure:
```
epic_slug: "VIN-72"
status: "success"
registered_at: "2026-04-18T10:30:00Z"
spec_hash: "a7f2d8e1c4b9f3e6a2d5c8b1f4e7a2d5"
```

## See Also

- Main skill documentation: `SKILL.md`
- Nushell wrapper: `scripts/0.1.0/allium-db.nu`
