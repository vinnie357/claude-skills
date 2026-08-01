---
name: linting
description: Guide for linting and formatting TypeScript with ESLint, typescript-eslint, Biome, and Prettier. Use when configuring flat-config ESLint, choosing typescript-eslint's strict or recommended presets, evaluating Biome as an ESLint/Prettier replacement, wiring pre-commit lint hooks, or adding lint/format to CI.
license: MIT
---

# TypeScript Linting and Formatting

ESLint + typescript-eslint for type-aware linting, Biome as a fast all-in-one alternative, Prettier for formatting, and CI wiring.

## When to Use This Skill

Activate when:
- Setting up `eslint.config.js` (flat config) for a TypeScript project
- Choosing between typescript-eslint's `recommended`, `strict`, and `stylistic` presets
- Deciding between the ESLint+Prettier stack and Biome
- Configuring pre-commit hooks (`husky` + `lint-staged`) for lint/format
- Adding lint and format checks to `mise run ci` or a CI workflow

## ESLint with typescript-eslint

### Setup

```bash
npm install -D eslint @eslint/js typescript typescript-eslint
```

ESLint 9+ uses **flat config** (`eslint.config.js` / `.mjs`) — a plain array of config objects, not the older `.eslintrc` cascading-file format. `npm init @eslint/config@latest` scaffolds one interactively; the shape by hand:

```javascript
// eslint.config.mjs
import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  js.recommended,
  ...tseslint.configs.strict,
  ...tseslint.configs.stylistic,
  {
    rules: {
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
  },
);
```

### Preset selection

typescript-eslint ships three stacked preset tiers — pick a floor, don't cherry-pick individual rules out of a higher tier without understanding what the lower tier already covers:

| Preset | What it adds |
|---|---|
| `recommended` | Rules that catch common bugs and mistakes with minimal false positives — the floor for any TypeScript project |
| `strict` | A superset of `recommended` with more opinionated rules that catch bugs `recommended` deliberately leaves out to avoid false positives |
| `stylistic` | Consistency rules with no bug-catching intent — naming conventions, member ordering; layered on top of either of the above, never a substitute |

Default to `recommended` + `stylistic` for most projects; reach for `strict` when the codebase can absorb its stricter defaults (banning `// @ts-ignore` without a description, disallowing certain type assertions) without a large one-off migration. This mirrors the workspace's general strictness posture (`/core:security`, `/core:tdd` CI-strictness discipline) — start strict on new code, treat loosening as the exception that needs a reason.

### Type-aware rules

Some typescript-eslint rules (`no-floating-promises`, `no-unsafe-assignment`, `await-thenable`) require the TypeScript type checker, not just the parser — they need `parserOptions.project` (or `projectService: true` in newer configs) pointed at a `tsconfig.json`:

```javascript
export default tseslint.config(
  ...tseslint.configs.strictTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
);
```

Type-aware linting is slower than syntax-only linting — it invokes the compiler. Scope it to source files (exclude generated output and config files) rather than running it over the whole repo, and expect it to dominate lint wall-clock time on a large codebase.

## Biome

Biome is a single Rust-implemented binary that combines a linter, a formatter, and import organization — the case for reaching for it instead of ESLint+Prettier is speed and zero-config startup, at the cost of a smaller (though fast-growing) rule set and plugin ecosystem compared to ESLint's.

### Setup

```bash
npm install -D -E @biomejs/biome
npx @biomejs/biome init
```

The `-E` flag pins the exact installed version — Biome's formatting output can shift between versions, so an unpinned range risks a CI failure from a formatter update alone, not a real style violation.

### Commands

```bash
npx biome format --write .   # formatting only
npx biome lint --write .     # linting, with safe autofixes
npx biome check --write .    # format + lint + import organization together
npx biome ci .               # non-mutating check, exit-code gate for CI
```

### Choosing Biome over ESLint+Prettier

Reach for Biome when starting a new project and the team values one fast tool over ESLint's larger rule/plugin ecosystem. Don't migrate an existing ESLint config with custom plugins or shareable configs to Biome as a drive-by — Biome's rule set doesn't map 1:1 to typescript-eslint's, and a migration is its own reviewed change with a real rule-parity check, not a mechanical swap.

## Prettier Integration

If linting with ESLint (not Biome), keep Prettier as the formatter and ESLint focused on code-quality rules — don't run Prettier as an ESLint rule via `eslint-plugin-prettier`. Running formatting through the lint pipeline is slower than running Prettier directly and produces editor squiggles for pure formatting differences that autofix on save anyway.

Use `eslint-config-prettier` instead, which disables the ESLint stylistic rules that would otherwise conflict with Prettier's own formatting decisions:

```javascript
import prettierConfig from "eslint-config-prettier";

export default tseslint.config(
  // ...other configs
  prettierConfig, // last — turns off conflicting stylistic rules
);
```

Run `prettier --check .` as its own CI step, separate from `eslint`.

## Pre-Commit Hooks

```bash
npm install -D husky lint-staged
npx husky init
```

```json
// package.json
{
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"]
  }
}
```

```bash
# .husky/pre-commit
npx lint-staged
```

`lint-staged` runs the configured commands only against staged files, not the whole repo — keeps the pre-commit hook fast enough that it doesn't become the thing developers reach for `--no-verify` to skip. Per `/core:git`, skipping hooks is not something an agent does without explicit instruction; that applies to `lint-staged`-backed pre-commit hooks the same as any other.

## CI Wiring

```toml
# mise.toml
[tasks.lint]
description = "Lint and type-check"
run = [
  "npx eslint .",
  "npx tsc --noEmit",
]

[tasks.format]
description = "Check formatting"
run = "npx prettier --check ."

[tasks.ci]
description = "Full CI gate"
depends = ["lint", "format", "test"]
```

`tsc --noEmit` belongs in the lint task, not the test task — a type error is a lint-time signal (it should fail fast, before tests even run) not a test-time one, and running it separately from `eslint` means a type error and a lint error are distinguishable in CI output.

## Anti-fabrication

This skill follows `/core:anti-fabrication`. Commands, config shapes, and preset names were verified against each tool's own documentation (eslint.org, typescript-eslint.io, biomejs.dev, prettier.io) — see `sources.md` for exact pages and access dates. Rule-level behavior for any specific typescript-eslint or Biome rule not named here should be checked against that tool's rule reference before being asserted, since individual rule defaults change across releases more often than the preset structure does.

## References

- `references/rule-catalog.md` — specific typescript-eslint rules worth enabling deliberately (`no-floating-promises`, `no-explicit-any`, `consistent-type-imports`) with the bug each one catches
