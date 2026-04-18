---
name: claude-output-styles
description: Guide for creating Claude Code output styles and reusable response-format contracts. Use when creating, shipping, or customizing an output style for a session; defining the response shape an agent, command, or team worker must produce; standardizing worker reports so a team lead can parse them; or deciding between an output style, a skill, and a CLAUDE.md entry.
license: MIT
---

# Claude Code Output Styles

Guide for the native Claude Code output style feature and for applying the same response-contract pattern to agents, slash commands, teams, and skills.

## When to Use This Skill

Activate this skill when:

- Creating a custom output style for a session or plugin
- Shipping output styles from a plugin via the `output-styles/` directory
- Deciding whether a need is best served by an output style, a skill, CLAUDE.md, or `--append-system-prompt`
- Standardizing the response shape a worker agent must return so a team lead can filter and parse it
- Writing reusable response-format contracts that multiple agents, commands, or skills reference
- Debugging why a subagent is not honoring the session's output style

## Two Things This Skill Covers

1. **The Claude Code feature**: a session-level system prompt modification selected via `/config`, shipped as Markdown files, optionally bundled in plugins.
2. **The pattern**: a reusable *response-format contract* authored once and referenced from agents, commands, teams, or skills when consistent, parseable output is needed.

The feature affects the main agent loop only. The pattern is portable to anywhere a system prompt or instruction block is authored.

## Part 1: The Claude Code Feature

### What Output Styles Do

Output styles modify Claude Code's system prompt at session start. They can:

- Replace the default software-engineering instructions with a different role/tone/format
- Preserve core capabilities (file I/O, running scripts, TODO tracking)
- Keep or remove coding-specific instructions via `keep-coding-instructions`

Output styles are **always active** once selected, for the whole session. They are set at session start — changes take effect next session so prompt caching stays stable.

### Built-In Styles

| Style | Behavior |
| :--- | :--- |
| **Default** | Standard software-engineering system prompt |
| **Explanatory** | Adds educational "Insights" during task completion |
| **Learning** | Collaborative mode — Claude inserts `TODO(human)` markers for the user to fill in |

### Custom Style File Format

```markdown
---
name: My Custom Style
description: A brief description shown in the /config picker
keep-coding-instructions: false
---

# Custom Style Instructions

You are an interactive CLI tool that helps users with [domain].

## Specific Behaviors

- Respond in [tone]
- Structure output as [format]
- When [condition], do [action]
```

### Frontmatter Fields

| Field | Purpose | Default |
| :--- | :--- | :--- |
| `name` | Display name (inherits from filename if omitted) | filename |
| `description` | Shown in `/config` picker | none |
| `keep-coding-instructions` | Retain Claude Code's coding-specific system prompt sections | `false` |

Set `keep-coding-instructions: true` when the custom style *augments* coding behavior rather than replacing it.

### File Locations

| Scope | Path |
| :--- | :--- |
| User-level | `~/.claude/output-styles/` |
| Project-level | `.claude/output-styles/` |
| Plugin-shipped | `<plugin-root>/output-styles/` |

### Selecting a Style

- Interactive: `/config` → **Output style** → pick from menu
- Direct: edit `outputStyle` in `.claude/settings.local.json`:

```json
{
  "outputStyle": "Explanatory"
}
```

Selection is written to `.claude/settings.local.json` at the local project level.

### Shipping Output Styles in a Plugin

Place style files under `<plugin-root>/output-styles/`. They are discovered when the plugin is installed and appear alongside built-in and user styles in `/config`.

```
my-plugin/
├── .claude-plugin/
│   └── plugin.json
├── skills/
└── output-styles/
    ├── terse-reviewer.md
    └── verbose-tutor.md
```

No additional `plugin.json` field is required — the `output-styles/` directory is discovered by convention.

### Token Usage Considerations

- Output styles add to the input token count via system prompt expansion, but **prompt caching** amortizes this after the first request per session
- Built-in **Explanatory** and **Learning** styles produce longer output by design — higher output token cost
- Custom styles' output cost is driven by what the instructions ask Claude to produce

## Part 2: The Pattern — Response Contracts for Agents, Commands, and Teams

The shape of an output style — a set of instructions controlling response format, tone, and structure — is portable. You can apply the same pattern anywhere a system prompt or instruction block is authored.

### Important: Subagents Do Not Inherit Output Style

The session-level output style modifies the **main agent loop's** system prompt. It does **not** propagate to:

- Subagents spawned via the `Agent` tool
- Slash command execution contexts
- Skills loaded within a subagent

If you need a subagent to produce output in a specific shape, encode the contract in the agent's own definition or reference a shared contract file.

### Where to Place a Contract

