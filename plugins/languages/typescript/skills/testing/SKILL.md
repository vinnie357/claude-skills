---
name: testing
description: Guide for testing TypeScript projects with Vitest, Jest, and Playwright. Use when writing unit tests, mocking modules or timers, asserting types at compile time, running end-to-end browser tests, configuring coverage thresholds, or wiring test tasks into CI.
license: MIT
---

# TypeScript Testing

Vitest and Jest for unit/integration tests, Playwright for end-to-end, type-level testing, coverage, and CI wiring.

## When to Use This Skill

Activate when:
- Choosing or configuring a unit test runner (Vitest or Jest) for a TypeScript project
- Mocking modules, timers, or globals in a test
- Asserting that a type is exactly what's expected, at compile time rather than runtime
- Writing or running Playwright end-to-end browser tests
- Setting coverage thresholds or wiring `test`/`coverage` into `mise run ci`
- Debugging a flaky or slow TypeScript test suite

## Choosing Vitest vs Jest

Both are viable; the deciding factor is the rest of the toolchain, not raw feature count.

- **Vitest** reads the project's existing Vite config and reuses its transform pipeline, so a Vite-based app (React/Vue/Svelte via Vite, or a Vite-built library) gets test config for near-free. Vitest requires Vite ≥6 and Node ≥20. Its API is Jest-compatible (`describe`/`test`/`expect`/`vi.fn()`), so migrating an existing Jest suite is mostly a find-and-replace of the mock namespace.
- **Jest** is the default for a project with no Vite in its pipeline — plain Node libraries, Next.js (which documents first-class Jest support), or a codebase already standardized on Jest tooling (snapshot serializers, custom matchers written against Jest's APIs). TypeScript support comes via `ts-jest` (type-checks as part of the test run) or Babel (transpile-only, faster, no type errors caught).

Restraint applies here directly: don't add Vitest to a project that already has a working Jest suite just because Vitest is newer, and don't bolt Jest onto a Vite app that would get Vitest for free.

## Vitest

### Setup

```bash
npm install -D vitest
```

No separate config file is required — Vitest reads `vite.config.ts` by default. Add a dedicated `vitest.config.ts` only when test-specific settings (environment, coverage thresholds, setup files) would otherwise clutter the Vite config:

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",       // or "jsdom" / "happy-dom" for DOM tests
    globals: false,            // false = import describe/test/expect explicitly (recommended)
    coverage: {
      provider: "v8",
      thresholds: { lines: 80, functions: 80, branches: 75, statements: 80 },
    },
  },
});
```

Leaving `globals: false` and importing `describe`/`test`/`expect`/`vi` explicitly from `"vitest"` keeps test files free of ambient globals — the same reasoning as avoiding `any`: an explicit import is a grep target and a type-checked one.

### Assertions and structure

```typescript
import { describe, test, expect } from "vitest";
import { add } from "./math.js";

describe("add", () => {
  test("adds two positive numbers", () => {
    expect(add(2, 3)).toBe(5);
  });

  test("adds negative numbers", () => {
    expect(add(-1, -1)).toBe(-2);
  });
});
```

### Mocking

```typescript
import { vi, expect, test } from "vitest";
import { fetchUser } from "./api.js";

vi.mock("./api.js", () => ({
  fetchUser: vi.fn().mockResolvedValue({ id: 1, name: "Ada" }),
}));

test("uses the mocked fetch", async () => {
  const user = await fetchUser(1);
  expect(user.name).toBe("Ada");
});
```

`vi.fn()` creates a spy/mock function; `vi.mock(path, factory)` replaces a module's exports for the whole file. `vi.useFakeTimers()` / `vi.advanceTimersByTime(ms)` control time for code under test that uses `setTimeout`/`setInterval` — mock the boundary (the module doing I/O or the clock), never the function under test itself, matching the `/core:agent-loop` mock-external-boundaries convention this workspace uses across languages.

## Jest

### Setup

```bash
npm install -D jest ts-jest @types/jest
npx ts-jest config:init
```

`ts-jest` type-checks test files as part of the run — a type error in a test fails the test run, not just `tsc`. The Babel path (`babel-jest` + `@babel/preset-typescript`) is faster because it strips types without checking them; pick it only when a separate `tsc --noEmit` step in CI already covers type-checking, so Babel isn't silently letting a type error through untested.

### Basic test

```typescript
// math.test.ts
import { add } from "./math";

