---
name: claude-commands
description: Guide for creating custom slash commands for Claude Code. Use when adding a new slash command, writing $ARGUMENTS or $N argument substitutions, setting argument-hint or arguments in command frontmatter, choosing command frontmatter fields, injecting shell output into a command, or migrating .claude/commands/ files to skills.
---

# Claude Code Commands

Custom slash commands for Claude Code: prompt files invoked with `/name`, with argument substitution and dynamic shell context.

**Custom commands have merged into skills.** A file at `.claude/commands/deploy.md` and a skill at `.claude/skills/deploy/SKILL.md` both create `/deploy` and work the same way. Existing `.claude/commands/` files keep working and support the same frontmatter. Skills add a directory for supporting files, invocation control, and automatic loading when relevant — so create new commands as skills, and use `.claude/commands/` only for single-file prompts you already maintain there. The full skill-authoring guide is the `claude-skills` skill; this skill covers the command surface: naming, frontmatter, arguments, and dynamic context.

## File Locations and Command Names

| Location | Path | Command name |
|----------|------|--------------|
| Personal skill | `~/.claude/skills/<dir>/SKILL.md` | `/<dir>` |
| Project skill | `.claude/skills/<dir>/SKILL.md` | `/<dir>` |
| Project command file | `.claude/commands/<file>.md` | `/<file>` (extension dropped) |
| Plugin skill | `<plugin>/skills/<dir>/SKILL.md` | `/<plugin>:<dir>` |
| Nested project skill | `apps/web/.claude/skills/deploy/SKILL.md` | `/apps/web:deploy` when the name clashes with another skill |

- Use kebab-case directory and file names; the name on disk is the name typed.
- When a skill and a command file share a name, the skill takes precedence. Across levels, personal overrides project; enterprise managed settings take precedence over both. Plugin skills are namespaced, so they cannot conflict with other levels.
- In a plugin skill, the frontmatter `name` field replaces the last segment of the command (`my-plugin/skills/review/SKILL.md` with `name: fancy` → `/my-plugin:fancy`). In personal and project skills, `name` is only a display label — the command still comes from the directory name.

## Frontmatter Reference

YAML between `---` markers at the top of the file. All fields are optional; `description` is recommended so Claude knows when to load the command automatically. Malformed YAML loads the body with empty metadata: `/name` still works, but Claude has no description to match against.

| Field | Type / values | Default | Effect |
|-------|---------------|---------|--------|
| `name` | string | directory name | Display name; sets the command's last segment for plugin skills only |
| `description` | string | first paragraph of body | What it does and when to use it; drives automatic invocation |
| `when_to_use` | string | — | Extra trigger phrases, appended to `description` in the listing |
| `argument-hint` | string | — | Autocomplete hint, e.g. `[issue-number]` or `[filename] [format]` |
| `arguments` | space-separated string or YAML list | — | Declares named positional arguments for `$name` substitution; names map to positions in order |
| `disable-model-invocation` | boolean | `false` | Only the user can invoke; Claude cannot trigger it automatically |
| `user-invocable` | boolean | `true` | `false` hides it from the `/` menu; only Claude can invoke |
| `allowed-tools` | space/comma-separated string or YAML list | — | Tools pre-approved for the turn that invokes the command; the grant clears on the user's next message |
| `disallowed-tools` | space/comma-separated string or YAML list | — | Tools removed from the pool while the command is active; clears on the next message |
| `model` | model name or `inherit` | session model | Model override for the rest of the current turn |
| `effort` | `low` \| `medium` \| `high` \| `xhigh` \| `max` | session effort | Effort override while active |
| `context` | `fork` | inline | Runs the command in a forked subagent; the body becomes the subagent's prompt |
| `agent` | agent type | `general-purpose` | Which subagent type executes when `context: fork` is set |
| `background` | boolean | `true` | With `context: fork`, `false` waits for the result in the invoking turn |
| `hooks` | hook config | — | Hooks scoped to the command's lifecycle |
| `paths` | glob patterns (string or list) | — | Auto-load only when working with matching files |
| `shell` | `bash` \| `powershell` | `bash` | Shell used for dynamic context injection in this file |

Do not put `allowed-tools` on skills in THIS marketplace — `test/validate-plugin.nu` rejects it as a hard failure; tool allowlists belong on agents here. The field itself is valid upstream Claude Code frontmatter, which is why the table documents it.

## Argument Substitution

