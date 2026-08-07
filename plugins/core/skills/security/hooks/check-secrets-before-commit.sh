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

# Export staged content, unstaged tracked-file modifications, AND
# untracked new files (claude-skills-271 mechanisms 2 and A1). Three
# separate export passes, into three separate subdirectories, all scanned:
#
#   staged/<file>    -- the INDEX content (`git show ":$file"`), i.e. what a
#                        plain `git commit` (no -a, no pathspec) would commit.
#   unstaged/<file>  -- the WORKING-TREE content of tracked files with
#                        pending modifications, i.e. what `git commit -a` /
#                        `-am` / `git commit <pathspec> -m` would ALSO pick
#                        up and commit. `git diff --cached` alone cannot see
#                        this: -a/pathspec stage their changes AS PART OF the
#                        commit itself, which has not happened yet at the
#                        moment this PreToolUse hook fires — before the
#                        intercepted command runs, the index still reflects
#                        only what was `git add`ed earlier.
#   untracked/<file> -- BRAND-NEW files never `git add`ed at all (Gate 3
#                        A1). Invisible to BOTH passes above — verified
#                        directly, neither `git diff --cached --name-only`
#                        nor `git diff --name-only` lists a file git has
#                        never seen before. `git add . && git commit` (this
#                        repo's own prescribed workflow) and `git add -A`
#                        stage exactly this shape, and a brand-new file is
#                        the most common way a secret enters a repo (a
#                        dumped key, a generated config, `.env.local`).
#                        `--exclude-standard` keeps gitignored files out —
#                        do not drop it, or a real `.env` a developer
#                        deliberately gitignored gets scanned, which
#                        claude-skills-268 decided against (worse than the
#                        leak this hook exists to prevent).
#
# All three passes run regardless of which staging form the intercepted
# command actually uses — the hook cannot always tell from the command
# string alone, and scanning a superset is the "fail toward scanning"
# direction: extra scanned content costs seconds, a missed one is the
# defect being fixed. A file present in more than one pass (e.g. staged
# content differs from a further working-tree edit) is intentionally
# exported to each path rather than merged/deduped, so a secret sitting in
# ANY version is caught.
#
# `-z` (NUL-terminated, unquoted paths) into `read -r -d ''` piped directly
# via process substitution, never through an intermediate bash variable:
# bash strings are NUL-terminated internally, so `VAR=$(git ... -z)` would
# silently truncate at the first embedded NUL and lose every filename after
# the first. `-z` also sidesteps git's quoted-path output entirely for
# non-ASCII filenames (e.g. `café.txt` -> literal `"caf\303\251.txt"` under
# plain --name-only, which `git show ":$file"` then fails to resolve,
# silently exporting a 0-byte file that `|| true` swallows).
#
# HAS_EXPECTED_CONTENT (Gate 3 A2): tracked alongside FILES_FOUND, using
# git/filesystem METADATA independent of whatever the export step above
# actually produces. A staged deletion (`git rm`) is LISTED by `git diff
# --cached --name-only` but has no blob in the index at all
# (`git cat-file -e` fails) — `git show ":$file"` correctly fails and
# `|| true` leaves nothing exported, and that is not a bug, there is
# nothing there. A staged/tracked file that legitimately has zero bytes
# exports to a genuine 0-byte file, also not a bug. Both must ALLOW the
# commit, not block it — but the invariant checked further down cannot
# tell "nothing was there to begin with" apart from Part 7/8's actual
# defect (real content that silently failed to export) by looking at
# gitleaks' scan summary alone, because BOTH situations produce the exact
# same "scanned ~0 bytes" outcome. The metadata check below answers the
# question the byte count can't: independent of the export, did any listed
# path actually have content to give? If none did, there is nothing for
# gitleaks to meaningfully verify and the invariant is skipped entirely
# (see the check after this section). If at least one path SHOULD have had
# content, the strict invariant applies exactly as before — this still
# catches a real future export bug, because the metadata check runs BEFORE
# and INDEPENDENT of the export attempt, not by trusting the export's own
# result.
FILES_FOUND=0
HAS_EXPECTED_CONTENT=0

