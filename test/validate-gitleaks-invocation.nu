#!/usr/bin/env nu

# Regression tests for claude-skills-267: gitleaks fail-open on non-git scan
# paths and on zero-commit git repos, and drift between the three
# implementations of the same invariants (scripts/gitleaks.nu,
# scripts/gitleaks.sh, and templates/mise.toml's [tasks.gitleaks] — shared
# by gitleaks:docker/gitleaks:colima via delegation).
#
# Gate 3 defeated textual (grep-the-source) checks against the template
# FOUR separate ways across three review rounds: a marker matching the
# task's own description prose, a marker inside a comment, a marker inside
# a bare string literal, and a marker inside a caret-bearing string literal
# in a dead (`if false { ... }`) branch. Each fix closed the witness, not
# the class — substring matching over source text cannot distinguish code
# from data. Gate 3 T1: stop grepping the template, EXECUTE it. Every
# template-facing check below extracts a task's real `run` body (following
# one level of `run = "mise run <other-task>"` delegation, since
# gitleaks:docker/gitleaks:colima are now thin wrappers around
# [tasks.gitleaks]'s shared implementation) and runs it as a real
# subprocess against real fixtures or a controlled, gitleaks-shaped stub —
# a comment, a string literal, or a dead branch cannot fake a subprocess's
# actual behavior.
#
# Usage: nu test/validate-gitleaks-invocation.nu

# ============================================================================
# Fixtures
# ============================================================================

# Slack bot token pattern gitleaks's default ruleset detects (RuleID:
# slack-bot-token) and does NOT allowlist — verified directly against
# gitleaks 8.30.1 before this test was written. The canonical AWS example
# key (AKIAIOSFODNN7EXAMPLE) is allowlisted by gitleaks's default config and
# produces "no leaks found" even when scanned correctly, so it cannot be
# used as a fixture here.
#
# Built at RUNTIME from parts, not as a single committed literal: a literal
# token-shaped string in this file would itself trip the slack-bot-token
# rule on every future scan of this repo, adding a permanent false positive
# to the exact gate this test exists to strengthen. The temp file(s) this
# writes still contain a complete, real token gitleaks detects — only the
# on-disk form of THIS source file avoids the pattern.
def fixture-secret [] {
    ["xoxb" "123456789012" "123456789012" "abcdefghijklmnopqrstuvwx"] | str join "-"
}

# A unique, non-git temp directory containing one file with a real
# (non-allowlisted) secret pattern. Caller is responsible for `rm -rf`.
def make-non-git-secret-fixture [] {
    let dir = (mktemp -d)
    $"slack_token = \"(fixture-secret)\"\n" | save --force ($dir | path join "secret.txt")
    $dir
}

# A unique, non-git temp directory containing one innocuous file — no
# secret content, used for the arg-construction test where detection
# outcome doesn't matter, only the invocation shape does.
def make-non-git-plain-fixture [] {
    let dir = (mktemp -d)
    "hello world\n" | save --force ($dir | path join "plain.txt")
    $dir
}

# A unique git repository with ZERO commits, containing one UNTRACKED file
# with a real secret. `git rev-parse --is-inside-work-tree` reports true
# here (it is a real work tree) even though `git log` has nothing to walk —
# the exact condition the zero-commit fail-open exploits. Caller is
# responsible for `rm -rf`.
def make-zero-commit-git-secret-fixture [] {
    let dir = (mktemp -d)
    git -C $dir init -q
    git -C $dir config user.email "test@example.com"
    git -C $dir config user.name "test"
    $"slack_token = \"(fixture-secret)\"\n" | save --force ($dir | path join "secret.txt")
    $dir
}

# A plain git repo (zero commits, no secret content) used as CWD for the
# controlled-stub tests below (T2/T3) — content doesn't matter there since
# a stub fully controls the scanner's stdout/stderr/exit; only "is this CWD
# a valid git worktree" matters, so the task body reaches its invocation
# point instead of crashing on the unwrapped `git rev-parse --show-toplevel`
# every template task starts with.
def make-plain-git-dir [] {
    let dir = (mktemp -d)
    git -C $dir init -q
    $dir
}

# ============================================================================
# Stub infrastructure (Gate 3 T1/T2/T3 — execute real code against
# controlled, gitleaks-shaped responses instead of grepping source text)
# ============================================================================

