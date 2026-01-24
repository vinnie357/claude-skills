#!/usr/bin/env nu

# Gitleaks secret scanner with automatic container runtime detection
# Supports Docker, Apple Container (macOS 26+), and Colima via mise

def main [
    --runtime (-R): string = ""     # Container runtime: docker, container, colima (auto-detect if empty)
    --report (-r): string = ""      # Generate JSON report to specified path
    --config (-c): string = ""      # Use custom gitleaks config file
    --baseline (-b): string = ""    # Use baseline file to ignore known findings
    --path (-p): string = "."       # Path to scan (default: current directory)
    --verbose (-v)                  # Verbose output (default: enabled)
    --help (-h)                     # Show help message
] {
    if $help {
        print-help
        return
    }

    let scan_path = ($path | path expand)

    if not ($scan_path | path exists) {
        print $"(ansi red)Error:(ansi reset) Path '($path)' does not exist"
        exit 1
    }

    # Detect or validate runtime
    let selected_runtime = if ($runtime | is-empty) {
        detect-runtime
    } else {
        validate-runtime $runtime
    }

    print $"(ansi cyan)Using runtime:(ansi reset) ($selected_runtime)"

    # Ensure runtime is started
    start-runtime $selected_runtime

    # Build gitleaks command arguments
    let gitleaks_args = build-gitleaks-args $report $config $baseline $verbose

    # Run gitleaks
    run-gitleaks $selected_runtime $scan_path $gitleaks_args
}

def print-help [] {
    print "Gitleaks Secret Scanner"
    print ""
    print "USAGE:"
    print "    gitleaks.nu [OPTIONS]"
    print ""
    print "OPTIONS:"
    print "    -R, --runtime <RUNTIME>  Container runtime: docker, container, colima"
    print "                             (auto-detects if not specified)"
    print "    -r, --report <PATH>      Generate JSON report to specified path"
    print "    -c, --config <PATH>      Use custom gitleaks config file"
    print "    -b, --baseline <PATH>    Use baseline file to ignore known findings"
    print "    -p, --path <PATH>        Path to scan (default: current directory)"
    print "    -v, --verbose            Verbose output (enabled by default)"
    print "    -h, --help               Show this help message"
    print ""
    print "CONTAINER RUNTIMES:"
    print "    container  Apple Container (macOS 26+)"
    print "    docker     Docker Desktop or Docker Engine"
    print "    colima     Colima via mise exec"
    print ""
    print "EXAMPLES:"
    print "    # Scan current directory with auto-detected runtime"
    print "    nu gitleaks.nu"
    print ""
    print "    # Scan with specific runtime"
    print "    nu gitleaks.nu --runtime docker"
    print ""
    print "    # Generate JSON report"
    print "    nu gitleaks.nu --report ./report.json"
    print ""
    print "    # Use baseline to ignore known findings"
    print "    nu gitleaks.nu --baseline ./.gitleaks-baseline.json"
    print ""
    print "    # Use custom config"
    print "    nu gitleaks.nu --config ./.gitleaks.toml"
}

def detect-runtime [] {
    print $"(ansi cyan)Detecting container runtime...(ansi reset)"

    # Priority 1: Apple Container (macOS 26+)
    if (which container | is-not-empty) {
        let status = (do { ^container system status } | complete)
        if $status.exit_code == 0 {
            print $"(ansi green)Found:(ansi reset) Apple Container"
            return "container"
        }
        # Container CLI exists but may need to be started
        print $"(ansi yellow)Found Apple Container CLI (not running)(ansi reset)"
        return "container"
    }

    # Priority 2: Docker
    if (which docker | is-not-empty) {
        let status = (do { ^docker info } | complete)
        if $status.exit_code == 0 {
            print $"(ansi green)Found:(ansi reset) Docker"
            return "docker"
        }
        # Docker CLI exists but daemon may not be running
        print $"(ansi yellow)Found Docker CLI (daemon not running)(ansi reset)"
        return "docker"
    }

    # Priority 3: Colima via mise
    if (which mise | is-not-empty) {
        let status = (do { ^mise exec lima@latest colima@latest -- colima status } | complete)
        if $status.exit_code == 0 {
            print $"(ansi green)Found:(ansi reset) Colima via mise"
            return "colima"
        }
        # mise exists, colima can be used
        print $"(ansi yellow)Found mise (Colima available)(ansi reset)"
        return "colima"
    }

    print $"(ansi red)Error:(ansi reset) No container runtime found"
    print "Install one of: Docker, Apple Container (macOS 26+), or mise with Colima"
    exit 1
}

