# typescript-eslint Rule Catalog

Rules worth enabling deliberately even outside the `strict` preset, with the specific bug each one catches. Verified against each rule's page at typescript-eslint.io — see `sources.md`.

## `@typescript-eslint/no-floating-promises`

Flags a Promise-valued expression statement with no error handling attached — no `await`, no `.then()`/`.catch()`, no `return`, no explicit `void`. A "floating" Promise silently swallows its rejection; nothing observes the failure.

```typescript
// Flagged — rejection is silently lost
someAsyncOperation();

// Fixed — pick one
await someAsyncOperation();
void someAsyncOperation();       // explicitly fire-and-forget
someAsyncOperation().catch(handleError);
```

The `void` operator is the correct fix when fire-and-forget really is the intent (e.g. a non-critical analytics call) — it documents the decision instead of looking like an oversight.

## `@typescript-eslint/no-misused-promises`

Catches a Promise passed where the calling context expects a synchronous, non-Promise-returning callback — commonly an `async` arrow function handed to `Array.prototype.forEach`, which never awaits its callback's return value:

```typescript
// Flagged — forEach does not await; rejections are unhandled and
// the loop does not wait for each iteration to finish
[1, 2, 3].forEach(async (value) => {
  await fetch(`/items/${value}`);
});

// Fixed — for...of lets the enclosing function await each iteration
for (const value of [1, 2, 3]) {
  await fetch(`/items/${value}`);
}
```

Pairs with `no-floating-promises` — the two together cover the two most common ways async code silently drops an error: not handling a Promise at all, and handing one to a context that can't handle it.

## `@typescript-eslint/no-explicit-any`

Flags an explicit `: any` type annotation. `any` is not "unknown, be careful" — it disables type checking entirely for anything it touches, including values derived from it, which is why it is called out as a last resort rather than a normal type.

```typescript
// Flagged
function parse(input: any): any { /* ... */ }

// Preferred — forces a narrowing check before use
function parse(input: unknown): ParsedResult {
  if (typeof input !== "string") throw new TypeError("expected string");
  // ...
}
```

`unknown` is the type-safe alternative for "I don't know this type yet" — it requires a narrowing check (a `typeof`/`instanceof` guard, a schema-validation call) before any operation is permitted, where `any` permits everything unchecked.

## `@typescript-eslint/consistent-type-imports`

Enforces that an import used only for type positions (annotations, generic arguments) is marked `import type` — the same type-only-import distinction covered in the language skill, enforced automatically instead of relying on every author to remember it by hand.

```typescript
// Flagged (Foo and Bar are only ever used as types)
import { Foo } from "./Foo.js";
import Bar from "./Bar.js";
type T = Foo;
const x: Bar = 1;

// Fixed
import type { Foo } from "./Foo.js";
import type Bar from "./Bar.js";
type T = Foo;
const x: Bar = 1;
```

Autofixable — safe to run with `eslint --fix` as part of a pre-commit hook or CI autofix step.

## Applying These Deliberately

These four rules split into two groups, and conflating them means either configuring type-aware parsing a rule doesn't need, or assuming a preset enables a rule it doesn't:

- **`no-floating-promises` and `no-misused-promises` are type-aware** (`requiresTypeChecking: true`) — they inspect actual inferred types (is this expression's type a `Promise`?), not just syntax, so they only run correctly once ESLint has the type-aware parser configuration (`parserOptions.project` / `projectService`) described in the main skill body. Both are included in `strictTypeChecked`.
- **`no-explicit-any` is syntax-only** (`requiresTypeChecking: false`) — it flags the literal `any` token in an annotation, no type inference required. It runs under plain `recommended`/`strict`, with no `parserOptions.project` wiring needed.
- **`consistent-type-imports` is also syntax-only, and is in no preset at all** — not `recommended`, not `strict`, not `stylistic`, and not any of the `*TypeChecked` variants. Adding `strictTypeChecked` does **not** turn it on; it must be enabled explicitly:

```javascript
export default tseslint.config(
  ...tseslint.configs.strict,
  {
    rules: {
      "@typescript-eslint/consistent-type-imports": "error",
    },
  },
);
```

Verify a rule's `requiresTypeChecking` value and preset membership against the installed `typescript-eslint` package's own metadata before assuming either — preset composition changes across releases more often than rule behavior does.