def write-stub [dir: string, name: string, body: string] {
    let path = ($dir | path join $name)
    ("#!/usr/bin/env bash\n" + $body + "\n") | save --force $path
    chmod +x $path
}

# Stub `mise` (which-gitleaks fails, forcing PATH fallback to the `gitleaks`
# stub below — the same pattern test/validate-security-hook.nu already uses
# to test gitleaks exit-code handling) and a `gitleaks` binary that prints
# the given canned stdout/stderr and exits with the given code, ignoring its
# real arguments. Base64-round-trips both streams so multi-line, quote- and
# paren-heavy fixture text survives the nu -> bash handoff intact.
def write-native-stub [bin_dir: string, stdout_text: string, stderr_text: string, exit_code: int] {
    let stdout_b64 = ($stdout_text | encode base64)
    let stderr_b64 = ($stderr_text | encode base64)
    let exit_str = ($exit_code | into string)

    write-stub $bin_dir "mise" "exit 1"
    write-stub $bin_dir "gitleaks" (
        "echo \"" + $stdout_b64 + "\" | base64 -d\n" +
        "echo \"" + $stderr_b64 + "\" | base64 -d >&2\n" +
        "exit " + $exit_str
    )
}

# Stub `mise` (exec passthrough — strips tool-version args up to `--` and
# execs the wrapped command directly, so a colima task's `mise exec
# lima@latest colima@latest -- docker run ...` transparently reaches the
# `docker` stub below with no real lima/colima involved), `docker`/
# `container` (info/system-status succeed; `run` prints the given canned
# stdout/stderr and exits with the given code), and `colima` (status/start
# always succeed). Deliberately provides NO `gitleaks` stub — paired with
# safe-minimal-path below, this makes native-binary resolution genuinely
# fail so the container/docker/colima dispatch branch actually executes.
def write-container-stubs [bin_dir: string, stdout_text: string, stderr_text: string, exit_code: int] {
    let stdout_b64 = ($stdout_text | encode base64)
    let stderr_b64 = ($stderr_text | encode base64)
    let exit_str = ($exit_code | into string)

    write-stub $bin_dir "mise" (
        "if [ \"$1\" = \"exec\" ]; then\n" +
        "  shift\n" +
        "  while [ \"$#\" -gt 0 ] && [ \"$1\" != \"--\" ]; do shift; done\n" +
        "  shift\n" +
        "  exec \"$@\"\n" +
        "fi\n" +
        "exit 1"
    )
    write-stub $bin_dir "docker" (
        "if [ \"$1\" = \"info\" ]; then\n" +
        "  exit 0\n" +
        "fi\n" +
        "if [ \"$1\" = \"run\" ]; then\n" +
        "  echo \"" + $stdout_b64 + "\" | base64 -d\n" +
        "  echo \"" + $stderr_b64 + "\" | base64 -d >&2\n" +
        "  exit " + $exit_str + "\n" +
        "fi\n" +
        "exit 0"
    )
    write-stub $bin_dir "container" (
        "if [ \"$1\" = \"system\" ]; then\n" +
        "  exit 0\n" +
        "fi\n" +
        "if [ \"$1\" = \"run\" ]; then\n" +
        "  echo \"" + $stdout_b64 + "\" | base64 -d\n" +
        "  echo \"" + $stderr_b64 + "\" | base64 -d >&2\n" +
        "  exit " + $exit_str + "\n" +
        "fi\n" +
        "exit 0"
    )
    write-stub $bin_dir "colima" "exit 0"
}

# A PATH that provides nu/git/bash (needed to run an extracted script and
# its own stub tools). Real gitleaks is genuinely absent from every
# directory this collects. Real mise is NOT absent — on a Homebrew host
# `which git`'s directory (e.g. /opt/homebrew/bin) also holds the real
# `mise` binary, verified directly (`ls $(dirname $(which git)) | grep -x
# mise`). This PATH alone does not suppress native resolution.
#
# The suppression is entirely the caller's responsibility: every call site
# below MUST prepend its stub bin_dir ahead of this list
# (`[$bin_dir] | append (safe-minimal-path))`), never append it. The stub's
# `mise` shadows the real one purely by PATH ORDER. Flip prepend to append
# and every "container/colima" test silently starts hitting the real mise
# -> real gitleaks native path instead — still exercising SOME code, but
# not the container dispatch the test claims to cover, and it would keep
# passing while testing nothing. Resolved dynamically, not hardcoded to one
# machine's layout.
def safe-minimal-path [] {
    let nu_dir = (which nu | get -o 0.path | default "" | path dirname)
    let git_dir = (which git | get -o 0.path | default "" | path dirname)
    let bash_dir = (which bash | get -o 0.path | default "" | path dirname)
    [$nu_dir $git_dir $bash_dir "/usr/bin" "/bin"] | where {|p| ($p | is-not-empty) and ($p | path exists)} | uniq
}

