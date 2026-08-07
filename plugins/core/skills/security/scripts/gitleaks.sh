#!/usr/bin/env bash

# Gitleaks secret scanner with automatic native-binary detection and
# container runtime fallback (Docker, Apple Container macOS 26+, Colima via mise)
#
# Runtime selection precedence (mirrors scripts/gitleaks.nu):
#   1. native-mise   -- `mise which gitleaks` resolves a mise-managed binary
#   2. native-path    -- a `gitleaks` binary is on PATH (non-mise install)
#   3. container      -- Apple Container (macOS 26+)
#   4. docker         -- Docker Desktop or Docker Engine
#   5. colima         -- Colima via mise exec
#   (none available)  -- explicit error, never a silent/opaque failure

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
RUNTIME=""
REPORT=""
CONFIG=""
BASELINE=""
SCAN_PATH="."
VERBOSE=true
# Extra -v mount flags for the container run, populated when --config maps
# the caller's actual file into the container (see main()).
CONFIG_MOUNT=()

# Populated by run_gitleaks_native / run_gitleaks right before their
# subprocess call, and cleared via explicit `rm -f` right after (the
# normal-path cleanup, deliberately NOT a `trap ... RETURN` -- see the
# comment at that `rm -f` for why). Global, not `local`: this EXIT trap
# needs a name that survives whichever function is currently running, to
# catch the window between `mktemp` and that explicit cleanup -- e.g.
# Ctrl-C mid-scan (claude-skills-267 Gate 3 T5). `trap ... EXIT` fires
# exactly once, when the whole script exits, so it doesn't have the
# RETURN-trap refire problem; `rm -f` on empty/already-removed paths is a
# silent no-op.
STDOUT_FILE=""
STDERR_FILE=""
trap 'rm -f "$STDOUT_FILE" "$STDERR_FILE"' EXIT

print_help() {
    cat << 'EOF'
Gitleaks Secret Scanner

USAGE:
    gitleaks.sh [OPTIONS]

OPTIONS:
    -R, --runtime <RUNTIME>  Runtime: native, docker, container, colima
                             (auto-detects if not specified)
    -r, --report <PATH>      Generate JSON report to specified path
    -c, --config <PATH>      Use custom gitleaks config file
    -b, --baseline <PATH>    Use baseline file to ignore known findings
    -p, --path <PATH>        Path to scan (default: current directory)
    -v, --verbose            Verbose output (enabled by default)
    -h, --help               Show this help message

RUNTIMES (in auto-detect priority order):
    native     Native gitleaks binary, resolved via `mise which gitleaks`
               or PATH -- preferred, no container/VM overhead
    container  Apple Container (macOS 26+)
    docker     Docker Desktop or Docker Engine
    colima     Colima via mise exec

EXAMPLES:
    # Scan current directory with auto-detected runtime
    ./gitleaks.sh

    # Force a container runtime
    ./gitleaks.sh --runtime docker

    # Generate JSON report
    ./gitleaks.sh --report ./report.json

    # Use baseline to ignore known findings
    ./gitleaks.sh --baseline ./.gitleaks-baseline.json

    # Use custom config
    ./gitleaks.sh --config ./.gitleaks.toml
EOF
}

# Write to stderr, not stdout: detect_runtime()'s return value is captured
# via command substitution ($(detect_runtime)), and these log calls run
# inside it -- on stdout they'd be captured into the return value along with
# the real "container"/"docker"/"colima" string, corrupting it into a
# multi-line value that never matches the runtime case statement downstream.
log_info() {
    echo -e "${CYAN}$1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}$1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}$1${NC}" >&2
}

log_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