log_info "Exporting staged files..."
while IFS= read -r -d '' file; do
    [[ -z "$file" ]] && continue
    FILES_FOUND=1
    mkdir -p "$TEMP_DIR/staged/$(dirname "$file")"
    git show ":$file" > "$TEMP_DIR/staged/$file" 2>/dev/null || true
    if git cat-file -e ":$file" 2>/dev/null; then
        BLOB_SIZE=$(git cat-file -s ":$file" 2>/dev/null || echo 0)
        [[ "$BLOB_SIZE" -gt 0 ]] && HAS_EXPECTED_CONTENT=1
    fi
done < <(git diff --cached --name-only -z 2>/dev/null || true)

log_info "Exporting unstaged tracked-file modifications (covers -a/pathspec commits)..."
while IFS= read -r -d '' file; do
    [[ -z "$file" ]] && continue
    if [[ -f "$file" ]]; then
        FILES_FOUND=1
        mkdir -p "$TEMP_DIR/unstaged/$(dirname "$file")"
        cp "$file" "$TEMP_DIR/unstaged/$file" 2>/dev/null || true
        [[ -s "$file" ]] && HAS_EXPECTED_CONTENT=1
    fi
done < <(git diff --name-only -z 2>/dev/null || true)

# Runs unconditionally, same as the two passes above -- NOT gated on the
# command string containing "add". An earlier version of this fix gated
# this pass on `$COMMAND == *add*`, reasoning that `git add` (in some form)
# is the only git operation that can put a brand-new untracked file into a
# commit. That reasoning about WHAT git can do was correct; using the
# command STRING to decide it was not, and was disproved directly: `git
# stage` is a real built-in synonym for `git add` (`git stage newfile.txt`
# actually stages the file) and contains no substring "add" at all, so the
# gate silently skipped this entire pass for `git stage . && git commit`
# and reintroduced the exact bypass it was meant to close
# (claude-skills-271 Gate 3, new Part 14). Matching a command STRING to
# decide export COVERAGE is the same primitive claude-skills-271's original
# defect (mechanism 1) proved unreliable, one layer down -- there is always
# another synonym or wrapper. `--exclude-standard` still keeps a gitignored
# `.env` out regardless (claude-skills-268); the `.gitignore` false-block
# this gate was originally added to work around turned out to be the test
# fixture's own artifact (it created `.gitignore` untracked, so the pass
# self-listed it) rather than a reason to scope this pass at all -- fixed
# on the fixture side, not here.
log_info "Exporting untracked new files (covers \`git add\`/\`git stage\`/pathspec commits of brand-new files)..."
while IFS= read -r -d '' file; do
    [[ -z "$file" ]] && continue
    if [[ -f "$file" ]]; then
        FILES_FOUND=1
        mkdir -p "$TEMP_DIR/untracked/$(dirname "$file")"
        cp "$file" "$TEMP_DIR/untracked/$file" 2>/dev/null || true
        [[ -s "$file" ]] && HAS_EXPECTED_CONTENT=1
    fi
done < <(git ls-files --others --exclude-standard -z 2>/dev/null || true)

# NO fourth pass here for force-added ignored files (claude-skills-272,
# reverted in round 4 -- do not re-add one without reading this).
#
# `git add -f <gitignored-path> && git commit` in a SINGLE compound
# command reaches this hook before the add has actually run, so the
# gitignored file is still untracked+excluded at the moment every pass
# above is evaluated -- none of them, correctly, ever see it. Two
# successive attempts to widen the export for this case were tried and
# both were defeated by a real false positive, not a theoretical one:
#
#   Round 1: `[[ "$COMMAND" == *-f* ]]` -- bare substring anywhere in the
#   command. Matched "-f" inside ANY unrelated long option starting with
#   "f": `git commit --fixup=HEAD` and `git commit --file=<path>` both
#   contain the literal two characters "-f" and both incorrectly triggered
#   a scan (and block) of a gitignored `.env` with a real secret that was
#   never being force-added at all.
#
#   Round 2: `[[ "$COMMAND" =~ (^|[[:space:]])(-f|--force)([[:space:]]|$) ]]`
#   -- tightened to a whitespace-bounded TOKEN instead of a bare
#   substring, closing round 1's exact failure. Still defeated: `rm -f
#   tmp.txt && git commit`, `grep -f patterns.txt file && git commit`,
#   `docker build -f Dockerfile . && git commit`, and `tar -x -f a.tar &&
#   git commit` all contain a perfectly well-formed standalone `-f` token
#   that belongs to `rm`/`grep`/`docker`/`tar`, not `git add` -- token
#   matching answers "is `-f` a token anywhere in this command?", never
#   "whose flag is it?", and attributing a flag to a specific subcommand
#   needs real argument parsing, not string matching.
#
# Operator decision: abandon the widening rather than try a third
# predicate. The pass had NO --exclude-standard by design (the whole
# point was to include what that flag hides), so every false trigger
# scanned every gitignored file in the repo, not just one -- the
# over-trigger direction is not a minor cost here, unlike the
# fail-toward-scanning detection regex at the top of this script.
#
# The residual gap is narrow and stays open, documented rather than
# chased: a SEPARATE `git add -f <path>` followed by a distinct `git
# commit` is already caught by the staged-files pass above, because the
# file is genuinely in the index by the time this hook fires (still
# verified working -- see test/validate-security-hook.nu Part 20). Only
# the single-command compound form escapes, and only when the file is
# both gitignored/excluded AND force-added AND committed in one command.
# test/validate-security-hook.nu Parts 15-17 pin this as an accepted,
# documented limitation; Parts 22-24 remain as regression guards against
# a third predicate reintroducing round 1 or round 2's exact failure.

