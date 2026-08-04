#!/usr/bin/env nu

# Gitleaks secret scanner with automatic native-binary detection and
# container runtime fallback (Docker, Apple Container macOS 26+, Colima via mise)
#
# Runtime selection precedence (see select-runtime):
#   1. native-mise   — `mise which gitleaks` resolves a mise-managed binary
#   2. native-path    — a `gitleaks` binary is on PATH (non-mise install)
#   3. container      — Apple Container (macOS 26+)
#   4. docker         — Docker Desktop or Docker Engine
#   5. colima         — Colima via mise exec
#   (none available)  — explicit error, never a silent/opaque failure
#
# Trap: a shell function named `gitleaks` in your interactive shell (zsh/bash)
# can shadow the real binary and silently reroute a bare `gitleaks ...`
# invocation through `container run` instead of running natively. This
# script never relies on an interactive-shell `gitleaks` alias/function —
# it resolves the binary path explicitly via `mise which` (or `which`) and
# invokes that resolved path directly, so it is immune to the shadow. The
# trap still bites a human typing `gitleaks ...` at the terminal; see the
# security skill body for the interactive-shell mitigation.

def main [
    --runtime (-R): string = ""     # Runtime: native, docker, container, colima (auto-detect if empty)
    --report (-r): string = ""      # Generate JSON report to specified path
    --config (-c): string = ""      # Use custom gitleaks config file
    --baseline (-b): string = ""    # Use baseline file to ignore known findings
    --path (-p): string = "."       # Path to scan (default: current directory)
    --verbose (-v)                  # Verbose output (default: enabled)
    --self-test                     # Run internal selection-logic tests (no subprocess/container calls) and exit
    --help (-h)                     # Show help message
] {
    if $self_test {
        run-self-tests
        return
    }

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

    # Ensure runtime is started (no-op for native)
    start-runtime $selected_runtime

    # Run gitleaks
    if $selected_runtime in ["native-mise" "native-path"] {
        let binary = (resolve-native-binary $selected_runtime)
        let built = (build-gitleaks-args-native $scan_path $report $config $baseline $verbose)
        run-gitleaks-native $binary $scan_path $built.args
    } else {
        let built = (build-gitleaks-args-container $report $config $baseline $verbose)
        run-gitleaks-container $selected_runtime $scan_path $built.args $built.config_mount
    }
}

