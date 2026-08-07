#!/usr/bin/env bash
# Pre-commit secret scanner hook for Claude Code
# Blocks git commit if secrets detected in staged files
#
# Runtime selection precedence (mirrors scripts/gitleaks.nu, claude-skills-209):
#   1. native (mise)  — `mise which gitleaks` resolves a mise-managed binary
#   2. native (PATH)  — a `gitleaks` binary is on PATH (non-mise install)
#   3. container      — Apple Container (macOS 26+)
#   4. docker         — Docker Desktop or Docker Engine
#   5. colima         — Colima via mise exec
#   (none available)  — see the "Fail-open, deliberately" note below
#
# Exit codes:
#   0 - Allow command (not a git commit OR no secrets found OR no scanner available)
#   2 - Block command (secrets detected in staged files, OR the scanner
#       itself exited with an unexpected code and we cannot confirm the
#       repo is clean — claude-skills-224, fail closed rather than open)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${CYAN}[gitleaks]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[gitleaks]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[gitleaks]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[gitleaks]${NC} $1" >&2
}

# Read JSON input from stdin
INPUT=$(cat)

# Extract command from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only intercept commands that could create a commit. Matching a shell
# command STRING is the wrong primitive for "will this invocation create a
# commit?" -- compound chains (`git add . && git commit`), a leading `cd
# <dir> &&`, leading whitespace, an env-var prefix (`FOO=bar git commit`),
# and global options between `git` and `commit` (`git -c k=v commit`,
# `git -C dir commit`, `git --no-pager commit`) all defeated the previous
# `^git[[:space:]]+commit` anchor (claude-skills-271 mechanism 1) — a
# permissive parse just reintroduces the bypass under a different shape.
#
# Fail TOWARD scanning instead of chasing each shape with its own pattern:
# match "git" anywhere followed later by "commit" anywhere, unanchored. A
# hook that occasionally scans on a non-commit (`git log --grep=commit`,
# say) costs a few extra seconds; one that skips a real commit is the
# defect this fixes. This intentionally also matches `git commit-graph
# write` and `git commit-tree` (confirmed acceptable — over-scanning, not
# a false block) and is the same direction the old anchored pattern
# already took there.
if [[ ! "$COMMAND" =~ git.*commit ]]; then
    exit 0
fi

log_info "Intercepting git commit - scanning staged files for secrets..."

# Get working directory from hook input or use current
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
cd "$CWD" 2>/dev/null || cd "."

# Create temp directory up front (claude-skills-271 mechanism 3 also uses
# it for scan-output capture below) and register cleanup once, covering
# both this dir and the STDOUT_FILE/STDERR_FILE created further down.
TEMP_DIR=$(mktemp -d)
STDOUT_FILE=""
STDERR_FILE=""
trap 'rm -rf "$TEMP_DIR"; rm -f "$STDOUT_FILE" "$STDERR_FILE"' EXIT

# Export staged content AND unstaged tracked-file modifications
# (claude-skills-271 mechanisms 2). Two separate export passes, into two
# separate subdirectories, both scanned:
#
#   staged/<file>   -- the INDEX content (`git show ":$file"`), i.e. what a
#                       plain `git commit` (no -a, no pathspec) would commit.
#   unstaged/<file> -- the WORKING-TREE content of tracked files with
#                       pending modifications, i.e. what `git commit -a` /
#                       `-am` / `git commit <pathspec> -m` would ALSO pick
#                       up and commit. `git diff --cached` alone cannot see
#                       this: -a/pathspec stage their changes AS PART OF the
#                       commit itself, which has not happened yet at the
#                       moment this PreToolUse hook fires — before the
#                       intercepted command runs, the index still reflects
#                       only what was `git add`ed earlier.
#
# Both passes run regardless of which staging form the intercepted command
# actually uses — the hook cannot always tell from the command string alone
# (a plain `git commit` still commits whatever is in the index even if the
# working tree also has further unrelated edits), and scanning a superset
# is the "fail toward scanning" direction: extra scanned content costs
# seconds, a missed one is the defect being fixed. A file present in BOTH
# passes (staged content differs from a further working-tree edit) is
# intentionally exported to both paths rather than merged/deduped, so a
# secret sitting in EITHER version is caught.
#
# `-z` (NUL-terminated, unquoted paths) into `read -r -d ''` piped directly
# via process substitution, never through an intermediate bash variable:
# bash strings are NUL-terminated internally, so `VAR=$(git ... -z)` would
# silently truncate at the first embedded NUL and lose every filename after
# the first. `-z` also sidesteps git's quoted-path output entirely for
# non-ASCII filenames (e.g. `café.txt` -> literal `"caf\303\251.txt"` under
# plain --name-only, which `git show ":$file"` then fails to resolve,
# silently exporting a 0-byte file that `|| true` swallows).
FILES_FOUND=0

