# WIT Syntax Reference

Complete reference for the WebAssembly Interface Type (WIT) language syntax.

Source: Component Model documentation at https://component-model.bytecodealliance.org/design/wit.html and https://component-model.bytecodealliance.org/design/worlds.html

---

## Grammar Overview

A WIT document consists of:

```
wit-file ::= package-decl? (toplevel-use-item | interface-item | world-item)*

package-decl ::= 'package' package-name ';'
package-name ::= id ':' id ('@' semver)?

toplevel-use-item ::= 'use' use-path '.' '{' use-names-list '}'  ';'
```

---

## Package Declarations

```wit
// With version
package my-org:my-package@1.2.3;

// Without version (less common; version is recommended)
package my-org:my-package;
```

Versioning follows semver. The version affects resolution when multiple versions of the same package coexist.

---

## Identifiers

Valid identifier rules:
- Lowercase ASCII letters, digits, hyphens
- Must start with a letter
- Cannot end with a hyphen
- No consecutive hyphens

Valid: `my-interface`, `http-client`, `wasi`, `v2-api`
Invalid: `MyInterface`, `my_interface`, `2api`, `my--api`

Reserved keywords used as identifiers require a `%` prefix:
```wit
%type, %use, %world, %interface, %record, %variant, %enum, %flags, %resource, %func
```

---

## Interfaces

```wit
interface interface-name {
    // use declarations (must come first)
    use other-pkg:lib/types.{some-type};

    // type definitions
    type my-alias = string;
    record my-record { ... }
    variant my-variant { ... }
    enum my-enum { ... }
    flags my-flags { ... }
    resource my-resource { ... }

    // function declarations
    my-func: func(param: type) -> return-type;
}
```

Interfaces may not contain nested interfaces or worlds.

---

## Type Aliases

```wit
type identifier = wit-type;
```

Examples:
```wit
type bytes = list<u8>;
type callback = func(data: bytes) -> result;
type nullable-string = option<string>;
```

Type aliases can alias any WIT type including function types, though function type aliases are uncommon.

---

## Primitive Types

| Keyword | Width | Range / Notes |
|---------|-------|---------------|
| `bool` | 1 bit logical | `true` / `false` |
| `u8` | 8-bit | 0 to 255 |
| `u16` | 16-bit | 0 to 65535 |
| `u32` | 32-bit | 0 to 4,294,967,295 |
| `u64` | 64-bit | 0 to 18,446,744,073,709,551,615 |
| `s8` | 8-bit signed | -128 to 127 |
| `s16` | 16-bit signed | -32768 to 32767 |
| `s32` | 32-bit signed | -2,147,483,648 to 2,147,483,647 |
| `s64` | 64-bit signed | -9,223,372,036,854,775,808 to max |
| `f32` | 32-bit IEEE 754 | single precision float |
| `f64` | 64-bit IEEE 754 | double precision float |
| `char` | Unicode scalar | not a byte; full Unicode code point |
| `string` | UTF-8 | length-prefixed, no null terminator |

---

## Compound Types

### list

```wit
list<u8>          // byte array
list<string>      // string array
list<list<u8>>    // nested lists allowed
```

### option

```wit
option<string>       // Some(string) or None
option<list<u8>>     // Some(bytes) or None
```

### result

```wit
result<ok-type, err-type>    // success or error, both with payload
result<ok-type, _>           // error has no payload
result<_, err-type>          // ok has no payload
result                       // both ok and err have no payload
result<_, _>                 // same as result
```

### tuple

```wit
tuple<string, u32>              // 2-element
tuple<string, u32, bool>        // 3-element
tuple<u8, u8, u8, u8>          // 4-element (e.g., IPv4)
```

Tuples are positional; elements have no names.

---

## Records

```wit
record record-name {
    field-name: type,
    another-field: type,
    // trailing comma allowed
}
```

Example:
```wit
record http-response {
    status: u16,
    headers: list<tuple<string, string>>,
    body: option<list<u8>>,
    content-type: option<string>,
}
```

Records map to structs in most languages. All fields are present; no optional fields (use `option<T>` for nullable fields).

---

## Variants

Tagged unions where each case may carry a distinct payload type.

