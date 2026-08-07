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

    # Detected once on the HOST path, before either arg builder runs: a
    # containerized scan mounts scan_path at /code, so git-repo status must
    # be known before the mount happens, not re-derived from inside the
    # container.
    let in_git = (is-git-worktree $scan_path)

    # Detect or validate runtime. Both return {runtime: string, binary: string}
    # — binary is the already-resolved native path (empty for container
    # runtimes), resolved exactly once here rather than probed-then-resolved
    # separately, to avoid a redundant `mise which gitleaks` subprocess call.
    let selected = if ($runtime | is-empty) {
        detect-runtime
    } else {
        validate-runtime $runtime
    }

    print $"(ansi cyan)Using runtime:(ansi reset) ($selected.runtime)"

    # Ensure runtime is started (no-op for native)
    start-runtime $selected.runtime

    # Run gitleaks
    if $selected.runtime in ["native-mise" "native-path"] {
        let built = (build-gitleaks-args-native $scan_path $report $config $baseline $in_git)
        run-gitleaks-native $selected.binary $scan_path $built.args
    } else {
        let built = (build-gitleaks-args-container $report $config $baseline $verbose $in_git)
        run-gitleaks-container $selected.runtime $scan_path $built.args $built.config_mount
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

    # The error-path message builders (validate-runtime's "not found" branch)
    # interpolate literal parens — the exact class of bug Gate 3 review found
    # at line 246 (unescaped parens evaluated as a nushell expression, crashing
    # before the message printed). Exercise the string construction itself via
    # try/catch: a regression here throws "External command failed" instead
    # of returning a string, which the pure select-runtime cases above cannot
    # catch since they never touch string interpolation.
    let native_not_found = (try {
        {ok: true, value: (native-not-found-message)}
    } catch { |err|
        {ok: false, value: $err.msg}
    })

    let cases = [
        (check "native-mise preferred over everything" (select-runtime true true true true true) "native-mise")
        (check "native-path used when mise unavailable" (select-runtime false true true true true) "native-path")
        (check "container preferred over docker/colima when no native" (select-runtime false false true true true) "container")
        (check "docker used when only docker/colima available" (select-runtime false false false true true) "docker")
        (check "colima used as last-resort runtime" (select-runtime false false false false true) "colima")
        (check "nothing available returns null, never a silent default" (select-runtime false false false false false) null)
        (check "native-mise still wins even with nothing else available" (select-runtime true false false false false) "native-mise")
        (check "native-not-found message builds without throwing (regression: unescaped parens)" $native_not_found.ok true)
        (check "native-not-found message names both checked sources" ($native_not_found.value | str contains "mise and PATH") true)
        # parse-scanned-bytes / gitleaks-verified-clean (claude-skills-267
        # Gate 3 B2): exact stderr shapes observed against real gitleaks
        # 8.30.1 output — a zero-commit repo, a real finding, a large repo,
        # and unparseable text (must fail closed, not crash or default to 0).
        (check "parses the zero-byte scan summary (zero-commit repo)" (parse-scanned-bytes "INF 0 commits scanned.\nINF scanned ~0 bytes (0) in 77.2ms\nINF no leaks found") 0)
        (check "parses a nonzero scan summary" (parse-scanned-bytes "INF scanned ~72 bytes (72 bytes) in 70.8ms\nWRN leaks found: 1") 72)
        (check "parses a large scan summary" (parse-scanned-bytes "INF 777 commits scanned.\nINF scanned ~9107683 bytes (9.11 MB) in 377ms") 9107683)
        (check "unparseable stderr returns null, not 0" (parse-scanned-bytes "some unrelated error text") null)
        # Gate 3 R6: a false "scanned ~" match earlier in the text (e.g. a
        # log line naming a file whose path happens to contain that
        # substring) must not win over gitleaks' own real summary line —
        # matching the FIRST occurrence is itself a fail-open. Matching the
        # LAST occurrence picks the real summary in this adversarial case.
        (check "matches the LAST scanned~ occurrence, not the first (R6 fail-open)" (parse-scanned-bytes "WRN skipping /x/scanned ~99 bytes.txt\nINF scanned ~0 bytes (0) in 80.6ms") 0)
        (check "verified-clean requires nonzero scanned bytes" (gitleaks-verified-clean "INF scanned ~72 bytes (72 bytes) in 70.8ms") true)
        (check "zero bytes scanned is NOT verified-clean" (gitleaks-verified-clean "INF scanned ~0 bytes (0) in 77.2ms") false)
        (check "unparseable stderr is NOT verified-clean (no evidence, not innocent)" (gitleaks-verified-clean "no scan summary here") false)
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

# Resolve a mise-managed gitleaks binary in one subprocess call. Returns
# the absolute path, or "" if mise is absent or has no gitleaks. Combining
# probe + resolve avoids calling `mise which gitleaks` twice (once to check
# availability, again to get the path) — a Gate 3 review nit on the first
# version of this script, which had that exact duplication.
def resolve-mise-native [] {
    if (which mise | is-empty) {
        ""
    } else {
        let result = (do { ^mise which gitleaks } | complete)
        if $result.exit_code == 0 {
            ($result.stdout | str trim)
        } else {
            ""
        }
    }
}

# Resolve a gitleaks binary on PATH (non-mise install). Returns the
# absolute path, or "" if not found.
def resolve-path-native [] {
    let found = (which gitleaks)
    if ($found | is-empty) {
        ""
    } else {
        ($found | get 0.path)
    }
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

    let mise_bin = (resolve-mise-native)
    let path_bin = (resolve-path-native)
    let container = (probe-container)
    let docker = (probe-docker)
    let colima = (probe-colima)

    let selected = (select-runtime ($mise_bin | is-not-empty) ($path_bin | is-not-empty) $container $docker $colima)

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

    let binary = match $selected {
        "native-mise" => $mise_bin
        "native-path" => $path_bin
        _ => ""
    }

    {runtime: $selected, binary: $binary}
}

# Pure message builder — kept separate from print/exit so --self-test can
# invoke it directly and assert the interpolation itself doesn't blow up.
# Literal parens in a `$"..."` string are evaluated as nushell expressions
# unless escaped with `\(...\)` — an earlier version of this exact message
# had an unescaped `(checked mise and PATH)` that nushell tried to run as
# an external command named `checked`, crashing before the message ever
# printed (claude-skills-209 Gate 3 review). This function exists so that
# regression has a test, not just a human re-reading the diff.
def native-not-found-message [] {
    $"--runtime native requested but no gitleaks binary found \(checked mise and PATH\)"
}

def validate-runtime [runtime: string] {
    if $runtime == "native" {
        let mise_bin = (resolve-mise-native)
        if ($mise_bin | is-not-empty) {
            {runtime: "native-mise", binary: $mise_bin}
        } else {
            let path_bin = (resolve-path-native)
            if ($path_bin | is-not-empty) {
                {runtime: "native-path", binary: $path_bin}
            } else {
                print $"(ansi red)Error:(ansi reset) (native-not-found-message)"
                exit 1
            }
        }
    } else if $runtime in ["docker" "container" "colima"] {
        {runtime: $runtime, binary: ""}
    } else {
        print $"(ansi red)Error:(ansi reset) Invalid runtime '($runtime)'"
        print "Valid options: native, docker, container, colima"
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

# Is `path` inside a git work tree? Asks git rather than checking for a
# literal `.git` directory: a git worktree or submodule uses a `.git` FILE,
# and a subdirectory of a repo is still inside a work tree. Without --no-git,
# `gitleaks detect` against a path that fails this check logs a git fatal,
# scans 0 bytes, and reports "no leaks found" at exit 0 — a silent fail-open
# (claude-skills-267).
def is-git-worktree [path: string] {
    let result = (do { ^git -C $path rev-parse --is-inside-work-tree } | complete)
    $result.exit_code == 0 and (($result.stdout | str trim) == "true")
}

# Extract the byte count from gitleaks' own scan-summary line, which it
# always logs to stderr regardless of runtime or outcome — e.g.
# "scanned ~72 bytes (72 bytes) in 70.8ms" or "scanned ~0 bytes (0) in
# 77ms". Returns null when the line isn't present (unparseable/unexpected
# gitleaks output), which callers must treat as "no evidence", not as "0".
# Matches the LAST "scanned ~" occurrence, not the first: gitleaks can log
# other lines containing that substring before its own summary (e.g. a file
# path being scanned) — matching first is itself a fail-open vector
# (claude-skills-267 Gate 3 R6). Pure string ops (split row / str index-of
# / str substring), no regex — same style already used by
# test/validate-gitleaks-invocation.nu for structural checks, and avoids a
# `parse` command corner case (empty match tables).
def parse-scanned-bytes [text: string] {
    let parts = ($text | split row "scanned ~")
    if ($parts | length) < 2 {
        return null
    }
    let after = ($parts | last)
    let end_idx = ($after | str index-of " bytes")
    if $end_idx < 0 {
        return null
    }
    let num_str = ($after | str substring 0..($end_idx - 1) | str trim)
    if ($num_str | is-empty) {
        return null
    }
    try { $num_str | into int } catch { null }
}

# What this check actually verifies, precisely (claude-skills-267 Gate 3
# R2 — a prior version of this comment overclaimed "checking the ACTUAL
# evidence gitleaks itself reports" closes fail-open in general; it does
# not, and the wording implied it did):
#
# This closes exactly two cases: a scan that covered LITERALLY ZERO bytes
# (claude-skills-267 Gate 3 B2 — e.g. a freshly `git init`'d repo with zero
# commits, where `is-git-worktree` correctly reports true but git-mode has
# no history to walk), and a scan whose summary couldn't be parsed at all
# (no evidence either way, treated as unverified rather than assumed
# innocent).
#
# It does NOT guarantee the requested scan SCOPE was covered. gitleaks'
# git-mode scans committed history — that is documented gitleaks behavior,
# not a bug this function fixes. A repo with one committed file and a
# separate uncommitted secret scans a nonzero byte count (the committed
# file) and passes this check while the uncommitted secret is never
# examined; reproduced directly (one-commit repo + live untracked secret →
# scanned_bytes = 9, verified-clean = true, secret unexamined). Whether
# gitleaks should also cover the working tree by default is a separate,
# already-filed question — this function only proves "something was
# scanned," never "the thing you meant to scan was scanned."
def gitleaks-verified-clean [stderr: string] {
    let scanned_bytes = (parse-scanned-bytes $stderr)
    $scanned_bytes != null and $scanned_bytes > 0
}

# Args for a directly-invoked native binary: real host paths, no /code mount prefix.
def build-gitleaks-args-native [scan_path: string, report: string, config: string, baseline: string, in_git: bool] {
    mut args = ["detect" $"--source=($scan_path)"]

    if not $in_git {
        $args = ($args | append "--no-git")
    }

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
# is bind-mounted at /code inside the container. `in_git` reflects the HOST
# path's git status (checked once in main, before the mount) — the bind
# mount carries the host's .git (or its absence) straight into /code, so the
# same fail-open hole applies here without --no-git (claude-skills-267).
def build-gitleaks-args-container [report: string, config: string, baseline: string, verbose: bool, in_git: bool] {
    mut args = ["detect" "--source=/code"]

    if not $in_git {
        $args = ($args | append "--no-git")
    }

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

    if $result.exit_code == 1 {
        print $"(ansi red)Secrets detected!(ansi reset)"
        print $result.stderr
        exit 1
    } else if $result.exit_code != 0 {
        print $"(ansi red)Error running gitleaks:(ansi reset)"
        print $result.stderr
        exit $result.exit_code
    }

    # exit_code == 0 here — gitleaks itself found nothing, but that only
    # means something if it actually scanned bytes. Print stderr (gitleaks'
    # scan summary lives there, not in stdout) and refuse to report clean
    # without it (see gitleaks-verified-clean). Distinct marker from real
    # detection (claude-skills-267 Gate 3 R5): printing "Secrets detected!"
    # when nothing was actually detected is a fabricated claim in a
    # security tool, even in service of failing closed.
    print $result.stderr
    if not (gitleaks-verified-clean $result.stderr) {
        print $"(ansi red)Scan unverified!(ansi reset)"
        print $"(ansi red)Error:(ansi reset) gitleaks reported success but scanned 0 bytes \(or the scan summary could not be parsed\) — refusing to report clean without evidence something was actually scanned"
        exit 1
    }

    print $"(ansi green)No secrets detected(ansi reset)"
    exit 0
}

# Stream separation (claude-skills-267 Gate 3 R7): the bytes-verification
# invariant below depends on `$result.stderr` actually containing gitleaks'
# scan-summary line rather than an empty string from a merged stdout/stderr
# stream. Verified empirically against Apple Container 1.0.0 (no -t/-it
# flag is passed to `container run`, so no pseudo-TTY merge): a clean scan
# of a real fixture correctly reported "No secrets detected" (stderr
# carried "scanned ~29 bytes" and parsed), and a zero-commit-repo fixture
# correctly reported "Scan unverified!" (stderr carried "scanned ~0
# bytes"). Docker and Colima were NOT reachable to test on this host
# (`docker info` unavailable) — same reasoning applies (no -t flag passed
# here either), but that specific claim is unverified for those two
# runtimes.
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

    if $result.exit_code == 1 {
        print $"(ansi red)Secrets detected!(ansi reset)"
        print $result.stderr
        exit 1
    } else if $result.exit_code != 0 {
        print $"(ansi red)Error running gitleaks:(ansi reset)"
        print $result.stderr
        exit $result.exit_code
    }

    # Same "never report clean without evidence" invariant as
    # run-gitleaks-native — gitleaks logs its scan summary to stderr
    # regardless of runtime, so the container path has the identical hole.
    # Same distinct "Scan unverified!" marker (Gate 3 R5) — see the
    # run-gitleaks-native comment for why it must not say "Secrets
    # detected!" when nothing was actually detected.
    print $result.stderr
    if not (gitleaks-verified-clean $result.stderr) {
        print $"(ansi red)Scan unverified!(ansi reset)"
        print $"(ansi red)Error:(ansi reset) gitleaks reported success but scanned 0 bytes \(or the scan summary could not be parsed\) — refusing to report clean without evidence something was actually scanned"
        exit 1
    }

    print $"(ansi green)No secrets detected(ansi reset)"
    exit 0
}