Placeholders in the body are replaced before Claude sees the content. **This means a doc that shows the literal token gets it substituted too when the doc itself loads as a skill.** Every `\$ARGUMENTS`/`${CLAUDE_*}` placeholder below carries a leading backslash (`\`) — the documented escape for a literal `$` (see "Substitution rules" below) — so this reference survives its own loading. Drop the backslash to get the real placeholder. Digit-indexed forms (`$0`, `$1`, `$2`, ...) and an undeclared `$name` need no such marker: with no arguments passed at load time they render unchanged, which is why plain `$0`/`$1` appear undecorated elsewhere on this page.

| Placeholder | Expands to |
|-------------|-----------|
| `\$ARGUMENTS` | The full argument string as typed |
| `\$ARGUMENTS[N]` | The argument at **0-based** index N |
| `$N` | Shorthand for `\$ARGUMENTS[N]` |
| `$name` | The named argument declared in `arguments:` frontmatter |
| `CLAUDE_SESSION_ID` | The current session ID |
| `CLAUDE_EFFORT` | The current effort level |
| `CLAUDE_SKILL_DIR` | The directory containing the command's SKILL.md |
| `CLAUDE_PROJECT_DIR` | The project root directory |

**The four `CLAUDE_*` rows are written bare on purpose.** In a real command you use them as brace expansions — a dollar sign, an opening brace, the name, a closing brace. They cannot be shown in that form here: **the leading-backslash escape does NOT work on the braced form.** Verified by loading this file as a skill — `\` before a braced token leaves the backslash in place AND still expands the token, so writing them out would print this session's real ID and paths into the documentation. The backslash escape works only on the bare `\$NAME` form, which is why the `$ARGUMENTS` rows above can use it.

**Indexing is 0-based: `$0` is the FIRST argument and `$1` is the SECOND.** This runs against shell convention (where `$1` is the first parameter) and is the easiest mistake to make when writing commands.

Substitution rules:

- **Quoting is shell-style.** `/my-skill "hello world" second` gives `$0` = `hello world`, `$1` = `second`. `\$ARGUMENTS` always gets the full string as typed.
- **Missing arguments differ by kind.** An indexed placeholder with no corresponding argument (`$2` when only one argument was passed) stays in the content unchanged — this is exactly why the digit-indexed examples on this page (`$0`, `$1`, `$2`) are safe to show undecorated: this skill declares no `arguments:` and loads with none, so every indexed placeholder above has "no corresponding argument" and renders literally. A named placeholder with no matching argument expands to an empty string.
- **Named arguments map by position.** With `arguments: [issue, branch]`, `$issue` expands to the first argument and `$branch` to the second.
- **Escaping a literal `$`:** a single backslash directly before the token, e.g. `\$1.00`. A doubled backslash (`\\$1`) does NOT escape — both backslashes stay and `$1` still expands. A backslash before any other `$` is left unchanged. This same backslash is the marker used throughout this page's `\$ARGUMENTS` placeholders, while the `CLAUDE_*` names below are shown bare examples to keep them literal while this doc itself loads.
- **No `\$ARGUMENTS` in the body?** When a command is invoked with arguments but contains no `\$ARGUMENTS`, Claude Code appends `ARGUMENTS: <input>` to the end of the content so Claude still sees what was typed.
- **Stacked invocations:** typing `/write-tests /fix-issue 123` at the start of one message loads both commands and passes the trailing text `123` as `\$ARGUMENTS` to each.
- `CLAUDE_SKILL_DIR` and `CLAUDE_PROJECT_DIR` also substitute inside Bash rules in `allowed-tools`, so a command can pre-approve exactly the bundled script its body tells Claude to run.

## Dynamic Context Injection

Shell output can be inlined into the command content before Claude reads it. **The examples below carry a `KEY=` prefix immediately before every `!` trigger, for the same reason the previous section escapes `$` placeholders with a backslash: showing the live syntax unguarded would run it, or corrupt it into a live diff, while this very page loads. Drop `KEY=` to get the real syntax.**

- **Inline:** `` KEY=!`git diff HEAD` `` on a line — the command runs and its stdout replaces the placeholder.
- **Fenced (multi-line):** a code fence opened with an info string of exactly `!` (shown here as ```` ```KEY=! ```` to keep this line inert) runs the commands and inlines the output.

This is preprocessing, not Claude executing a tool: every command runs before Claude sees anything, and Claude receives only the rendered result. Substitution runs once over the original file — command output is not re-scanned for further placeholders.

The inline `!` is recognized only at the start of a line or immediately after whitespace — **in the text Claude Code actually scans, which is the text after markdown code-span delimiters are stripped, not the markdown source as written.** Wrapping a bang in backticks does not by itself supply that preceding whitespace: only a real, visible character immediately before the bang in the rendered text does, which is why `` KEY=!`cmd` `` stays literal (the `KEY=` is real text, not a delimiter) while merely removing the space that might otherwise sit between an opening double-backtick and the bang does not — the delimiters were never counted as separating characters to begin with.

There is no file-inclusion placeholder. To inject a file's content, use `` KEY=!`cat path/to/file` `` (drop `KEY=`).

To block injection for user, project, plugin, and additional-directory sources, set `"disableSkillShellExecution": true` in settings; each command is replaced with `[shell command execution disabled by policy]`. Bundled and managed skills are not affected.

## Plugin Wiring

Plugin commands ship two ways:

- **Plugin skills** (preferred): directories under `<plugin>/skills/`, listed in the plugin.json `skills` array. Invoked as `/<plugin>:<name>`.
- **Command files:** the plugin.json `commands` field — a single path string or an array of `.md` file and directory paths; a directory entry loads every `.md` file in it.

See the `claude-plugins` skill for the full plugin.json schema and validation scripts.

## Security

- Never hardcode secrets — API keys, passwords, tokens, private URLs — in command files. Command bodies are prompts checked into repos and plugins.
- Treat `` KEY=!`command` `` (drop `KEY=`) lines as executable code in review: they run on invocation, before anyone reads the output. Audit third-party skills and plugins for injection lines and `allowed-tools` grants before installing; project-level `allowed-tools` takes effect only after the workspace trust dialog is accepted.
- Use `disable-model-invocation: true` for commands with side effects (deploy, commit, send-message) so Claude cannot trigger them on its own.
- In managed environments, enforce `disableSkillShellExecution` through managed settings, where users cannot override it.

## Examples

Complete worked commands — `\$ARGUMENTS`, `$N`, named arguments, and dynamic injection — are in [references/examples.md](references/examples.md).

## References

- Claude Code docs, "Extend Claude with skills" (covers custom commands): https://code.claude.com/docs/en/slash-commands
- `claude-skills` skill — full skill-authoring guide (structure, supporting files, evaluation)
- `claude-plugins` skill — plugin.json schema for shipping commands in plugins
- `core:anti-fabrication` skill — command bodies are prompts; verify every claim they make about tools, files, and behavior before shipping them