```wit
variant variant-name {
    case-name,                  // no payload
    case-with-payload(type),    // with payload
    another-case(other-type),
}
```

Example:
```wit
variant json-value {
    null,
    bool-val(bool),
    number(f64),
    str(string),
    array(list<json-value>),
    object(list<tuple<string, json-value>>),
}

variant error {
    parse-error(string),
    io-error(u32),
    timeout,
    unknown,
}
```

---

## Enums

Discriminant-only variants (no payload on any case).

```wit
enum enum-name {
    case-one,
    case-two,
    case-three,
}
```

Example:
```wit
enum http-method {
    get,
    post,
    put,
    delete,
    patch,
    head,
    options,
}

enum compression {
    none,
    gzip,
    zstd,
    brotli,
}
```

Enums are more efficient than variants when no payloads are needed.

---

## Flags

A set of boolean flags; multiple can be active simultaneously.

```wit
flags flags-name {
    flag-one,
    flag-two,
    flag-three,
}
```

Example:
```wit
flags open-flags {
    read,
    write,
    create,
    truncate,
    append,
    exclusive,
}

flags event-types {
    readable,
    writable,
    error,
    hang-up,
}
```

Flags map to bitfield types. The number of flags determines the underlying integer size used by the canonical ABI.

---

## Functions

```wit
function-name: func(param-list) -> return-type
```

Variations:
```wit
// No parameters, no return
noop: func();

// Parameters, no return
log: func(level: u8, msg: string);

// Single return (unnamed)
add: func(a: s32, b: s32) -> s32;

// Multiple named returns
minmax: func(values: list<f64>) -> (min: f64, max: f64);

// Result return
open: func(path: string) -> result<resource, string>;

// Option return
find-first: func(items: list<string>, prefix: string) -> option<string>;
```

Named return values use the tuple syntax `-> (name: type, ...)`. The names appear in generated bindings as struct fields or variable names.

---

## Resources

```wit
resource resource-name {
    // Default constructor (creates owned instance)
    constructor(params);

    // Named constructor (static factory method)
    %new: static func(params) -> resource-name;

    // Instance methods (implicit borrow of self)
    method-name: func(params) -> return-type;

    // Static methods (no self)
    static-method: static func(params) -> return-type;

    // Destructor: implicit (no syntax needed — auto-dropped when handle goes out of scope)
}
```

Example:
```wit
resource tcp-socket {
    constructor(address: string, port: u16) -> result<tcp-socket, string>;

    send: func(data: list<u8>) -> result<u32, string>;
    recv: func(max-bytes: u32) -> result<list<u8>, string>;
    close: func();

    local-address: func() -> string;
    remote-address: func() -> string;

    set-timeout: static func(sock: borrow<tcp-socket>, millis: u32);
}
```

### Resource Ownership

```wit
interface storage {
    resource blob {
        constructor(data: list<u8>);
        size: func() -> u64;
    }

    // Takes ownership of blob (moved in)
    store: func(key: string, value: blob) -> result<_, string>;

    // Borrows blob (no ownership transfer)
    inspect: func(key: string, value: borrow<blob>) -> u64;

    // Returns new owned blob
    load: func(key: string) -> result<blob, string>;
}
```

`borrow<T>` signals that the resource is borrowed for the duration of the call. Owned `T` transfers ownership to the callee.

---

## Use Declarations

Import types or interfaces from other packages or the same package.

```wit
// Import specific types from an interface
use wasi:io/streams@0.2.0.{input-stream, output-stream};

// Import with alias
use wasi:clocks/wall-clock@0.2.0.{datetime as wall-datetime};

// Multiple imports
use my-org:types/common@0.1.0.{
    timestamp,
    status,
    error-kind,
};
```

Use declarations must come before type definitions and function declarations within the same scope.

### Use Path Syntax

```
package-name '/' interface-name ('@' version)?
```

Examples:
- `wasi:io/streams@0.2.0` — interface `streams` from package `wasi:io` version 0.2.0
- `my-org:utils/strings` — no version (latest or only version)

---

## Worlds