| Target | Where the contract goes |
| :--- | :--- |
| Agent (`.claude/agents/<name>.md`) | Body of the agent markdown, under a `## Response Format` heading |
| Slash command (`.claude/commands/<name>.md`) | Body of the command markdown |
| Team worker | Prompt template passed to the worker when spawned |
| Skill | Dedicated section in `SKILL.md`, or a referenced file in `assets/` |
| Plugin-wide | Shared file in `assets/contracts/` that components link to |

### Why Standardize Worker Output

When a team lead spawns multiple workers and must parse their results, inconsistent output shapes force the lead to write bespoke parsing for each worker. A shared contract lets the lead:

- Extract specific fields (e.g., `PR_URL`, `STATUS`) with one parser
- Filter worker reports for pass/fail without reading prose
- Compare two workers' results reliably

### Writing a Contract

A contract specifies:

- **Sections the response must contain** (fixed headings)
- **Field formats** inside sections (literal strings, enums, lengths)
- **What must not appear** (e.g., no prose preamble, no trailing summaries)

Use imperative language. Example contract body:

```markdown
Respond using exactly these sections, in this order:

## SUMMARY
One sentence describing what was done. No preamble.

## EVIDENCE
Verbatim output from `mise run ci`. Paste the tail if too long,
marked with `[truncated]`.

## STATUS
One of: `passed` | `failed` | `blocked`.

## NEXT
One sentence — what the team lead should do with this report.

Do not add sections. Do not summarize at the end.
```

### Referencing a Shared Contract

From an agent definition:

```markdown
---
name: ci-validator
description: Runs mise run ci and returns a structured report
---

# CI Validator

Run `mise run ci`. Report using the contract in
`assets/contracts/ci-evidence-format.md` — copy the section headings
exactly.
```

From a team prompt template (pseudocode):

```
Spawn worker with prompt:
  "Fix the failing test in src/foo.ex.
   Report using {{contract: worker-report-format}}."
```

### When to Use a Contract vs. an Output Style

| Need | Use |
| :--- | :--- |
| Session-level persona for the human user | Output style |
| Consistent shape from a specific agent role | Contract in the agent definition |
| Parseable reports from N parallel workers | Shared contract referenced by each worker |
| Reusable response shape across a plugin | Contract in `assets/contracts/` |
| One-off format for a single prompt | Inline instructions, no contract needed |

## Output Styles vs. Related Features

| Feature | Scope | Loaded When | Modifies |
| :--- | :--- | :--- | :--- |
| Output style | Main agent loop only | Session start (after `/config`) | System prompt (replaces coding sections) |
| CLAUDE.md | Main agent loop | Session start | Appended as user message after system prompt |
| `--append-system-prompt` | Main agent loop | Session start | Appended to system prompt |
| Skill | Main loop and subagents | On-demand (invoke or auto) | Adds procedural knowledge |
| Agent | Spawned subagent | When `Agent` tool invoked | Independent system prompt |
| Response contract (pattern) | Wherever embedded | When the host component loads | The host's instructions |

## Anti-Fabrication

Do not fabricate output-style behavior or frontmatter fields not documented at https://code.claude.com/docs/en/output-styles. When authoring contracts, verify referenced files exist with `Read` or `Glob` before claiming they do. Do not claim an agent honors the session output style — it does not. For the full anti-fabrication ruleset, see `core:anti-fabrication`.

## Common Pitfalls

- **Assuming subagents inherit the style.** They do not. Encode the contract in the agent definition.
- **Editing `outputStyle` and expecting mid-session effect.** Output style is fixed at session start for cache stability.
- **Mixing session persona and agent response format.** A session-level output style for a reviewer persona is not the right tool for "all my workers must emit structured reports."
- **Over-constraining.** A contract that dictates every word produces fragile output across model versions. Specify structure, not phrasing.
- **Missing `keep-coding-instructions`.** Custom styles default to stripping coding instructions — if the style is meant to augment coding, set this to `true`.

## Assets

Reference response-format contracts in `assets/`:

- `assets/worker-report-format.md` — structured report for team workers (SUMMARY / EVIDENCE / STATUS / NEXT)
- `assets/ci-evidence-format.md` — verbatim CI-output contract for validation agents
- `assets/review-findings-format.md` — findings-list contract for code review agents

Copy, reference, or adapt these when defining agents, commands, or team workers.

## References

- Claude Code Output Styles: https://code.claude.com/docs/en/output-styles
- Claude Code Plugins Reference: https://code.claude.com/docs/en/plugins-reference
- Settings: https://code.claude.com/docs/en/settings
- CLAUDE.md memory: https://code.claude.com/docs/en/memory