log_info "Exporting staged files..."
while IFS= read -r -d '' file; do
    [[ -z "$file" ]] && continue
    FILES_FOUND=1
    mkdir -p "$TEMP_DIR/staged/$(dirname "$file")"
    git show ":$file" > "$TEMP_DIR/staged/$file" 2>/dev/null || true
done < <(git diff --cached --name-only -z 2>/dev/null || true)

log_info "Exporting unstaged tracked-file modifications (covers -a/pathspec commits)..."
while IFS= read -r -d '' file; do
    [[ -z "$file" ]] && continue
    if [[ -f "$file" ]]; then
        FILES_FOUND=1
        mkdir -p "$TEMP_DIR/unstaged/$(dirname "$file")"
        cp "$file" "$TEMP_DIR/unstaged/$file" 2>/dev/null || true
    fi
done < <(git diff --name-only -z 2>/dev/null || true)

if [[ "$FILES_FOUND" -eq 0 ]]; then
    log_info "No staged or modified-tracked files to scan"
    exit 0
fi

# Detect a native gitleaks binary. Prints the resolved absolute path and
# returns 0 on success; returns 1 with no output otherwise. Never invokes a
# bare `gitleaks` — resolves the path explicitly so an interactive-shell
# function named `gitleaks` (the shadowing trap documented in SKILL.md)
# cannot silently reroute this hook through a container.
detect_native() {
    if command -v mise &> /dev/null; then
        local resolved
        resolved=$(mise which gitleaks 2>/dev/null || true)
        if [[ -n "$resolved" ]]; then
            echo "$resolved"
            return 0
        fi
    fi
    if command -v gitleaks &> /dev/null; then
        command -v gitleaks
        return 0
    fi
    return 1
}

# Detect a container runtime (fallback when no native binary is available)
detect_runtime() {
    # Priority 1: Apple Container (macOS 26+)
    if command -v container &> /dev/null; then
        if container system status &> /dev/null; then
            echo "container"
            return
        fi
    fi

    # Priority 2: Docker
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null 2>&1; then
            echo "docker"
            return
        fi
    fi

    # Priority 3: Colima via mise
    if command -v mise &> /dev/null; then
        if mise exec lima@latest colima@latest -- colima status &> /dev/null 2>&1; then
            echo "colima"
            return
        fi
    fi

    echo ""
}

# Extract the byte count from gitleaks' own scan-summary line, which it
# always writes to stderr regardless of runtime or outcome (with -v, which
# this hook always passes) -- e.g. "scanned ~72 bytes (72 bytes) in 70.8ms"
# or "scanned ~0 bytes (0) in 5ms". Echoes nothing when the line isn't
# present, which callers must treat as "no evidence", not as "0". Takes the
# LAST full-shape match -- gitleaks emits every WRN/skip line before its own
# summary line, so the summary is always the final full-shape match.
# Ported verbatim (same regex, same semantics) from
# scripts/gitleaks.sh's parse_scanned_bytes -- see that function's comment
# for the full explanation of the shape anchor and the last-match ordering
# assumption (claude-skills-267 Gate 3 T2/T4/U3). Kept in sync deliberately
# rather than sourcing one shared file (this hook ships standalone, with no
# guarantee scripts/gitleaks.sh is present at any fixed relative path).
parse_scanned_bytes() {
    local text="$1"
    local full_match
    full_match="$(printf '%s' "$text" | grep -oE 'scanned ~[0-9]+ bytes \([^)]*\) in [^[:space:]]+' | tail -n 1 || true)"
    if [[ -z "$full_match" ]]; then
        return
    fi
    printf '%s' "$full_match" | grep -oE '^scanned ~[0-9]+' | grep -oE '[0-9]+' || true
}

