#!/usr/bin/env nu

# Regression test for check-secrets-before-commit.sh's gitleaks exit-code
# handling (claude-skills-224) AND its command-detection / staged-file-export
# correctness (claude-skills-271). Before the 224 fix, ANY gitleaks exit code
# other than 0 (clean) or 1 (secrets found) fell into a "scan failed -> allow
# the commit" branch. That is a standing, silent bypass: a single committed
# broken .gitleaks.toml makes every subsequent scan exit non-1, and every
# commit thereafter is allowed with only a warning, indefinitely. This repo
# has no gitleaks step in CI (verified via `grep -rni gitleaks .github/`
# returning zero hits), so this hook is the only automated secret scan —
# the fail-open here has no other line of defense behind it.
#
# claude-skills-271 adds four more confirmed bypasses, all empirically
# verified against real git/bash before writing the tests below:
#   - Detection regex (:51) `^git[[:space:]]+commit` is anchored at the
#     START of the command string. `git add . && git commit`, `cd x && git
#     commit`, leading whitespace, an env-var prefix (`FOO=bar git commit`),
#     and global options BEFORE the subcommand (`git -c k=v commit`, `git -C
#     dir commit`, `git --no-pager commit`) never match — the hook exits 0
#     without ever running gitleaks.
#   - `git diff --cached --name-only` (:62) emits git's QUOTED form for
#     non-ASCII filenames — verified directly: a staged `café.txt` produces
#     the literal string `"caf\303\251.txt"` (quote characters and octal
#     escapes included), not the raw filename. The hook's export loop then
#     runs `git show ":\"caf\303\251.txt\""`, which matches no real path,
#     fails, and `|| true` swallows the failure — verified directly: the
#     resulting temp file exists but is 0 bytes. Nothing of the real
#     content is ever exported.
#   - No bytes-verification invariant anywhere: the hook trusts gitleaks'
#     exit code alone. A scan that covers zero bytes (whatever the cause —
#     the non-ASCII export failure above, or anything else) still exits 0
#     and the hook reports "No secrets detected". This is the same
#     invariant gitleaks.nu, gitleaks.sh, and templates/mise.toml's
#     [tasks.gitleaks] all gained in PR #246/#247 (claude-skills-267); this
#     hook is the one implementation that never got it.
#   - `git commit -am`/`git commit -a -m`/`git commit <path> -m` stage their
#     changes AS PART OF the commit itself — verified directly: at the
#     moment this PreToolUse hook fires (before the intercepted command
#     actually runs), `git diff --cached --name-only` is EMPTY for a
#     modified-but-not-`git add`ed tracked file, so the hook's own
#     "no staged files to scan" branch exits 0 without scanning anything
#     that -a/a pathspec is about to commit.
#
# This test stubs a `gitleaks` binary on PATH with a scripted exit code
# (and, where the byte-invariant matters, scripted stdout/stderr too) and
# asserts the hook's own exit code:
#   0  (clean)          -> hook allows the commit (exit 0)
#   1  (secrets found)  -> hook blocks the commit (exit 2)
#   42 (unexpected)      -> hook now fails CLOSED (exit 2), not open
# plus the pre-existing, still-intentional fail-open when no scanner is
# available at all (documented in the hook's "Fail-open, deliberately" note).
#
# Usage: nu test/validate-security-hook.nu

# Slack bot token pattern gitleaks's default ruleset detects (RuleID:
# slack-bot-token) and does NOT allowlist — the canonical AWS example key
# (AKIAIOSFODNN7EXAMPLE) IS allowlisted by gitleaks's default config and
# produces "no leaks found" even when genuinely scanned, so it cannot be
# used as a fixture here (verified directly against gitleaks 8.30.1 in an
# earlier session on this same repo). Built at RUNTIME from parts, not as a
# single committed literal — a literal token-shaped string in this file
# would itself trip the rule on every future scan of this repo.
def fixture-secret [] {
    ["xoxb" "123456789012" "123456789012" "abcdefghijklmnopqrstuvwx"] | str join "-"
}