# ============================================================================
# Template task extraction (Gate 3 T1/T3 — real TOML structure, not regex
# guesswork over prose)
#
# Gate 3 round 4: an earlier version of this section sliced the RAW file
# text with `str index-of`/`str substring` instead of parsing it as TOML.
# `run = """..."""` is a TOML basic (not literal) multi-line string, and
# mise's TOML parser un-escapes it before nu ever sees it — a raw-text
# slice never applies that unescaping. That bug produced a false report
# that the template's `\\d`-doubled-backslash regex was broken; it is not
# — TOML unescapes `\\d` to `\d` before nu evaluates it, verified directly
# by comparing a raw slice against `$content | from toml`. Parse the file
# as TOML and index into the parsed value; never slice its text again.
# ============================================================================

# Extracts task_name's declaration from the PARSED template. Returns:
#   {kind: "script", body: string}                          — a
#     self-contained `run = """...""""` body, already TOML-unescaped.
#   {kind: "delegate", target: string, runtime: string}      — a
#     `run = "mise run <target>"` wrapper, with its own
#     `env.GITLEAKS_RUNTIME` value (empty string if undeclared).
#   null if the task or its `run` field isn't found in a recognized shape.
def extract-task [content: string, task_name: string] {
    let parsed = ($content | from toml)
    let task = ($parsed.tasks | get -o $task_name)
    if $task == null {
        return null
    }
    let run_value = ($task | get -o run)
    if $run_value == null {
        return null
    }

    let delegate_prefix = "mise run "
    if ($run_value | str starts-with $delegate_prefix) {
        # Not a self-contained script — a single-line delegation (how
        # gitleaks:docker/gitleaks:colima share [tasks.gitleaks]'s
        # implementation, Gate 3 T3).
        let target = ($run_value | str substring ($delegate_prefix | str length)..)
        let runtime = ($task | get -o env | default {} | get -o GITLEAKS_RUNTIME | default "")
        return {kind: "delegate", target: $target, runtime: $runtime}
    }

    {kind: "script", body: $run_value}
}

# Resolves task_name to what actually runs when it's invoked: its own body
# if self-contained, or its delegation target's body plus the
# GITLEAKS_RUNTIME value THIS task's own `env` block declares. Follows
# exactly one level of delegation (the current template's shape) and
# returns null — a hard failure the caller must check, not a silent
# fallback — if the target isn't itself a self-contained script (a broken
# or chained delegation).
def resolve-task-execution [content: string, task_name: string] {
    let t = (extract-task $content $task_name)
    if $t == null {
        return null
    }
    if $t.kind == "script" {
        return {body: $t.body, runtime: ""}
    }
    let target_task = (extract-task $content $t.target)
    if $target_task == null or $target_task.kind != "script" {
        return null
    }
    {body: $target_task.body, runtime: $t.runtime}
}

# Enumerates documented gitleaks SCAN tasks from the PARSED template — any
# task name that starts with "gitleaks" and isn't a `gitleaks:stop*`
# teardown task. Reads the task list from the file's own parsed structure
# rather than a hardcoded name list (Gate 3 T3), so a fourth scan task
# added later is covered automatically.
def list-gitleaks-scan-tasks [content: string] {
    let parsed = ($content | from toml)
    ($parsed.tasks | columns) | where {|name| ($name | str starts-with "gitleaks") and not ($name | str contains "stop")}
}

