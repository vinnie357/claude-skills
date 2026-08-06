---
name: c-interop
description: Guide for Zig and C interoperability. Use when importing C headers with @cImport, exporting Zig functions to C, mapping C types, using translate-c, or linking C libraries.
---

# Zig C Interop

Importing C libraries, exporting Zig to C, type mappings, and translate-c.

## When to Use This Skill

Activate when:
- Importing C headers with @cImport/@cInclude
- Exporting Zig functions for C consumption
- Mapping between Zig and C types
- Using the translate-c tool
- Linking C libraries in build.zig

For type mappings, linking patterns, and string interop examples, see `references/c-interop.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified against zig 0.16.0 (locally
installed, claude-skills-204): `references/c-interop.md`'s type mappings and linking
snippets compile as documented — no corrections needed here. A related claim, that
`@cImport` emits a deprecation warning, was found wrong and corrected, but that
claim lived in the troubleshooting skill's compiler-error catalog, not in this file.
Re-verify against a locally installed `zig build-exe` with a real C header before
asserting a type mapping this skill doesn't cover — Zig is pre-1.0 and `translate-c`
behavior has changed across minor releases.