# Resolve a mise-managed gitleaks binary, or one on PATH (non-mise
# install). Echoes the absolute path on success, echoes nothing when
# neither resolves. Mirrors scripts/gitleaks.nu's resolve-mise-native /
# resolve-path-native precedence (claude-skills-267 Gate 3 R3 -- this
# script previously had no native-binary path at all and always went
# straight to a container runtime).
resolve_native_binary() {
    if command -v mise &> /dev/null; then
        local mise_bin
        if mise_bin="$(mise which gitleaks 2>/dev/null)" && [[ -n "$mise_bin" ]]; then
            echo "$mise_bin"
            return
        fi
    fi
    if command -v gitleaks &> /dev/null; then
        command -v gitleaks
        return
    fi
}

# Is $1 inside a git work tree? Asks git rather than checking for a literal
# .git directory -- a git worktree or submodule uses a .git FILE, and a
# subdirectory of a repo is still inside a work tree. Mirrors
# scripts/gitleaks.nu's is-git-worktree. Without --no-git, `gitleaks
# detect` against a path that fails this check logs a git fatal, scans 0
# bytes, and reports "no leaks found" at exit 0 -- silent fail-open
# (claude-skills-267).
is_git_worktree() {
    local path="$1"
    local result
    result="$(git -C "$path" rev-parse --is-inside-work-tree 2>/dev/null)" || return 1
    [[ "$result" == "true" ]]
}

# Extract the byte count from gitleaks' own scan-summary line, anchored to
# its actual STRUCTURE rather than picked by text position (claude-skills-267
# Gate 3 T2/T4). Position-based picking -- first occurrence or last
# occurrence of the substring "scanned ~" -- is defeated by a decoy on
# whichever side isn't checked: a decoy BEFORE the real summary beats
# first-match (Gate 3 R6); a decoy AFTER the real summary beats last-match
# (Gate 3 T4, the mirror image of R6, not a fix for it).
#
# The real line has a fixed, verifiable shape -- checked directly against
# gitleaks 8.30.1: "scanned ~<digits> bytes (<total>) in <duration>", e.g.
# "scanned ~72 bytes (72 bytes) in 70.8ms" or "scanned ~9107683 bytes
# (9.11 MB) in 377ms". A decoy that merely contains the substring "scanned
# ~" -- a file path, a bare trailing fragment with no reading -- never
# matches this full shape, so it is excluded regardless of which side of
# the real line it sits on. Echoes nothing when no line matches the full
# shape, which callers must treat as "no evidence", not as "0".
#
# Takes the LAST full-shape match. This is NOT a dead tie-break -- a
# full-shape decoy is reachable in practice, not just theoretically: a
# gitleaks WRN line can name a skipped file, and a file whose NAME is
# literally "scanned ~4242 bytes (4242 bytes) in 7ms" (mode 000, permission
# denied) produces a genuine second full-shape match in the same stderr
# (claude-skills-267 Gate 3 U3, reproduced directly -- a prior version of
# this comment claimed such a decoy could never satisfy the full shape,
# which was wrong). Last-match is correct here ONLY because gitleaks emits
# every WRN/skip line BEFORE its own summary line, in every observed
# ordering (8.30.1) -- the summary is always the final line of the run, so
# it is always the LAST full-shape match regardless of how many
# file-path-shaped decoys precede it. That ordering is the entire safety
# property this function relies on, and it lives in gitleaks' own output
# discipline, not in this code: if a future gitleaks version ever logs
# anything full-shaped AFTER the summary -- or a caller starts
# concatenating multiple runs' stderr with a decoy-bearing run appended
# after a clean one -- last-match silently returns the decoy's byte count
# instead of the real one. There is no assertion here that would catch
# that; this comment is the only record of the assumption.
#
# Identical regex semantics to scripts/gitleaks.nu's parse-scanned-bytes
# (`parse -r` there, `grep -oE` here) and the same last-match-because-
# summary-is-always-last assumption -- kept in sync deliberately rather
# than reusing one implementation across languages (no shared runtime
# between nu and bash). A prior version of this comment claimed it
# "mirrors" gitleaks.nu while implementing a DIFFERENT algorithm
# (first-vs-last, no shape anchor) that produced different verdicts on
# identical input (claude-skills-267 Gate 3 T2) -- verify this claim
# against the actual regex, not just the comment, if either changes.
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
# Mirrors scripts/gitleaks.nu's gitleaks-verified-clean -- closes the
# zero-byte-scanned case and the unparseable-summary case; does NOT
# guarantee the requested scan scope was covered (gitleaks' git-mode scans
# committed history only -- documented gitleaks behavior, not a bug this
# closes). See that function's comment in scripts/gitleaks.nu for the full
# explanation (claude-skills-267 Gate 3 R2).
gitleaks_verified_clean() {
    local stderr_text="$1"
    local bytes
    bytes="$(parse_scanned_bytes "$stderr_text")"
    [[ -n "$bytes" ]] && [[ "$bytes" -gt 0 ]]
}