# Writes an executable stub at dir/name that ignores all arguments and
# exits with exit_code.
def stub [dir: string, name: string, exit_code: int] {
    let path = ($dir | path join $name)
    $"#!/usr/bin/env bash\nexit ($exit_code)\n" | save --force $path
    chmod +x $path
}

# Writes an executable stub at dir/name that ignores all arguments, prints
# the given stdout/stderr text, and exits with exit_code. Base64
# round-trips both streams so multi-line or quote-heavy text survives the
# nu -> bash handoff intact (claude-skills-271 part 7 — the stub's exit
# code alone is enough since the hook never inspects gitleaks' output, but
# the response shape is built the same way the gitleaks.nu/gitleaks.sh/
# template stub tests already use, for consistency).
def stub-with-response [dir: string, name: string, stdout_text: string, stderr_text: string, exit_code: int] {
    let path = ($dir | path join $name)
    let stdout_b64 = ($stdout_text | encode base64)
    let stderr_b64 = ($stderr_text | encode base64)
    (
        "#!/usr/bin/env bash\n" +
        "echo \"" + $stdout_b64 + "\" | base64 -d\n" +
        "echo \"" + $stderr_b64 + "\" | base64 -d >&2\n" +
        "exit " + ($exit_code | into string) + "\n"
    ) | save --force $path
    chmod +x $path
}

# A minimal git repo with one staged file — enough for the hook to find
# staged content to export and scan.
def setup-repo [] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    "hello world" | save --force ($repo | path join "file.txt")
    git -C $repo add "file.txt"
    $repo
}

# A git repo with file_name STAGED, containing a real (non-allowlisted)
# secret. Caller is responsible for `rm -rf`.
def setup-repo-with-staged-secret [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    let path = ($repo | path join $file_name)
    let parent = ($path | path dirname)
    mkdir $parent
    $"slack_token = \"(fixture-secret)\"\n" | save --force $path
    git -C $repo add $file_name
    $repo
}

# A git repo where file_name is TRACKED (committed clean) but has since
# been modified to contain a secret WITHOUT being re-staged — the exact
# shape `git commit -am`/`-a -m`/`<path> -m` would pick up at commit time,
# which this hook's static `git diff --cached` pre-check cannot see
# (claude-skills-271 part 4). Caller is responsible for `rm -rf`.
def setup-repo-with-unstaged-secret-in-tracked-file [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    let path = ($repo | path join $file_name)
    "clean content\n" | save --force $path
    git -C $repo add $file_name
    git -C $repo commit -q -m "initial"
    $"clean content\nslack_token = \"(fixture-secret)\"\n" | save --force $path
    $repo
}

# Runs the real hook script (Claude Code PreToolUse hook input shape) against
# repo_dir with PATH pinned to path_list, and returns {exit_code, stdout,
# stderr}. `command` defaults to a plain commit so existing exit-code-focused
# call sites are unaffected; claude-skills-271 cases pass the exact command
# shape under test.
def run-hook [hook: string, repo_dir: string, path_list: list, command: string = "git commit -m test"] {
    let input = ({tool_input: {command: $command} cwd: $repo_dir} | to json)
    with-env {PATH: $path_list} {
        $input | bash $hook | complete
    }
}

# Sets up a native-resolution PATH (mise fails, forcing PATH-based
# `command -v gitleaks` to find our stub — the same pattern the exit-code
# cases above already use) with a gitleaks stub that reports the given
# response. Returns {bin_dir: string, path: list} — caller cleans up
# bin_dir.
def native-stub-path [real_path: list, stdout_text: string, stderr_text: string, exit_code: int] {
    let bin_dir = (mktemp -d)
    stub $bin_dir "mise" 1
    stub-with-response $bin_dir "gitleaks" $stdout_text $stderr_text $exit_code
    {bin_dir: $bin_dir, path: ([$bin_dir] | append $real_path)}
}

