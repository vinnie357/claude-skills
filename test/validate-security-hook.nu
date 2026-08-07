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
# Fixture rule (claude-skills-272 round 3, after this pattern bit Part 13
# and then Part 23): the hook scans untracked files for ANY commit command
# that reaches it, including a plain `git commit` that would not itself
# stage anything new — this is the deliberate claude-skills-271 tradeoff
# (the hook cannot know whether an `add` ran earlier in a compound
# command it can't fully parse, so it errs toward scanning). That means a
# fixture's INCIDENTAL untracked files — anything written to disk for
# setup convenience, not as the condition under test — are always in
# scope for that pass and will trip an unconditional "secrets found" stub
# the moment the untracked pass runs, independent of whatever command
# shape the test claims to be exercising. Before adding a fixture: any
# file created but not `git add`ed+committed must be untracked ON
# PURPOSE (the secret file itself in a "does the untracked pass catch
# this" test, or a deliberately-unstaged modification in a staging-timing
# test) — never incidental. Every setup-repo-* fixture in this file has
# been checked against this rule as of round 3; see each fixture's own
# comment for why its untracked (or tracked) files are the ones they are.
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

# A git repo with an initial commit (so it's not a brand-new repo with zero
# history) and file_name written but NEVER `git add`ed — a genuinely
# untracked, brand-new file, containing a secret. Matches the moment this
# PreToolUse hook fires for `git add . && git commit`: the intercepted
# command hasn't run yet, so the file is still untracked when the hook
# runs (claude-skills-271 A1). Caller is responsible for `rm -rf`.
def setup-repo-with-untracked-secret [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    git -C $repo commit -q --allow-empty -m "initial"
    let path = ($repo | path join $file_name)
    let parent = ($path | path dirname)
    mkdir $parent
    $"slack_token = \"(fixture-secret)\"\n" | save --force $path
    $repo
}

# A git repo where file_name was committed clean, then STAGED FOR DELETION
# (`git rm`) — no secret anywhere in the repo, past or present
# (claude-skills-271 A2). Caller is responsible for `rm -rf`.
def setup-repo-with-staged-deletion [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    let path = ($repo | path join $file_name)
    "clean content, nothing secret\n" | save --force $path
    git -C $repo add $file_name
    git -C $repo commit -q -m "initial"
    git -C $repo rm -q $file_name
    $repo
}

# A git repo with an empty (0-byte) file STAGED — no secret anywhere
# (claude-skills-271 A2). Caller is responsible for `rm -rf`.
def setup-repo-with-staged-empty-file [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    let path = ($repo | path join $file_name)
    "" | save --force $path
    git -C $repo add $file_name
    $repo
}

# A git repo with a COMMITTED (tracked) .gitignore excluding file_name,
# and file_name containing a secret, present on disk but neither tracked
# nor staged — the shape claude-skills-268 decided must NOT be scanned
# (this hook scanning a developer's real .env would be worse than the
# leak it's trying to prevent). Control for claude-skills-271 A1: the
# untracked-file export pass MUST respect .gitignore via
# --exclude-standard, not just pick up "everything on disk".
#
# .gitignore is committed BEFORE file_name is created — Gate 3 round 4:
# an earlier version of this fixture created .gitignore AFTER the initial
# commit and never tracked it, which is not how real repositories look
# (.gitignore is tracked). `git ls-files --others --exclude-standard`
# correctly lists an UNTRACKED .gitignore itself (nothing excludes a
# gitignore file from itself), which fired the unconditional
# "secrets found" stub and produced a false block — the implementer
# worked around that by gating the untracked-file export pass on the
# command string containing "add", reintroducing command-string matching
# as a coverage decision (defeated by `git stage . && git commit`, a
# real synonym — see Part 14). Fixing the fixture's realism removes the
# reason for that gate to exist at all. Caller is responsible for `rm -rf`.
def setup-repo-with-gitignored-secret [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    $"($file_name)\n" | save --force ($repo | path join ".gitignore")
    git -C $repo add ".gitignore"
    git -C $repo commit -q -m "initial"
    $"slack_token = \"(fixture-secret)\"\n" | save --force ($repo | path join $file_name)
    $repo
}

