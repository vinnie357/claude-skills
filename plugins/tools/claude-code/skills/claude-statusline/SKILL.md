---
name: claude-statusline
description: Guide for creating and configuring the Claude Code status line. Use when building a custom status bar, configuring statusLine in settings.json, scripting token/model/git readouts, or debugging status-line output.
license: MIT
---

# Claude Code Status Line

Guide for designing, configuring, and debugging the Claude Code status line — a customizable bar rendered at the bottom of the UI that runs a user-supplied shell script on each session update.

## When to Use This Skill

Activate this skill when:
- Creating or editing a status-line script
- Configuring the `statusLine` block in `settings.json`
- Surfacing token usage, model, cost, git, or project context at a glance
- Debugging blank or stale status-line output
- Customizing the subagent panel via `subagentStatusLine`

## What Is the Status Line?

The status line is a shell command that Claude Code executes locally on each session update. Claude Code pipes a JSON payload (model, workspace, context-window, cost, etc.) to the script's stdin and renders the script's stdout verbatim as the bar at the bottom of the UI. It runs on the user's machine, consumes no API tokens, and is temporarily hidden during autocomplete, help menus, and permission prompts.

The status line is gated by the same workspace-trust acceptance as hooks. Setting `disableAllHooks: true` in settings also disables the status line.

## Configuration

Add a `statusLine` block to `~/.claude/settings.json` (user) or `.claude/settings.json` (project):

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 2,
    "refreshInterval": 5
  }
}
```

Fields:
- `type` — must be `"command"`
- `command` — path to a script, or an inline shell command
- `padding` (optional) — extra horizontal spacing in characters (default `0`)
- `refreshInterval` (optional, seconds, min `1`) — re-runs on a fixed timer in addition to event-driven updates; set this when displaying time-based data or when state changes during idle (e.g. subagent progress). Omit for event-only updates.

### The `/statusline` slash command

Claude Code ships a built-in `/statusline <description>` command that generates a script and updates settings for you (e.g. `/statusline show model name and context percentage with a progress bar`). Use `/statusline delete` to remove the configuration.

## Stdin JSON Payload

Every invocation receives a JSON object on stdin containing session metadata. Key top-level fields:

| Need | Field path |
|------|------------|
| Model label | `model.display_name` (human) or `model.id` (stable) |
| Current folder | `workspace.current_dir` (basename for display) |
| Project root | `workspace.project_dir` |
| Context % | `context_window.used_percentage` (null-guard with `// 0`) |
| Cumulative tokens | `context_window.total_input_tokens`, `.total_output_tokens` |
| Cost USD | `cost.total_cost_usd` |
| Wall time ms | `cost.total_duration_ms` |
| Lines changed | `cost.total_lines_added`, `.total_lines_removed` |
| Cache key | `session_id` |
| Transcript file | `transcript_path` |
| Rate limits | `rate_limits.five_hour.used_percentage` (Pro/Max only) |
| Output style | `output_style.name` |
| Vim mode | `vim.mode` (absent when vim off) |
| Worktree | `worktree.*` / `workspace.git_worktree` |

See `references/input-schema.md` for the full JSON schema, nullable fields, and per-field semantics.

**Note on `context_window.used_percentage`**: pre-calculated by Claude Code as `(input + cache_creation + cache_read) / context_window_size` — output tokens are *not* included. Use this field rather than computing from `current_usage` or `total_input_tokens` (which is cumulative and can exceed the window size).

## Default Example

The default script shipped in `assets/statusline-default.sh` surfaces model, folder, context %, and git branch:

```bash
#!/usr/bin/env bash
input=$(cat)
MODEL=$(jq -r '.model.display_name // "Claude"' <<<"$input")
DIR=$(jq -r '.workspace.current_dir // .cwd' <<<"$input")
PCT=$(jq -r '.context_window.used_percentage // 0' <<<"$input" | cut -d. -f1)

BRANCH=""
if git -C "$DIR" rev-parse --git-dir >/dev/null 2>&1; then
  B=$(git -C "$DIR" branch --show-current 2>/dev/null)
  [ -n "$B" ] && BRANCH=" | 🌿 $B"
fi

echo "[$MODEL] 📁 ${DIR##*/} | ${PCT}% ctx${BRANCH}"
```

Install it:

