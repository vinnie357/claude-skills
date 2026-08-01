# TypeScript Type System Deep Dive

Full utility type signatures and lesser-used utility types not covered in the main skill body. Source: TypeScript Handbook, Utility Types page.

## Full Utility Type Reference

| Utility | Signature shape | Example |
|---|---|---|
| `Awaited<Type>` | Recursively unwraps a `Promise` | `Awaited<Promise<string>>` → `string` |
| `Partial<Type>` | `{ [P in keyof Type]?: Type[P] }` | `Partial<Todo>` |
| `Required<Type>` | `{ [P in keyof Type]-?: Type[P] }` | `Required<Props>` |
| `Readonly<Type>` | `{ readonly [P in keyof Type]: Type[P] }` | `Readonly<Todo>` |
| `Record<Keys, Type>` | `{ [P in Keys]: Type }` | `Record<"a" \| "b", string>` → `{ a: string; b: string }` |
| `Pick<Type, Keys>` | `{ [P in Keys]: Type[P] }` | `Pick<Todo, "title" \| "completed">` |
| `Omit<Type, Keys>` | `Pick<Type, Exclude<keyof Type, Keys>>` | `Omit<Todo, "description">` |
| `Exclude<UnionType, ExcludedMembers>` | Members of `UnionType` not assignable to `ExcludedMembers` | `Exclude<"a" \| "b" \| "c", "a">` → `"b" \| "c"` |
| `Extract<Type, Union>` | Members of `Type` assignable to `Union` | `Extract<"a" \| "b", "a" \| "f">` → `"a"` |
| `NonNullable<Type>` | `Type` minus `null` and `undefined` | `NonNullable<string \| null>` → `string` |
| `Parameters<Type>` | Tuple of a function type's parameters | `Parameters<(s: string) => void>` → `[s: string]` |
| `ConstructorParameters<Type>` | Tuple of a constructor's parameters | `ConstructorParameters<ErrorConstructor>` → `[message?: string]` |
| `ReturnType<Type>` | A function type's return type | `ReturnType<() => string>` → `string` |
| `InstanceType<Type>` | The instance type of a constructor type | `InstanceType<typeof C>` → `C` |
| `NoInfer<Type>` | Blocks inference on the wrapped type (5.4+) | see below |
| `ThisParameterType<Type>` | Extracts a function's `this` parameter type | `ThisParameterType<typeof toHex>` |
| `OmitThisParameter<Type>` | Removes the `this` parameter from a function type | `OmitThisParameter<typeof toHex>` |
| `ThisType<Type>` | Contextual `this` typing inside an object literal (requires `noImplicitThis`) | see below |

### `NoInfer<Type>` (TypeScript 5.4+)

Blocks a type parameter from being inferred from a particular argument, forcing inference to come from elsewhere in the call — useful when one parameter should constrain the type and a second should only be checked against it, not widen it:

```typescript
function createStreetLight<C extends string>(
  colors: C[],
  defaultColor?: NoInfer<C>,
) {
  // ...
}

createStreetLight(["red", "yellow", "green"], "red");   // ok
createStreetLight(["red", "yellow", "green"], "blue");  // error — "blue" not in the colors array
```

Without `NoInfer`, TypeScript would widen `C` to include `"blue"` from the second argument, defeating the constraint.

### `ThisType<Type>`

A marker type with no members, consumed by the compiler to set the contextual type of `this` inside an object literal's methods — commonly used by fluent/builder-style option objects:

```typescript
interface ObjectDescriptor<D, M> {
  data?: D;
  methods?: M & ThisType<D & M>; // methods see `this` as D & M
}

function makeObject<D, M>(desc: ObjectDescriptor<D, M>): D & M {
  // ...
  return {} as D & M;
}

const obj = makeObject({
  data: { x: 0, y: 0 },
  methods: {
    moveBy(dx: number, dy: number) {
      this.x += dx; // `this` is typed as { x: number; y: number } & the methods object
      this.y += dy;
    },
  },
});
```

Requires `noImplicitThis` (implied by `strict`) — otherwise `this` inside the method falls back to an implicit `any` instead of using the `ThisType` hint.

## String Manipulation Utility Types

Operate on string literal types at the type level — the type-level counterparts of the JS string methods of the same name:

```typescript
type Greeting = "hello world";

type A = Uppercase<Greeting>;     // "HELLO WORLD"
type B = Lowercase<"HELLO">;      // "hello"
type C = Capitalize<Greeting>;    // "Hello world"
type D = Uncapitalize<"Hello">;   // "hello"
```

These compose with template literal types and the `as` mapped-type remapping clause — see the `Getters<T>` example in the main skill body, which uses `Capitalize` to build `getName`/`getAge` keys from a data shape.
