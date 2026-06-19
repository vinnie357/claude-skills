# whamm Installation Reference

## mise github backend (preferred)

The mise `github` backend installs tools directly from GitHub release assets. No plugin required — built into mise.

### Template stanzas

```toml
[tools."github:ejrgilbert/whamm"]
version = "0.1.0"

[tools."github:ejrgilbert/whamm".platforms]
linux-x64   = { asset_pattern = "whamm-linux-x86_64" }
macos-x64   = { asset_pattern = "whamm-macos-x86_64" }
macos-arm64 = { asset_pattern = "whamm-macos-x86_64" }
```

**How `asset_pattern` works.** mise downloads the release asset whose filename matches the pattern string. v0.1.0 assets are bare binaries (no archive): `whamm-linux-x86_64` and `whamm-macos-x86_64`. The pattern must be an exact substring match or glob against the asset filename.

**x86_64 only.** v0.1.0 (2026-03-04) ships two assets — Linux x86_64 and macOS x86_64. No arm64 or Windows asset exists in this release. The `macos-arm64` platform entry maps to the x86_64 binary so mise does not fail on Apple Silicon; macOS runs it under Rosetta 2.

**Version pinning.** Pin to `"0.1.0"` explicitly. Use the `/claude-code:skill-update` skill to check for newer releases and bump the pin intentionally. Never set `version = "latest"` for a binary tool without a lock mechanism — silent upgrades can break scripts.

### Install and verify

```bash
mise install
whamm --help
```

Expected: the whamm help text prints without error.

### Rosetta 2 caveat

On Apple Silicon Macs, Rosetta 2 translates the x86_64 binary at runtime. To check whether Rosetta is available:

```bash
arch -x86_64 echo "rosetta ok"
```

If Rosetta is absent or you need a native arm64 binary, build from source (section below).

---

## Build from source

Build from source when:
- Running Apple Silicon without Rosetta 2
- Building `whamm_core.wasm` (required for the bytecode-rewriting runtime path)
- Developing whamm itself

### Prerequisites

- Rust toolchain via `rustup`
- `cargo`
- For `whamm_core.wasm`: the `wasm32-wasip1` target

### Steps

```bash
# Clone the repository
git clone https://github.com/ejrgilbert/whamm
cd whamm

# Debug build (faster compile, slower binary)
make

# Release build (includes whamm_core.wasm)
make release
```

The `make release` target:
1. Compiles the `whamm` CLI to `target/release/whamm`
2. Adds the `wasm32-wasip1` Rust target if absent
3. Builds `whamm_core` with `cargo build -p whamm_core --target wasm32-wasip1 --release`
4. Outputs `whamm_core.wasm` to `embedded/release/whamm_core.wasm`

### Post-build setup

```bash
# Add the binary to PATH (add to shell profile for persistence)
export PATH="$PWD/target/release:$PATH"

# Set WHAMM_HOME to the repository root
export WHAMM_HOME="$PWD"
```

`WHAMM_HOME` tells whamm where to find `whamm_core.wasm` and related embedded assets.

### Building whamm_core separately

If you already have the whamm binary but need `whamm_core.wasm`:

```bash
rustup target add wasm32-wasip1
cargo build -p whamm_core --target wasm32-wasip1 --release
# Output: embedded/release/whamm_core.wasm
```

---

## Prebuilt binary and whamm_core.wasm

The prebuilt release binary (`whamm-linux-x86_64`, `whamm-macos-x86_64`) does NOT include `whamm_core.wasm` as a separate downloadable asset in v0.1.0. `whamm_core.wasm` is required at runtime for the bytecode-rewriting path when `TO_CONSOLE=true` output is used. Build from source to obtain it.

---

## Verification

```bash
# Confirm whamm is on PATH and responds
whamm --help

# Inspect bound variables for a specific event rule
whamm info -fv --rule "wasm:opcode:i32.load:before"
```

The `info` command lists which variables are bound at the given probe site. If whamm is installed correctly, it prints a table of variable names and types; it does not require a `.wasm` file at this stage.