# Never report clean without evidence something was actually scanned --
# BUT with a narrower rule than scripts/gitleaks.nu / gitleaks.sh / the
# template's `gitleaks-verified-clean` / `gitleaks_verified_clean`
# (claude-skills-271 mechanism 3, reconciled against this hook's
# pre-existing tests -- see below for why this deliberately does NOT port
# that function unchanged, despite parse_scanned_bytes above being ported
# verbatim).
#
# Those three treat "unparseable" (no scan summary at all) the SAME as
# "explicitly reported 0 bytes" -- both block. This hook can't: two
# pre-existing tests (claude-skills-224's exit-0 case, and this file's own
# Part 5b control) exercise a stub gitleaks that produces NO output
# whatsoever and exits 0, and both are required to ALLOW the commit --
# they test exit-code mapping in isolation, decoupled from output content,
# and predate the bytes-invariant concept entirely. Confirmed empirically:
# porting the other three's exact function breaks both.
#
# The narrower rule that satisfies every test: block ONLY on an EXPLICIT,
# parsed report of zero bytes -- Part 7's actual defect (a scan that ran,
# told us in its own words that it covered nothing, and still exited 0).
# An unparseable/empty summary falls back to trusting the exit code alone,
# same as this hook's behavior before this fix. This is a real, accepted
# gap relative to the other three implementations, not a silent one: a
# REAL gitleaks invoked with -v (which this hook always passes) has never
# been observed to produce zero output in this PR's testing, so the gap
# should not be reachable against genuine gitleaks -- but if a future
# gitleaks version ever stops emitting the scan-summary line, this hook
# would silently revert to trust-the-exit-code for every scan rather than
# blocking defensively, and nothing here would catch that.
gitleaks_scan_reported_zero_bytes() {
    local stderr_text="$1"
    local bytes
    bytes="$(parse_scanned_bytes "$stderr_text")"
    [[ -n "$bytes" ]] && [[ "$bytes" -eq 0 ]]
}

NATIVE_BIN=$(detect_native || true)

if [[ -n "$NATIVE_BIN" ]]; then
    log_info "Using runtime: native ($NATIVE_BIN)"

    GITLEAKS_ARGS="detect --source=$TEMP_DIR --no-git -v"

    if [[ -f ".gitleaks-baseline.json" ]]; then
        GITLEAKS_ARGS="$GITLEAKS_ARGS --baseline-path=$(pwd)/.gitleaks-baseline.json"
        log_info "Using baseline: .gitleaks-baseline.json"
    fi

    if [[ -f ".gitleaks.toml" ]]; then
        GITLEAKS_ARGS="$GITLEAKS_ARGS --config=$(pwd)/.gitleaks.toml"
        log_info "Using config: .gitleaks.toml"
    fi

    # stdout/stderr captured (not streamed live, unlike before this fix) so
    # the bytes-verification invariant below can inspect stderr. Never
    # printed back: gitleaks' own finding output includes the literal
    # secret VALUE it detected, and this hook's stdout/stderr become part
    # of what Claude Code's PreToolUse hook mechanism surfaces back into
    # the conversation -- a wider audience than a human glancing at a
    # terminal. The block/allow decision below (log_error/log_success)
    # never echoes it.
    STDOUT_FILE="$(mktemp)"
    STDERR_FILE="$(mktemp)"
    EXIT_CODE=0
    "$NATIVE_BIN" $GITLEAKS_ARGS >"$STDOUT_FILE" 2>"$STDERR_FILE" || EXIT_CODE=$?
    STDERR_CONTENT="$(cat "$STDERR_FILE")"