```wit
world world-name {
    // use declarations
    use some-pkg:lib/types.{some-type};

    // import items
    import item-name: func(...) -> ...;
    import interface-name: interface { ... };
    import pkg:name/iface@ver;
    import pkg:name/iface@ver.{type-name};

    // export items
    export item-name: func(...) -> ...;
    export interface-name: interface { ... };
    export named-iface;

    // includes
    include other-world;
    include other-world with { old-name as new-name };
}
```

### Import Styles

```wit
world example {
    // Import a function directly
    import log: func(msg: string);

    // Import an inline interface
    import filesystem: interface {
        read-file: func(path: string) -> result<list<u8>, string>;
    };

    // Import a named interface from the same package
    import my-interface;

    // Import an interface from another package
    import wasi:filesystem/preopens@0.2.0;

    // Import specific types only (not the whole interface)
    import wasi:io/streams@0.2.0.{input-stream};
}
```

### Export Styles

```wit
world example {
    // Export a function
    export run: func() -> result<_, string>;

    // Export an interface by name (interface defined in same package)
    export my-interface;

    // Export an inline interface
    export api: interface {
        process: func(data: list<u8>) -> list<u8>;
    };
}
```

### World Includes

```wit
world base-cli {
    import wasi:cli/stdin@0.2.0;
    import wasi:cli/stdout@0.2.0;
    export wasi:cli/run@0.2.0;
}

world extended-cli {
    include base-cli;
    import wasi:filesystem/preopens@0.2.0;
    export my-app: func();
}
```

The `with` clause renames items to avoid name conflicts:

```wit
world merged {
    include world-a with {
        process as process-a,
        config as config-a,
    };
    include world-b with {
        process as process-b,
        config as config-b,
    };
}
```

---

## Comments

```wit
// Single-line comment

/*
  Block comment (does not nest)
*/

/// Documentation comment.
/// Attached to the immediately following item.
/// Appears in generated bindings as doc comments/JSDoc/etc.
interface well-documented {
    /// Computes the factorial of n.
    /// Returns error if n > 20 to avoid overflow.
    factorial: func(n: u32) -> result<u64, string>;
}
```

---

## Full Example: HTTP Client Interface

```wit
package my-org:http-client@0.2.0;

interface types {
    record request {
        method: http-method,
        url: string,
        headers: list<tuple<string, string>>,
        body: option<list<u8>>,
    }

    record response {
        status: u16,
        headers: list<tuple<string, string>>,
        body: list<u8>,
    }

    enum http-method {
        get,
        post,
        put,
        delete,
        patch,
        head,
        options,
    }

    variant http-error {
        connection-failed(string),
        timeout(u32),
        invalid-url,
        tls-error(string),
        server-error(u16),
    }
}

interface client {
    use types.{request, response, http-error};

    resource http-client {
        constructor(base-url: string);
        send: func(req: request) -> result<response, http-error>;
        set-timeout: func(millis: u32);
        set-header: func(name: string, value: string);
    }
}

world http-plugin {
    import wasi:clocks/wall-clock@0.2.0;
    export client;
}
```

---

## Canonical ABI Notes

The Canonical ABI defines how WIT types are represented at the wasm binary level. Key points:

- Strings are passed as (pointer, length) pairs in linear memory, encoded as UTF-8
- Lists are (pointer, length) pairs
- Options are lowered as a discriminant + value
- Results are lowered as a discriminant + payload
- Records are laid out field-by-field with alignment padding
- Variants use a discriminant sized to fit the number of cases, plus the largest payload
- Resources are represented as 32-bit handles (indices into a resource table)
- `borrow<T>` resources have a different handle space than owned resources

Tools like `wasm-tools component wit` show the ABI for any compiled component.

---

## WIT Package Layout on Disk

A WIT package can span multiple files in a directory:

```
wit/
├── my-package.wit        # package declaration and interfaces
├── worlds.wit            # world definitions
└── deps/                 # vendored dependencies
    └── wasi:io@0.2.0/
        ├── streams.wit
        └── poll.wit
```

Reference a WIT directory with tools:
```bash
# cargo-component uses wit/ by default
cargo component build

# wasm-tools accepts a directory
wasm-tools component wit wit/

# wit-bindgen
wit-bindgen rust wit/ --world my-world --out-dir src/bindings/
```

The `wit/deps/` directory holds vendored WIT packages fetched via `cargo component add` or manually.
