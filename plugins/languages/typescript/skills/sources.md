# TypeScript Plugin Sources

This file documents the sources used to create the typescript plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there. Entries: `typescript`, `vitest`, `jest`, `playwright`, `expect-type`, `tsd`, `eslint`, `typescript-eslint`, `biome`, `prettier`, `husky`, `node`, `pnpm`, `bun`.

## Language Skill

### TypeScript Handbook
- **URL**: https://www.typescriptlang.org/docs/handbook/
- **Purpose**: Foundation for the language skill — the type system, strict mode, generics, conditional types, mapped types
- **Date Accessed**: 2026-08-01
- **Key Topics**: Strict flags, generics and constraints, conditional types and `infer`, mapped types with `as` remapping, template literal types

### TSConfig Reference
- **URL**: https://www.typescriptlang.org/tsconfig/
- **Purpose**: Authoritative reference for `strict` and its component compiler options
- **Date Accessed**: 2026-08-01
- **Key Topics**: `noImplicitAny`, `strictNullChecks`, `strictFunctionTypes`, `strictBindCallApply`, `strictPropertyInitialization`, `noImplicitThis`, `alwaysStrict`, `useUnknownInCatchVariables`, `exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`

### TypeScript Utility Types
- **URL**: https://www.typescriptlang.org/docs/handbook/utility-types.html
- **Purpose**: Full utility type signature reference, extracted into `language/references/type-system-deep-dive.md`
- **Date Accessed**: 2026-08-01
- **Key Topics**: `Partial`, `Required`, `Readonly`, `Record`, `Pick`, `Omit`, `Exclude`, `Extract`, `NonNullable`, `Parameters`, `ReturnType`, `InstanceType`, `Awaited`, `NoInfer`, `ThisType`, string manipulation types

### TypeScript Narrowing (Discriminated Unions)
- **URL**: https://www.typescriptlang.org/docs/handbook/2/narrowing.html
- **Purpose**: Discriminated unions and exhaustiveness checking with `never`
- **Date Accessed**: 2026-08-01

### TypeScript Generics
- **URL**: https://www.typescriptlang.org/docs/handbook/2/generics.html
- **Purpose**: Generic functions, constraints, and generic classes
- **Date Accessed**: 2026-08-01

### TypeScript Conditional Types
- **URL**: https://www.typescriptlang.org/docs/handbook/2/conditional-types.html
- **Purpose**: Conditional types, `infer`, mapped types with key remapping, distributive conditional types
- **Date Accessed**: 2026-08-01

### TypeScript Modules Handbook
- **URL**: https://www.typescriptlang.org/docs/handbook/2/modules.html
- **Purpose**: Type-only imports/exports (`import type`) and declaration files (`.d.ts`)
- **Date Accessed**: 2026-08-01

### TypeScript Modules Reference (moduleResolution)
- **URL**: https://www.typescriptlang.org/docs/handbook/modules/reference.html
- **Purpose**: `moduleResolution` strategy comparison, extracted into `node/references/module-resolution.md`
- **Date Accessed**: 2026-08-01
- **Key Topics**: `node10`, `node16`/`nodenext`, `bundler`

### TypeScript 5.9 Release Notes
- **URL**: https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-9.html
- **Purpose**: `tsc --init` default shape cited in the tsconfig.json practices section
- **Date Accessed**: 2026-08-01
- **Key Topics**: Minimal `tsc --init` output (`strict: true`, `module: nodenext`, `moduleDetection: force`)

### TypeScript npm Registry
- **URL**: https://registry.npmjs.org/typescript/latest
- **Purpose**: Version tracking — see the discrepancy note in `sources.toml`'s `typescript` entry
- **Date Accessed**: 2026-08-01

### GitHub Repository (microsoft/TypeScript)
- **URL**: https://github.com/microsoft/TypeScript/releases
- **Purpose**: Release tracking for `mise sources:check`
- **Date Accessed**: 2026-08-01

## Testing Skill

### Vitest Guide
- **URL**: https://vitest.dev/guide/
- **Purpose**: Foundation for the Vitest section — setup, config, mocking, assertions
- **Date Accessed**: 2026-08-01
- **Key Topics**: `vi.fn()`, `vi.mock()`, Vite config reuse, Node/Vite version floors

### Vitest / Jest npm Registry and GitHub Releases
- **URLs**: https://registry.npmjs.org/vitest/latest, https://github.com/vitest-dev/vitest/releases, https://registry.npmjs.org/jest/latest, https://github.com/jestjs/jest/releases
- **Purpose**: Version tracking
- **Date Accessed**: 2026-08-01

### Jest Getting Started
- **URL**: https://jestjs.io/docs/getting-started
- **Purpose**: Foundation for the Jest section — setup, `ts-jest` vs Babel, basic test shape
- **Date Accessed**: 2026-08-01

### Playwright Intro
- **URL**: https://playwright.dev/docs/intro
- **Purpose**: Foundation for the end-to-end testing section
- **Date Accessed**: 2026-08-01
- **Key Topics**: `npm init playwright@latest`, `npx playwright test`, `--ui` mode

### Playwright npm Registry
- **URL**: https://registry.npmjs.org/@playwright/test/latest
- **Purpose**: Version tracking
- **Date Accessed**: 2026-08-01