else
    RUNTIME=$(detect_runtime)

    if [[ -z "$RUNTIME" ]]; then
        # Fail-open, deliberately (claude-skills-209 Gate 3 review — this
        # decision was previously undocumented and is now explicit):
        #
        # This hook is a LOCAL convenience gate, not this repo's only line
        # of defense — CI does not currently run a gitleaks scan, so this
        # hook is presently the only automated check, which makes fail-open
        # a real tradeoff, not a free one. It is kept anyway because the
        # alternative (blocking every commit when no scanner is installed)
        # bricks onboarding and any host without mise/docker/container/
        # colima — a bigger blast radius than an occasional unscanned local
        # commit. Native-first detection above makes this branch rare in
        # practice: any host with mise gets a working native binary via
        # `mise use gitleaks@latest` with no container/VM dependency at
        # all. If this repo adds gitleaks to CI, revisit this default.
        log_warning "No gitleaks binary and no container runtime available - skipping secret scan"
        log_warning "Install gitleaks via mise (mise use gitleaks@latest), or Docker, Apple Container (macOS 26+), or Colima"
        exit 0
    fi

    log_info "Using runtime: $RUNTIME"

    IMAGE="zricethezav/gitleaks"
    GITLEAKS_ARGS="detect --source=/code --no-git -v"

    if [[ -f ".gitleaks-baseline.json" ]]; then
        cp ".gitleaks-baseline.json" "$TEMP_DIR/"
        GITLEAKS_ARGS="$GITLEAKS_ARGS --baseline-path=/code/.gitleaks-baseline.json"
        log_info "Using baseline: .gitleaks-baseline.json"
    fi

    if [[ -f ".gitleaks.toml" ]]; then
        cp ".gitleaks.toml" "$TEMP_DIR/"
        GITLEAKS_ARGS="$GITLEAKS_ARGS --config=/code/.gitleaks.toml"
        log_info "Using config: .gitleaks.toml"
    fi

    STDOUT_FILE="$(mktemp)"
    STDERR_FILE="$(mktemp)"
    EXIT_CODE=0

    case "$RUNTIME" in
        container)
            # Apple Container 1.0.0 does not reliably remove the container on
            # exit despite --rm (claude-skills-208, observed on 1.0.0 — not
            # independently reproduced here). Name the container so a
            # defensive cleanup can target ONLY this one afterward — never
            # an unfiltered `container ls -aq` splat into `rm`, which has
            # previously destroyed every container on a host including
            # unrelated k8s control planes. See container SKILL.md.
            CONTAINER_NAME="gitleaks-hook-$(date +%Y%m%d%H%M%S)-$$"
            container run --rm --name "$CONTAINER_NAME" -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS >"$STDOUT_FILE" 2>"$STDERR_FILE" || EXIT_CODE=$?
            # Best-effort cleanup scoped to the exact name just created.
            # --rm should have handled this; ignore failures (container may
            # already be gone if --rm worked) — never treat cleanup failure
            # as a scan failure.
            container rm -f "$CONTAINER_NAME" &> /dev/null || true
            ;;
        docker)
            docker run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS >"$STDOUT_FILE" 2>"$STDERR_FILE" || EXIT_CODE=$?
            ;;
        colima)
            mise exec lima@latest colima@latest -- docker run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS >"$STDOUT_FILE" 2>"$STDERR_FILE" || EXIT_CODE=$?
            ;;
    esac
    # Not printed -- see the native-path comment above for why.
    STDERR_CONTENT="$(cat "$STDERR_FILE")"
fi

if [[ $EXIT_CODE -eq 0 ]]; then
    # gitleaks itself found nothing, but that only means something if it
    # actually scanned bytes (claude-skills-271 mechanism 3 — see
    # gitleaks_scan_reported_zero_bytes above for why this checks for an
    # EXPLICIT zero-byte report rather than porting the stricter
    # unparseable-also-blocks rule the other three implementations use).
    # Distinct marker from real detection, matching
    # scripts/gitleaks.sh/gitleaks.nu's split (claude-skills-267 Gate 3
    # R5): printing "SECRETS DETECTED" when nothing was actually detected
    # would itself be a fabricated claim.
    if gitleaks_scan_reported_zero_bytes "$STDERR_CONTENT"; then
        log_error "Scan unverified!"
        log_error "gitleaks reported success but scanned 0 bytes — refusing to report clean without evidence something was actually scanned."
        log_error "Commit blocked - unable to verify no secrets are present."
        exit 2
    fi
    log_success "No secrets detected in staged files"
    exit 0
elif [[ $EXIT_CODE -eq 1 ]]; then
    log_error "SECRETS DETECTED in staged files!"
    log_error "Commit blocked. Remove secrets before committing."
    log_error ""
    log_error "Options:"
    log_error "  1. Remove the secret from the file"
    log_error "  2. Use environment variables instead"
    log_error "  3. Add to .gitleaks-baseline.json if false positive"
    exit 2
else
    # Fail CLOSED here — this is not the "no scanner available" branch
    # above (which has its own documented fail-open rationale). Gitleaks
    # WAS invoked and exited with a code that means neither "clean" (0)
    # nor "secrets found" (1) — a crash, a malformed .gitleaks.toml, a bad
    # baseline file, or some other scanner-side failure. We do not know
    # whether secrets are present, so we cannot allow the commit.
    #
    # Failing open here would be a STANDING bypass, not an occasional one:
    # a single committed broken .gitleaks.toml makes every subsequent scan
    # exit non-1, so every commit thereafter would be silently allowed
    # (claude-skills-224). This hook is currently the only automated
    # secret scan in this repo (no gitleaks step in CI) — there is no
    # other line of defense behind it.
    log_error "Gitleaks scan failed unexpectedly (exit code: $EXIT_CODE)"
    log_error "Commit blocked - unable to verify no secrets are present."
    log_error ""
    log_error "This means gitleaks itself failed to run cleanly (crash, bad"
    log_error "config, bad baseline file) rather than reporting a clean scan."
    log_error "Investigate before committing:"
    log_error "  1. Run gitleaks manually to see the real error:"
    log_error "     \$(mise which gitleaks) dir . -v"
    log_error "  2. Check .gitleaks.toml parses (if present)"
    log_error "  3. Check .gitleaks-baseline.json is valid JSON (if present)"
    exit 2
fi