```bash
cp assets/statusline-default.sh ~/.claude/statusline.sh
chmod +x ~/.claude/statusline.sh
```

Then add to `~/.claude/settings.json`:

```json
{ "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }
```

Renders e.g. `[Opus] 📁 my-project | 42% ctx | 🌿 main`.

## Output Rules

- Stdout is rendered verbatim; each `echo`/`print` line becomes a separate row (multi-line supported).
- ANSI color escape codes work: `\033[32m` green, `\033[33m` yellow, `\033[31m` red, `\033[0m` reset.
- OSC 8 sequences produce clickable hyperlinks in supporting terminals (iTerm2, Kitty, WezTerm). Set `FORCE_HYPERLINK=1` for terminals that aren't auto-detected.
- Keep lines short — long output truncates or wraps in narrow terminals.
- Write to stdout only. A non-zero exit code or empty stdout blanks the row. Writes to stderr are not rendered.

### Colored context-bar example

```bash
PCT=$(jq -r '.context_window.used_percentage // 0' <<<"$input" | cut -d. -f1)
if   [ "$PCT" -lt 70 ]; then COLOR="\033[32m"      # green
elif [ "$PCT" -lt 90 ]; then COLOR="\033[33m"      # yellow
else                         COLOR="\033[31m"; fi  # red
printf "${COLOR}%d%% ctx\033[0m\n" "$PCT"
```

## Update Cadence

- The script runs after each new assistant message, on permission-mode change, and on vim-mode toggle.
- Events are debounced at 300ms.
- If a new trigger fires while a previous run is still executing, the in-flight run is cancelled.
- Edits to the script apply on the next trigger, not retroactively.
- During idle (e.g. waiting on subagents) events stop firing — set `refreshInterval` to keep time-based data live.

## Caching & Performance

Expensive operations (git branch lookups, network calls, file reads) should be cached because the script runs on every update.

- Key the cache on `session_id` — stable per session. Do **not** use `$$` / pid; those change on every invocation.
- Cache under `/tmp` or `$XDG_CACHE_HOME` with the session id in the filename.
- Skip the cache on miss by returning fast-path defaults; populate it in the background when safe.

```bash
SID=$(jq -r '.session_id' <<<"$input")
CACHE="/tmp/statusline-${SID}.branch"
if [ ! -f "$CACHE" ] || [ $(($(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE"))) -gt 30 ]; then
  git -C "$DIR" branch --show-current 2>/dev/null > "$CACHE"
fi
BRANCH=$(cat "$CACHE" 2>/dev/null)
```

## Subagent Status Line

A parallel `subagentStatusLine` setting customizes the row rendered inside the subagent panel. Input adds a `tasks` array with `{id, name, tokenCount, ...}`. Output expects **NDJSON** — one JSON object per line:

```
{"id":"task-abc","content":"analyzing schema..."}
{"id":"task-def","content":"✓ done"}
```

Use this to project per-subagent progress into the UI.

## Testing Locally

Pipe canned JSON to the script:

```bash
echo '{
  "model": {"display_name": "Opus"},
  "workspace": {"current_dir": "/tmp/x"},
  "context_window": {"used_percentage": 42},
  "session_id": "test"
}' | ~/.claude/statusline.sh
```

Iterate until the output looks right, then trigger an assistant message in Claude Code to see it rendered.

## Common Pitfalls

- **`used_percentage` is null before the first API call** — always `// 0` or similar fallback.
- **`total_input_tokens` is cumulative** across the session and can exceed the window size. Never divide it by `context_window_size` for a percentage — use `used_percentage`.
- **`rate_limits` is Pro/Max only** and absent before the first API response.
- **Non-zero exit or stderr writes blank the line.** Redirect diagnostics: `git ... 2>/dev/null`.
- **Nullable / absent fields**: `session_name`, `workspace.git_worktree`, `vim`, `agent`, `worktree`, `rate_limits`. Default them with `// "fallback"` in `jq`.
- **Script edits apply on the next trigger**, not instantly — send a message to re-run.
- **Windows runs scripts via Git Bash.** Invoke PowerShell explicitly: `powershell -NoProfile -File %USERPROFILE%\.claude\statusline.ps1`.
- **`disableAllHooks: true`** also disables the status line.
- **Autocomplete / help menus / permission prompts** hide the status line temporarily — this is expected behavior, not a script failure.
