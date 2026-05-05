# Skill Frontmatter Reference

Complete reference for SKILL.md YAML frontmatter fields. Source: [Claude Code Skills documentation](https://code.claude.com/docs/en/skills#frontmatter-reference). Load this when authoring a skill that needs anything beyond `name` / `description` / `license`.

## All fields are optional

Only `description` is recommended (so Claude knows when to invoke the skill).

## Field reference

### Identity

| Field | Description |
|---|---|
| `name` | Display name. Defaults to directory name if omitted. Lowercase letters, numbers, hyphens only. Max 64 chars. |
| `description` | What the skill does and when to use it. Use third person. Combined with `when_to_use` and capped at 1,536 chars in the listing — put key use case first. |
| `when_to_use` | Additional triggers / example phrases. Appended to `description` in the listing; counts toward the 1,536-char cap. |
| `license` | License name (e.g., `MIT`) or filename reference. |
| `metadata` | Key-value string pairs for client-specific properties. |

### Invocation control

| Field | Description |
|---|---|
| `disable-model-invocation` | `true` prevents Claude from auto-loading the skill. User can still invoke with `/name`. Also blocks preload into subagents. Default: `false`. |
| `user-invocable` | `false` hides the skill from the `/` menu. Claude can still invoke it. Use for background knowledge. Default: `true`. |
| `argument-hint` | Autocomplete hint shown for arguments. Example: `[issue-number]` or `[filename] [format]`. |
| `arguments` | Named positional arguments for `$name` substitution. Space-separated string or YAML list. Names map to argument positions in order. |

### Tools and permissions

| Field | Description |
|---|---|
| `allowed-tools` | Tools pre-approved while this skill is active. Space-separated string or YAML list. **Rejected by this marketplace's `test/validate-plugin.nu`** — declare allowlists on agents instead. Permission rules in `.claude/settings.json` still apply. |

### Execution control

| Field | Description |
|---|---|
| `model` | Override the session model while this skill is active. Same values as `/model`, or `inherit`. Reverts at end of turn. |
| `effort` | Override effort level: `low`, `medium`, `high`, `xhigh`, `max`. Available levels depend on model. Default: inherit. |
| `context` | `fork` runs the skill in a forked subagent context. Skill body becomes the subagent prompt. |
| `agent` | Subagent type when `context: fork`. Built-in: `Explore`, `Plan`, `general-purpose`. Or any custom subagent in `.claude/agents/`. |
| `hooks` | Hooks scoped to this skill's lifecycle. See `claude-hooks` skill. |
| `paths` | Glob patterns that limit auto-activation. Comma-separated string or YAML list. Skill loads only when working with matching files. |
| `shell` | `bash` (default) or `powershell` for `` !`...` `` inline shell. PowerShell requires `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`. |

## String substitutions in skill content

| Variable | Expansion |
|---|---|
| `$ARGUMENTS` | All arguments passed when invoking the skill. |
| `$ARGUMENTS[N]` / `$N` | Single argument by 0-based index. |
| `$name` | Named argument from the `arguments:` frontmatter list. |
| `${CLAUDE_SESSION_ID}` | Current session ID. |
| `${CLAUDE_EFFORT}` | Current effort level. |
| `${CLAUDE_SKILL_DIR}` | Absolute path to the skill's directory. Use for referencing bundled scripts: `bash ${CLAUDE_SKILL_DIR}/scripts/foo.sh`. |

Indexed arguments use shell-style quoting. Wrap multi-word values in quotes: `/skill "hello world" second` makes `$0 = "hello world"`, `$1 = "second"`. `$ARGUMENTS` always expands to the full string as typed.

## Dynamic context injection

Inline shell commands run before the skill content reaches Claude. Output replaces the placeholder:

```markdown
## Current changes
!`git diff HEAD`
```

Multi-line form uses a fenced code block opened with ` ```! `:

````markdown
## Environment
```!
node --version
npm --version
```
````

Disable across user/project/plugin/additional-directory skills via `"disableSkillShellExecution": true` in settings. Bundled and managed skills are unaffected.

## Invocation matrix

| Frontmatter | User invokes? | Claude invokes? | Description in context? |
|---|---|---|---|
| (default) | yes | yes | always |
| `disable-model-invocation: true` | yes | no | not in context — full skill loads only when user invokes |
| `user-invocable: false` | no | yes | always — but hidden from `/` menu |

## Where skills live

Precedence: enterprise > personal > project. Plugin skills use `plugin-name:skill-name` namespace and cannot conflict with other levels.

| Location | Path | Scope |
|---|---|---|
| Enterprise | managed settings | All users in org |
| Personal | `~/.claude/skills/<name>/SKILL.md` | All your projects |
| Project | `.claude/skills/<name>/SKILL.md` | This project only |
| Plugin | `<plugin>/skills/<name>/SKILL.md` | Where plugin is enabled |

Live change detection: edits to existing skill directories take effect mid-session. Creating a top-level skills directory mid-session requires restart so the watcher picks it up.

## Description budget

Skill descriptions are loaded into context so Claude can decide when to invoke. Combined description + when_to_use is capped at 1,536 characters per skill in the listing.

Total slash-command-tool char budget defaults to 1% of context window (or 8,000 char fallback). Override via `SLASH_COMMAND_TOOL_CHAR_BUDGET` env var. When too many skills exceed budget, descriptions get shortened — front-load the key use case.

## Pre-approve patterns

`allowed-tools` accepts patterns:

```yaml
allowed-tools: Bash(git add *) Bash(git commit *) Bash(git status *)
```

For project-level skills, `allowed-tools` activates after the workspace trust dialog is accepted, like `.claude/settings.json` permission rules. Review skills before trusting a repo — a malicious skill can grant itself broad tool access.

This marketplace prohibits `allowed-tools` on skills (validator-enforced). The pattern lives on agents.
