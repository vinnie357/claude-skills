# GitLab MR Commands

Scope: policy is unchanged from the main skill — commit format, no attribution,
branch naming, the Three-Gate Merge Policy, and squash-only merging apply
identically on GitLab. Only the CLI verbs differ, from `gh` to `glab`. This file
covers `glab` flag detail; the main skill body carries the policy.

## Provenance

Sourced from the official docs at `https://docs.gitlab.com/cli/` (per-command
pages cited in `sources.md`), not from local execution. `glab` was not installed
on the machine where this content was authored, and no command here was tested by
running it. No `glab` version is pinned — pinning a version never actually run
against would overstate the evidence. Re-check with `glab <cmd> --help` before
relying on a flag.

## Authentication — `glab auth login [flags]`

| Flag | Purpose |
|------|---------|
| `--hostname string` | GitLab instance — required for self-managed/Dedicated, omit for gitlab.com |
| `--stdin` | Read the token from stdin (scripting, CI) |
| `-t, --token string` | Pass the access token directly |
| `-j, --job-token` | Use a CI job token |
| `--device` | OAuth 2.0 device flow for headless environments (GitLab 17.9+) |
| `-g, --git-protocol string` | `ssh`, `https`, or `http` |

## Create — `glab mr create [flags]`

| Flag | Purpose |
|------|---------|
| `-t, --title` / `-d, --description string` | MR title / description — **`--description`, not `--body`**; `glab`'s flag name differs from `gh`'s |
| `--description-file string` | Read description from a file (`-` for stdin) — the `gh --body-file` equivalent |
| `--draft` | Mark as draft |
| `-b, --target-branch` / `-s, --source-branch` | Base / source branch |
| `-f, --fill` | Auto-fill title/description from commits, push branch |
| `--push`, `-y, --yes`, `-w, --web` | Push after creation; skip confirmation; finish in browser |
| `-l, --label`, `-a, --assignee`, `--reviewer` | Attach labels, assignees, reviewers |

## List / view / checkout

`glab mr list [flags]` (alias `ls`): `-A, --all`; `-c, --closed`; `-M, --merged`;
`-d, --draft`; `-s/-t, --source-branch/--target-branch string`; `-F, --output
text|json`.

`glab mr view [<id|branch>] [flags]`:

| Flag | Purpose |
|------|---------|
| `-c, --comments` | Comments and activities — the Gate-3 durable-record read, equivalent to `gh pr view --comments` |
| `--resolved` / `--unresolved` | Only resolved / unresolved discussions (implies `--comments`) |
| `-s, --system-logs` | System activity/logs |
| `-F, --output`, `-w, --web` | `text`/`json`; open in browser |

`glab mr checkout [<id>|<branch>|<url>] [flags]`: `-b, --branch string` (local
branch name); `-f, --force` (reset to remote on divergence); `-u,
--set-upstream-to string`.

## Comment — `glab mr note create`

The `gh pr comment` equivalent — posts under the authenticated identity.

`glab mr note create [<id>|<branch>] [flags]`

| Flag | Purpose |
|------|---------|
| `-m, --message string` | The comment content — the key flag |
| `--file string` / `--line string` / `--old-line int` | Diff comment: file, line (single or range), old-version line for removed lines |
| `--reply string` | Reply to an existing discussion |
| `--resolvable` | Resolvable discussion thread (default true) |
| `--unique` | Skip posting if identical content already exists |

Docs example: `glab mr note create 123 -m "Looks good to me!"`

**Attribution rule applies here too.** This posts under the authenticated identity
exactly like a commit — no `Co-Authored-By`, no "Generated with Claude Code" or
model/vendor mentions. Unlike a commit, a posted comment is public immediately and
cannot be quietly amended; edits leave a visible history.

## Merge — `glab mr merge [<id|branch>] [flags]`

| Flag | Purpose |
|------|---------|
| `-s, --squash` / `-r, --rebase` | Squash or rebase merge |
| `-d, --remove-source-branch` | Delete source branch after merge |
| `-m, --message` / `--squash-message` | Merge / squash commit message |
| `--sha string` | Require a specific SHA to merge |
| `-y, --yes` | Skip confirmation |
| `--auto-merge` | Queue automatic merge once checks pass — **defaults to true** |

**Hazard.** `--auto-merge` defaults to true. Left unset, `glab mr merge` can queue
a merge that fires later when the pipeline succeeds — a merge the user never
explicitly approved at that moment. Conflicts directly with "agents never merge."
Always pass `--auto-merge=false`, or do not run `glab mr merge` at all without
explicit user go-ahead.

## CI status — `glab ci status [flags]`

The Gate 2 command.

| Flag | Purpose |
|------|---------|
| `-b, --branch string` | Branch to check — **defaults to the current branch** |
| `-l, --live` | Live-updating view, roughly `gh`'s `--watch` |
| `-w, --wait` | Wait for the pipeline to finish (scripts) |
| `-F, --output`, `--jq` | `text`/`json`; jq filter for programmatic parsing |

**Scoping asymmetry.** `glab ci status` is branch-scoped (current branch by
default); `gh pr checks` is PR-scoped. Not interchangeable at Gate 2 — on GitLab,
confirm the branch being checked is the MR's actual source branch.

## Explicitly out of scope

- **MR approvals** (`glab mr approve`/`approvers`/`revoke`). GitLab's approval
  system is a project/instance policy engine (required approvers, approval rules,
  code-owner approvals) with no GitHub-side counterpart this skill models. Gate 3
  here is an agent adversarial review recorded as a comment — not a platform
  approval. Never satisfy Gate 3 with `glab mr approve`.
- `glab mr todo`, `subscribe`/`unsubscribe`, `rebase`, `diff`, `glab issue` — no
  corresponding GitHub-side content in this skill.
- Self-managed GitLab instance configuration beyond `--hostname` — a deployment
  concern, not a git-workflow one.

## Global flag

`-R, --repo string` — select another repository (`OWNER/REPO` or
`GROUP/NAMESPACE/REPO`), same shape as `gh -R`.
