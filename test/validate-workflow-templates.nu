#!/usr/bin/env nu

# Validates the agent-loop workflow templates
# (plugins/core/skills/agent-loop/templates/{forge-issue,five-tier-issue}.workflow.js)
# against the reviewer-evidence contract (adversarial TDD test author; this
# script is frozen once committed).
#
# Nine named assertions per template, run via test/workflow-templates/harness.mjs:
#   syntax                    — node --check passes on the wrapped template
#   no-reviewer-clone         — no reviewer prompt contains "git clone"
#                                (ciPrompt is exempt — that agent executes)
#   finding-line               — a top-level FINDING_LINE constant exists,
#                                contains "defect and impact; basis", and
#                                every reviewer prompt includes its text
#   evidence-round             — a reviewer's evidenceRequests triggers
#                                exactly one execution-hands call
#                                (opts.model === args.handsModel, no
#                                opts.agentType) running "mise run ci",
#                                then exactly one re-invoked reviewer call
#                                whose prompt includes the hands record's
#                                RESULT text
#   second-request-escalates   — a second evidenceRequests from the
#                                re-invoked reviewer makes the workflow
#                                return status: 'escalate'
#   stale-record-dropped       — a hands record whose revision does not
#                                match the revision under review never
#                                appears in the re-invoked reviewer prompt
#   evidence-metadata-validated — a hands record is dropped (never reaches
#                                the re-invoked reviewer prompt) when exactly
#                                one of three other fields is wrong: the
#                                command differs from the requested command,
#                                the exit is a non-integer number, or the
#                                cwd is an empty string
#   absent-stage-model-no-substitution — a stage model absent from
#                                escalationChain is never substituted by a
#                                chain model, in ANY phase: the ladder for
#                                that stage stays [stageModel], tried exactly
#                                twice
#   present-stage-model-promotes — a stage model present in escalationChain
#                                (at index 0) drives a ladder of the chain
#                                suffix from that model onward: two attempts
#                                on the stage model, then two on the next
#                                chain model, before the workflow escalates
#
# harness.mjs drives each template with stub agent/parallel/phase/log/
# workflow/budget functions — no real agent is ever spawned, no network
# call is made. See harness.mjs for the full wrapping recipe and stub
# dispatch tables.
#
# Usage: nu test/validate-workflow-templates.nu

const TEMPLATES = [
    "plugins/core/skills/agent-loop/templates/forge-issue.workflow.js"
    "plugins/core/skills/agent-loop/templates/five-tier-issue.workflow.js"
]

def main [] {
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let harness = ($repo_root | path join "test" "workflow-templates" "harness.mjs")

    mut any_failed = false

    # Template-independent dispatch-key regression (isPrincipalReviewCall's
    # selection rule) — run once, not once per template.
    let self_check = (^node $harness "--self-check" | complete)
    print ($self_check.stdout | str trim)
    if ($self_check.stderr | str trim | str length) > 0 {
        print $"(ansi yellow)[stderr harness self-check](ansi reset)\n($self_check.stderr | str trim)"
    }
    if $self_check.exit_code != 0 {
        $any_failed = true
    }

    for tmpl in $TEMPLATES {
        let tmpl_path = ($repo_root | path join $tmpl)
        if not ($tmpl_path | path exists) {
            print $"FAIL ($tmpl) missing: template file not found at ($tmpl_path)"
            $any_failed = true
            continue
        }

        let syntax = (^node $harness $tmpl_path "syntax" | complete)
        print ($syntax.stdout | str trim)
        if ($syntax.stderr | str trim | str length) > 0 {
            print $"(ansi yellow)[stderr ($tmpl) syntax](ansi reset)\n($syntax.stderr | str trim)"
        }
        if $syntax.exit_code != 0 {
            $any_failed = true
        }

        let run = (^node $harness $tmpl_path "run" | complete)
        print ($run.stdout | str trim)
        if ($run.stderr | str trim | str length) > 0 {
            print $"(ansi yellow)[stderr ($tmpl) run](ansi reset)\n($run.stderr | str trim)"
        }
        if $run.exit_code != 0 {
            $any_failed = true
        }
    }

    if $any_failed {
        print $"(ansi red_bold)validate-workflow-templates: FAIL(ansi reset)"
        exit 1
    }
    print $"(ansi green_bold)validate-workflow-templates: PASS(ansi reset)"
    exit 0
}
