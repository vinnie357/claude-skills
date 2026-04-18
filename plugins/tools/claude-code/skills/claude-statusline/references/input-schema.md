# Status Line — Stdin JSON Schema

Complete reference for the JSON payload Claude Code pipes to the status-line script on stdin.

Source: https://code.claude.com/docs/en/statusline (accessed 2026-04-18).

## Full example payload

```json
{
  "cwd": "/current/working/directory",
  "session_id": "abc123...",
  "session_name": "my-session",
  "transcript_path": "/path/to/transcript.jsonl",
  "version": "2.1.90",
  "model": {
    "id": "claude-opus-4-7",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/current/working/directory",
    "project_dir": "/original/project/directory",
    "added_dirs": [],
    "git_worktree": "feature-xyz"
  },
  "output_style": { "name": "default" },
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "rate_limits": {
    "five_hour": { "used_percentage": 23.5, "resets_at": 1738425600 },
    "seven_day": { "used_percentage": 41.2, "resets_at": 1738857600 }
  },
  "vim": { "mode": "NORMAL" },
  "agent": { "name": "security-reviewer" },
  "worktree": {
    "name": "my-feature",
    "path": "/path/to/.claude/worktrees/my-feature",
    "branch": "worktree-my-feature",
    "original_cwd": "/path/to/project",
    "original_branch": "main"
  }
}
```

## Field cheat-sheet

| Need | Field path | Notes |
|------|------------|-------|
| Model label (human) | `model.display_name` | e.g. `"Opus"`, `"Sonnet"` |
| Model id (stable) | `model.id` | e.g. `"claude-opus-4-7"` — use for logic that depends on exact model |
| Current folder | `workspace.current_dir` | basename for display |
| Project root | `workspace.project_dir` | original cwd at session start |
| Added dirs | `workspace.added_dirs` | array of extra roots |
| Context % | `context_window.used_percentage` | **null-guard with `// 0`** |
| Remaining % | `context_window.remaining_percentage` | complementary to used |
| Window size | `context_window.context_window_size` | 200000 default, 1000000 for extended-context |
| Cumulative input tokens | `context_window.total_input_tokens` | session-wide, can exceed window size |
| Cumulative output tokens | `context_window.total_output_tokens` | session-wide |
| Last-message tokens | `context_window.current_usage.*` | per-message breakdown |
| Over-200k flag | `exceeds_200k_tokens` | boolean |
| Cost (USD) | `cost.total_cost_usd` | session total |
| Wall time (ms) | `cost.total_duration_ms` | includes user think time |
| API time (ms) | `cost.total_api_duration_ms` | actual API work |
| Lines changed | `cost.total_lines_added`, `cost.total_lines_removed` | code diff counters |
| Cache key | `session_id` | **use for cache keys, not `$$`/pid** |
| Transcript | `transcript_path` | JSONL file for deeper per-message analysis |
| Claude Code version | `version` | semver string |
| Output style | `output_style.name` | e.g. `"default"`, `"explanatory"` |
| 5-hour rate limit | `rate_limits.five_hour.used_percentage` | **Pro/Max only** |
| 7-day rate limit | `rate_limits.seven_day.used_percentage` | **Pro/Max only** |
| Rate limit reset | `rate_limits.{five_hour,seven_day}.resets_at` | unix timestamp |
| Vim mode | `vim.mode` | `"NORMAL"`, `"INSERT"`, etc. — absent when vim off |
| Subagent name | `agent.name` | absent unless running with `--agent` |
| Worktree name | `worktree.name` | absent outside worktrees |
| Worktree branch | `worktree.branch` | worktree's branch |
| Worktree path | `worktree.path` | `.claude/worktrees/<name>` |
| Worktree original cwd | `worktree.original_cwd` | pre-worktree project path |
| Worktree original branch | `worktree.original_branch` | pre-worktree branch |
| Legacy worktree name | `workspace.git_worktree` | older worktree surface |

## Nullable / absent fields

| Field | State | Condition |
|-------|-------|-----------|
| `session_name` | absent | session has no user-assigned name |
| `workspace.git_worktree` | absent | not in a worktree |
| `vim` | absent | vim mode disabled |
| `agent` | absent | no subagent invocation |
| `worktree` | absent | not in a `.claude/worktrees/*` checkout |
| `rate_limits` | absent | non-Pro/Max plans, or before first API response |
| `context_window.used_percentage` | null | before first API call |
| `context_window.remaining_percentage` | null | before first API call |
| `context_window.current_usage` | null | before first API call |

Always fallback in `jq`:

```bash
jq -r '.context_window.used_percentage // 0'
jq -r '.vim.mode // ""'
jq -r '.rate_limits.five_hour.used_percentage // 0'
```

## `context_window.used_percentage` — how it's computed

Pre-calculated by Claude Code as:

```
used_percentage = (input_tokens + cache_creation_input_tokens + cache_read_input_tokens) / context_window_size * 100
```

Output tokens are **not** included. Prefer this field over computing your own percentage:

- Do **not** divide `total_input_tokens` by `context_window_size` — that value is cumulative across the whole session and will exceed 100%.
- Do **not** sum `current_usage.*` manually — the calculation already accounts for caching.

## `model.id` stability

`model.id` is the stable identifier (e.g. `claude-opus-4-7`) and is safe to match in script logic. `model.display_name` is intended for rendering and may vary cosmetically over time.

## Related

- Main skill: `../SKILL.md`
- Upstream docs: https://code.claude.com/docs/en/statusline
- Subagent payload differs — includes a `tasks` array and expects NDJSON output. See `SKILL.md` § "Subagent Status Line".