# Extracts the colima OS-gate's exact print message from a resolved
# [tasks.gitleaks] body (Gate 3 V1) — reads the real string out of the
# parsed body rather than hardcoding a copy that could silently drift from
# it. Returns null if the line isn't found (a broken/removed gate), which
# the caller must treat as "gate did not fire", not as a pass.
def extract-colima-os-gate-message [gitleaks_body: string] {
    let line = ($gitleaks_body | lines | where {|l| $l | str contains "only available on macOS"} | get -o 0)
    if $line == null {
        return null
    }
    let quote_start = ($line | str index-of '"')
    if $quote_start < 0 {
        return null
    }
    let after = ($line | str substring ($quote_start + 1)..)
    let quote_end = ($after | str index-of '"')
    if $quote_end < 0 {
        return null
    }
    $after | str substring 0..($quote_end - 1)
}

# Runs a resolved task body as a real subprocess: CWD=cwd (every template
# task computes its scan target via `git rev-parse --show-toplevel`, which
# is CWD-relative), PATH=path_list, GITLEAKS_RUNTIME set from `resolved`
# when its delegation declared one.
def run-resolved-task [resolved: record, cwd: string, path_list: list<string>] {
    let tmp_script = (mktemp --suffix .nu)
    $resolved.body | save --force $tmp_script
    let env_record = if ($resolved.runtime | is-empty) {
        {PATH: $path_list}
    } else {
        {PATH: $path_list, GITLEAKS_RUNTIME: $resolved.runtime}
    }
    let result = (with-env $env_record { do { cd $cwd; ^nu $tmp_script } | complete })
    rm -f $tmp_script
    $result
}

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let script = ($repo_root | path join "plugins" "core" "skills" "security" "scripts" "gitleaks.nu")
    let sh_script = ($repo_root | path join "plugins" "core" "skills" "security" "scripts" "gitleaks.sh")
    let template = ($repo_root | path join "plugins" "core" "skills" "security" "templates" "mise.toml")

    if not ($script | path exists) {
        print $"(ansi red_bold)❌ gitleaks.nu not found at ($script)(ansi reset)"
        exit 1
    }
    if not ($sh_script | path exists) {
        print $"(ansi red_bold)❌ gitleaks.sh not found at ($sh_script)(ansi reset)"
        exit 1
    }
    if not ($template | path exists) {
        print $"(ansi red_bold)❌ security template mise.toml not found at ($template)(ansi reset)"
        exit 1
    }

    mut failed = false

    # --- Case 1: fail-open regression on a non-git scan path (gitleaks.nu)
    let secret_dir = (make-non-git-secret-fixture)
    let scan = (nu $script --path $secret_dir -R native | complete)
    if not ($scan.stdout | str contains "Secrets detected!") {
        print $"(ansi red_bold)❌ [gitleaks.nu] non-git scan with a real secret present: want 'Secrets detected!' in output, script exit ($scan.exit_code) — fail-open regression \(claude-skills-267\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.nu] non-git scan with a real secret present blocks \(Secrets detected!\)(ansi reset)"
    }
    rm -rf $secret_dir

    # --- Case 2: non-git scan path must add --no-git to the constructed
    # gitleaks arguments (gitleaks.nu).
    let plain_dir = (make-non-git-plain-fixture)
    let arg_check = (nu $script --path $plain_dir -R native | complete)
    let command_line = ($arg_check.stdout | lines | where {|l| $l | str contains "Command:"} | get -o 0 | default "")
    if not ($command_line | str contains "--no-git") {
        print $"(ansi red_bold)❌ [gitleaks.nu] non-git scan path: constructed gitleaks args do not include --no-git(ansi reset)"
        print $"   command line: ($command_line)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.nu] non-git scan path: constructed gitleaks args include --no-git(ansi reset)"
    }
    rm -rf $plain_dir

    # --- Case 3 (Gate 3 T1 — execute the template, not grep it): run
    # [tasks.gitleaks]'s REAL body against the REAL non-git and zero-commit
    # fixtures, no stub. Four separate textual-mutation shapes (description,
    # comment, bare string literal, caret-bearing string literal in a dead
    # branch) each defeated a marker-matching version of this check across
    # three review rounds — genuine subprocess execution cannot be faked by
    # any of them.
    let content = (open $template --raw)
    let gitleaks_resolved = (resolve-task-execution $content "gitleaks")
    if $gitleaks_resolved == null {
        print $"(ansi red_bold)❌ [template] could not resolve [tasks.gitleaks]'s run body(ansi reset)"
        $failed = true
    } else {
        # Non-git directory: every template task computes its scan target
        # via an UNWRAPPED `git rev-parse --show-toplevel`, which raises a
        # hard nu shell error (exit 128, "fatal: not a git repository")
        # before the script ever reaches its own args/verification logic —
        # confirmed directly. This is a LOUD failure, never a silent
        # "No secrets detected" — the invariant that actually generalizes
        # here (and the one a regression could plausibly break, e.g. by
        # wrapping the git call in `do {} | complete` without also adding
        # the graceful handling that would require) is "never silently
        # claims clean", not the specific "Secrets detected!" marker
        # gitleaks.nu's --path-parameterized form can reach and this
        # CWD-only form structurally cannot.
        let tmp_nongit = (mktemp -d)
        "unused\n" | save --force ($tmp_nongit | path join "f.txt")
        let nongit_result = (do { cd $tmp_nongit; ^nu (
            let p = (mktemp --suffix .nu); $gitleaks_resolved.body | save --force $p; $p
        ) } | complete)
        if ($nongit_result.stdout | str contains "No secrets detected") {
            print $"(ansi red_bold)❌ [template] [tasks.gitleaks] silently reported clean when run outside any git repository at all(ansi reset)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ [template] [tasks.gitleaks] never silently reports clean outside a git repository \(exit ($nongit_result.exit_code)\)(ansi reset)"
        }
        rm -rf $tmp_nongit

        # Zero-commit git repo: reachable, meaningful defect shape for this
        # CWD-driven task (unlike the non-git case above).
        let zero_commit_dir = (make-zero-commit-git-secret-fixture)
        let template_zero_commit = (run-resolved-task $gitleaks_resolved $zero_commit_dir ($env.PATH | default []))
        if not ($template_zero_commit.stdout | str contains "Scan unverified!") {
            print $"(ansi red_bold)❌ [template] [tasks.gitleaks] zero-commit git repo with an untracked secret present: want 'Scan unverified!' in output, exit ($template_zero_commit.exit_code) — fail-open regression \(claude-skills-267\)(ansi reset)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ [template] [tasks.gitleaks] zero-commit git repo with an untracked secret present blocks \(Scan unverified!\)(ansi reset)"
        }
        rm -rf $zero_commit_dir
    }

    # --- Case 4: fail-open on a zero-commit git repo (gitleaks.nu).
    let zc_dir = (make-zero-commit-git-secret-fixture)
    let zc_scan = (nu $script --path $zc_dir -R native | complete)
    if not ($zc_scan.stdout | str contains "Scan unverified!") {
        print $"(ansi red_bold)❌ [gitleaks.nu] zero-commit git repo with an untracked secret present: want 'Scan unverified!' in output, script exit ($zc_scan.exit_code) — fail-open regression \(claude-skills-267\)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.nu] zero-commit git repo with an untracked secret present blocks \(Scan unverified!\)(ansi reset)"
    }
    rm -rf $zc_dir

    # --- Case 5/6: gitleaks.sh parity — same two fail-open shapes as Cases
    # 1 and 4, now that gitleaks.sh has gained -R native support.
    let sh_secret_dir = (make-non-git-secret-fixture)
    let sh_scan = (do { ^bash $sh_script --path $sh_secret_dir -R native } | complete)
    let sh_combined = ($sh_scan.stdout + $sh_scan.stderr)
    if not ($sh_combined | str contains "Secrets detected!") {
        print $"(ansi red_bold)❌ [gitleaks.sh] non-git scan with a real secret present: want 'Secrets detected!' in output, script exit ($sh_scan.exit_code)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.sh] non-git scan with a real secret present blocks \(Secrets detected!\)(ansi reset)"
    }
    rm -rf $sh_secret_dir

    let sh_zero_commit_dir = (make-zero-commit-git-secret-fixture)
    let sh_zero_scan = (do { ^bash $sh_script --path $sh_zero_commit_dir -R native } | complete)
    let sh_zero_combined = ($sh_zero_scan.stdout + $sh_zero_scan.stderr)
    if not ($sh_zero_combined | str contains "Scan unverified!") {
        print $"(ansi red_bold)❌ [gitleaks.sh] zero-commit git repo with an untracked secret present: want 'Scan unverified!' in output, script exit ($sh_zero_scan.exit_code)(ansi reset)"
        $failed = true
    } else {
        print $"(ansi green_bold)✅ [gitleaks.sh] zero-commit git repo with an untracked secret present blocks \(Scan unverified!\)(ansi reset)"
    }
    rm -rf $sh_zero_commit_dir

    # --- Gate 3 T3: extend the zero-bytes invariant to EVERY documented
    # gitleaks scan task, enumerated from the template (not hardcoded), each
    # resolved through delegation and run for real against a controlled
    # zero-bytes gitleaks-shaped response with native resolution suppressed
    # (safe-minimal-path + write-container-stubs) — this exercises the
    # gitleaks:docker/gitleaks:colima -> [tasks.gitleaks] delegation and
    # runtime dispatch specifically, not just re-hitting the native branch.
    let zero_bytes_stdout = "gitleaks console output"
    let zero_bytes_stderr = "0 commits scanned.\nscanned ~0 bytes (0) in 5ms\nno leaks found\n"
    let scan_tasks = (list-gitleaks-scan-tasks $content)
    if ($scan_tasks | is-empty) {
        print $"(ansi red_bold)❌ [template] no documented gitleaks scan tasks found — enumeration itself is broken(ansi reset)"
        $failed = true
    }
    for task_name in $scan_tasks {
        let resolved = (resolve-task-execution $content $task_name)
        if $resolved == null {
            print $"(ansi red_bold)❌ [template] [tasks.\"($task_name)\"] could not be resolved \(broken or unrecognized delegation shape\)(ansi reset)"
            $failed = true
            continue
        }
        let bin_dir = (mktemp -d)
        write-container-stubs $bin_dir $zero_bytes_stdout $zero_bytes_stderr 0
        # LOAD-BEARING ORDER: bin_dir MUST come first. safe-minimal-path
        # does not exclude real mise (see its comment) — the stub `mise`
        # only shadows the real one because it is earlier on PATH. Reorder
        # this to `(safe-minimal-path) | append $bin_dir` and this loop
        # silently starts testing the real native path instead of the
        # container dispatch it claims to.
        let stub_path = ([$bin_dir] | append (safe-minimal-path))
        let cwd = (make-plain-git-dir)
        let result = (run-resolved-task $resolved $cwd $stub_path)

        # Colima is genuinely macOS-only — the template's colima match arm
        # has its own `if $nu.os-info.name != "macos" { ... exit 1 }` gate,
        # verified directly by reading the resolved body, and this is
        # correct/intentional (Colima itself does not run on Linux). An
        # earlier version of this assertion expected "Scan unverified!"
        # unconditionally, which made the test's verdict depend on the
        # runner's OS instead of on the code under test: green on this
        # (macOS) host, red on GitHub's ubuntu-latest runner, which the
        # colima branch's OS gate exits out of before ever reaching the
        # byte-verification logic.
        #
        # Gate 3 V1: a SECOND version of this assertion ("exit_code != 0 and
        # not claiming clean") still passed on a crash, a syntax error, or
        # the colima arm being silently misrouted to the docker arm — any
        # nonzero exit without "No secrets detected" satisfied it, whether
        # or not the OS gate itself ever fired. Assert the OS gate's own
        # message instead, extracted dynamically from the resolved body
        # (not copied as a literal here, which could silently drift from
        # the real string) — this is only satisfiable by the actual gate
        # firing.
        let is_colima_on_non_macos = ($resolved.runtime == "colima") and ($nu.os-info.name != "macos")
        if $is_colima_on_non_macos {
            let os_gate_message = (extract-colima-os-gate-message $resolved.body)
            let fires_correctly = if $os_gate_message == null {
                false
            } else {
                ($result.stdout | str contains $os_gate_message)
            }
            if not $fires_correctly {
                print $"(ansi red_bold)❌ [template] [tasks.\"($task_name)\"] \(runtime=colima, non-macOS\) does not fire the macOS-only gate: exit ($result.exit_code), stdout: ($result.stdout | str substring 0..120)(ansi reset)"
                $failed = true
            } else {
                print $"(ansi green_bold)✅ [template] [tasks.\"($task_name)\"] \(runtime=colima\) fires the macOS-only gate on non-macOS instead of silently reporting clean(ansi reset)"
            }
        } else if not ($result.stdout | str contains "Scan unverified!") {
            print $"(ansi red_bold)❌ [template] [tasks.\"($task_name)\"] \(runtime=($resolved.runtime)\) lacks the zero-bytes verification invariant: want 'Scan unverified!', exit ($result.exit_code) \(claude-skills-267 Gate 3 T3\)(ansi reset)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ [template] [tasks.\"($task_name)\"] \(runtime=($resolved.runtime)\) enforces the zero-bytes verification invariant(ansi reset)"
        }
        rm -rf $bin_dir
        rm -rf $cwd
    }

    # --- Gate 3 T2: cross-implementation conformance table. Feeds the SAME
    # stderr fixtures to gitleaks.nu, gitleaks.sh, and the template's
    # [tasks.gitleaks] native branch via a stubbed native `gitleaks` binary,
    # and asserts they agree — this is what stops the three copies drifting
    # apart again (Gate 3 R6 first-vs-last occurrence picking was the first
    # drift).
    #
    # Fixtures adapted from the reviewer's originals to the FULL real
    # gitleaks log-line shape ("scanned ~<digits> bytes (<total>) in
    # <duration>") that all three implementations now anchor their regex on
    # (Gate 3 T2/T4/R6 hardening) — an incomplete fixture (no trailing
    # " in <duration>") fails to match ANY of the three uniformly, which
    # tests nothing.
    #
    # Gate 3 U3: an earlier version of this comment claimed a full-shaped
    # decoy ("scanned ~N bytes (X) in Yms" appearing a SECOND time) could
    # not occur, since gitleaks emits exactly one scan-summary line per
    # invocation — that claim was wrong. stderr also carries file PATHS,
    # and a file NAME can carry the full shape. Reproduced live against
    # gitleaks 8.30.1: a file literally named
    # "scanned ~4242 bytes (4242 bytes) in 7ms", made unreadable
    # (chmod 000, non-empty so gitleaks attempts and fails the read rather
    # than short-circuiting on "skipping empty file"), produces
    # `WRN skipping file: permission denied path="scanned ~4242 bytes
    # (4242 bytes) in 7ms"` on stderr at the DEFAULT log level — a second,
    # complete match for the anchor regex, verified with `cat -A`-style
    # capture of the real process's stderr (ascii-art banner trimmed below
    # for readability; every log line is verbatim).
    #
    # The invariant that actually keeps last-match-wins correct: gitleaks
    # logs every WARN/INF diagnostic line BEFORE its final scan-summary
    # line, so the REAL summary is always the LAST full-shaped match in a
    # real run — the fixture below is that live reproduction, decoy first,
    # real (correct) 0-byte summary last. The second fixture takes the
    # SAME real decoy text and moves it after the real summary — an
    # ordering gitleaks itself would never produce, but one nothing here
    # prevents from occurring (a future gitleaks log-order change, a
    # downstream tool appending output, etc.) — to PIN the current
    # contingent behavior (verified=true, the wrong answer) rather than
    # leave the dependency on log ordering implicit and untested.
    let table = [
        {label: "zero bytes" stderr: "0 commits scanned.\nscanned ~0 bytes (0) in 5ms\nno leaks found\n" expected: false contingent: false}
        {label: "clean 72 bytes" stderr: "scanned ~72 bytes (72 bytes) in 10ms\nno leaks found\n" expected: true contingent: false}
        {label: "real summary + non-matching decoy path (notanumber)" stderr: "scanned ~72 bytes (72 bytes) in 10ms\nno leaks found\nsome file named scanned ~notanumber.txt exists\n" expected: true contingent: false}
        {label: "comma-formatted number (not real gitleaks output shape)" stderr: "scanned ~9,107,683 bytes (9.11 MB) in 50ms\nno leaks found\n" expected: null contingent: false}
        {label: "real summary + bare trailing 'scanned ~'" stderr: "scanned ~72 bytes (72 bytes) in 10ms\nno leaks found\ntrailing garbage scanned ~\n" expected: true contingent: false}
        {label: "live-reproduced filename decoy BEFORE the real summary (gitleaks 8.30.1)" stderr: "10:20AM WRN skipping file: permission denied path=\"scanned ~4242 bytes (4242 bytes) in 7ms\"\n10:20AM INF scanned ~0 bytes (0) in 588µs\n10:20AM INF no leaks found\n" expected: false contingent: false}
        {label: "same real decoy moved AFTER the summary — CURRENTLY-WRONG pinned verdict, not a target (see contingent note)" stderr: "10:20AM INF scanned ~0 bytes (0) in 588µs\n10:20AM INF no leaks found\n10:20AM WRN skipping file: permission denied path=\"scanned ~4242 bytes (4242 bytes) in 7ms\"\n" expected: true contingent: true}
    ]

    for c in $table {
        # gitleaks.nu
        let nu_bin = (mktemp -d)
        write-native-stub $nu_bin "" $c.stderr 0
        let nu_path = ([$nu_bin] | append ($env.PATH | default []))
        let nu_dir = (make-plain-git-dir)
        let nu_result = (with-env {PATH: $nu_path} { nu $script --path $nu_dir -R native } | complete)
        let nu_verified = ($nu_result.stdout | str contains "No secrets detected")
        rm -rf $nu_bin
        rm -rf $nu_dir

        # gitleaks.sh
        let sh_bin = (mktemp -d)
        write-native-stub $sh_bin "" $c.stderr 0
        let sh_path = ([$sh_bin] | append ($env.PATH | default []))
        let sh_dir = (make-plain-git-dir)
        let sh_result = (with-env {PATH: $sh_path} { do { ^bash $sh_script --path $sh_dir -R native } } | complete)
        let sh_combined_out = ($sh_result.stdout + $sh_result.stderr)
        let sh_verified = ($sh_combined_out | str contains "No secrets detected")
        rm -rf $sh_bin
        rm -rf $sh_dir

        # template [tasks.gitleaks] native branch
        let tpl_bin = (mktemp -d)
        write-native-stub $tpl_bin "" $c.stderr 0
        let tpl_path = ([$tpl_bin] | append ($env.PATH | default []))
        let tpl_dir = (make-plain-git-dir)
        let tpl_resolved = (resolve-task-execution $content "gitleaks")
        let tpl_result = if $tpl_resolved == null { {stdout: "", exit_code: -1} } else { (run-resolved-task $tpl_resolved $tpl_dir $tpl_path) }
        let tpl_verified = ($tpl_result.stdout | str contains "No secrets detected")
        rm -rf $tpl_bin
        rm -rf $tpl_dir

        let verdicts = {gitleaks.nu: $nu_verified, gitleaks.sh: $sh_verified, template: $tpl_verified}
        let all_agree = ($nu_verified == $sh_verified) and ($sh_verified == $tpl_verified)

        # Gate 3 V3: a row can be marked `contingent: true` — its `expected`
        # value is a PINNED CURRENTLY-WRONG verdict (see the ordering
        # comment above the table), not a target to preserve. Without this,
        # a maintainer who correctly hardens the parser (e.g. anchoring to
        # the INF-prefixed summary line specifically) sees a bare
        # "expected true, got false" failure that reads exactly like a
        # regression they caused — and the cheapest way to green is to
        # revert their own fix. Surface the flag in both outcomes so the
        # message itself says what it means.
        if not $all_agree {
            print $"(ansi red_bold)❌ [T2 conformance] ($c.label): implementations disagree — ($verdicts)(ansi reset)"
            $failed = true
        } else if $c.expected != null and $nu_verified != $c.expected {
            let contingent_note = if $c.contingent {
                " -- this row is PINNED CONTINGENT, its expected value is a KNOWN-WRONG verdict: a flip away from it is very likely a parser improvement, not a regression. Update `expected` to match, do not revert whatever caused this."
            } else {
                ""
            }
            print $"(ansi red_bold)❌ [T2 conformance] ($c.label): all three agree, but on the WRONG verdict — want verified=($c.expected), got ($nu_verified) \(claude-skills-267 Gate 3 T4\)($contingent_note)(ansi reset)"
            $failed = true
        } else {
            let contingent_note = if $c.contingent {
                " -- PINNED CONTINGENT value, not a target: this verdict is currently WRONG (see the ordering comment above the table)."
            } else {
                ""
            }
            print $"(ansi green_bold)✅ [T2 conformance] ($c.label): consistent verdict verified=($nu_verified) across gitleaks.nu, gitleaks.sh, template($contingent_note)(ansi reset)"
        }
    }

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ gitleaks invocation checks verified(ansi reset)"
}
