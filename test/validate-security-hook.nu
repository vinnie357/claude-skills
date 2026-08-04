#!/usr/bin/env nu

# Regression test for check-secrets-before-commit.sh's gitleaks exit-code
# handling (claude-skills-224). Before the fix, ANY gitleaks exit code other
# than 0 (clean) or 1 (secrets found) fell into a "scan failed -> allow the
# commit" branch. That is a standing, silent bypass: a single committed
# broken .gitleaks.toml makes every subsequent scan exit non-1, and every
# commit thereafter is allowed with only a warning, indefinitely. This repo
# has no gitleaks step in CI (verified via `grep -rni gitleaks .github/`
# returning zero hits), so this hook is the only automated secret scan —
# the fail-open here has no other line of defense behind it.
#
# This test stubs a `gitleaks` binary on PATH with a scripted exit code and
# asserts the hook's own exit code:
#   0  (clean)          -> hook allows the commit (exit 0)
#   1  (secrets found)  -> hook blocks the commit (exit 2)
#   42 (unexpected)      -> hook now fails CLOSED (exit 2), not open
# plus the pre-existing, still-intentional fail-open when no scanner is
# available at all (documented in the hook's "Fail-open, deliberately" note).
#
# Usage: nu test/validate-security-hook.nu

# Writes an executable stub at dir/name that ignores all arguments and
# exits with exit_code.
def stub [dir: string, name: string, exit_code: int] {
    let path = ($dir | path join $name)
    $"#!/usr/bin/env bash\nexit ($exit_code)\n" | save --force $path
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

# Runs the real hook script (Claude Code PreToolUse hook input shape) against
# repo_dir with PATH pinned to path_list, and returns {exit_code, stdout,
# stderr}.
def run-hook [hook: string, repo_dir: string, path_list: list] {
    let input = ({tool_input: {command: "git commit -m test"} cwd: $repo_dir} | to json)
    with-env {PATH: $path_list} {
        $input | bash $hook | complete
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

    if $failed {
        exit 1
    }
    print $"(ansi green_bold)✅ security hook exit-code handling verified(ansi reset)"
}
