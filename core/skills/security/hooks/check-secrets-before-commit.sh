#!/usr/bin/env bash
# Pre-commit secret scanner hook for Claude Code
# Blocks git commit if secrets detected in staged files
#
# Exit codes:
#   0 - Allow command (not a git commit OR no secrets found)
#   2 - Block command (secrets detected in staged files)

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

# Detect container runtime
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

RUNTIME=$(detect_runtime)

if [[ -z "$RUNTIME" ]]; then
    log_warning "No container runtime available - skipping secret scan"
    log_warning "Install Docker, Apple Container (macOS 26+), or Colima via mise"
    exit 0
fi

log_info "Using runtime: $RUNTIME"

# Run gitleaks scan on staged files (--no-git since we exported files)
IMAGE="zricethezav/gitleaks"
GITLEAKS_ARGS="detect --source=/code --no-git -v"

# Check for baseline file
if [[ -f ".gitleaks-baseline.json" ]]; then
    # Copy baseline to temp dir
    cp ".gitleaks-baseline.json" "$TEMP_DIR/"
    GITLEAKS_ARGS="$GITLEAKS_ARGS --baseline-path=/code/.gitleaks-baseline.json"
    log_info "Using baseline: .gitleaks-baseline.json"
fi

# Check for config file
if [[ -f ".gitleaks.toml" ]]; then
    cp ".gitleaks.toml" "$TEMP_DIR/"
    GITLEAKS_ARGS="$GITLEAKS_ARGS --config=/code/.gitleaks.toml"
    log_info "Using config: .gitleaks.toml"
fi

EXIT_CODE=0

case "$RUNTIME" in
    container)
        container run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS || EXIT_CODE=$?
        ;;
    docker)
        docker run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS || EXIT_CODE=$?
        ;;
    colima)
        mise exec lima@latest colima@latest -- docker run --rm -v "$TEMP_DIR:/code" "$IMAGE" $GITLEAKS_ARGS || EXIT_CODE=$?
        ;;
esac

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
    log_warning "Gitleaks scan failed (exit code: $EXIT_CODE)"
    log_warning "Allowing commit - check gitleaks configuration"
    exit 0
fi
