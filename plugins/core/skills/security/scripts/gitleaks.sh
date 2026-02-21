#!/usr/bin/env bash

# Gitleaks secret scanner with automatic container runtime detection
# Supports Docker, Apple Container (macOS 26+), and Colima via mise

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

print_help() {
    cat << 'EOF'
Gitleaks Secret Scanner

USAGE:
    gitleaks.sh [OPTIONS]

OPTIONS:
    -R, --runtime <RUNTIME>  Container runtime: docker, container, colima
                             (auto-detects if not specified)
    -r, --report <PATH>      Generate JSON report to specified path
    -c, --config <PATH>      Use custom gitleaks config file
    -b, --baseline <PATH>    Use baseline file to ignore known findings
    -p, --path <PATH>        Path to scan (default: current directory)
    -v, --verbose            Verbose output (enabled by default)
    -h, --help               Show this help message

CONTAINER RUNTIMES:
    container  Apple Container (macOS 26+)
    docker     Docker Desktop or Docker Engine
    colima     Colima via mise exec

EXAMPLES:
    # Scan current directory with auto-detected runtime
    ./gitleaks.sh

    # Scan with specific runtime
    ./gitleaks.sh --runtime docker

    # Generate JSON report
    ./gitleaks.sh --report ./report.json

    # Use baseline to ignore known findings
    ./gitleaks.sh --baseline ./.gitleaks-baseline.json

    # Use custom config
    ./gitleaks.sh --config ./.gitleaks.toml
EOF
}

log_info() {
    echo -e "${CYAN}$1${NC}"
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

log_error() {
    echo -e "${RED}Error:${NC} $1"
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
            echo "Valid options: docker, container, colima"
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

run_gitleaks() {
    local runtime="$1"
    local scan_path="$2"
    shift 2
    local args=("$@")

    local image="zricethezav/gitleaks"

    log_info "Scanning: $scan_path"
    log_info "Command: gitleaks ${args[*]}"
    echo ""

    local exit_code=0

    case "$runtime" in
        container)
            container run --rm -v "$scan_path:/code" "$image" "${args[@]}" || exit_code=$?
            ;;
        docker)
            docker run --rm -v "$scan_path:/code" "$image" "${args[@]}" || exit_code=$?
            ;;
        colima)
            mise exec lima@latest colima@latest -- docker run --rm -v "$scan_path:/code" "$image" "${args[@]}" || exit_code=$?
            ;;
    esac

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        log_success "No secrets detected"
    elif [[ $exit_code -eq 1 ]]; then
        log_error "Secrets detected!"
    else
        log_error "Error running gitleaks"
    fi

    return $exit_code
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

    # Detect or validate runtime
    if [[ -z "$RUNTIME" ]]; then
        RUNTIME=$(detect_runtime)
    else
        RUNTIME=$(validate_runtime "$RUNTIME")
    fi

    log_info "Using runtime: $RUNTIME"

    # Ensure runtime is started
    start_runtime "$RUNTIME"

    # Build gitleaks arguments
    local args=("detect" '--source="/code"' "-v")

    if [[ -n "$REPORT" ]]; then
        args+=("--report-path=/code/report.json" "--report-format=json")
    fi

    if [[ -n "$CONFIG" ]]; then
        if [[ ! -f "$CONFIG" ]]; then
            log_error "Config file '$CONFIG' does not exist"
            exit 1
        fi
        args+=("--config=/code/.gitleaks-config.toml")
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