# A git repo excluding file_name via `.git/info/exclude` (the local,
# per-clone ignore mechanism — never committed, unlike .gitignore) with a
# secret in file_name, present on disk but neither tracked nor staged.
# `--exclude-standard` respects info/exclude the same way it respects
# .gitignore — verified directly. Second control surface for
# claude-skills-272 alongside .gitignore, since a fix keyed narrowly to
# "reads .gitignore" could still miss this one. Caller is responsible for
# `rm -rf`.
def setup-repo-with-info-exclude-secret [file_name: string] {
    let repo = (mktemp -d)
    git -C $repo init -q
    git -C $repo config user.email "test@example.com"
    git -C $repo config user.name "test"
    git -C $repo commit -q --allow-empty -m "initial"
    $"($file_name)\n" | save --append ($repo | path join ".git" "info" "exclude")
    $"slack_token = \"(fixture-secret)\"\n" | save --force ($repo | path join $file_name)
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

    # Gate 3 W (claude-skills-271 round 2): real gitleaks, invoked with -v
    # (which this hook always passes), ALWAYS emits a "scanned ~N bytes
    # (X) in Yms" scan-summary line on stderr — verified directly when
    # building the T2 conformance table for gitleaks.nu/gitleaks.sh/the
    # template. A stub that prints nothing and exits 0 is not a realistic
    # "clean scan" — it is a scanner that told the hook nothing, which is
    # exactly the "no evidence" case the strict bytes-invariant (ported
    # from gitleaks.sh's gitleaks_verified_clean) must BLOCK, not allow.
    # Every "clean" or "secrets found" stub below uses one of these
    # realistic response bodies instead of empty output — reserving a
    # genuinely EMPTY stderr for the one new case that specifically tests
    # the no-evidence path (below, after Part 7).
    let clean_scan_stderr = "scanned ~72 bytes (72 bytes) in 10ms\nno leaks found\n"
    let secrets_found_stderr = "leaks found: 1\nscanned ~72 bytes (72 bytes) in 10ms\n"

    # --- Cases 1-3: gitleaks exit-code handling on the native-binary path ---
    let bin_dir = (mktemp -d)
    # A stub `mise` that always fails makes `mise which gitleaks` resolve to
    # nothing, so detect_native() falls through to the PATH-based `command -v
    # gitleaks` lookup below — which finds OUR stub, since bin_dir is
    # prepended to PATH.
    stub $bin_dir "mise" 1
    let native_path = ([$bin_dir] | append $real_path)

    let cases = [
        {label: "gitleaks exit 0 (clean) -> hook allows the commit" gitleaks_exit: 0 stderr: $clean_scan_stderr want: 0}
        {label: "gitleaks exit 1 (secrets found) -> hook blocks the commit" gitleaks_exit: 1 stderr: $secrets_found_stderr want: 2}
        {label: "gitleaks exit 42 (unexpected failure) -> hook now fails closed" gitleaks_exit: 42 stderr: "" want: 2}
    ]

    for c in $cases {
        # Exit 42 keeps empty stderr deliberately — it represents a genuine
        # gitleaks CRASH (bad config, bad baseline) that never completes a
        # scan, so no scan-summary line is the realistic shape there,
        # unlike a "clean" exit-0 stub with no output.
        stub-with-response $bin_dir "gitleaks" "" $c.stderr $c.gitleaks_exit
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
    let p1a_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p1a_result = (run-hook $hook $p1a_repo $p1a_stub.path "git add . && git commit -m test")
    if not (check "Part 1a: `git add . && git commit -m test` with a staged secret blocks" $p1a_result 2) {
        $failed = true
    }
    rm -rf $p1a_repo
    rm -rf $p1a_stub.bin_dir

    let p1b_repo = (setup-repo-with-staged-secret "secret.txt")
    let p1b_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p1b_result = (run-hook $hook $p1b_repo $p1b_stub.path $"cd ($p1b_repo) && git commit -m test")
    if not (check "Part 1b: `cd <dir> && git commit -m test` with a staged secret blocks" $p1b_result 2) {
        $failed = true
    }
    rm -rf $p1b_repo
    rm -rf $p1b_stub.bin_dir

    # --- Part 2: prefixes. Leading whitespace, and an env-var assignment
    # prefix (a real, common shell idiom for one-off commits).
    let p2a_repo = (setup-repo-with-staged-secret "secret.txt")
    let p2a_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p2a_result = (run-hook $hook $p2a_repo $p2a_stub.path "  git commit -m test")
    if not (check "Part 2a: leading whitespace before `git commit` with a staged secret blocks" $p2a_result 2) {
        $failed = true
    }
    rm -rf $p2a_repo
    rm -rf $p2a_stub.bin_dir

    let p2b_repo = (setup-repo-with-staged-secret "secret.txt")
    let p2b_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
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
        let stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
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
        let stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
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
    let p5a_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p5a_result = (run-hook $hook $p5a_repo $p5a_stub.path "git commit -m test")
    if not (check "Part 5a (control): plain `git commit -m test` with a staged secret still blocks" $p5a_result 2) {
        $failed = true
    }
    rm -rf $p5a_repo
    rm -rf $p5a_stub.bin_dir

    let p5b_repo = (setup-repo)
    let p5b_stub = (native-stub-path $real_path "" $clean_scan_stderr 0)
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
    #
    # Gate 3 A2 carve-out (claude-skills-271 round 3): this pins the
    # "scanned nothing UNEXPECTEDLY" side of the invariant — real,
    # non-empty content genuinely existed to export (setup-repo-with-
    # staged-secret writes a real, non-trivial file), yet gitleaks reports
    # zero. That must BLOCK. It is the opposite of Parts 9/10 below, which
    # pin "there was genuinely NOTHING to scan" (a deletion, an empty
    # file) — that must ALLOW. A correct fix distinguishes the two by
    # whether real bytes were actually exported, not by gitleaks' report
    # alone; this test and Parts 9/10 together are what pins that
    # distinction rather than leaving it implicit.
    let p7_repo = (setup-repo-with-staged-secret "secret.txt")
    let p7_stub = (native-stub-path $real_path "" "0 commits scanned.\nscanned ~0 bytes (0) in 5ms\nno leaks found\n" 0)
    let p7_result = (run-hook $hook $p7_repo $p7_stub.path "git commit -m test")
    if not (check "Part 7: gitleaks reporting a zero-byte scan (exit 0) still blocks" $p7_result 2) {
        $failed = true
    }
    rm -rf $p7_repo
    rm -rf $p7_stub.bin_dir

    # --- Part 8 (Gate 3 W, landed): "no evidence" — gitleaks exits 0
    # having emitted NO parseable scan-summary line at all, not an
    # explicit zero. gitleaks.nu/gitleaks.sh/the template's shared
    # invariant treats this IDENTICALLY to Part 7's explicit-zero case —
    # "no evidence is not innocence" was PR #246's six-round conclusion —
    # and the hook's `gitleaks_verified_clean` now matches that exactly
    # (ported verbatim from gitleaks.sh, confirmed at commit 4429fdd).
    let p8_repo = (setup-repo-with-staged-secret "secret.txt")
    let p8_stub = (native-stub-path $real_path "" "" 0)
    let p8_result = (run-hook $hook $p8_repo $p8_stub.path "git commit -m test")
    if not (check "Part 8: gitleaks exiting 0 with NO parseable scan summary (not explicit zero) still blocks" $p8_result 2) {
        $failed = true
    }
    rm -rf $p8_repo
    rm -rf $p8_stub.bin_dir

    # ==========================================================================
    # claude-skills-271 Gate 3 A1/A2 (round 3): the strict bytes-invariant
    # port (Part 8) closed one gap and immediately opened two more that the
    # existing 19 cases could not see. Both were reproduced directly
    # before writing these tests (see the commit message / PR thread for
    # the exact commands run).
    # ==========================================================================

    # --- Part 9 (A1): untracked (brand-new) file. `git diff --cached
    # --name-only` (staged) and `git diff --name-only` (unstaged tracked
    # modifications) are BOTH empty for a file that was never `git add`ed
    # at all — verified directly: only `git ls-files --others
    # --exclude-standard` sees it. `git add . && git commit`, `git add -A
    # && git commit`, and a plain new file anywhere are exactly this
    # shape — the most common way a secret enters a repo (a dumped key, a
    # generated config, `.env.local`) is a BRAND NEW file, and it
    # currently exports nothing. Same unconditional "secrets found" stub
    # methodology as Parts 1-4: isolates "does the export even find this
    # file" from whether real gitleaks would detect the specific token.
    let p9_repo = (setup-repo-with-untracked-secret "brand-new.txt")
    let p9_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p9_result = (run-hook $hook $p9_repo $p9_stub.path "git add . && git commit -m test")
    if not (check "Part 9: untracked brand-new.txt with a real secret + `git add . && git commit` blocks" $p9_result 2) {
        $failed = true
    }
    rm -rf $p9_repo
    rm -rf $p9_stub.bin_dir

    # --- Part 10 (A1): untracked file in a subdirectory. Same mechanism
    # as Part 9; a separate case because a naive fix (e.g. `ls` instead of
    # a recursive `git ls-files`) could pass Part 9 while still missing
    # this.
    let p10_repo = (setup-repo-with-untracked-secret "configs/brand-new.txt")
    let p10_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p10_result = (run-hook $hook $p10_repo $p10_stub.path "git add . && git commit -m test")
    if not (check "Part 10: untracked configs/brand-new.txt (subdirectory) with a real secret blocks" $p10_result 2) {
        $failed = true
    }
    rm -rf $p10_repo
    rm -rf $p10_stub.bin_dir

    # --- Part 11 (A2): staged deletion, no secret anywhere. Verified
    # directly: `git diff --cached --name-only` DOES list a deleted path
    # (a deletion is a staged change), but `git show ":$file"` fails
    # \(file no longer exists in the index\) and the redirect creates a
    # 0-byte export artifact regardless. Real gitleaks against that
    # genuinely-empty export correctly reports "scanned ~0 bytes... no
    # leaks found" — this is Part 7's mirror image: real gitleaks, not a
    # stub, so the fix under test is "does the hook correctly ALLOW when
    # there was truly nothing to scan", not detection logic. `git rm
    # <file> && git commit` is one of the most routine git operations
    # there is — this hook currently blocking it is the disable-the-hook
    # risk. Skips gracefully, like Part 6, if no native gitleaks/mise is
    # reachable on this host.
    let p11_precheck = (bash -c "command -v mise || command -v gitleaks" | complete)
    if $p11_precheck.exit_code != 0 {
        print $"(ansi yellow)⚠️  skipping Part 11 \(staged deletion\): no native gitleaks/mise reachable on this host to run a REAL scan against(ansi reset)"
    } else {
        let p11_repo = (setup-repo-with-staged-deletion "gone.txt")
        let p11_result = (run-hook $hook $p11_repo $real_path "git rm gone.txt && git commit -m test")
        if not (check "Part 11: `git rm gone.txt && git commit` with no secret anywhere is allowed" $p11_result 0) {
            $failed = true
        }
        rm -rf $p11_repo
    }

    # --- Part 12 (A2): staged empty file, no secret anywhere. Same
    # mirror-of-Part-7 methodology as Part 11 — real gitleaks against
    # genuinely empty (0-byte) content correctly reports "scanned ~0
    # bytes... no leaks found", and a correct fix must allow this, not
    # block it.
    let p12_precheck = (bash -c "command -v mise || command -v gitleaks" | complete)
    if $p12_precheck.exit_code != 0 {
        print $"(ansi yellow)⚠️  skipping Part 12 \(staged empty file\): no native gitleaks/mise reachable on this host to run a REAL scan against(ansi reset)"
    } else {
        let p12_repo = (setup-repo-with-staged-empty-file "empty.txt")
        let p12_result = (run-hook $hook $p12_repo $real_path "git commit -m test")
        if not (check "Part 12: staged empty.txt (0 bytes), no secret anywhere, is allowed" $p12_result 0) {
            $failed = true
        }
        rm -rf $p12_repo
    }

    # --- Part 13 (control, claude-skills-268): a gitignored .env with a
    # secret, present on disk but never tracked/staged, must still NOT be
    # scanned. Guards the A1 fix specifically: an untracked-file pass that
    # forgot `--exclude-standard` (or used a bare directory walk instead
    # of `git ls-files`) would pick this up and this test would catch it
    # — the unconditional "secrets found" stub only fires if the export
    # pass reaches it at all, so a regression here fails LOUD (block
    # instead of the expected allow), not silently.
    let p13_repo = (setup-repo-with-gitignored-secret ".env")
    let p13_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p13_result = (run-hook $hook $p13_repo $p13_stub.path "git commit -m test")
    if not (check "Part 13 (control): gitignored .env with a secret is NOT scanned, commit allowed" $p13_result 0) {
        $failed = true
    }
    rm -rf $p13_repo
    rm -rf $p13_stub.bin_dir

    # --- Part 14 (Gate 3 round 4): `git stage . && git commit`. `stage` is
    # a real, working git built-in synonym for `add` — verified directly
    # (`git stage newfile.txt` stages it exactly like `git add` would).
    # Regression test for the specific compromise Part 13's earlier
    # unrealistic fixture forced: the implementer had gated the untracked-
    # file export pass on `$COMMAND =~ add` to make that fixture pass,
    # which this command defeats (no "add" substring, so the gate would
    # have skipped the untracked-file pass entirely — the exact A1 bypass
    # reintroduced one layer down). Same mechanism and stub methodology as
    # Part 9; a separate case specifically to pin that the fix does NOT
    # depend on which staging synonym appears in the command string.
    let p14_repo = (setup-repo-with-untracked-secret "brand-new.txt")
    let p14_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p14_result = (run-hook $hook $p14_repo $p14_stub.path "git stage . && git commit -m test")
    if not (check "Part 14: untracked brand-new.txt with a real secret + `git stage . && git commit` blocks" $p14_result 2) {
        $failed = true
    }
    rm -rf $p14_repo
    rm -rf $p14_stub.bin_dir

    # ==========================================================================
    # claude-skills-272: `git add -f <gitignored> && git commit` goes
    # unscanned. Verified directly against the real (current) hook before
    # writing these: the compound form exits 0 with "No staged, modified-
    # tracked, or new untracked files to scan" for both a gitignored
    # `.env` and a `.git/info/exclude`d path, force-added in the SAME
    # command — the file is still untracked+ignored at the moment this
    # PreToolUse hook fires, before `git add -f` has actually run.
    #
    # OPERATOR DECISION (round 4, reverting the widening): two successive
    # attempts to detect `-f`/`--force` in the command string each
    # introduced a false positive worse than the hole being closed —
    # `git stage` (claude-skills-271, string matching used to SKIP a
    # pass — unsafe, a miss reopens a hole) is a different failure mode
    # from what killed THIS widening, but the token-boundary predicate
    # that replaced the bare substring check was ALSO defeated: `rm -f
    # tmp.txt && git commit`, `grep -f patterns.txt file && git commit`,
    # `docker build -f Dockerfile . && git commit`, and `tar -x -f a.tar
    # && git commit` all trigger the widened pass and block a legitimate
    # commit over a gitignored file the user deliberately excluded — every
    # one verified directly. Token matching answers "is `-f` a token
    # anywhere in this command?", never "whose flag is it?" — a `-f`
    # belonging to `rm`/`grep`/`docker`/`tar` is indistinguishable from one
    # belonging to `git add` without actually parsing subcommand
    # boundaries, which is out of scope for this hook.
    #
    # The hole this widening tried to close is NARROW: a SEPARATE `git add
    # -f` followed by a distinct `git commit` is already caught by the
    # existing staged-files pass (Part 20 below, unchanged, still pins
    # this). Only the COMPOUND form (`git add -f x && git commit` in one
    # shell invocation) escapes, and only for a file that is both
    # gitignored/excluded AND force-added AND committed in the same
    # command — accepted as a documented gap rather than chased with a
    # fourth predicate. Parts 15/16/17 below are now documented-limitation
    # pins (matching Part 21/24's style), not requirements — they keep
    # claude-skills-272 visible in this suite as a known, bounded gap
    # rather than letting it disappear when the widening code does.
    #
    # Same unconditional-stub methodology as Parts 1-4/9/10/14 throughout:
    # isolates "does the export/detection pass even reach the scanner for
    # this command shape" from real-gitleaks-detection-accuracy.
    # ==========================================================================

    # --- Part 15 (documented-limitation pin, NOT a requirement,
    # claude-skills-272): `git add -f .env && git commit` (short flag), a
    # compound force-add of a gitignored secret. Accepted gap per the
    # round-4 operator decision above — no predicate widens the scan for
    # this, so it behaves exactly as an ordinary gitignored file: NOT
    # scanned, exit 0. If a future, safely-scoped detector (one that can
    # actually attribute `-f` to `git add` specifically, not just find the
    # token anywhere) closes this without reintroducing the
    # rm/grep/docker/tar false positives, that is a welcome improvement —
    # flip this expectation then, the same asymmetry-in-reverse Part
    # 21/24 describe. Kept in the suite (not deleted) so this gap stays
    # visible rather than disappearing with the code that used to close it.
    let p15_repo = (setup-repo-with-gitignored-secret ".env")
    let p15_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p15_result = (run-hook $hook $p15_repo $p15_stub.path "git add -f .env && git commit -m test")
    if not (check "Part 15 (documented limitation): compound `git add -f .env && git commit` is NOT scanned (accepted gap)" $p15_result 0) {
        $failed = true
    }
    rm -rf $p15_repo
    rm -rf $p15_stub.bin_dir

    # --- Part 16 (documented-limitation pin): `git add --force .env &&
    # git commit` (long flag). Same accepted gap as Part 15, kept as a
    # separate case so both flag spellings stay documented.
    let p16_repo = (setup-repo-with-gitignored-secret ".env")
    let p16_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p16_result = (run-hook $hook $p16_repo $p16_stub.path "git add --force .env && git commit -m test")
    if not (check "Part 16 (documented limitation): compound `git add --force .env && git commit` is NOT scanned (accepted gap)" $p16_result 0) {
        $failed = true
    }
    rm -rf $p16_repo
    rm -rf $p16_stub.bin_dir

    # --- Part 17 (documented-limitation pin): a `.git/info/exclude`d path
    # (not .gitignore), force-added in a compound command. Kept as a
    # separate case so the gap's extent is documented across BOTH ignore
    # mechanisms, not just .gitignore.
    let p17_repo = (setup-repo-with-info-exclude-secret "private.txt")
    let p17_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p17_result = (run-hook $hook $p17_repo $p17_stub.path "git add -f private.txt && git commit -m test")
    if not (check "Part 17 (documented limitation): compound `git add -f private.txt && git commit` \(info/exclude\) is NOT scanned (accepted gap)" $p17_result 0) {
        $failed = true
    }
    rm -rf $p17_repo
    rm -rf $p17_stub.bin_dir

    # --- Part 18 (control, LOAD-BEARING, claude-skills-268): a gitignored
    # .env with a secret, NOT force-added, plain `git commit`, must still
    # NOT be scanned. This is the regression that would make the gate
    # obnoxious — scanning every gitignored file on every commit was
    # explicitly rejected. The unconditional "secrets found" stub only
    # fires if the export pass reaches this file at all, so a fix that
    # over-widens (e.g. drops --exclude-standard, or treats "ignored" and
    # "force-added" the same) fails LOUD here, not silently.
    let p18_repo = (setup-repo-with-gitignored-secret ".env")
    let p18_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p18_result = (run-hook $hook $p18_repo $p18_stub.path "git commit -m test")
    if not (check "Part 18 (control): gitignored .env, NOT force-added, plain commit is NOT scanned" $p18_result 0) {
        $failed = true
    }
    rm -rf $p18_repo
    rm -rf $p18_stub.bin_dir

    # --- Part 19 (control): a clean commit still succeeds.
    let p19_repo = (setup-repo)
    let p19_stub = (native-stub-path $real_path "" $clean_scan_stderr 0)
    let p19_result = (run-hook $hook $p19_repo $p19_stub.path "git commit -m test")
    if not (check "Part 19 (control): a clean commit still succeeds" $p19_result 0) {
        $failed = true
    }
    rm -rf $p19_repo
    rm -rf $p19_stub.bin_dir

    # --- Part 20: separate commands — `git add -f .env` runs to
    # completion BEFORE a distinct `git commit` is intercepted. The file
    # is genuinely in the index by the time this hook fires, so the
    # EXISTING staged-files pass already exports and scans it — verified
    # directly against the real (unfixed) hook AND against real gitleaks
    # with a real detectable token: exit 2, "SECRETS DETECTED". This
    # already passes today; pinned here so a claude-skills-272 fix cannot
    # accidentally narrow the staged pass while widening the compound-
    # command detection.
    let p20_repo = (setup-repo-with-gitignored-secret ".env")
    git -C $p20_repo add -f ".env"
    let p20_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p20_result = (run-hook $hook $p20_repo $p20_stub.path "git commit -m test")
    if not (check "Part 20: separate `git add -f .env` then `git commit` blocks (already works today)" $p20_result 2) {
        $failed = true
    }
    rm -rf $p20_repo
    rm -rf $p20_stub.bin_dir

    # --- Part 21 (asymmetry pin): an OBFUSCATED force-add a naive
    # `-f`/`--force` substring detector would miss. `git add -Af` force-
    # adds exactly like `git add -f` (verified directly: `-Af` stages a
    # gitignored file, `git status --short` shows `A  .env`) but contains
    # neither the literal substring "-f" nor "--force" anywhere in the
    # flag token — "-Af" is dash, A, f; "-f" as two consecutive characters
    # never appears. This is the asymmetry contract made concrete: the
    # detector is EXPECTED to miss this, and the correct behavior on a
    # miss is "identical to today" (unscanned, exit 0), NOT a crash and
    # NOT a false block. If a future, cleverer detector starts catching
    # this specific form too, that is a welcome improvement, not a
    # regression — update this test's expectation then; do not treat a
    # newly-caught case as something to guard against.
    let p21_repo = (setup-repo-with-gitignored-secret ".env")
    let p21_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p21_result = (run-hook $hook $p21_repo $p21_stub.path "git add -Af && git commit -m test")
    if not (check "Part 21 (asymmetry pin): obfuscated `git add -Af` behaves as today (unscanned, exit 0) when missed" $p21_result 0) {
        $failed = true
    }
    rm -rf $p21_repo
    rm -rf $p21_stub.bin_dir

    # ==========================================================================
    # claude-skills-272 round 2 (history, kept for context): the FIRST
    # landed detector was `[[ "$COMMAND" == *-f* ]]` — bare substring,
    # anywhere in the whole command. Confirmed directly against that hook
    # (commit e5b000d) that it OVER-triggered: `git commit --fixup=HEAD`
    # and `git commit --file=<path>` both contain the literal substring
    # "-f" inside an unrelated long-option name and both incorrectly
    # scanned (and blocked on) a gitignored .env with a real secret. A
    # SECOND, token-boundary detector fixed that but was itself defeated
    # by `rm -f`/`grep -f`/`docker build -f`/`tar -x -f` (round 4, see the
    # revert note above Part 15) — the whole widening is gone now, so
    # Parts 22/23 below pass TRIVIALLY (no predicate exists to over-
    # trigger on anything). Kept as regression guards specifically against
    # a THIRD predicate attempt reintroducing this exact failure mode —
    # if `--fixup`/`--file` ever start blocking again, that is the
    # over-trigger direction coming back, not a coincidence.
    # ==========================================================================

    # --- Part 22 (regression guard against re-adding a predicate):
    # `git commit --fixup=HEAD`, gitignored .env with a real secret,
    # nothing force-added. Must NOT scan.
    let p22_repo = (setup-repo-with-gitignored-secret ".env")
    let p22_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p22_result = (run-hook $hook $p22_repo $p22_stub.path "git commit --fixup=HEAD")
    if not (check "Part 22: `git commit --fixup=HEAD` does not scan a gitignored .env (false-positive guard)" $p22_result 0) {
        $failed = true
    }
    rm -rf $p22_repo
    rm -rf $p22_stub.bin_dir

    # --- Part 23 (regression guard against re-adding a predicate):
    # `git commit --file=<path>`, same setup. Separate case from Part 22 —
    # a hypothetical future predicate keyed narrowly to excluding
    # "--fixup" specifically could still reintroduce this one.
    #
    # Gate 3 round 3 (claude-skills-272): msg.txt is TRACKED (committed)
    # here, not left on disk untracked. An earlier version wrote it
    # straight to disk with no `git add` — real content, genuinely
    # untracked, not gitignored — which the UNCONDITIONAL untracked-file
    # export pass from claude-skills-271 (no --exclude-standard skip logic
    # applies to that pass; it scans any real untracked file regardless of
    # the command shape, since the hook cannot know whether an `add` ran
    # earlier in a compound command — see the note below) correctly
    # exported and the stub then correctly fired on. That made this test
    # red for the wrong reason: the incidental fixture file, not the
    # `--file=msg.txt` command shape being tested. Second occurrence of
    # this exact pattern — Part 13's untracked `.gitignore` was the first
    # (claude-skills-271 round 4) — see the sweep note in this file's
    # header comment for the general rule extracted from both.
    let p23_repo = (setup-repo-with-gitignored-secret ".env")
    "a commit message\n" | save --force ($p23_repo | path join "msg.txt")
    git -C $p23_repo add "msg.txt"
    git -C $p23_repo commit -q -m "add message file"
    let p23_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p23_result = (run-hook $hook $p23_repo $p23_stub.path "git commit --file=msg.txt")
    if not (check "Part 23: `git commit --file=msg.txt` does not scan a gitignored .env (false-positive guard)" $p23_result 0) {
        $failed = true
    }
    rm -rf $p23_repo
    rm -rf $p23_stub.bin_dir

    # --- Part 24: a commit MESSAGE that itself contains the literal
    # substring "-f" — e.g. `git commit -m "add -f support"`.
    #
    # Round 4 update: this previously pinned a genuine, judged-unavoidable
    # false-positive limitation of the token-boundary predicate (a
    # refinement requiring "add" to co-occur with "-f" would still have
    # been fooled by this exact message text — see the git log for that
    # analysis). That predicate is gone with the round-4 revert, so there
    # is no detector left to fool: this is now an ordinary gitignored-file
    # case, identical in shape to Parts 15/16/17, and correctly belongs
    # alongside them as exit 0 rather than as its own limitation pin — the
    # limitation it used to document doesn't exist anymore because the
    # mechanism that caused it doesn't exist anymore. Kept as its own case
    # (not merged into Part 15) because it exercises a DIFFERENT trigger
    # shape (message text, not a real flag) that any future detector
    # attempt needs to independently avoid re-breaking.
    let p24_repo = (setup-repo-with-gitignored-secret ".env")
    let p24_stub = (native-stub-path $real_path "" $secrets_found_stderr 1)
    let p24_result = (run-hook $hook $p24_repo $p24_stub.path 'git commit -m "add -f support"')
    if not (check "Part 24: commit message containing \"-f\" is NOT scanned (no predicate left to fool)" $p24_result 0) {
        $failed = true
    }
    rm -rf $p24_repo
    rm -rf $p24_stub.bin_dir

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ security hook exit-code handling and command-detection/export correctness verified(ansi reset)"
}