def validate-runtime [runtime: string] {
    if $runtime in ["docker" "container" "colima"] {
        $runtime
    } else {
        print $"(ansi red)Error:(ansi reset) Invalid runtime '($runtime)'"
        print "Valid options: docker, container, colima"
        exit 1
    }
}

def start-runtime [runtime: string] {
    match $runtime {
        "container" => { start-apple-container }
        "docker" => { start-docker }
        "colima" => { start-colima }
        _ => {}
    }
}

def start-apple-container [] {
    let status = (do { ^container system status } | complete)
    if $status.exit_code != 0 {
        print $"(ansi yellow)Starting Apple Container...(ansi reset)"
        let start_result = (do { ^container system start } | complete)
        if $start_result.exit_code != 0 {
            print $"(ansi red)Error:(ansi reset) Failed to start Apple Container"
            print $start_result.stderr
            exit 1
        }
        print $"(ansi green)Apple Container started(ansi reset)"
    }
}

def start-docker [] {
    let status = (do { ^docker info } | complete)
    if $status.exit_code != 0 {
        print $"(ansi yellow)Starting Docker...(ansi reset)"

        # Attempt to start Docker Desktop on macOS
        let os_type = (sys host | get name)
        if $os_type == "Darwin" {
            do { ^open -a Docker } | complete

            # Wait for Docker to be ready (max 60 seconds)
            print "Waiting for Docker to start..."
            mut attempts = 0
            loop {
                sleep 2sec
                $attempts = $attempts + 1
                let check = (do { ^docker info } | complete)
                if $check.exit_code == 0 {
                    print $"(ansi green)Docker started(ansi reset)"
                    break
                }
                if $attempts >= 30 {
                    print $"(ansi red)Error:(ansi reset) Docker failed to start within 60 seconds"
                    exit 1
                }
            }
        } else {
            print $"(ansi red)Error:(ansi reset) Docker daemon is not running"
            print "Start Docker manually and try again"
            exit 1
        }
    }
}

def start-colima [] {
    let status = (do { ^mise exec lima@latest colima@latest -- colima status } | complete)
    if $status.exit_code != 0 {
        print $"(ansi yellow)Starting Colima via mise...(ansi reset)"
        let start_result = (do { ^mise exec lima@latest colima@latest -- colima start } | complete)
        if $start_result.exit_code != 0 {
            print $"(ansi red)Error:(ansi reset) Failed to start Colima"
            print $start_result.stderr
            exit 1
        }
        print $"(ansi green)Colima started(ansi reset)"
    }
}

def build-gitleaks-args [report: string, config: string, baseline: string, verbose: bool] {
    mut args = ["detect" "--source=/code"]

    # Always add verbose flag
    $args = ($args | append "-v")

    if not ($report | is-empty) {
        $args = ($args | append ["--report-path=/code/report.json" "--report-format=json"])
    }

    if not ($config | is-empty) {
        let config_path = ($config | path expand)
        if not ($config_path | path exists) {
            print $"(ansi red)Error:(ansi reset) Config file '($config)' does not exist"
            exit 1
        }
        $args = ($args | append "--config=/code/.gitleaks-config.toml")
    }

    if not ($baseline | is-empty) {
        let baseline_path = ($baseline | path expand)
        if not ($baseline_path | path exists) {
            print $"(ansi red)Error:(ansi reset) Baseline file '($baseline)' does not exist"
            exit 1
        }
        # Get the filename from the baseline path
        let baseline_filename = ($baseline_path | path basename)
        $args = ($args | append $"--baseline-path=/code/($baseline_filename)")
    }

    $args
}

def run-gitleaks [runtime: string, scan_path: string, args: list<string>] {
    let args_str = ($args | str join " ")
    let image = "zricethezav/gitleaks"

    print $"(ansi cyan)Scanning:(ansi reset) ($scan_path)"
    print $"(ansi cyan)Command:(ansi reset) gitleaks ($args_str)"
    print ""

    let result = match $runtime {
        "container" => {
            do {
                ^container run --rm -v $"($scan_path):/code" $image ...$args
            } | complete
        }
        "docker" => {
            do {
                ^docker run --rm -v $"($scan_path):/code" $image ...$args
            } | complete
        }
        "colima" => {
            do {
                ^mise exec lima@latest colima@latest -- docker run --rm -v $"($scan_path):/code" $image ...$args
            } | complete
        }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown runtime"
            exit 1
        }
    }

    print $result.stdout

    if $result.exit_code == 0 {
        print $"(ansi green)No secrets detected(ansi reset)"
    } else if $result.exit_code == 1 {
        print $"(ansi red)Secrets detected!(ansi reset)"
        print $result.stderr
    } else {
        print $"(ansi red)Error running gitleaks:(ansi reset)"
        print $result.stderr
    }

    exit $result.exit_code
}
