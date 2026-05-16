# amux Workflow Authoring

Reference for authoring amux workflow files in all three supported syntaxes: Markdown, TOML, and YAML.

Source: https://github.com/prettysmartdev/amux/blob/main/docs/04-workflows.md — accessed 2026-05-16.
Run `amux workflow validate <path>` to catch parse errors before executing. Run `amux workflow render <path> --work-item <nnnn>` to preview substituted output.

---

## Critical rules (read first)

1. **Lowercase keys only.** Uppercase field names are a parse error in all three formats. Write `prompt:`, `agent:`, `depends-on:` — never `PROMPT:`, `Agent:` (in TOML/YAML), `Depends-On:`.
2. **Markdown field order is strict.** Within a step, fields must appear in this sequence:
   ```
   Depends-on: (optional)
   Agent: (optional)
   Model: (optional)
   Prompt: (required — everything after this line is prompt text)
   ```
   Any text following the `Prompt:` line, including blank lines and other field-looking lines, is treated as prompt content. Do not place `Agent:` or `Model:` after `Prompt:`.
3. **`Prompt:` ends the header.** Once `amux` encounters the `Prompt:` key in a Markdown step, all remaining text in that step block is the prompt body.
4. **Step names come from Markdown headings.** Use `## Step: <name>` to name a step. The name is used in `Depends-on:` references.
5. **Template variables** are case-sensitive: `{{work_item_number}}`, `{{work_item_content}}`, `{{work_item_section:[Name]}}`.

---

## Template variables

Template variables are substituted at workflow execution time, not at parse time. They require `--work-item <nnnn>` to be passed to `amux exec workflow`.

| Variable | Substituted with |
|----------|-----------------|
| `{{work_item_number}}` | Zero-padded 4-digit work item number (e.g. `0027`) |
| `{{work_item_content}}` | Full text of the work item file at `workItems.dir/<nnnn>` |
| `{{work_item_section:[Name]}}` | Text of the named section within the work item (case-insensitive match) |

**Example section extraction:**

If the work item contains:
```markdown
## Acceptance Criteria
- Tests pass
- No regressions
```

Then `{{work_item_section:[Acceptance Criteria]}}` renders to the text of that section.

If `--work-item` is not passed, template variables render as empty strings (not as an error). Preview before running: `amux workflow render ./workflow.md --work-item 0027`.

---

## Markdown format

### Grammar

A Markdown workflow file is a sequence of step blocks. Each block starts with a level-2 heading:

```
## Step: <step-name>
```

Followed by optional fields and then the prompt body:

```
[Depends-on: <step-name>[, <step-name>]]
[Agent: <agent-name>]
[Model: <model-id>]
Prompt: <first line of prompt (may be blank)>
<prompt body — all remaining lines in this step block>
```

**Field rules:**
- `Depends-on:` — comma-separated list of step names this step waits for. Omit for the first step.
- `Agent:` — one of `claude`, `codex`, `opencode`, `maki`, `gemini`, `copilot`, `crush`, `cline`. Overrides `--agent` and per-repo `agent` for this step only.
- `Model:` — model string passed to the agent CLI (e.g. `claude-haiku-4-5`, `gpt-4o`). Requires agent support.
- `Prompt:` — required. Everything after the colon on this line AND all subsequent lines until the next `## Step:` heading is prompt text.

### Key ordering rule

```
Depends-on (optional)
Agent (optional)
Model (optional)
Prompt (required — must be last field)
```

### Complete Markdown example

```markdown
## Step: plan
Prompt: Read the following work item and produce a detailed implementation plan.
Include file paths, function names, and acceptance criteria.

{{work_item_content}}

## Step: implement
Depends-on: plan
Agent: codex
Model: claude-haiku-4-5
Prompt: Implement work item {{work_item_number}} according to the plan produced in the previous step.
Run the test suite after each significant change.

## Step: review
Depends-on: implement
Agent: claude
Prompt: Review the implementation against the acceptance criteria in:

{{work_item_section:[Acceptance Criteria]}}

Report any gaps or regressions.
```

### Common Markdown errors