# Asserts result.exit_code == want_exit, prints pass/fail, returns a bool
# so the caller can accumulate $failed without check() needing to mutate an
# outer variable itself. Never prints result.stdout/stderr verbatim on
# failure without checking first — see the two call sites that redact.
def check [label: string, result: record, want_exit: int] {
    if $result.exit_code != $want_exit {
        print $"(ansi red_bold)❌ ($label): want exit ($want_exit), got ($result.exit_code)(ansi reset)"
        false
    } else {
        print $"(ansi green_bold)✅ ($label)(ansi reset)"
        true
    }
}

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let hook = ($repo_root | path join "plugins" "core" "skills" "security" "hooks" "check-secrets-before-commit.sh")
    if not ($hook | path exists) {
        print $"(ansi red_bold)❌ hook not found at ($hook)(ansi reset)"
        exit 1
    }

    mut failed = false
    let real_path = ($env.PATH | default [])

    # --- Cases 1-3: gitleaks exit-code handling on the native-binary path ---
    let bin_dir = (mktemp -d)
    # A stub `mise` that always fails makes `mise which gitleaks` resolve to
    # nothing, so detect_native() falls through to the PATH-based `command -v
    # gitleaks` lookup below — which finds OUR stub, since bin_dir is
    # prepended to PATH.
    stub $bin_dir "mise" 1
    let native_path = ([$bin_dir] | append $real_path)

    let cases = [
        {label: "gitleaks exit 0 (clean) -> hook allows the commit" gitleaks_exit: 0 want: 0}
        {label: "gitleaks exit 1 (secrets found) -> hook blocks the commit" gitleaks_exit: 1 want: 2}
        {label: "gitleaks exit 42 (unexpected failure) -> hook now fails closed" gitleaks_exit: 42 want: 2}
    ]

    for c in $cases {
        stub $bin_dir "gitleaks" $c.gitleaks_exit
        let repo = (setup-repo)
        let result = (run-hook $hook $repo $native_path)
        if $result.exit_code != $c.want {
            print $"(ansi red_bold)❌ ($c.label): want exit ($c.want), got ($result.exit_code)(ansi reset)"
            print $"   stdout: ($result.stdout)"
            print $"   stderr: ($result.stderr)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ ($c.label)(ansi reset)"
        }
        rm -rf $repo
    }
    rm -rf $bin_dir

    # --- Case 4: no scanner available at all -> pre-existing, documented
    # fail-open. Stub mise/docker/container to fail so none of the runtime
    # branches trigger, and filter any real PATH component containing
    # "mise" — this repo's own gitleaks is mise-managed, so mise's shim/
    # install directories are how a real gitleaks would otherwise leak onto
    # PATH behind our stubs.
    let no_runtime_dir = (mktemp -d)
    stub $no_runtime_dir "mise" 1
    stub $no_runtime_dir "docker" 1
    stub $no_runtime_dir "container" 1
    let filtered_path = ($real_path | where {|p| not ($p | str contains "mise")})
    let no_runtime_path = ([$no_runtime_dir] | append $filtered_path)

    let precheck = (with-env {PATH: $no_runtime_path} { bash -c "command -v gitleaks" | complete })
    if $precheck.exit_code == 0 {
        print $"(ansi yellow)⚠️  skipping no-runtime case: a native gitleaks is still reachable on the filtered PATH \(($precheck.stdout | str trim)\) — cannot construct a clean 'no scanner available' environment on this host(ansi reset)"
    } else {
        let repo = (setup-repo)
        let result = (run-hook $hook $repo $no_runtime_path)
        if $result.exit_code != 0 {
            print $"(ansi red_bold)❌ no-runtime case: want exit 0 \(documented fail-open\), got ($result.exit_code)(ansi reset)"
            print $"   stdout: ($result.stdout)"
            print $"   stderr: ($result.stderr)"
            $failed = true
        } else {
            print $"(ansi green_bold)✅ no gitleaks binary and no container runtime -> hook allows the commit \(documented fail-open\)(ansi reset)"
        }
        rm -rf $repo
    }
    rm -rf $no_runtime_dir

    # ==========================================================================
    # claude-skills-271: command-detection and staged-file-export correctness.
    # Parts 1-4 and 6 use a `gitleaks` stub that UNCONDITIONALLY reports
    # "secrets found" (exit 1) regardless of what's actually in the export
    # temp dir — this isolates exactly one variable per test (does the hook
    # even recognize the command / does it even find something staged to
    # export), independent of whether real gitleaks would correctly detect
    # the fixture token. Part 6 (non-ASCII) deliberately does NOT use that
    # stub — its bug is specifically that gitleaks never receives real bytes
    # to scan, which an unconditional "secrets found" stub would mask; it
    # uses real native gitleaks instead, skipping gracefully if none is
    # reachable (mirroring the no-runtime case's precheck above). Part 7
    # isolates the missing bytes-invariant on its own, independent of the
    # non-ASCII export bug specifically.
    # ==========================================================================

    # --- Part 1: compound commands. `git add . && git commit -m "..."` is
    # THIS REPO'S OWN prescribed workflow (/core:git SKILL.md:105, bees
    # SKILL.md:243, CLAUDE.md:130) — treat as the headline case. `cd <dir>
    # && git commit` covers a commit issued from outside the current cwd.
    let p1a_repo = (setup-repo-with-staged-secret "secret.txt")
    let p1a_stub = (native-stub-path $real_path "" "" 1)
    let p1a_result = (run-hook $hook $p1a_repo $p1a_stub.path "git add . && git commit -m test")
    if not (check "Part 1a: `git add . && git commit -m test` with a staged secret blocks" $p1a_result 2) {
        $failed = true
    }
    rm -rf $p1a_repo
    rm -rf $p1a_stub.bin_dir

    let p1b_repo = (setup-repo-with-staged-secret "secret.txt")
    let p1b_stub = (native-stub-path $real_path "" "" 1)
    let p1b_result = (run-hook $hook $p1b_repo $p1b_stub.path $"cd ($p1b_repo) && git commit -m test")
    if not (check "Part 1b: `cd <dir> && git commit -m test` with a staged secret blocks" $p1b_result 2) {
        $failed = true
    }
    rm -rf $p1b_repo
    rm -rf $p1b_stub.bin_dir

    # --- Part 2: prefixes. Leading whitespace, and an env-var assignment
    # prefix (a real, common shell idiom for one-off commits).
    let p2a_repo = (setup-repo-with-staged-secret "secret.txt")
    let p2a_stub = (native-stub-path $real_path "" "" 1)
    let p2a_result = (run-hook $hook $p2a_repo $p2a_stub.path "  git commit -m test")
    if not (check "Part 2a: leading whitespace before `git commit` with a staged secret blocks" $p2a_result 2) {
        $failed = true
    }
    rm -rf $p2a_repo
    rm -rf $p2a_stub.bin_dir

    let p2b_repo = (setup-repo-with-staged-secret "secret.txt")
    let p2b_stub = (native-stub-path $real_path "" "" 1)
    let p2b_result = (run-hook $hook $p2b_repo $p2b_stub.path "GIT_AUTHOR_NAME=z git commit -m test")
    if not (check "Part 2b: env-var-prefixed `git commit` with a staged secret blocks" $p2b_result 2) {
        $failed = true
    }
    rm -rf $p2b_repo
    rm -rf $p2b_stub.bin_dir

    # --- Part 3: global options between `git` and `commit`.
    let p3_cases = ["git -c k=v commit -m test" "git -C . commit -m test" "git --no-pager commit -m test"]
    for cmd in $p3_cases {
        let repo = (setup-repo-with-staged-secret "secret.txt")
        let stub = (native-stub-path $real_path "" "" 1)
        let result = (run-hook $hook $repo $stub.path $cmd)
        if not (check $"Part 3: `($cmd)` with a staged secret blocks" $result 2) {
            $failed = true
        }
        rm -rf $repo
        rm -rf $stub.bin_dir
    }

    # --- Part 4: staging-timing. `-a`/`--all`/a pathspec stage their
    # changes AS PART OF the commit — this hook's static `git diff --cached`
    # pre-check runs BEFORE that staging happens.
    let p4_cases = [
        {label: "git commit -am" cmd: "git commit -am test"}
        {label: "git commit -a -m" cmd: "git commit -a -m test"}
        {label: "git commit <path> -m" cmd: "git commit secret.txt -m test"}
    ]
    for c in $p4_cases {
        let repo = (setup-repo-with-unstaged-secret-in-tracked-file "secret.txt")
        let stub = (native-stub-path $real_path "" "" 1)
        let result = (run-hook $hook $repo $stub.path $c.cmd)
        if not (check $"Part 4: `($c.label)` with an unstaged secret in a tracked file blocks" $result 2) {
            $failed = true
        }
        rm -rf $repo
        rm -rf $stub.bin_dir
    }

    # --- Part 5: control. Both directions — a fix that blocks EVERYTHING
    # would pass Parts 1-4 and be useless; these two sub-cases catch that.
    # Expected to already pass against the CURRENT (unfixed) hook — these
    # are baseline-sanity/regression guards, not claude-skills-271 defects.
    let p5a_repo = (setup-repo-with-staged-secret "secret.txt")
    let p5a_stub = (native-stub-path $real_path "" "" 1)
    let p5a_result = (run-hook $hook $p5a_repo $p5a_stub.path "git commit -m test")
    if not (check "Part 5a (control): plain `git commit -m test` with a staged secret still blocks" $p5a_result 2) {
        $failed = true
    }
    rm -rf $p5a_repo
    rm -rf $p5a_stub.bin_dir

    let p5b_repo = (setup-repo)
    let p5b_stub = (native-stub-path $real_path "" "" 0)
    let p5b_result = (run-hook $hook $p5b_repo $p5b_stub.path "git commit -m test")
    if not (check "Part 5b (control): plain `git commit -m test` with no secret still succeeds" $p5b_result 0) {
        $failed = true
    }
    rm -rf $p5b_repo
    rm -rf $p5b_stub.bin_dir

    # --- Part 6: non-ASCII staged filename. Verified cause (see the header
    # comment): git's quoted-path output makes the hook's export step fail
    # silently, leaving a 0-byte file at a mis-named path. Uses REAL native
    # gitleaks (not the unconditional stub above) so the effect of the
    # actual export bug is what's observed, not masked by a stub that
    # would "detect" regardless of content. Skips gracefully — like the
    # existing no-runtime case above — if no native gitleaks is reachable
    # on this host.
    let p6_precheck = (bash -c "command -v mise || command -v gitleaks" | complete)
    if $p6_precheck.exit_code != 0 {
        print $"(ansi yellow)⚠️  skipping Part 6 \(non-ASCII filename\): no native gitleaks/mise reachable on this host to run a REAL scan against(ansi reset)"
    } else {
        let p6_repo = (setup-repo-with-staged-secret "café.txt")
        let p6_result = (run-hook $hook $p6_repo $real_path "git commit -m test")
        if not (check "Part 6: staged café.txt (non-ASCII name) with a real secret blocks" $p6_result 2) {
            $failed = true
        }
        rm -rf $p6_repo
    }

    # --- Part 7: bytes-verification invariant, independent of Part 6. A
    # NORMAL ascii file, real secret, export succeeds normally — the ONLY
    # manipulated variable is gitleaks' own reported outcome: a scan that
    # covered zero bytes but still exits 0. The current hook has no
    # mechanism to tell "gitleaks found nothing because it scanned real
    # content" apart from "gitleaks found nothing because there was
    # nothing to scan" — it trusts exit 0 unconditionally.
    let p7_repo = (setup-repo-with-staged-secret "secret.txt")
    let p7_stub = (native-stub-path $real_path "" "0 commits scanned.\nscanned ~0 bytes (0) in 5ms\nno leaks found\n" 0)
    let p7_result = (run-hook $hook $p7_repo $p7_stub.path "git commit -m test")
    if not (check "Part 7: gitleaks reporting a zero-byte scan (exit 0) still blocks" $p7_result 2) {
        $failed = true
    }
    rm -rf $p7_repo
    rm -rf $p7_stub.bin_dir

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ security hook exit-code handling and command-detection/export correctness verified(ansi reset)"
}
