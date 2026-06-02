# awman Workflow Authoring

Reference for authoring awman workflow files as of v0.9.1. Two formats are supported: **TOML** and **YAML**.

Source: https://github.com/prettysmartdev/awman/blob/main/docs/04-workflows.md — accessed 2026-06-02.

> **Migrating from amux:** Markdown workflow files (`.md`) are **no longer supported as of 0.9.1**. Any extension other than `.toml`, `.yml`, or `.yaml` is rejected. Convert Markdown workflows to TOML or YAML.

---

## Critical rules (read first)

1. **Lowercase keys only.** Field names are `name`, `prompt`, `depends_on`, `agent`, `model`. Uppercase variants are not accepted.
2. **`name` and `prompt` are required** on every step; `depends_on`, `agent`, and `model` are optional.
3. **No prescribed field order** — structure follows normal TOML/YAML syntax.
4. **Template variables** are substituted at execution time and require `--work-item`.

---

## Creating workflows

```sh
awman new workflow                 # interactive
awman new workflow --interview     # AI-generated from a summary
awman new workflow --global        # write to the personal library
awman new workflow --format yaml   # choose output format (toml | yaml)
```

## Executing workflows

```sh
awman exec workflow aspec/workflows/implement.toml
awman exec workflow <path> --work-item 0027
awman exec workflow <path> --yolo --worktree
```

Execution flags: `--agent`, `--model`, `--non-interactive`, `--plan`, `--yolo`, `--worktree`, `--allow-docker`, `--mount-ssh`, `--work-item <N>`.

---

## Template variables

Available in all workflow text fields. Substituted at execution time; require `--work-item <nnnn>`. Omitting the flag replaces variables with empty strings and emits a warning.

| Variable | Substituted with |
|----------|-----------------|
| `{{work_item_number}}` | Zero-padded 4-digit number (e.g. `0027`) |
| `{{work_item}}` | The bare number |
| `{{work_item_content}}` | Full Markdown text of the work item file |
| `{{work_item_section:[Name]}}` | Named section within the work item (case-insensitive) |

---

## Step fields

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | string | yes | Step identifier; referenced by `depends_on` |
| `prompt` | string | yes | Prompt body; supports template variables |
| `depends_on` | array of step names | no | Steps that must finish before this one |
| `agent` | string | no | Overrides the default agent for this step |
| `model` | string | no | Overrides the model for this step |

---

## TOML format

A TOML workflow is an array of step tables (`[[step]]`) with an optional top-level `title`.

```toml
title = "Implement Feature Workflow"

[[step]]
name = "plan"
prompt = """
Read the following work item and produce a detailed implementation plan.
Include file paths, function names, and acceptance criteria.

{{work_item_content}}
"""

[[step]]
name = "implement"
depends_on = ["plan"]
agent = "codex"
model = "claude-haiku-4-5"
prompt = """
Implement work item {{work_item_number}} according to the plan from the previous step.
Run the test suite after each significant change.
"""

[[step]]
name = "review"
depends_on = ["implement"]
agent = "claude"
prompt = """
Review the implementation against the acceptance criteria in:

{{work_item_section:[Acceptance Criteria]}}

Report any gaps or regressions.
"""
```

**Key rules:** all keys lowercase; `depends_on` is an array even for a single dependency; multi-line prompts use TOML triple-quoted strings (`"""`).

### Common TOML errors

| Error | Cause | Fix |
|-------|-------|-----|
| `depends_on` not an array | `depends_on = "plan"` | Use `depends_on = ["plan"]` |
| Template var not substituted | `--work-item` not passed | Add `--work-item <nnnn>` |
| Uppercase key rejected | `Name = "plan"` | Use `name = "plan"` |

---

## YAML format

A YAML workflow nests steps under a top-level `steps:` key. `depends_on` must be a YAML sequence, not a bare string.

```yaml
steps:
  - name: plan
    prompt: |
      Read the following work item and produce a detailed implementation plan.
      Include file paths, function names, and acceptance criteria.

      {{work_item_content}}

  - name: implement
    depends_on:
      - plan
    agent: codex
    model: claude-haiku-4-5
    prompt: |
      Implement work item {{work_item_number}} according to the plan from the previous step.
      Run the test suite after each significant change.

  - name: review
    depends_on:
      - implement
    agent: claude
    prompt: |
      Review the implementation against the acceptance criteria in:

      {{work_item_section:[Acceptance Criteria]}}

      Report any gaps or regressions.
```

**Key rules:** all keys lowercase; `depends_on` is a sequence; use block scalars (`|`) for multi-line prompts; 2-space indentation.

### Common YAML errors

| Error | Cause | Fix |
|-------|-------|-----|
| Indentation parse error | Inconsistent spaces | Use 2-space indentation throughout |
| `depends_on` not a list | `depends_on: plan` | Use a YAML sequence (`- plan`) |
| Template variable literal in output | Typo or no `--work-item` | Check spelling; add `--work-item <nnnn>` |

---

## Choosing a format

| Format | When to use |
|--------|-------------|
| TOML | Machine-generated workflows; strict schema; structured data alongside prompts |
| YAML | Teams that already use YAML tooling; shorter syntax for simple step sequences |

Both formats support identical features. Choose based on your team's tooling preferences.

---

Back to skill: [SKILL.md](../SKILL.md)
