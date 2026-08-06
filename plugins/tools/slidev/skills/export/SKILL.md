---
name: export
description: Guide for exporting Slidev presentations. Use when exporting to PDF, PPTX, PNG, building static SPA sites, or configuring export CLI flags.
---

# Slidev Export

Export presentations to PDF, PPTX, PNG, and build static SPA sites.

## When to Use This Skill

Activate when:
- Exporting slides to PDF or PPTX
- Generating PNG images of individual slides
- Building a static SPA for web hosting
- Configuring export options and CLI flags
- Troubleshooting Playwright dependencies for export

For export commands, format options, CLI flags, and build configuration, see `references/export.md`.

## Anti-fabrication

This skill follows `core:anti-fabrication`. Verified claim-by-claim against live
slidevjs/slidev source (claude-skills-223, 2026-08-05): the export CLI flags against
`packages/slidev/node/commands/export.ts` (`getExportOptions`) — all existing defaults
confirmed (`format=pdf`, `timeout=30000`, `dark=false`, `omit-background=false`,
`wait-until=networkidle`), `--wait`'s documented default corrected from blank to `0`,
and `--per-slide`/`--scale` added as real flags the skill previously omitted; the dev/
build/eject CLI against `packages/slidev/node/cli.ts` — added the entirely undocumented
`export-notes` command plus `--base`/`--log`/`--inspect`/`--tunnel` for the dev server
and `--router-mode` for build. Re-verify against `slidev export --help` / `slidev build
--help` on a current install before asserting a flag this skill doesn't cover — Slidev's
CLI surface grows between minor versions.