def print-help [] {
    print "Gitleaks Secret Scanner"
    print ""
    print "USAGE:"
    print "    gitleaks.nu [OPTIONS]"
    print ""
    print "OPTIONS:"
    print "    -R, --runtime <RUNTIME>  Runtime: native, docker, container, colima"
    print "                             (auto-detects if not specified)"
    print "    -r, --report <PATH>      Generate JSON report to specified path"
    print "    -c, --config <PATH>      Use custom gitleaks config file"
    print "    -b, --baseline <PATH>    Use baseline file to ignore known findings"
    print "    -p, --path <PATH>        Path to scan (default: current directory)"
    print "    -v, --verbose            Verbose output (enabled by default)"
    print "    --self-test              Run internal selection-logic tests and exit"
    print "    -h, --help               Show this help message"
    print ""
    print "RUNTIMES (in auto-detect priority order):"
    print "    native     Native gitleaks binary, resolved via `mise which gitleaks`"
    print "               or PATH — preferred, no container/VM overhead"
    print "    container  Apple Container (macOS 26+)"
    print "    docker     Docker Desktop or Docker Engine"
    print "    colima     Colima via mise exec"
    print ""
    print "EXAMPLES:"
    print "    # Scan current directory with auto-detected runtime"
    print "    nu gitleaks.nu"
    print ""
    print "    # Force a specific runtime"
    print "    nu gitleaks.nu --runtime native"
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

# Pure selection function — no subprocess calls, no I/O. Takes availability
# booleans (already probed by the caller) and returns the runtime name to
# use, or null when nothing is available. Kept pure so --self-test can
# exercise every precedence branch without touching mise, a container
# runtime, or the network.
# Positional, not named flags: nushell disallows explicit type annotations
# on boolean `--flag` switches (they're presence-only), so a pure function
# that needs true/false VALUES — not presence — takes plain bool positionals.
def select-runtime [
    mise_native: bool    # a mise-managed gitleaks binary resolved
    path_native: bool    # a gitleaks binary is on PATH
    container: bool      # Apple Container CLI is on PATH
    docker: bool         # Docker CLI is on PATH
    colima: bool         # mise is on PATH (Colima runs via mise exec)
] {
    if $mise_native {
        "native-mise"
    } else if $path_native {
        "native-path"
    } else if $container {
        "container"
    } else if $docker {
        "docker"
    } else if $colima {
        "colima"
    } else {
        null
    }
}

def run-self-tests [] {
    mut failures = 0
    mut total = 0

    def check [name: string, actual: any, expected: any] {
        # returns a record; the caller accumulates pass/fail since a nested
        # closure can't mutate the outer `mut` counters
        {name: $name, pass: ($actual == $expected), actual: $actual, expected: $expected}
    }

    let cases = [
        (check "native-mise preferred over everything" (select-runtime true true true true true) "native-mise")
        (check "native-path used when mise unavailable" (select-runtime false true true true true) "native-path")
        (check "container preferred over docker/colima when no native" (select-runtime false false true true true) "container")
        (check "docker used when only docker/colima available" (select-runtime false false false true true) "docker")
        (check "colima used as last-resort runtime" (select-runtime false false false false true) "colima")
        (check "nothing available returns null, never a silent default" (select-runtime false false false false false) null)
        (check "native-mise still wins even with nothing else available" (select-runtime true false false false false) "native-mise")
    ]

    for $c in $cases {
        $total = $total + 1
        if $c.pass {
            print $"(ansi green)PASS(ansi reset) ($c.name)"
        } else {
            $failures = $failures + 1
            print $"(ansi red)FAIL(ansi reset) ($c.name) — expected ($c.expected), got ($c.actual)"
        }
    }

    print ""
    if $failures == 0 {
        print $"(ansi green)($total)/($total) self-tests passed(ansi reset)"
        exit 0
    } else {
        print $"(ansi red)($failures)/($total) self-tests failed(ansi reset)"
        exit 1
    }
}

def probe-mise-native [] {
    if (which mise | is-empty) {
        false
    } else {
        (do { ^mise which gitleaks } | complete).exit_code == 0
    }
}

def probe-path-native [] {
    (which gitleaks | is-not-empty)
}

def probe-container [] {
    which container | is-not-empty
}

def probe-docker [] {
    which docker | is-not-empty
}

def probe-colima [] {
    which mise | is-not-empty
}

def detect-runtime [] {
    print $"(ansi cyan)Detecting gitleaks runtime...(ansi reset)"

    let mise_native = (probe-mise-native)
    let path_native = (probe-path-native)
    let container = (probe-container)
    let docker = (probe-docker)
    let colima = (probe-colima)

    let selected = (select-runtime $mise_native $path_native $container $docker $colima)

    if $selected == null {
        print $"(ansi red)Error:(ansi reset) No gitleaks binary and no container runtime found"
        print "Install one of:"
        print "  - gitleaks via mise (recommended): mise use gitleaks@latest"
        print "  - gitleaks on PATH (brew install gitleaks, etc.)"
        print "  - Docker, Apple Container (macOS 26+), or mise with Colima"
        exit 1
    }

    let label = match $selected {
        "native-mise" => "native gitleaks binary (via mise)"
        "native-path" => "native gitleaks binary (on PATH)"
        _ => $selected
    }
    print $"(ansi green)Found:(ansi reset) ($label)"

    $selected
}

def validate-runtime [runtime: string] {
    if $runtime == "native" {
        if (probe-mise-native) {
            "native-mise"
        } else if (probe-path-native) {
            "native-path"
        } else {
            print $"(ansi red)Error:(ansi reset) --runtime native requested but no gitleaks binary found (checked mise and PATH)"
            exit 1
        }
    } else if $runtime in ["docker" "container" "colima"] {
        $runtime
    } else {
        print $"(ansi red)Error:(ansi reset) Invalid runtime '($runtime)'"
        print "Valid options: native, docker, container, colima"
        exit 1
    }
}

def resolve-native-binary [selected_runtime: string] {
    if $selected_runtime == "native-mise" {
        (^mise which gitleaks | str trim)
    } else {
        (which gitleaks | get 0.path)
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

# Args for a directly-invoked native binary: real host paths, no /code mount prefix.
def build-gitleaks-args-native [scan_path: string, report: string, config: string, baseline: string, verbose: bool] {
    mut args = ["detect" $"--source=($scan_path)"]

    $args = ($args | append "-v")

    if not ($report | is-empty) {
        let report_path = ($report | path expand)
        $args = ($args | append [$"--report-path=($report_path)" "--report-format=json"])
    }

    if not ($config | is-empty) {
        let config_path = ($config | path expand)
        if not ($config_path | path exists) {
            print $"(ansi red)Error:(ansi reset) Config file '($config)' does not exist"
            exit 1
        }
        $args = ($args | append $"--config=($config_path)")
    }

    if not ($baseline | is-empty) {
        let baseline_path = ($baseline | path expand)
        if not ($baseline_path | path exists) {
            print $"(ansi red)Error:(ansi reset) Baseline file '($baseline)' does not exist"
            exit 1
        }
        $args = ($args | append $"--baseline-path=($baseline_path)")
    }

    {args: $args}
}

# Args for a containerized run: /code-relative paths, since the scan path
# is bind-mounted at /code inside the container.
def build-gitleaks-args-container [report: string, config: string, baseline: string, verbose: bool] {
    mut args = ["detect" "--source=/code"]

    # Always add verbose flag
    $args = ($args | append "-v")

    if not ($report | is-empty) {
        $args = ($args | append ["--report-path=/code/report.json" "--report-format=json"])
    }

    let config_mount = if ($config | is-empty) {
        null
    } else {
        let config_path = ($config | path expand)
        if not ($config_path | path exists) {
            print $"(ansi red)Error:(ansi reset) Config file '($config)' does not exist"
            exit 1
        }
        # Mount the config's PARENT directory, not the file itself:
        # single-file bind mounts behaved inconsistently in one observed
        # environment (not reproduced on container CLI 1.0.0 — both
        # mounts worked there); parent-dir mount is used defensively
        # since it works correctly everywhere tested. This exposes the
        # parent directory's sibling files to the short-lived local scan
        # container — keep configs in a directory you're comfortable
        # mounting.
        {host: ($config_path | path dirname), container: "/gitleaks-config", filename: ($config_path | path basename)}
    }

    if $config_mount != null {
        $args = ($args | append $"--config=/gitleaks-config/($config_mount.filename)")
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

    {args: $args, config_mount: $config_mount}
}

def run-gitleaks-native [binary: string, scan_path: string, args: list<string>] {
    let args_str = ($args | str join " ")

    print $"(ansi cyan)Scanning:(ansi reset) ($scan_path)"
    print $"(ansi cyan)Command:(ansi reset) ($binary) ($args_str)"
    print ""

    let result = (do { ^$binary ...$args } | complete)

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

def run-gitleaks-container [runtime: string, scan_path: string, args: list<string>, config_mount: any] {
    let args_str = ($args | str join " ")
    let image = "zricethezav/gitleaks"

    print $"(ansi cyan)Scanning:(ansi reset) ($scan_path)"
    print $"(ansi cyan)Command:(ansi reset) gitleaks ($args_str)"
    print ""

    let mount_flags = if $config_mount != null {
        ["-v" $"($config_mount.host):($config_mount.container)"]
    } else {
        []
    }

    let result = match $runtime {
        "container" => {
            # Apple Container 1.0.0 does not reliably remove the container
            # on exit despite --rm (claude-skills-208, observed on 1.0.0 —
            # not independently reproduced here). Give the container an
            # explicit, unique name so a defensive cleanup can target ONLY
            # this container by name after the run — never an unfiltered
            # `container ls -aq` splat into `rm`, which has previously
            # destroyed every container on a host including unrelated k8s
            # control planes.
            let container_name = $"gitleaks-scan-(date now | format date '%Y%m%d%H%M%S')-(random int 1000..9999)"
            let run_result = (do {
                ^container run --rm --name $container_name -v $"($scan_path):/code" ...$mount_flags $image ...$args
            } | complete)
            # Best-effort cleanup scoped to the exact name we just created.
            # --rm should have handled this; this is the documented fallback
            # for claude-skills-208. Ignore failures (container may already
            # be gone if --rm worked) — never treat cleanup failure as a
            # scan failure.
            do { ^container rm -f $container_name } | complete | ignore
            $run_result
        }
        "docker" => {
            do {
                ^docker run --rm -v $"($scan_path):/code" ...$mount_flags $image ...$args
            } | complete
        }
        "colima" => {
            do {
                ^mise exec lima@latest colima@latest -- docker run --rm -v $"($scan_path):/code" ...$mount_flags $image ...$args
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