### expect-type / tsd
- **URLs**: https://github.com/mmkal/expect-type, https://github.com/tsdjs/tsd, https://registry.npmjs.org/expect-type/latest, https://registry.npmjs.org/tsd/latest
- **Purpose**: Type-level testing section — `expectTypeOf`/`expectType` API entry points and version tracking
- **Date Accessed**: 2026-08-01

## Linting Skill

### ESLint Getting Started
- **URL**: https://eslint.org/docs/latest/use/getting-started
- **Purpose**: Foundation for the ESLint section — flat config setup and shape
- **Date Accessed**: 2026-08-01
- **Key Topics**: `eslint.config.js`, `npm init @eslint/config@latest`

### typescript-eslint Getting Started
- **URL**: https://typescript-eslint.io/getting-started/
- **Purpose**: Foundation for the typescript-eslint section — presets and config wiring
- **Date Accessed**: 2026-08-01
- **Key Topics**: `recommended`/`strict`/`stylistic` preset tiers

### typescript-eslint Rule Pages
- **URLs**: https://typescript-eslint.io/rules/no-floating-promises/, https://typescript-eslint.io/rules/no-misused-promises/, https://typescript-eslint.io/rules/no-explicit-any/, https://typescript-eslint.io/rules/consistent-type-imports/
- **Purpose**: Individual rule behavior extracted into `linting/references/rule-catalog.md`
- **Date Accessed**: 2026-08-01

### Biome Getting Started
- **URL**: https://biomejs.dev/guides/getting-started/
- **Purpose**: Foundation for the Biome section — install, init, commands
- **Date Accessed**: 2026-08-01
- **Key Topics**: `biome init`, `biome format`/`lint`/`check`/`ci`

### Prettier — Integrating with Linters
- **URL**: https://prettier.io/docs/integrating-with-linters
- **Purpose**: `eslint-config-prettier` vs `eslint-plugin-prettier` recommendation, cited directly
- **Date Accessed**: 2026-08-01

### ESLint / typescript-eslint / Biome / Prettier / Husky npm Registry and GitHub Releases
- **URLs**: https://registry.npmjs.org/eslint/latest, https://github.com/eslint/eslint/releases, https://registry.npmjs.org/typescript-eslint/latest, https://github.com/typescript-eslint/typescript-eslint/releases, https://registry.npmjs.org/@biomejs/biome/latest, https://github.com/biomejs/biome/releases, https://registry.npmjs.org/prettier/latest, https://registry.npmjs.org/husky/latest
- **Purpose**: Version tracking
- **Date Accessed**: 2026-08-01

## Node Skill

### Node.js Streams API
- **URL**: https://nodejs.org/api/stream.html
- **Purpose**: Foundation for the Streams section — the four stream types, piping, backpressure
- **Date Accessed**: 2026-08-01

### Node.js Packages API (exports/imports/type)
- **URL**: https://nodejs.org/api/packages.html
- **Purpose**: Foundation for the ESM vs CommonJS section — `exports`, `imports`, `type` fields, conditional exports
- **Date Accessed**: 2026-08-01

### Node.js Packages API — Subpath Imports
- **URL**: https://nodejs.org/api/packages.html#subpath-imports
- **Purpose**: `imports` field and `#`-prefixed subpath imports, extracted into `node/references/module-resolution.md`
- **Date Accessed**: 2026-08-01

### Node.js Packages API — Dual Package Hazard
- **URL**: https://nodejs.org/api/packages.html#dual-package-hazard
- **Purpose**: Dual CJS/ESM entry-point hazard, extracted into `node/references/module-resolution.md`
- **Date Accessed**: 2026-08-01
- **Note**: The page's own prose is thin here (points to an external examples repo); the module-instance-duplication explanation in the reference is this skill's own synthesis of the documented cause, not a verbatim quote — flagged for re-verification if a more authoritative Node source is found.

### Node.js Release Schedule
- **URL**: https://nodejs.org/en/about/previous-releases
- **Purpose**: Active LTS vs Current release line determination for the mise pinning guidance
- **Date Accessed**: 2026-08-01
- **Key Topics**: v24 "Krypton" (Active LTS), v26 (Current)

### pnpm Motivation
- **URL**: https://pnpm.io/motivation
- **Purpose**: Foundation for the pnpm entry in the package-manager comparison table
- **Date Accessed**: 2026-08-01

### Bun Documentation
- **URL**: https://bun.sh/docs
- **Purpose**: Foundation for the Bun entry in the package-manager comparison table
- **Date Accessed**: 2026-08-01
- **Key Topics**: Runtime + package manager + test runner + bundler, JavaScriptCore engine, Node-compatibility status as an ongoing effort

### pnpm / bun-types npm Registry
- **URLs**: https://registry.npmjs.org/pnpm/latest, https://registry.npmjs.org/bun-types/latest
- **Purpose**: Version tracking
- **Date Accessed**: 2026-08-01

## Plugin Information

- **Name**: typescript
- **Description**: TypeScript development skills: language and type system, Vitest/Jest/Playwright testing, ESLint/typescript-eslint/Biome linting, and the Node.js runtime
- **Skills**: 4 skills covering the TypeScript language, testing, linting, and the Node.js runtime
- **Created**: 2026-08-01
- **Updated**: 2026-08-01
