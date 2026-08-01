---
name: language
description: Guide for core TypeScript language features and the type system. Use when writing or reviewing TypeScript types, enabling strict mode, choosing a utility type, designing generics or conditional types, writing declaration files, or modeling data with discriminated unions.
license: MIT
---

# TypeScript Language

Core TypeScript: strict mode, the type system, utility types, declaration files, and discriminated unions.

## When to Use This Skill

Activate when:
- Configuring `tsconfig.json`, especially `strict` and its component flags
- Designing generic functions, classes, or constraints
- Writing conditional types, mapped types, or template literal types
- Choosing between the built-in utility types (`Partial`, `Pick`, `Omit`, `Record`, ...)
- Writing or consuming `.d.ts` declaration files
- Modeling variant data with discriminated unions and exhaustiveness checks
- Deciding between `interface` and `type`, or between `enum` and a union of literals

## Strict Mode

`strict: true` in `tsconfig.json` is the floor for new TypeScript code in this workspace, not an opt-in extra. It is a single flag that enables a family of component flags — turn it on first, then reach for a component flag only when you need something `strict` doesn't cover.

```json
{
  "compilerOptions": {
    "strict": true
  }
}
```

`strict` enables, among others:

| Flag | What it catches |
|---|---|
| `noImplicitAny` | A variable or parameter would be inferred as `any` because no annotation is present |
| `strictNullChecks` | `null`/`undefined` stop being implicitly assignable to every type |
| `strictFunctionTypes` | Function parameter types are checked contravariantly instead of bivariantly |
| `strictBindCallApply` | `.call`/`.bind`/`.apply` are checked against the underlying function's signature |
| `strictPropertyInitialization` | A class field must be assigned in the constructor or have a definite-assignment marker |
| `noImplicitThis` | `this` inside a function with unclear context is flagged instead of defaulting to `any` |
| `alwaysStrict` | Every emitted file is parsed as, and emits, ECMAScript strict mode |
| `useUnknownInCatchVariables` | `catch (e)` types `e` as `unknown`, not `any` — forces a type check before use |

Two flags `strict` does **not** enable — they are separate opt-ins the `strict` family does not imply, though a current `tsc --init` now writes both into a fresh project's generated `tsconfig.json` alongside `strict: true` (listed under its own "Stricter Typechecking Options" heading, not inside the `strict` block itself):

- `exactOptionalPropertyTypes` — an optional property (`foo?: string`) rejects an explicit `undefined` assignment unless the type says `foo?: string | undefined`. Catches call sites that "clear" a field by writing `undefined` when the schema meant "omit it."
- `noUncheckedIndexedAccess` — indexing into a `Record<string, T>` or array by a computed key returns `T | undefined` instead of `T`, since JavaScript doesn't guarantee the key exists.

Both close real holes; both also touch a large fraction of existing index/optional-property call sites when retrofitted onto an established codebase. For a **new** project, accept them as part of the scaffolded default rather than deleting them — that's what `tsc --init` on a current release now hands you. For an **existing** codebase without them, treat enabling them as its own reviewed migration, not a drive-by addition alongside an unrelated change.

## The Type System

### Generics

A generic function or class defers a type decision to its caller instead of committing to one type or widening to `any`:

```typescript
function firstOf<T>(items: T[]): T | undefined {
  return items[0];
}

const n = firstOf([1, 2, 3]);        // T inferred as number
const s = firstOf<string>(["a"]);    // T explicit
```

Constrain a type parameter with `extends` when the function body needs to rely on a property existing:

```typescript
interface HasLength {
  length: number;
}

function longest<T extends HasLength>(a: T, b: T): T {
  return a.length >= b.length ? a : b;
}
```

`keyof` combined with a second type parameter constrained to it is the standard shape for a type-safe property getter:

```typescript
function get<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
```

Generic classes are generic only over their instance side — a static member cannot reference the class's own type parameter.

### Conditional types and `infer`

A conditional type picks between two branches based on an `extends` check evaluated at the type level:

```typescript
type IsString<T> = T extends string ? true : false;
```

`infer` introduces a type variable inside the `extends` clause and captures whatever the checked type matched there — this is how library-authored utility types extract a piece of a larger type:

```typescript
type Flatten<T> = T extends Array<infer Item> ? Item : T;
type ElementOf<T extends readonly unknown[]> = T extends readonly (infer E)[] ? E : never;
```

Conditional types **distribute** over a union type parameter by default — `Cond<A | B>` evaluates as `Cond<A> | Cond<B>`. Wrap both sides in a tuple (`[T] extends [U] ? ... : ...`) to compare the union as one type instead of distributing across it. Distribution is usually what you want for a "filter this union" utility; non-distribution is what you want when the conditional is deciding between two shapes of the same aggregate type.

### Mapped types and key remapping

A mapped type transforms every property of an existing type using the same rule:

```typescript
type Readonly<T> = { readonly [K in keyof T]: T[K] };
type Partial<T> = { [K in keyof T]?: T[K] };
```

The `as` clause in a mapped type (TypeScript 4.1+) remaps the resulting key, not just its value — the standard shape for deriving a getter/setter interface or an event-name map from a data shape:

```typescript
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

interface Person { name: string; age: number; }
type PersonGetters = Getters<Person>;
// { getName: () => string; getAge: () => number }
```

### Template literal types