detect_runtime() {
    log_info "Detecting container runtime..."

    # Priority 1: Apple Container (macOS 26+)
    if command -v container &> /dev/null; then
        if container system status &> /dev/null; then
            log_success "Found: Apple Container"
            echo "container"
            return
        fi
        log_warning "Found Apple Container CLI (not running)"
        echo "container"
        return
    fi

    # Priority 2: Docker
    if command -v docker &> /dev/null; then
        if docker info &> /dev/null; then
            log_success "Found: Docker"
            echo "docker"
            return
        fi
        log_warning "Found Docker CLI (daemon not running)"
        echo "docker"
        return
    fi

    # Priority 3: Colima via mise
    if command -v mise &> /dev/null; then
        if mise exec lima@latest colima@latest -- colima status &> /dev/null; then
            log_success "Found: Colima via mise"
            echo "colima"
            return
        fi
        log_warning "Found mise (Colima available)"
        echo "colima"
        return
    fi

    log_error "No container runtime found"
    echo "Install one of: Docker, Apple Container (macOS 26+), or mise with Colima"
    exit 1
}

validate_runtime() {
    case "$1" in
        docker|container|colima)
            echo "$1"
            ;;
        *)
            log_error "Invalid runtime '$1'"
            echo "Valid options: native, docker, container, colima"
            exit 1
            ;;
    esac
}

start_apple_container() {
    if ! container system status &> /dev/null; then
        log_warning "Starting Apple Container..."
        if ! container system start; then
            log_error "Failed to start Apple Container"
            exit 1
        fi
        log_success "Apple Container started"
    fi
}

start_docker() {
    if ! docker info &> /dev/null; then
        log_warning "Starting Docker..."

        # Attempt to start Docker Desktop on macOS
        if [[ "$(uname)" == "Darwin" ]]; then
            open -a Docker

            # Wait for Docker to be ready (max 60 seconds)
            echo "Waiting for Docker to start..."
            local attempts=0
            while ! docker info &> /dev/null; do
                sleep 2
                attempts=$((attempts + 1))
                if [[ $attempts -ge 30 ]]; then
                    log_error "Docker failed to start within 60 seconds"
                    exit 1
                fi
            done
            log_success "Docker started"
        else
            log_error "Docker daemon is not running"
            echo "Start Docker manually and try again"
            exit 1
        fi
    fi
}

start_colima() {
    if ! mise exec lima@latest colima@latest -- colima status &> /dev/null; then
        log_warning "Starting Colima via mise..."
        if ! mise exec lima@latest colima@latest -- colima start; then
            log_error "Failed to start Colima"
            exit 1
        fi
        log_success "Colima started"
    fi
}

start_runtime() {
    case "$1" in
        container) start_apple_container ;;
        docker) start_docker ;;
        colima) start_colima ;;
    esac
}

