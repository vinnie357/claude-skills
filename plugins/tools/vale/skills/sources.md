# Vale Plugin Sources

This file documents the sources used to create the vale plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `vale-docs`, `vale-package-registry` (Vale Skill).

## Vale Skill

### Vale Documentation
- **URL**: https://docs.vale.sh/
- **Purpose**: Extension points, scopes, alert levels, `.vale.ini` structure, front-matter scoping, and suppression syntax
- **Date Accessed**: 2026-08-27
- **License**: Vale is MIT-licensed; its documentation is the upstream reference for the behaviour this skill describes
- **Key Topics**: existence/substitution/occurrence/consistency/sequence extension points, scope options, MinAlertLevel, section globs, vale sync

### Vale Package Registry
- **URL**: https://vale.sh/explorer
- **Purpose**: The published style packages (Google, Microsoft, write-good, proselint, alex, Readability) that `vale sync` installs
- **Date Accessed**: 2026-08-27
- **Key Topics**: Package discovery, `Packages` key, versioned package pinning
