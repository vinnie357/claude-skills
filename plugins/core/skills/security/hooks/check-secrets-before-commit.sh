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

# Only intercept git commit commands
if [[ ! "$COMMAND" =~ ^git[[:space:]]+commit ]]; then
    exit 0
fi

log_info "Intercepting git commit - scanning staged files for secrets..."

# Get working directory from hook input or use current
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
cd "$CWD" 2>/dev/null || cd "."

# Check if there are staged files
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null || echo "")
if [[ -z "$STAGED_FILES" ]]; then
    log_info "No staged files to scan"
    exit 0
fi

# Create temp directory for staged files
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Export staged files to temp directory
log_info "Exporting staged files..."
while IFS= read -r file; do
    if [[ -n "$file" ]]; then
        # Create parent directory in temp
        mkdir -p "$TEMP_DIR/$(dirname "$file")"
        # Export staged content (not working tree)
        git show ":$file" > "$TEMP_DIR/$file" 2>/dev/null || true
    fi
done <<< "$STAGED_FILES"

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

    EXIT_CODE=0
    "$NATIVE_BIN" $GITLEAKS_ARGS || EXIT_CODE=$?
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
            container run --rm --name "$CONTAINER_NAME" -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS || EXIT_CODE=$?
            # Best-effort cleanup scoped to the exact name just created.
            # --rm should have handled this; ignore failures (container may
            # already be gone if --rm worked) — never treat cleanup failure
            # as a scan failure.
            container rm -f "$CONTAINER_NAME" &> /dev/null || true
            ;;
        docker)
            docker run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS || EXIT_CODE=$?
            ;;
        colima)
            mise exec lima@latest colima@latest -- docker run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS || EXIT_CODE=$?
            ;;
    esac
fi

if [[ $EXIT_CODE -eq 0 ]]; then
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
