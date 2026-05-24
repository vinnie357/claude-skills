#!/usr/bin/env nu
# Failing content-grep tests for the VIN-313 skill-extraction sweep (18 bees).
# Every test case verifies the EXPECTED post-extraction state — against current main,
# all tests FAIL because the rules have not been extracted yet.
# Tier 3 makes them pass by writing the rules into the target files.
#
# Run via: mise run test:skill-extract
# Or directly: nu test/skill-extract/skill-extract-sweep.nu

def run-check [repo_root: string, label: string, file: string, regex: string] {
    let path = ($repo_root | path join $file)
    let result = (do { grep -qE $regex $path } | complete)
    {
        label: $label
        file: $file
        regex: $regex
        passed: ($result.exit_code == 0)
    }
}

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)

    let checks = [
        # -----------------------------------------------------------------------
        # BEE claude-skills-53: git/shallow-clone-remotes
        # -----------------------------------------------------------------------
        ["53-h1-exists" "plugins/core/skills/git/references/shallow-clone-remotes.md" "^# Shallow clones and remote verification"]
        ["53-named-remote-pattern" "plugins/core/skills/git/references/shallow-clone-remotes.md" "git remote add github"]
        ["53-verify-command" "plugins/core/skills/git/references/shallow-clone-remotes.md" "gh api repos/.+/git/refs/heads"]
        ["53-skill-links-ref" "plugins/core/skills/git/SKILL.md" "shallow-clone-remotes\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-54: git/build-source-staleness
        # -----------------------------------------------------------------------
        ["54-h1-exists" "plugins/core/skills/git/references/build-source-staleness.md" "^# Build chains and local-cache staleness"]
        ["54-git-pull-pattern" "plugins/core/skills/git/references/build-source-staleness.md" "git pull origin <branch>"]
        ["54-correct-verification" "plugins/core/skills/git/references/build-source-staleness.md" "git rev-parse HEAD"]
        ["54-anti-pattern-label" "plugins/core/skills/git/references/build-source-staleness.md" "INSUFFICIENT"]
        ["54-skill-links-ref" "plugins/core/skills/git/SKILL.md" "build-source-staleness\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-37: git inline Remote and Authentication Conventions
        # -----------------------------------------------------------------------
        ["37-section-header" "plugins/core/skills/git/SKILL.md" "## Remote and Authentication Conventions"]
        ["37-ssh-urls" "plugins/core/skills/git/SKILL.md" "### SSH-form remote URLs for operations"]
        ["37-no-worktrees" "plugins/core/skills/git/SKILL.md" "### No git worktrees for agent isolation"]
        ["37-private-releases" "plugins/core/skills/git/SKILL.md" "### GitHub Releases on private repositories require authentication"]
        ["37-layered-auth" "plugins/core/skills/git/SKILL.md" "### Layered GitHub authentication"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-39: linear epic body format rules
        # -----------------------------------------------------------------------
        ["39-epic-body-rules" "plugins/tools/linear/skills/linear/SKILL.md" "## Epic Body Format Rules"]
        ["39-no-yaml-fences" "plugins/tools/linear/skills/linear/SKILL.md" "### No YAML fences in epic bodies"]
        ["39-skill-label-discipline" "plugins/tools/linear/skills/linear/SKILL.md" "### Skill-label discipline"]
        ["39-core-skills-must-not" "plugins/tools/linear/skills/linear/SKILL.md" "Core skills .* MUST NOT be listed"]
        ["39-command-pointer" "plugins/tools/linear/commands/plan-epic.md" "## Body Format Rules"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-40: bees claude-teams format + single-writer
        # -----------------------------------------------------------------------
        ["40-teams-aware-format" "plugins/core/skills/bees/SKILL.md" "### Claude-teams-aware bee format"]
        ["40-single-writer" "plugins/core/skills/bees/SKILL.md" "### Single-writer constraint"]
        ["40-bees-ready-queue" "plugins/core/skills/bees/SKILL.md" "### .bees ready. as canonical queue"]
        ["40-sqlite-failure" "plugins/core/skills/bees/SKILL.md" "SQLITE_CONSTRAINT|daemon\\.lock"]
        ["40-bees-requests" "plugins/core/skills/bees/SKILL.md" "BEES REQUESTS"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-36: runex bundle-build-rules
        # -----------------------------------------------------------------------
        ["36-h1-exists" "plugins/tools/runex/skills/runex/references/bundle-build-rules.md" "^# Bundle structure and build workflow rules"]
        ["36-name-must-match" "plugins/tools/runex/skills/runex/references/bundle-build-rules.md" "workflow.name.*MUST match the directory name"]
        ["36-mise-exec-tool" "plugins/tools/runex/skills/runex/references/bundle-build-rules.md" "mise exec <tool>@<version>"]
        ["36-api-info-sha" "plugins/tools/runex/skills/runex/references/bundle-build-rules.md" "/api/info.*git_sha"]
        ["36-no-api-key-param" "plugins/tools/runex/skills/runex/references/bundle-build-rules.md" "ANTHROPIC_API_KEY"]
        ["36-skill-links-ref" "plugins/tools/runex/skills/runex/SKILL.md" "bundle-build-rules\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-57: tidewave introspection in tier prompts (two surfaces)
        # -----------------------------------------------------------------------
        ["57-tidewave-section" "plugins/languages/elixir/skills/tidewave/SKILL.md" "## Using tidewave in tier prompts"]
        ["57-search-package-docs" "plugins/languages/elixir/skills/tidewave/SKILL.md" "mcp__tidewave-.+__search_package_docs"]
        ["57-preferred-over-webfetch" "plugins/languages/elixir/skills/tidewave/SKILL.md" "PREFERRED over WebFetch"]
        ["57-agent-loop-ref-h1" "plugins/core/skills/agent-loop/references/dep-doc-introspection.md" "^# Dependency documentation introspection in tier prompts"]
        ["57-training-data-recall" "plugins/core/skills/agent-loop/references/dep-doc-introspection.md" "training-data recall"]
        ["57-agent-loop-links-ref" "plugins/core/skills/agent-loop/SKILL.md" "dep-doc-introspection\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-38: phoenix + style (runtime config, logger, openapi)
        # -----------------------------------------------------------------------
        ["38-runtime-config" "plugins/languages/elixir/skills/phoenix/SKILL.md" "## Runtime configuration"]
        ["38-ip-bind" "plugins/languages/elixir/skills/phoenix/SKILL.md" "### Phoenix Endpoint .:ip. bind config"]
        ["38-bind-address" "plugins/languages/elixir/skills/phoenix/SKILL.md" "BIND_ADDRESS"]
        ["38-phx-host" "plugins/languages/elixir/skills/phoenix/SKILL.md" "### PHX_HOST matches the public DNS name"]
        ["38-dev-restart" "plugins/languages/elixir/skills/phoenix/SKILL.md" "### Dev-server restart after .lib"]
        ["38-openapi" "plugins/languages/elixir/skills/phoenix/SKILL.md" "## OpenAPI Contract-First"]
        ["38-open-api-spex" "plugins/languages/elixir/skills/phoenix/SKILL.md" "open_api_spex"]
        ["38-logger-section" "plugins/languages/elixir/skills/style/SKILL.md" "## Logger over IO.puts"]
        ["38-logger-wrong" "plugins/languages/elixir/skills/style/SKILL.md" "WRONG.*IO\\.puts"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-52: no TODOs in shipped code (two surfaces)
        # -----------------------------------------------------------------------
        ["52-code-review-h1" "plugins/core/skills/code-review/references/no-todos-scan.md" "^# Scanning for TODO/FIXME/XXX/HACK markers"]
        ["52-full-marker-list" "plugins/core/skills/code-review/references/no-todos-scan.md" "TODO\\|FIXME\\|XXX\\|HACK\\|KLUDGE\\|DEFERRED"]
        ["52-blocker" "plugins/core/skills/code-review/references/no-todos-scan.md" "BLOCKER"]
        ["52-agent-loop-h1" "plugins/core/skills/agent-loop/references/no-todos.md" "^# Forbid TODO markers in implementer worker prompts"]
        ["52-code-review-links-ref" "plugins/core/skills/code-review/SKILL.md" "no-todos-scan\\.md"]
        ["52-agent-loop-links-ref" "plugins/core/skills/agent-loop/SKILL.md" "no-todos\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-34: agent dispatch + delegation rules
        # -----------------------------------------------------------------------
        ["34-h1-exists" "plugins/core/skills/agent-loop/references/dispatch-discipline.md" "^# Agent dispatch and delegation discipline"]
        ["34-model-selection" "plugins/core/skills/agent-loop/references/dispatch-discipline.md" "## Model selection is explicit, never inherited"]
        ["34-lead-delegates" "plugins/core/skills/agent-loop/references/dispatch-discipline.md" "## Tier 1 leads delegate ALL execution"]
        ["34-branch-from-main" "plugins/core/skills/agent-loop/references/dispatch-discipline.md" "## Branch from fresh main"]
        ["34-git-fetch" "plugins/core/skills/agent-loop/references/dispatch-discipline.md" "git fetch origin main"]
        ["34-no-polling" "plugins/core/skills/agent-loop/references/dispatch-discipline.md" "## No timed polling loops in workers"]
        ["34-skill-links-ref" "plugins/core/skills/agent-loop/SKILL.md" "dispatch-discipline\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-56: secret provisioning (general form)
        # -----------------------------------------------------------------------
        ["56-h1-exists" "plugins/core/skills/agent-loop/references/secret-provisioning.md" "^# Tier 1 plans for env-var-backed features include provisioning"]
        ["56-openssl-rand" "plugins/core/skills/agent-loop/references/secret-provisioning.md" "openssl rand -hex 32"]
        ["56-generation-cmd" "plugins/core/skills/agent-loop/references/secret-provisioning.md" "Generation command"]
        ["56-prod-deploy-diff" "plugins/core/skills/agent-loop/references/secret-provisioning.md" "Production deploy template diff"]
        ["56-dev-local-diff" "plugins/core/skills/agent-loop/references/secret-provisioning.md" "Developer-local environment diff"]
        ["56-blocker-not-nit" "plugins/core/skills/agent-loop/references/secret-provisioning.md" "BLOCKER, not NIT"]
        ["56-skill-links-ref" "plugins/core/skills/agent-loop/SKILL.md" "secret-provisioning\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-41: CI discipline + docs-first TDD
        # -----------------------------------------------------------------------
        ["41-h1-exists" "plugins/core/skills/tdd/references/ci-discipline.md" "^# CI discipline and docs-first TDD"]
        ["41-mise-run-ci" "plugins/core/skills/tdd/references/ci-discipline.md" "## .mise run ci. .or equivalent. passes before EVERY commit"]
        ["41-ci-green-both" "plugins/core/skills/tdd/references/ci-discipline.md" "## CI green = local AND remote both passing"]
        ["41-verbatim-output" "plugins/core/skills/tdd/references/ci-discipline.md" "## Verbatim CI output as evidence"]
        ["41-no-carveouts" "plugins/core/skills/tdd/references/ci-discipline.md" "## No pre-existing failure carve-outs"]
        ["41-docs-first" "plugins/core/skills/tdd/references/ci-discipline.md" "## Docs-first TDD"]
        ["41-no-estimates" "plugins/core/skills/tdd/references/ci-discipline.md" "## No fabricated time estimates"]
        ["41-skill-links-ref" "plugins/core/skills/tdd/SKILL.md" "ci-discipline\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-55: OS subprocess boundary (two surfaces)
        # -----------------------------------------------------------------------
        ["55-tdd-h1" "plugins/core/skills/tdd/references/os-subprocess-boundary.md" "^# OS subprocess calls are external boundaries"]
        ["55-found-but-not-usable" "plugins/core/skills/tdd/references/os-subprocess-boundary.md" "found-but-not-usable"]
        ["55-find-executable" "plugins/core/skills/tdd/references/os-subprocess-boundary.md" "find_executable"]
        ["55-elixir-h1" "plugins/languages/elixir/skills/testing/references/os-subprocess-adapter.md" "^# OS-subprocess adapters in Elixir"]
        ["55-callback-run" "plugins/languages/elixir/skills/testing/references/os-subprocess-adapter.md" "@callback run"]
        ["55-mox-defmock" "plugins/languages/elixir/skills/testing/references/os-subprocess-adapter.md" "Mox\\.defmock"]
        ["55-compile-env" "plugins/languages/elixir/skills/testing/references/os-subprocess-adapter.md" "compile_env"]
        ["55-tdd-links-ref" "plugins/core/skills/tdd/SKILL.md" "os-subprocess-boundary\\.md"]
        ["55-testing-links-ref" "plugins/languages/elixir/skills/testing/SKILL.md" "os-subprocess-adapter\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-35: Elixir TDD discipline
        # -----------------------------------------------------------------------
        ["35-h1-exists" "plugins/languages/elixir/skills/testing/references/elixir-tdd-discipline.md" "^# Elixir TDD discipline"]
        ["35-cmd-mod-seam" "plugins/languages/elixir/skills/testing/references/elixir-tdd-discipline.md" "## .@cmd_mod. compile-time seam is the default"]
        ["35-async-true" "plugins/languages/elixir/skills/testing/references/elixir-tdd-discipline.md" "## All tests .async: true."]
        ["35-no-integration-tag" "plugins/languages/elixir/skills/testing/references/elixir-tdd-discipline.md" "## No .@tag :integration"]
        ["35-no-log-noise" "plugins/languages/elixir/skills/testing/references/elixir-tdd-discipline.md" "## No log noise in test output"]
        ["35-else-anti-pattern" "plugins/languages/elixir/skills/testing/references/elixir-tdd-discipline.md" "else _ -> :ok"]
        ["35-skill-links-ref" "plugins/languages/elixir/skills/testing/SKILL.md" "elixir-tdd-discipline\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-42: infrastructure conventions
        # -----------------------------------------------------------------------
        ["42-h1-exists" "plugins/core/skills/twelve-factor/references/infrastructure-conventions.md" "^# Infrastructure conventions"]
        ["42-nginx-upstream" "plugins/core/skills/twelve-factor/references/infrastructure-conventions.md" "## NGINX upstream .nginx.org., not the community ingress controller"]
        ["42-kustomize-helm" "plugins/core/skills/twelve-factor/references/infrastructure-conventions.md" "## Kustomize . Helm together for k8s"]
        ["42-iac-section" "plugins/core/skills/twelve-factor/references/infrastructure-conventions.md" "## Infrastructure as Code .IaC. for every service"]
        ["42-bind-all-interfaces" "plugins/core/skills/twelve-factor/references/infrastructure-conventions.md" "## Production services bind all interfaces"]
        ["42-cross-link-phoenix" "plugins/core/skills/twelve-factor/references/infrastructure-conventions.md" "/elixir:phoenix.*Phoenix Endpoint"]
        ["42-skill-links-ref" "plugins/core/skills/twelve-factor/SKILL.md" "infrastructure-conventions\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-58: mise exec transitive runtime deps
        # -----------------------------------------------------------------------
        ["58-h1-exists" "plugins/core/skills/mise/references/transitive-runtime-deps.md" "^# .mise exec. transitive runtime dependencies"]
        ["58-informational" "plugins/core/skills/mise/references/transitive-runtime-deps.md" "INFORMATIONAL"]
        ["58-openssl-rand" "plugins/core/skills/mise/references/transitive-runtime-deps.md" "openssl rand -hex"]
        ["58-dev-urandom" "plugins/core/skills/mise/references/transitive-runtime-deps.md" "head -c .* /dev/urandom"]
        ["58-cross-link-secret-prov" "plugins/core/skills/mise/references/transitive-runtime-deps.md" "secret-provisioning\\.md"]
        ["58-skill-links-ref" "plugins/core/skills/mise/SKILL.md" "transitive-runtime-deps\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-33: nushell shell-interop (Runex API shape half)
        # -----------------------------------------------------------------------
        ["33-h1-exists" "plugins/core/skills/nushell/references/shell-interop.md" "^# Shell interop pitfalls"]
        ["33-runex-api-section" "plugins/core/skills/nushell/references/shell-interop.md" "## Runex HTTP API response shape via nushell"]
        ["33-data-pattern" "plugins/core/skills/nushell/references/shell-interop.md" "\\$resp\\.data\\.status"]
        ["33-env-home" "plugins/core/skills/nushell/references/shell-interop.md" "\\$env\\.HOME"]
        ["33-out-plus-err" "plugins/core/skills/nushell/references/shell-interop.md" "out\\+err>"]
        ["33-skill-links-ref" "plugins/core/skills/nushell/SKILL.md" "shell-interop\\.md"]

        # -----------------------------------------------------------------------
        # BEE claude-skills-43: nushell bash silent-error-mask half
        # -----------------------------------------------------------------------
        ["43-bash-mask-section" "plugins/core/skills/nushell/references/shell-interop.md" "## Bash logical-operator silent error mask"]
        ["43-the-trap" "plugins/core/skills/nushell/references/shell-interop.md" "The trap"]
        ["43-if-test-fix" "plugins/core/skills/nushell/references/shell-interop.md" "if test -f"]
        ["43-codesign-example" "plugins/core/skills/nushell/references/shell-interop.md" "codesign"]
        ["43-skill-second-bullet" "plugins/core/skills/nushell/SKILL.md" "Bash logical-operator silent error mask"]
    ]

    let results = ($checks | each { |row|
        run-check $repo_root $row.0 $row.1 $row.2
    })

    let total = ($results | length)
    let passed = ($results | where passed == true | length)
    let failed = ($results | where passed == false | length)
    let failures = ($results | where passed == false)

    print ""
    print "===== skill-extract-sweep results ====="
    print $"Total: ($total) | Passed: ($passed) | Failed: ($failed)"
    print ""

    if ($failed > 0) {
        print "FAILURES:"
        for f in $failures {
            print $"  FAIL [($f.label)]: grep -qE '($f.regex)' ($f.file)"
        }
        print ""
        exit 1
    } else {
        print "All skill-extract-sweep tests passed."
        exit 0
    }
}