| Error | Cause | Fix |
|-------|-------|-----|
| `parse error: uppercase key` | `Agent:` used in a position amux doesn't expect, or `PROMPT:` | Use lowercase: `agent:` in TOML/YAML, `Agent:` (initial cap only) in Markdown headers |
| `field after Prompt:` | `Agent:` placed after `Prompt:` | Move `Agent:` above `Prompt:` |
| Step dependency not found | Typo in `Depends-on:` value | Match exactly the string after `## Step:` |

---

## TOML format

### Grammar

A TOML workflow is an array of step tables.

```toml
[[steps]]
name = "<step-name>"
prompt = """
<prompt body>
"""

[[steps]]
name = "<step-name>"
depends_on = ["<step-name>"]   # array of step names
agent = "<agent-name>"          # optional
model = "<model-id>"            # optional
prompt = """
<prompt body>
"""
```

**Key rules:**
- All keys lowercase: `name`, `prompt`, `depends_on`, `agent`, `model`.
- `depends_on` is an array (even for a single dependency).
- Multi-line prompts use TOML triple-quoted strings (`"""`).
- Template variables work inside prompt strings.

### Complete TOML example

```toml
[[steps]]
name = "plan"
prompt = """
Read the following work item and produce a detailed implementation plan.
Include file paths, function names, and acceptance criteria.

{{work_item_content}}
"""

[[steps]]
name = "implement"
depends_on = ["plan"]
agent = "codex"
model = "claude-haiku-4-5"
prompt = """
Implement work item {{work_item_number}} according to the plan from the previous step.
Run the test suite after each significant change.
"""

[[steps]]
name = "review"
depends_on = ["implement"]
agent = "claude"
prompt = """
Review the implementation against the acceptance criteria in:

{{work_item_section:[Acceptance Criteria]}}

Report any gaps or regressions.
"""
```

### Common TOML errors

| Error | Cause | Fix |
|-------|-------|-----|
| `depends_on` not an array | Written as a string: `depends_on = "plan"` | Use array syntax: `depends_on = ["plan"]` |
| Template var not substituted | `--work-item` flag not passed to `amux exec workflow` | Add `--work-item <nnnn>` |
| Uppercase key rejected | `Name = "plan"` | Use `name = "plan"` |

---

## YAML format

### Grammar

A YAML workflow is a `steps` list at the top level.

```yaml
steps:
  - name: <step-name>
    prompt: |
      <prompt body>

  - name: <step-name>
    depends_on:
      - <step-name>
    agent: <agent-name>       # optional
    model: <model-id>         # optional
    prompt: |
      <prompt body>
```

**Key rules:**
- All keys lowercase: `steps`, `name`, `prompt`, `depends_on`, `agent`, `model`.
- `depends_on` is a YAML sequence.
- Use YAML block scalars (`|`) for multi-line prompts.
- Template variables work inside prompt scalars.

### Complete YAML example

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

### Common YAML errors

| Error | Cause | Fix |
|-------|-------|-----|
| Indentation parse error | Inconsistent spaces | Use 2-space indentation throughout |
| `depends_on` not a list | Written as a scalar: `depends_on: plan` | Use YAML sequence syntax |
| Template variable literal in output | Var name typo or no `--work-item` passed | Check spelling; add `--work-item <nnnn>` |

---

## Choosing a format

| Format | When to use |
|--------|-------------|
| Markdown | Human-readable step descriptions; prompts that include prose, lists, or embedded work item content |
| TOML | Machine-generated workflows; strict schema enforcement; structured data alongside prompts |
| YAML | Teams that already use YAML tooling; shorter syntax for simple step sequences |

All three formats support identical features. Choose based on your team's tooling preferences. Validate any format with `amux workflow validate <path>` before the first execution.

---

## Executing workflows

```sh
# Validate before running
amux workflow validate ./workflows/plan-implement-review.md

# Preview with substitution
amux workflow render ./workflows/plan-implement-review.md --work-item 0027

# Execute (asks for permission on each tool use)
amux exec workflow ./workflows/plan-implement-review.md --work-item 0027

# Execute autonomously in a worktree (60-second countdown between steps)
amux exec workflow ./workflows/plan-implement-review.md --work-item 0027 --yolo
```

---

Back to skill: [SKILL.md](../SKILL.md)
