---
name: code
description: Guide for Slidev code block features. Use when configuring syntax highlighting, line highlighting, Monaco editor, Magic Move animations, TwoSlash type annotations, or code groups.
---

# Slidev Code Blocks

Code presentation features including highlighting, editor integration, and animated transitions.

For code block syntax, highlighting options, and editor configuration, see `references/code.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified claim-by-claim against live
slidevjs/slidev source (claude-skills-223, 2026-08-05) — line-highlighting and Magic
Move against `docs/features/line-highlighting.md` and `docs/features/shiki-magic-move.md`
(added the undocumented `{hide}`/`{none}` line values and Magic Move's `{at:}`/`duration`/
title-bar options); code groups against `docs/features/code-groups.md` (corrected: groups
require `comark: true`, not `mdc: true` — `mdc` is a deprecated-but-working alias);
Monaco editor against `docs/features/monaco-editor.md` and `packages/types/src/
frontmatter.ts` (all confirmed, no changes); import-snippet against `docs/features/
import-snippet.md` (confirmed exact match including the "since v0.47.0" version claim).
The `finally` code-block option was independently re-verified against source
(`CodeBlockWrapper.vue`'s prop declaration) after two earlier revisions of this pass
wrongly called it nonexistent from a docs-only search. Re-verify against a fresh
`slidevjs/slidev` clone before asserting a code-block feature this skill doesn't cover.