if [[ "$FILES_FOUND" -eq 0 ]]; then
    log_info "No staged, modified-tracked, or new untracked files to scan"
    exit 0
fi

if [[ "$HAS_EXPECTED_CONTENT" -eq 0 ]]; then
    # Every listed path was a deletion or a genuinely empty file (Gate 3
    # A2) -- nothing for gitleaks to meaningfully verify, so the
    # bytes-invariant below is skipped rather than blocking a routine
    # `git rm` or an empty-file commit on the same "scanned ~0 bytes"
    # shape Part 7/8's real defect produces.
    log_info "Listed paths are deletions/empty files only — nothing to scan"
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

# Never report clean without evidence something was actually scanned.
# Ported verbatim from scripts/gitleaks.sh's gitleaks_verified_clean
# (claude-skills-271 mechanism 3 -- this hook was the one implementation in
# the PR #246/#247 chain that never gained this invariant: it trusted exit
# code 0 alone, so a scan that covered zero bytes -- for any reason,
# including the non-ASCII export bug this same fix closes -- still reported
# "No secrets detected"). An explicit parsed zero AND an unparseable/missing
# summary are both treated as NOT verified-clean -- "no evidence is not
# innocence" is the conclusion scripts/gitleaks.nu / gitleaks.sh / the
# template's shared invariant reached over six PR #246 review rounds
# (claude-skills-267 Gate 3 R2/R6/T2/T4/U3), and this hook now matches it
# exactly rather than the narrower explicit-zero-only rule an earlier
# version of this fix used. That narrower rule existed only because two
# pre-existing tests (the exit-0 case and the Part 5b control) exercised a
# gitleaks stub with unrealistic empty output; the test suite fixed those
# fixtures to emit realistic scan-summary text instead of the hook
# weakening the invariant to match them (claude-skills-271 Gate 3, "your
# escalation was right"). Does NOT guarantee the requested scan scope was
# covered (gitleaks' git-mode / dir-mode semantics are unrelated to this
# check) -- see scripts/gitleaks.sh's parse_scanned_bytes comment for the
# full explanation.
gitleaks_verified_clean() {
    local stderr_text="$1"
    local bytes
    bytes="$(parse_scanned_bytes "$stderr_text")"
    [[ -n "$bytes" ]] && [[ "$bytes" -gt 0 ]]
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
    # gitleaks_verified_clean above: an explicit zero-byte report AND an
    # unparseable/missing summary both fail this check). Distinct marker
    # from real detection, matching scripts/gitleaks.sh/gitleaks.nu's split
    # (claude-skills-267 Gate 3 R5): printing "SECRETS DETECTED" when
    # nothing was actually detected would itself be a fabricated claim.
    if ! gitleaks_verified_clean "$STDERR_CONTENT"; then
        log_error "Scan unverified!"
        log_error "gitleaks reported success but scanned 0 bytes (or the scan summary could not be parsed) — refusing to report clean without evidence something was actually scanned."
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
