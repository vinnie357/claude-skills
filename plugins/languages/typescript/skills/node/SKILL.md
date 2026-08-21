---
name: node
description: Guide for the Node.js runtime in TypeScript projects. Use when working with async/await and Promises, reading or writing streams, choosing between ESM and CommonJS, configuring package.json exports, picking npm/pnpm/bun, managing Node versions with mise, or wiring Node CI/CD.
license: MIT
---

# Node.js Runtime

Async patterns, streams, module systems, package managers, and mise/CI integration for Node.js TypeScript projects.

## Async Patterns

### async/await over raw Promise chains

```typescript
async function fetchUserAndPosts(userId: string) {
  const user = await fetchUser(userId);
  const posts = await fetchPosts(user.id);
  return { user, posts };
}
```

Prefer `await` in sequence over `.then()` chains for anything with more than one step — the stack trace on a rejected `await` points at the actual failing line, where a long `.then()` chain's error frequently doesn't.

### Concurrency with `Promise.all` / `Promise.allSettled`

Sequential `await` calls that don't depend on each other's results waste wall-clock time — run independent async work concurrently:

```typescript
// Sequential — unnecessarily slow if these don't depend on each other
const user = await fetchUser(id);
const settings = await fetchSettings(id);

// Concurrent — same total work, shorter wall time
const [user, settings] = await Promise.all([fetchUser(id), fetchSettings(id)]);
```

`Promise.all` rejects as soon as any one input rejects, discarding the other results. `Promise.allSettled` never rejects — it resolves with a `{ status: "fulfilled" | "rejected", ... }` record per input, appropriate when partial failure is an expected, handled case (e.g. "notify five webhooks, report which ones failed") rather than a hard error.

### `EventEmitter`

Node's `EventEmitter` is the base of most non-stream async Node APIs (`process`, `net.Server`, `child_process`) — extend it for a custom object that fires multiple named events over its lifetime, as opposed to a Promise's single resolve/reject:

```typescript
import { EventEmitter } from "node:events";

class JobQueue extends EventEmitter {
  enqueue(job: Job) {
    // ...
    this.emit("enqueued", job);
  }
}

const queue = new JobQueue();
queue.on("enqueued", (job: Job) => console.log(`queued ${job.id}`));
```

Reach for `EventEmitter` for "zero or more things will happen over time, listeners subscribe/unsubscribe" — reach for a Promise for "exactly one thing happens once." Mixing the two (a Promise that also emits progress events) is a common source of Node API confusion; if progress reporting is needed, an `EventEmitter` combined with a distinct completion Promise (or an async generator) is clearer than overloading one Promise for both jobs.

## Streams

Four stream types, all `EventEmitter` subclasses under the hood:

| Type | Direction | Example |
|---|---|---|
| `Readable` | Data flows out | `fs.createReadStream()`, an HTTP response body |
| `Writable` | Data flows in | `fs.createWriteStream()`, `process.stdout` |
| `Duplex` | Both, independently | `net.Socket` |
| `Transform` | Both, output derived from input | `zlib.createGzip()` |

### Piping

```typescript
import { createReadStream, createWriteStream } from "node:fs";
import { createGzip } from "node:zlib";

createReadStream("input.txt")
  .pipe(createGzip())
  .pipe(createWriteStream("input.txt.gz"));
```

`.pipe()` is the default choice over manual `data`/`end` event listeners — it handles backpressure automatically, which manual event handling does not.

### Backpressure

A `Writable.write()` call returns `false` when its internal buffer is full — code writing directly (not through `.pipe()`) must pause until the stream's `'drain'` event fires, or memory grows unbounded on a fast producer / slow consumer:

```typescript
function writeAll(stream: NodeJS.WritableStream, data: string, done: () => void) {
  if (!stream.write(data)) {
    stream.once("drain", done);
  } else {
    process.nextTick(done);
  }
}
```

`stream.pipeline()` (from `node:stream/promises`) is the preferred modern API over chained `.pipe()` calls for anything that needs error propagation across the whole chain — a `.pipe()` chain does not automatically forward an error from an earlier stream to destroy later ones, `pipeline()` does.

## ESM vs CommonJS

### `"type"` field

```json
{ "type": "module" }
```

- `"module"` — `.js` files are ES modules (`import`/`export`)
- `"commonjs"` or omitted — `.js` files are CommonJS (`require`/`module.exports`)
- `.mjs` is always ESM and `.cjs` is always CommonJS, regardless of `"type"` — use the explicit extension when a package needs to ship both formats in adjacent files.