Template literal types build string-literal unions the same way template literal *values* build strings, but at the type level — combined with `as` remapping above, or standalone for validating a string shape like a route pattern or a CSS unit.

```typescript
type Vertical = "top" | "bottom";
type Horizontal = "left" | "right";
type Corner = `${Vertical}-${Horizontal}`;
// "top-left" | "top-right" | "bottom-left" | "bottom-right"
```

## Utility Types

Built-in generic types the compiler ships — reach for one of these before writing a custom mapped type; most "helper type" needs are already covered.

| Utility | Does |
|---|---|
| `Partial<T>` | Every property optional |
| `Required<T>` | Every property required (drops `?`) |
| `Readonly<T>` | Every property `readonly` |
| `Record<K, V>` | Object type with keys `K`, all values `V` |
| `Pick<T, K>` | Subset of `T` limited to keys `K` |
| `Omit<T, K>` | `T` minus keys `K` |
| `Exclude<U, M>` | Union `U` minus members assignable to `M` |
| `Extract<U, M>` | Union `U` narrowed to members assignable to `M` |
| `NonNullable<T>` | `T` minus `null` and `undefined` |
| `Parameters<F>` | Tuple of a function type's parameter types |
| `ReturnType<F>` | A function type's return type |
| `InstanceType<C>` | The instance type of a constructor type |
| `Awaited<P>` | Recursively unwraps a `Promise` type, mirroring `await` |

`Pick`/`Omit` are the two to reach for first when a type needs to be "the same shape as X, minus/plus a couple of fields" — writing that mapped type by hand is the YAGNI case the ladder in `/core:restraint` calls out directly.

Full signatures, the string-manipulation utility types (`Uppercase`, `Capitalize`, ...), and `ThisType`/`ThisParameterType` are in `references/type-system-deep-dive.md`.

## Declaration Files and Type-Only Imports

A `.d.ts` file describes the shape of JavaScript without an implementation — the mechanism that lets an untyped JS library, or a project's own public API surface, carry types without shipping `.ts` source:

```typescript
// maths.d.ts
export function absolute(num: number): number;
export const pi: number;
```

`import type` and inline `type` imports mark an import as type-only, so the compiler strips it entirely at emit — no runtime module load for something only used in annotations. Prefer the inline form when a module mixes value and type exports:

```typescript
import type { Cat } from "./animal.js";                    // whole import is types-only
import { createCatName, type Cat, type Dog } from "./animal.js"; // mixed
```

`export type { Cat }` does the same at the export boundary. Both forms exist specifically to avoid pulling in a module at runtime just because one of its exports is used as a type — relevant to bundler tree-shaking and to breaking import cycles that only exist because of type references.

## Enums, Unions, and Exhaustiveness

Prefer a union of string literals over `enum` for new code. A literal union has no runtime footprint, structurally matches plain strings from JSON/HTTP without a cast, and doesn't carry `enum`'s reverse-mapping surprises for numeric variants:

```typescript
type Status = "pending" | "active" | "archived"; // prefer this
enum StatusEnum { Pending, Active, Archived }     // over this, for new code
```

A **discriminated union** is a union whose members share a literal-typed tag property — the tag lets the compiler narrow the whole object from one `if`/`switch` check:

```typescript
interface Circle { kind: "circle"; radius: number }
interface Square { kind: "square"; side: number }
type Shape = Circle | Square;

function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "square": return shape.side ** 2;
  }
}
```

Add an exhaustiveness check so a new union member fails to compile instead of falling through silently at runtime:

```typescript
function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle": return Math.PI * shape.radius ** 2;
    case "square": return shape.side ** 2;
    default: {
      const _exhaustive: never = shape;
      return _exhaustive;
    }
  }
}
```

Adding a `Triangle` variant to `Shape` without a matching `case` now fails at compile time — `shape` in the `default` branch is no longer assignable to `never`.

## tsconfig.json Practices

- Start from `tsc --init` on a current TypeScript release rather than an old copied config — recent `tsc --init` output defaults to `"strict": true`, `"module": "nodenext"`, and `"moduleDetection": "force"`, which match modern Node/bundler resolution instead of the legacy `commonjs` default.
- Set `"module"` and `"moduleResolution"` to match the runtime, not to whatever a tutorial used — `"nodenext"` for a Node ESM/CJS-dual package, `"bundler"` when a bundler (Vite, esbuild, webpack) does resolution and TypeScript only type-checks.
- Keep `include`/`exclude` narrow — `dist`, `node_modules`, and generated output excluded explicitly rather than relying on defaults, since a stray `.ts` file under `dist` being re-type-checked is a common source of duplicate-identifier errors.
- One `tsconfig.json` per emit target in a monorepo (`tsconfig.build.json` for the compiled output, a base `tsconfig.json` for editor/type-check-only use) via `"extends"`, rather than one config trying to serve both.

## Anti-fabrication

This skill follows `/core:anti-fabrication`. Every flag, utility type signature, and version number here was verified against the TypeScript Handbook (`typescriptlang.org/docs/handbook`) and the npm registry — see `sources.md` for the exact pages and access dates. Where a TypeScript release changes a flag's default or a utility type's signature, treat this skill as stale until re-verified against the current Handbook rather than assumed still accurate.

## References

- `references/type-system-deep-dive.md` — full utility type signatures, string-manipulation utility types, `ThisType`/`ThisParameterType`, and the `NoInfer` utility type
