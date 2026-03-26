# Update Checklist

Detailed per-type checklists for applying upstream updates to skills. Load this file when executing Phase 4 of the skill-update workflow.

---

## CLI Tools

For skills wrapping command-line tools (e.g., container, bees, beads).

### Pre-Update Research

- [ ] Fetch full release notes from `releases_url`
- [ ] List all new commands and subcommands
- [ ] List all new flags and options
- [ ] Identify removed or renamed commands (breaking changes)
- [ ] Identify deprecated flags with their replacements
- [ ] Note any changed default behaviors
- [ ] Check if config file format changed

### Version Template

- [ ] Create `templates/<new-version>/commands.md` with a snapshot of commands for this version
- [ ] Verify the old version template still exists at `templates/<old-version>/commands.md`
- [ ] Add migration note in SKILL.md pointing users from old to new template

### SKILL.md Updates

- [ ] Update version number in frontmatter or version table
- [ ] Update installation instructions (new download URL, checksum)
- [ ] Update quick reference table with new commands
- [ ] Add breaking changes table if any removals or renames
- [ ] Add migration checklist section if major version bump
- [ ] Update features list to reflect new capabilities
- [ ] Remove references to deprecated commands
- [ ] Update any inline examples that use changed syntax

### references/command-reference.md (if present)

- [ ] Add new commands with full flag documentation
- [ ] Annotate deprecated flags with `[DEPRECATED in vX.Y]`
- [ ] Annotate new flags with `[NEW in vX.Y]`
- [ ] Remove commands that no longer exist (or mark `[REMOVED in vX.Y]`)
- [ ] Verify all examples produce valid output with the new version

### Scripts (if present)

- [ ] Add Nushell helper functions for new subcommands
- [ ] Update existing functions if flag syntax changed
- [ ] Remove helpers for removed commands
- [ ] Run scripts against new version to verify behavior

### Bookkeeping

- [ ] Update `current_version` in `sources.toml`
- [ ] Update `last_checked` in `sources.toml`
- [ ] Add entry to `sources.md`: date, from-version, to-version, summary
- [ ] Bump `plugin.json` version (patch unless breaking changes to skill itself)
- [ ] Bump matching version in `marketplace.json`
- [ ] Run `mise update-all-skills`
- [ ] Run `mise test`

---

## Library Packages

For skills wrapping hex.pm packages, crates, or npm packages (e.g., tidewave, wasmex, phoenix).

### Pre-Update Research

- [ ] Query check_method endpoint for latest version number
- [ ] Read CHANGELOG or release notes for all changes since `current_version`
- [ ] Identify API additions (new functions, modules, types)
- [ ] Identify API removals or renames (breaking changes)
- [ ] Identify changed function signatures
- [ ] Note new optional dependencies or feature flags
- [ ] Check minimum runtime/language version requirement changes

### SKILL.md Updates

- [ ] Update version constraint (e.g., `~> 0.5.6` → `~> 0.6.0`)
- [ ] Update installation instructions (`mix.exs`, `Cargo.toml`, etc.)
- [ ] Document new APIs with usage examples
- [ ] Update changed API examples
- [ ] Note deprecated APIs with migration path
- [ ] Update minimum runtime version if changed
- [ ] Update any feature flags or optional dependency instructions

### References (if present)

- [ ] Update API reference with new functions/modules
- [ ] Annotate changed signatures with version info
- [ ] Update integration examples

### Bookkeeping

- [ ] Update `current_version` in `sources.toml`
- [ ] Update `last_checked` in `sources.toml`
- [ ] Add entry to `sources.md`
- [ ] Bump `plugin.json` version
- [ ] Bump matching version in `marketplace.json`
- [ ] Run `mise update-all-skills`
- [ ] Run `mise test`

---

## Language / Runtime

For skills covering a programming language or runtime (e.g., rust, zig).

### Pre-Update Research

- [ ] Identify new stable release version
- [ ] Read official release blog post or changelog
- [ ] List new language features (syntax, keywords, concepts)
- [ ] List new standard library additions
- [ ] Identify removed or changed language features
- [ ] Note changes to compiler flags or toolchain commands
- [ ] Check for edition/epoch changes (Rust editions, Zig stages)
- [ ] Identify ecosystem tooling changes (formatter, linter, package manager)

### SKILL.md Updates

- [ ] Update version references throughout
- [ ] Add new language features with examples
- [ ] Update compiler command examples for new flags
- [ ] Update toolchain installation instructions
- [ ] Document new standard library features
- [ ] Note removed features with migration path
- [ ] Update any idiom recommendations based on new best practices

### References (if present)

- [ ] Update language reference with new syntax
- [ ] Update toolchain reference
- [ ] Add edition/migration guide if applicable

### Bookkeeping

- [ ] Update `current_version` in `sources.toml`
- [ ] Update `last_checked` in `sources.toml`
- [ ] Add entry to `sources.md`
- [ ] Bump `plugin.json` version
- [ ] Bump matching version in `marketplace.json`
- [ ] Run `mise update-all-skills`
- [ ] Run `mise test`

---

## Documentation-Based

For skills based on evolving documentation or standards (e.g., git, accessibility, twelve-factor).

### Pre-Update Research

- [ ] Check if upstream specification or guide has changed
- [ ] Look for new best practices or recommendations
- [ ] Check if any referenced external URLs have moved or gone stale
- [ ] Note any community-driven changes (new conventions, deprecations)

### SKILL.md Updates (only if content has changed)

- [ ] Refresh outdated examples
- [ ] Update or replace broken external links
- [ ] Add new best practices
- [ ] Remove outdated recommendations
- [ ] Update version references if specification is versioned

### Bookkeeping

- [ ] Update `last_checked` in `sources.toml` (always)
- [ ] Update `current_version` if specification version changed
- [ ] Add entry to `sources.md` only if content changed
- [ ] Bump `plugin.json` version only if SKILL.md content changed
- [ ] Run `mise test` if versions were bumped

---

## Anti-Fabrication Rules for All Types

- Do not check off any item without executing the corresponding verification
- Do not claim a command, flag, or API exists without reading official release notes or documentation
- Do not mark a version as "current" until `sources.toml` is updated with the verified version string
- If release notes are unavailable, mark the source as `check_method = "manual"` and add a note in `sources.toml`
- Do not report test results without actual execution