Default new projects to `"type": "module"` — ESM is where the Node and browser ecosystems converge, and `tsc --init` on a current TypeScript release defaults `"module"` to `"nodenext"`, which follows this field.

### `exports` field

`exports` is both an encapsulation boundary (only listed paths are importable from outside the package — deep imports into unlisted internal files fail) and the mechanism for dual ESM/CJS publishing via **conditional exports**:

```json
{
  "name": "my-package",
  "type": "module",
  "exports": {
    ".": {
      "import": "./dist/index.mjs",
      "require": "./dist/index.cjs"
    },
    "./utils": {
      "import": "./dist/utils.mjs",
      "require": "./dist/utils.cjs"
    }
  }
}
```

Node evaluates conditions in the **order they're written in the object** — first matching key wins, not some engine-enforced specificity ranking. Author them most-specific-first (`node-addons`, then `node`, then `import`/`require`, then `default` last) as a matter of convention, because listing a broader condition earlier would shadow every narrower one written after it and it would never be reached. `"default"` always goes last for the same reason: it matches everything, so anything after it is dead. Keep a top-level `"main"` pointing at the CJS build alongside `"exports"` only for consumers on Node versions old enough not to read `exports` — new projects that don't need that floor can rely on `exports` alone.

## Package Managers

| Tool | Reach for it when |
|---|---|
| **npm** | The default — ships with Node, needs no extra install, fine for most single-package projects |
| **pnpm** | A monorepo, or disk/install-speed matters — content-addressable store avoids per-project dependency duplication, and its non-flat `node_modules` (symlinks, not hoisting) catches undeclared-dependency bugs npm's flat hoisting hides |
| **Bun** | The whole toolchain (runtime + package manager + test runner + bundler) is being adopted, not just the installer — Bun's `bun install` is fast, but picking Bun-the-package-manager while running Node-the-runtime forfeits most of its advantage |

Bun ships as a single dependency-free binary combining a JavaScriptCore-based runtime (a drop-in Node replacement, still working toward full Node API parity), `bun install`, `bun test` (Jest-compatible), and `bun build`. It executes `.ts`/`.tsx` directly without a separate compile step. Node compatibility is an ongoing effort, not a guarantee — verify a specific Node API/package works under Bun before committing a production service to it, rather than assuming parity.

Restraint applies to this choice directly: don't add pnpm to a single-package project that npm already handles, and don't adopt Bun for one fast test runner when the rest of the deployment target is Node.

## mise Integration

```toml
# mise.toml
[tools]
node = "24"          # fuzzy — tracks the latest 24.x patch/minor
# node = "24.1.2"     # --pin exact, for reproducible CI

[tasks.dev]
run = "node --watch src/index.ts"

[tasks.build]
run = "tsc -p tsconfig.build.json"
```

Pin the Node major to whichever release is Active LTS at the time (see `sources.md` for the version verified for this skill) — new projects should not start on a Current (non-LTS) release line, since Current releases have a shorter support window and are more likely to carry breaking changes between minors. `mise install` inside a freshly cloned repo installs the pinned version with no separate `nvm`/`fnm` step, consistent with `/core:mise`'s "mise, not brew" convention for this workspace's tool management.

## CI/CD Patterns

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: jdx/mise-action@v3
      - run: mise run ci
```

Delegate to `mise run ci` from the CI workflow rather than duplicating individual `npm run lint` / `npm test` steps in YAML — the local and remote invocations then run the exact same command, so "passes locally, fails in CI" collapses to an environment difference (Node version, missing env var) instead of a command drift, per this workspace's `/core:git` Gate 2 discipline (local `mise run ci` green is a precondition for remote CI being meaningful, not a redundant check).

## Anti-fabrication

This skill follows `/core:anti-fabrication`. Stream types, backpressure behavior, and `exports`/`type` field semantics were verified against the Node.js API docs (`nodejs.org/api`) and the current Active LTS/Current release lines from `nodejs.org/en/about/previous-releases`; package manager claims were verified against each tool's own docs (pnpm.io, bun.sh/docs). See `sources.md` for exact pages and access dates. Bun's Node-compatibility status changes release to release — treat any specific "Bun supports X Node API" claim as needing a fresh check against `bun.sh/docs/runtime/nodejs-compat`, not this skill.

## References

- `references/module-resolution.md` — `moduleResolution` strategies (`node16`/`nodenext`/`bundler`), the dual-package hazard, and subpath import patterns (`#internal/*`)