# Run gitleaks natively (real host paths, no container). Captures stdout
# and stderr separately via temp files (cleaned up on return) so the
# bytes-verification invariant can inspect stderr, where gitleaks logs its
# scan summary -- mirrors scripts/gitleaks.nu's run-gitleaks-native via
# `do { ... } | complete`.
run_gitleaks_native() {
    local binary="$1"
    local scan_path="$2"
    shift 2
    local args=("$@")

    log_info "Scanning: $scan_path"
    log_info "Command: $binary ${args[*]}"
    echo ""

    STDOUT_FILE="$(mktemp)"
    STDERR_FILE="$(mktemp)"

    local exit_code=0
    "$binary" "${args[@]}" >"$STDOUT_FILE" 2>"$STDERR_FILE" || exit_code=$?

    local stdout_content stderr_content
    stdout_content="$(cat "$STDOUT_FILE")"
    stderr_content="$(cat "$STDERR_FILE")"
    # Cleaned up synchronously, right after reading -- NOT via `trap ...
    # RETURN`: a RETURN trap set inside a bash function is not
    # function-scoped, it fires on every subsequent function return until
    # explicitly cleared, including the CALLER's return. That refired this
    # cleanup from main()'s own return with the temp-file locals already
    # out of scope, tripping "unbound variable" under `set -u` (found by
    # actually running this function, not just `bash -n`). The top-level
    # `trap ... EXIT` on the global STDOUT_FILE/STDERR_FILE is the backstop
    # for an interrupt landing before this line runs (Gate 3 T5).
    rm -f "$STDOUT_FILE" "$STDERR_FILE"
    STDOUT_FILE=""
    STDERR_FILE=""

    echo "$stdout_content"
    echo ""

    if [[ $exit_code -eq 1 ]]; then
        log_error "Secrets detected!"
        echo "$stderr_content" >&2
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        log_error "Error running gitleaks"
        echo "$stderr_content" >&2
        return "$exit_code"
    fi

    # exit_code == 0 here -- gitleaks itself found nothing, but that only
    # means something if it actually scanned bytes (claude-skills-267 Gate
    # 3 B2). Distinct marker from real detection (Gate 3 R5): printing
    # "Secrets detected!" when nothing was actually detected is a
    # fabricated claim in a security tool.
    echo "$stderr_content" >&2
    if ! gitleaks_verified_clean "$stderr_content"; then
        log_error "Scan unverified!"
        log_error "gitleaks reported success but scanned 0 bytes (or the scan summary could not be parsed) -- refusing to report clean without evidence something was actually scanned"
        return 1
    fi

    log_success "No secrets detected"
    return 0
}

