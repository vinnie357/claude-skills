# Distilling Legacy Code

Procedure for running `/allium:distill` on existing Elixir or Runex modules before a refactor epic. Distillation captures current observable behavior as an Allium spec — establishing a behavioral baseline that `weed` can defend during and after refactoring.

## When to Distill

- Refactor epic that changes module internals without changing external behavior
- OTP process refactor (GenServer, Supervisor restructuring)
- Runex workflow bundle rewrite
- Any change where "the behavior should stay the same" is the acceptance criterion

Distillation converts implicit behavior into explicit spec rules. Once distilled, any refactor that accidentally changes behavior is caught by `weed`.

## Procedure

### 1. Identify the Module(s)

List the modules being refactored. For OTP processes, identify:
- The public API functions (calls into the GenServer)
- The state machine (if the process has `status` or `phase` fields)
- External events (casts, messages from other processes)

### 2. Run Distill

```bash
/allium:distill <file-or-directory>
```

Examples:

```bash
# Single module
/allium:distill lib/vantage_ex/auth/session.ex

# OTP supervisor tree
/allium:distill lib/vantage_ex/pipeline/

# Runex workflow bundle
/allium:distill workflows/build-deploy.toml
```

Distill reads the source and generates a draft `.allium` spec. It will mark uncertain inferences with `# TODO: verify` comments.

### 3. Review the Draft

Open the generated spec. Check every `# TODO: verify` comment. For each:
- Read the relevant source code
- Confirm or correct the inferred rule
- Remove the comment when verified

Do not commit a spec with unresolved `# TODO: verify` markers — they indicate unverified inferences.

### 4. Save and Commit

```bash
mv distilled-output.allium docs/specs/<epic-slug>.allium
git add docs/specs/<epic-slug>.allium
git commit -m "docs(specs): distill behavioral baseline for <epic-slug>"
```

### 5. Verify with Weed Before Refactoring

Before changing any implementation:

```bash
allium weed docs/specs/<epic-slug>.allium
```

The weed check must pass against the existing code before the refactor begins. If it reports divergences against the current code, the distilled spec is inaccurate — fix the spec first.

### 6. Refactor

Implement the refactor. After each significant change, run:

```bash
mise run ci && allium weed docs/specs/<epic-slug>.allium
```

Any weed divergence means the refactor accidentally changed observable behavior. Fix before proceeding.

## OTP-Specific Patterns

For GenServer refactors, distill captures:

```allium
entity SessionProcess {
    status: idle | processing | draining

    transitions status {
        idle -> processing
        processing -> idle
        processing -> draining
        terminal: draining
    }
}

rule HandleCall {
    when: GenServer.call(pid, :get_state)
    requires: status in {idle, processing}
    ensures: return = current_state
}
```

For Supervisor restructuring, focus on restart strategies — model which child failures cascade to siblings.

## Runex-Specific Patterns

For Runex workflow bundles, distill captures step sequencing and retry behavior. Reference `templates/runex-workflow.allium` as a model. Key constructs:

- `entity WorkflowRun` with `pending | running | succeeded | failed | timed_out`
- `entity WorkflowStep` with `attempt` counter and retry rule
- `config` block for `max_retries` and `step_timeout_ms`

## Anti-Fabrication Note

Do not claim a distilled spec covers a behavior without verifying the `ensures` or `requires` blocks against the actual source code. Use Read tool on the source file before asserting any rule is correctly captured. See `/core:anti-fabrication`.
