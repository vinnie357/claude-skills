# Module Resolution Deep Dive

`moduleResolution` strategies, the dual-package hazard, and subpath imports. Verified against the TypeScript Handbook's Modules Reference and the Node.js `packages` API docs — see `sources.md`.

## `moduleResolution` Strategies

| Value | Intended for | Extensionless paths | `exports`/`imports` support |
|---|---|---|---|
| `node10` (formerly `node`) | Legacy pre-v12 Node — deprecated | Yes | No |
| `node16` / `nodenext` | Any Node.js app or library, ESM or CJS | ESM: no. CJS: yes | Yes |
| `bundler` | webpack/esbuild/Vite/Rollup, Bun, tsx — anything where a bundler (not `tsc`) does the actual module resolution and emit | Yes | Yes |

`node16`/`nodenext` mirror Node's actual runtime resolution rules exactly, including the parts that are inconvenient in a TypeScript-first workflow — no extensionless ESM imports, no implicit `/index.js` directory resolution for ESM. That strictness is deliberate: it prevents `tsc` from accepting an import path Node itself would reject at runtime.

`bundler` relaxes those rules to match what bundlers actually support (extensionless imports, directory index resolution) because the bundler — not `tsc` — performs the real resolution and emit; `tsc` under `bundler` mode is typically run with `noEmit: true` purely for type-checking.

Match this setting to where the code actually runs, not to habit: a library published to npm and executed by Node needs `nodenext`; a frontend app built by Vite needs `bundler`.

## The Dual Package Hazard

Occurs when a package ships separate entry points for `require()` (CommonJS) and `import` (ESM) via conditional `exports`:

```json
{
  "exports": {
    "import": "./index.mjs",
    "require": "./index.cjs"
  }
}
```

If a single application ends up loading the package through **both** paths — one dependency imports it via ESM, another (or the app itself) requires it via CJS — Node instantiates the module **twice**, once per entry point. Two separate module instances mean two separate copies of any module-level state: a singleton, a cache, a class whose `instanceof` checks now fail across the two copies, a registry pattern that silently splits in half.

Mitigations, roughly in order of preference:

1. **Keep the package stateless at the module level.** No top-level singletons, no module-level mutable caches. If there's no shared state to duplicate, dual instantiation is harmless.
2. **Make the CJS entry point a thin wrapper that re-exports the ESM implementation**, so there's only one real implementation and one place state can live — common in packages that publish CJS purely for backward compatibility with older Node consumers.
3. **Publish ESM-only** where the audience can bear it (a library targeting only current Node/bundler consumers) — no dual entry, no hazard, at the cost of dropping older CJS-only consumers.

This is the concrete, load-bearing reason the Node module skill in this plugin defaults new projects to `"type": "module"` rather than shipping dual CJS/ESM by default: dual publishing solves a real compatibility problem but introduces this hazard as its cost, so it should be a deliberate choice for a library maintaining broad compatibility, not the default for an application.

## Subpath Imports (`#internal/*`)

The `imports` field (distinct from `exports`) maps internal-only import specifiers, always prefixed with `#` to disambiguate them from external package names:

```json
{
  "imports": {
    "#config": {
      "node": "./src/config.node.js",
      "default": "./src/config.browser.js"
    }
  }
}
```

```typescript
import { getConfig } from "#config"; // resolves per-condition, per the map above
```

Two things `imports` does that `exports` cannot:

- It is private to the package — nothing outside the package can import through an `#`-prefixed specifier, where `exports` entries are the package's public surface.
- It can map to an **external** package, not just an internal file — useful for swapping a Node-native dependency for a browser polyfill of the same internal import path, letting the rest of the codebase `import` one specifier regardless of which environment it runs in.

Reach for `imports` when a module needs an environment-conditional internal dependency (Node-native vs. polyfill) and the goal is to keep that branching out of every call site — the call sites stay a single, unconditional `import "#config"`.