run_gitleaks() {
    local runtime="$1"
    local scan_path="$2"
    shift 2
    local args=("$@")

    local image="zricethezav/gitleaks"

    log_info "Scanning: $scan_path"
    log_info "Command: gitleaks ${args[*]}"
    echo ""

    local -a mounts=(-v "$scan_path:/code")
    if [[ ${#CONFIG_MOUNT[@]} -gt 0 ]]; then
        mounts+=("${CONFIG_MOUNT[@]}")
    fi

    STDOUT_FILE="$(mktemp)"
    STDERR_FILE="$(mktemp)"

    local exit_code=0
    case "$runtime" in
        container)
            container run --rm "${mounts[@]}" "$image" "${args[@]}" >"$STDOUT_FILE" 2>"$STDERR_FILE" || exit_code=$?
            ;;
        docker)
            docker run --rm "${mounts[@]}" "$image" "${args[@]}" >"$STDOUT_FILE" 2>"$STDERR_FILE" || exit_code=$?
            ;;
        colima)
            mise exec lima@latest colima@latest -- docker run --rm "${mounts[@]}" "$image" "${args[@]}" >"$STDOUT_FILE" 2>"$STDERR_FILE" || exit_code=$?
            ;;
    esac

    local stdout_content stderr_content
    stdout_content="$(cat "$STDOUT_FILE")"
    stderr_content="$(cat "$STDERR_FILE")"
    # Cleaned up synchronously -- see run_gitleaks_native for why this is
    # NOT a `trap ... RETURN` (bash RETURN traps are not function-scoped).
    # The top-level `trap ... EXIT` on the global STDOUT_FILE/STDERR_FILE
    # is the backstop for an interrupt landing before this line (Gate 3 T5).
    rm -f "$STDOUT_FILE" "$STDERR_FILE"
    STDOUT_FILE=""
    STDERR_FILE=""

    echo "$stdout_content"
    echo ""

    if [[ $exit_code -eq 1 ]]; then
        log_error "Secrets detected!"
        echo "$stderr_content" >&2
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        log_error "Error running gitleaks"
        echo "$stderr_content" >&2
        return "$exit_code"
    fi

    # Same "never report clean without evidence" invariant as
    # run_gitleaks_native -- gitleaks logs its scan summary to stderr
    # regardless of runtime. Verified empirically against Apple Container
    # 1.0.0 (claude-skills-267 Gate 3 R7): stdout/stderr remain separate
    # through `container run` since no -t/-it flag is passed, so stderr
    # here genuinely carries gitleaks' scan summary rather than an empty
    # string from a merged stream. Docker/Colima were not reachable to
    # test on this host -- same reasoning applies (no -t flag passed here
    # either) but that specific claim is unverified for those two runtimes.
    echo "$stderr_content" >&2
    if ! gitleaks_verified_clean "$stderr_content"; then
        log_error "Scan unverified!"
        log_error "gitleaks reported success but scanned 0 bytes (or the scan summary could not be parsed) -- refusing to report clean without evidence something was actually scanned"
        return 1
    fi

    log_success "No secrets detected"
    return 0
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -R|--runtime)
                RUNTIME="$2"
                shift 2
                ;;
            -r|--report)
                REPORT="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG="$2"
                shift 2
                ;;
            -b|--baseline)
                BASELINE="$2"
                shift 2
                ;;
            -p|--path)
                SCAN_PATH="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                print_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_help
                exit 1
                ;;
        esac
    done

    # Expand scan path
    SCAN_PATH="$(cd "$SCAN_PATH" 2>/dev/null && pwd)" || {
        log_error "Path '$SCAN_PATH' does not exist"
        exit 1
    }

    # Detected once on the HOST path, before either arg builder runs: a
    # containerized scan mounts SCAN_PATH at /code, so git-repo status must
    # be known before the mount happens (claude-skills-267 Gate 3 R3,
    # mirrors scripts/gitleaks.nu's is-git-worktree check in main).
    local in_git=false
    if is_git_worktree "$SCAN_PATH"; then
        in_git=true
    fi

    # An explicit non-native --runtime request skips native resolution
    # entirely, same as scripts/gitleaks.nu's validate-runtime for
    # docker/container/colima.
    local native_bin=""
    if [[ -z "$RUNTIME" || "$RUNTIME" == "native" ]]; then
        native_bin="$(resolve_native_binary)"
    fi

    if [[ -n "$native_bin" ]]; then
        log_info "Using runtime: native ($native_bin)"

        local args=("detect" "--source=$SCAN_PATH")
        if [[ "$in_git" != true ]]; then
            args+=("--no-git")
        fi
        args+=("-v")

        if [[ -n "$REPORT" ]]; then
            # Errors when the requested directory doesn't exist, rather
            # than silently relocating the report to $(pwd) -- a prior
            # version did that silently (claude-skills-267 Gate 3 T6),
            # which means a typo'd --report path would write the report
            # somewhere the caller never asked for and never find out.
            local report_dir
            if ! report_dir="$(cd "$(dirname "$REPORT")" 2>/dev/null && pwd)"; then
                log_error "Directory for --report '$REPORT' does not exist"
                exit 1
            fi
            local report_path="$report_dir/$(basename "$REPORT")"
            args+=("--report-path=$report_path" "--report-format=json")
        fi

        if [[ -n "$CONFIG" ]]; then
            if [[ ! -f "$CONFIG" ]]; then
                log_error "Config file '$CONFIG' does not exist"
                exit 1
            fi
            local config_path
            config_path="$(cd "$(dirname "$CONFIG")" && pwd)/$(basename "$CONFIG")"
            args+=("--config=$config_path")
        fi

        if [[ -n "$BASELINE" ]]; then
            if [[ ! -f "$BASELINE" ]]; then
                log_error "Baseline file '$BASELINE' does not exist"
                exit 1
            fi
            local baseline_path
            baseline_path="$(cd "$(dirname "$BASELINE")" && pwd)/$(basename "$BASELINE")"
            args+=("--baseline-path=$baseline_path")
        fi

        run_gitleaks_native "$native_bin" "$SCAN_PATH" "${args[@]}"
        exit $?
    fi

    if [[ -n "$RUNTIME" && "$RUNTIME" == "native" ]]; then
        log_error "--runtime native requested but no gitleaks binary found (checked mise and PATH)"
        exit 1
    fi

    # No native binary found -- fall back to a container runtime.
    if [[ -z "$RUNTIME" ]]; then
        RUNTIME=$(detect_runtime)
    else
        RUNTIME=$(validate_runtime "$RUNTIME")
    fi

    log_info "Using runtime: $RUNTIME"

    # Ensure runtime is started
    start_runtime "$RUNTIME"

    # Build gitleaks arguments (/code-relative -- SCAN_PATH is bind-mounted
    # at /code inside the container). `in_git` reflects the HOST path's
    # status, checked above before the mount -- the mount carries the
    # host's .git (or its absence) straight into /code, so the same
    # fail-open hole applies here without --no-git (claude-skills-267 Gate
    # 3 R3).
    local args=("detect" "--source=/code")
    if [[ "$in_git" != true ]]; then
        args+=("--no-git")
    fi
    args+=("-v")

    if [[ -n "$REPORT" ]]; then
        # restraint: honors the requested FILENAME, not the requested
        # DIRECTORY -- the container only has /code (the bind-mounted
        # SCAN_PATH) to write into, so the report lands inside the scanned
        # directory under this basename rather than at the literal $REPORT
        # path when the two differ. A full fix needs a second bind mount
        # for the report's directory, the same trick CONFIG_MOUNT already
        # uses for --config; not done here since this is a LOW-priority
        # gap (claude-skills-267 Gate 3 T6) and gitleaks.nu's own container
        # path has the identical limitation (hardcodes /code/report.json).
        # Previously this branch discarded the filename too -- fixed here.
        args+=("--report-path=/code/$(basename "$REPORT")" "--report-format=json")
    fi

    if [[ -n "$CONFIG" ]]; then
        if [[ ! -f "$CONFIG" ]]; then
            log_error "Config file '$CONFIG' does not exist"
            exit 1
        fi
        # Mount the config's PARENT directory, not the file itself:
        # single-file bind mounts behaved inconsistently in one observed
        # environment (not reproduced on container CLI 1.0.0 -- both
        # mounts worked there); parent-dir mount is used defensively
        # since it works correctly everywhere tested. This exposes the
        # parent directory's sibling files to the short-lived local scan
        # container -- keep configs in a directory you're comfortable
        # mounting.
        local config_dir
        config_dir="$(cd "$(dirname "$CONFIG")" && pwd)"
        local config_filename
        config_filename="$(basename "$CONFIG")"
        CONFIG_MOUNT=(-v "$config_dir:/gitleaks-config")
        args+=("--config=/gitleaks-config/$config_filename")
    fi

    if [[ -n "$BASELINE" ]]; then
        if [[ ! -f "$BASELINE" ]]; then
            log_error "Baseline file '$BASELINE' does not exist"
            exit 1
        fi
        local baseline_filename
        baseline_filename="$(basename "$BASELINE")"
        args+=("--baseline-path=/code/$baseline_filename")
    fi

    # Run gitleaks
    run_gitleaks "$RUNTIME" "$SCAN_PATH" "${args[@]}"
}

main "$@"