test("adds 1 + 2 to equal 3", () => {
  expect(add(1, 2)).toBe(3);
});
```

### Mocking modules

```typescript
import { fetchUser } from "./api";

jest.mock("./api");
const mockFetchUser = fetchUser as jest.MockedFunction<typeof fetchUser>;

test("uses the mocked fetch", async () => {
  mockFetchUser.mockResolvedValue({ id: 1, name: "Ada" });
  const user = await fetchUser(1);
  expect(user.name).toBe("Ada");
});
```

The `as jest.MockedFunction<typeof fetchUser>` cast is the standard Jest+TypeScript pattern for getting mock-specific methods (`mockResolvedValue`, `mockReturnValueOnce`) on a function whose static type is the real implementation's signature.

## Type-Level Testing

A test suite that only exercises runtime behavior can still ship a type regression — a generic that silently widens to `any`, an overload that resolves to the wrong branch. Two focused tools assert on the *type*, not the value:

- **`expect-type`** — runtime-free type assertions inside a normal test file, checked by `tsc`, not executed:

  ```typescript
  import { expectTypeOf } from "expect-type";

  expectTypeOf(add(1, 2)).toEqualTypeOf<number>();
  expectTypeOf<Partial<{ a: number }>>().toEqualTypeOf<{ a?: number }>();
  ```

  These assertions run as part of a normal `vitest`/`tsc` pass — no separate command. Vitest also ships an `expectTypeOf` re-export built on the same library.

- **`tsd`** — a standalone CLI that type-checks `.test-d.ts` files against `.d.ts` output, aimed at library authors verifying their *published* declaration file, not internal application types:

  ```typescript
  // index.test-d.ts
  import { expectType } from "tsd";
  import { add } from "./index.js";

  expectType<number>(add(1, 2));
  ```

  Run via `npx tsd`. Reach for `tsd` specifically when the thing under test is a package's public `.d.ts`, not its implementation — `expect-type` inside the normal suite covers everything else.

## Playwright (End-to-End)

### Setup

```bash
npm init playwright@latest
```

Interactive: choose TypeScript, the test directory (default `tests/` or `e2e/`), whether to add a GitHub Actions workflow, and which browsers to install. Produces `playwright.config.ts`.

### Running tests

```bash
npx playwright test                # headless, parallel across configured browsers
npx playwright test --headed       # watch the browser
npx playwright test --project=chromium
npx playwright test --ui           # interactive UI mode with time-travel debugging
npx playwright show-report         # HTML report from the last run
```

### Example test

```typescript
import { test, expect } from "@playwright/test";

test("home page has expected heading", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Welcome" })).toBeVisible();
});
```

Playwright tests run against a real browser engine (Chromium/Firefox/WebKit) — treat them as the outermost layer of the test pyramid (`/core:tdd` "Ice Cream Cone" anti-pattern applies directly): cover behavior with fast Vitest/Jest unit tests first, and reserve Playwright for flows that only a real browser can verify (navigation, layout, cross-tab behavior).

## Coverage and CI Integration

```json
// package.json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:coverage": "vitest run --coverage",
    "test:e2e": "playwright test"
  }
}
```

```toml
# mise.toml
[tasks.test]
description = "Run unit tests"
run = "npm run test"

[tasks."test:coverage"]
description = "Run unit tests with coverage"
run = "npm run test:coverage"

[tasks.ci]
description = "Full CI gate"
depends = ["lint", "test", "test:coverage"]
```

Fail CI on a coverage threshold drop, not just on a red test — set `coverage.thresholds` in `vitest.config.ts` (see the Vitest section above) so a PR that adds code without tests fails the same gate a red test would, consistent with `/core:tdd` "code without tests is not complete."

## Anti-fabrication

This skill follows `/core:anti-fabrication`. Package names, CLI commands, and config shapes were verified against each tool's own documentation (vitest.dev, jestjs.io, playwright.dev) and the npm registry for version numbers — see `sources.md` for exact pages and access dates. `expect-type` and `tsd` API surfaces shown here are the documented public entry points (`expectTypeOf`, `expectType`); verify against the installed package version before relying on a less common assertion method not shown here.

## References

- `references/mocking-patterns.md` — timer mocking, partial module mocks, and spying on object methods in both Vitest and Jest
