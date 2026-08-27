# WIT Common Patterns

Worked WIT shapes for the three cases that come up most: a plugin world, a
service interface built on resources, and a shared type library imported across
packages. Syntax rules for the constructs used here are in this skill's
syntax-reference.md.

## Plugin Interface

A world where the host supplies capabilities and the plugin supplies the
lifecycle hooks.

```wit
package my-app:plugin@0.1.0;

world plugin {
    // Host provides these to the plugin
    import log: func(level: string, msg: string);
    import config: func(key: string) -> option<string>;

    // Plugin must provide these
    export init: func() -> result<_, string>;
    export process: func(input: list<u8>) -> result<list<u8>, string>;
    export shutdown: func();
}
```

## Service Interface with Resources

`connection` is an owned resource; `transaction` takes a `borrow<connection>`
in its static constructor so beginning a transaction does not transfer
ownership of the connection.

```wit
package my-org:database@1.0.0;

interface db {
    resource connection {
        constructor(url: string) -> result<connection, string>;
        query: func(sql: string, params: list<string>) -> result<list<list<string>>, string>;
        close: func();
    }

    resource transaction {
        begin: static func(conn: borrow<connection>) -> result<transaction, string>;
        commit: func() -> result<_, string>;
        rollback: func() -> result<_, string>;
    }
}

world database-client {
    import db;
}
```

## Shared Type Library

Define the shared types in their own package:

```wit
package my-org:types@0.1.0;

interface common {
    record timestamp {
        seconds: u64,
        nanos: u32,
    }

    variant status {
        ok,
        error(string),
        pending,
    }
}
```

Then `use` them from another package. Include the `@version` — resolution is
only deterministic when the version is explicit.

```wit
package my-org:service@0.1.0;

use my-org:types/common@0.1.0.{timestamp, status};

interface service {
    get-status: func() -> status;
    last-updated: func() -> timestamp;
}
```
