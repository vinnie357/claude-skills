# Mocking Patterns: Vitest and Jest

Patterns beyond the basics in the main skill body: timer mocking, partial module mocks, and spying on existing object methods. Both runners expose a Jest-compatible mock API, so the shapes below differ mainly in namespace (`vi.*` vs `jest.*`).

## Timer Mocking

Code that calls `setTimeout`/`setInterval`/`Date.now()` needs fake timers so the test doesn't actually wait — mock the clock, never restructure the code under test just to make it testable.

### Vitest

```typescript
import { vi, test, expect, beforeEach, afterEach } from "vitest";

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());

test("debounced function fires once after the delay", () => {
  const fn = vi.fn();
  const debounced = debounce(fn, 200);

  debounced();
  debounced();
  vi.advanceTimersByTime(200);

  expect(fn).toHaveBeenCalledTimes(1);
});
```

### Jest

```typescript
beforeEach(() => jest.useFakeTimers());
afterEach(() => jest.useRealTimers());

test("debounced function fires once after the delay", () => {
  const fn = jest.fn();
  const debounced = debounce(fn, 200);

  debounced();
  debounced();
  jest.advanceTimersByTime(200);

  expect(fn).toHaveBeenCalledTimes(1);
});
```

Always pair `useFakeTimers()` with `useRealTimers()` in `afterEach` — an un-restored fake timer leaks into the next test file's real-timer expectations, the same class of test-isolation bug `/core:tdd`'s isolation guidance and this workspace's binding test-isolation rules call out for other kinds of global state.

## Partial Module Mocks

Mocking an entire module is sometimes too broad — a module might export five functions and only one needs a fake implementation, with the rest expected to run for real.

### Vitest

```typescript
import { vi, test, expect } from "vitest";

vi.mock("./api.js", async (importOriginal) => {
  const actual = await importOriginal<typeof import("./api.js")>();
  return {
    ...actual,
    fetchUser: vi.fn().mockResolvedValue({ id: 1, name: "Ada" }),
  };
});
```

`importOriginal()` returns the real module so everything not explicitly overridden keeps its real implementation — the standard shape for "mock this one boundary call, leave the rest of the module alone."

### Jest

```typescript
jest.mock("./api", () => ({
  ...jest.requireActual("./api"),
  fetchUser: jest.fn().mockResolvedValue({ id: 1, name: "Ada" }),
}));
```

`jest.requireActual` is the Jest equivalent of Vitest's `importOriginal`.

## Spying on Existing Methods

Spying replaces one method on a real object while leaving the object's other behavior untouched — useful for asserting a method was called without replacing the whole collaborator.

### Vitest

```typescript
import { vi, test, expect } from "vitest";
import * as logger from "./logger.js";

test("logs an error on failure", () => {
  const spy = vi.spyOn(logger, "error").mockImplementation(() => {});

  runRiskyOperation();

  expect(spy).toHaveBeenCalledWith(expect.stringContaining("failed"));
  spy.mockRestore();
});
```

### Jest

```typescript
import * as logger from "./logger";

test("logs an error on failure", () => {
  const spy = jest.spyOn(logger, "error").mockImplementation(() => {});

  runRiskyOperation();

  expect(spy).toHaveBeenCalledWith(expect.stringContaining("failed"));
  spy.mockRestore();
});
```

Call `.mockRestore()` (or configure `restoreMocks: true` in the runner config so it happens automatically between tests) — an un-restored spy is the same isolation hazard as an un-restored fake timer: it silently changes behavior for every test that runs after it in the same file.

## Mock Boundary Discipline

Both runners make it just as easy to mock an internal module as an external one — the API doesn't distinguish. The discipline that keeps tests meaningful is the same one this workspace applies across languages (`/core:agent-loop` mock-external-boundaries convention): mock HTTP calls, the filesystem, the system clock, and third-party SDKs; let internal modules run for real against their actual implementation. A test that mocks a module in the same package it's testing is usually testing the mock, not the code.
