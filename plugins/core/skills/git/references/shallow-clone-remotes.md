# Local-path remotes and push verification

When a worker's clone has a local path as its `origin` (a local-path clone in a build
source cache, or any clone whose `origin` was never repointed at GitHub), the `origin`
remote points at that LOCAL path, NOT at GitHub. `git push origin` writes to the local
clone's branch ref but does not propagate to GitHub. This does NOT cover the
destructive-execution-hands scratchpad clone — those hands remove `origin` entirely and
never push (`/core:agent-loop`'s `references/researcher.md`), so this file's pattern
does not apply there.

## The pattern

For every worker whose `origin` is a local path and that creates commits:

1. Add `github` as a named remote in the local-path clone, pointing at the GitHub HTTPS URL:

   ```bash
   git remote add github https://github.com/<owner>/<repo>.git
   git fetch github
   ```

2. Push directly to `github`, not `origin`:

   ```bash
   git push github <branch-name>
   ```

3. Verify the GitHub-side branch tip matches the local tip before reporting completion:

   ```bash
   gh api repos/<owner>/<repo>/git/refs/heads/<branch-name> --jq '.object.sha'
   # Compare against:
   git rev-parse <branch-name>
   ```

   Or, if a PR exists:

   ```bash
   gh pr view <num> -R <owner>/<repo> --json headRefOid
   ```

4. Report failure honestly when the GitHub-side sha does not match the local sha. `git push` exit code 0 against a file-based remote is NOT proof of GitHub receipt.

## Why this exists

`git push` returns success when the configured remote accepts the push. For a file-based remote (a local directory), that is trivially true — the local clone updates its branch ref but the change does not reach GitHub. The exit code is 0, the operation succeeded against the configured target, and a worker that only checks exit code will report "pushed successfully" while GitHub still shows the prior HEAD.

## Recovery

When this gap is caught after the fact, the file-based remote's branch tip is the source of truth for the work done. Push it to GitHub from inside the local-path clone via the `github` remote, or from the canonical clone using `git push origin <branch>` if the canonical's `origin` is GitHub.

## Related

- Build-time source-cache staleness (`build-source-staleness.md`, linked from SKILL.md) is the sibling case in this same family of file-based-remote silent absorption — this file covers the push side, that one covers the read side.
- Worker isolation — a worktree (see SKILL.md "Worktrees") is the isolation choice for ordinary work. A local-path clone survives for build source caches, where this file's add-a-github-remote-and-push pattern is the gap to close. It also survives for the destructive-execution-hands scratchpad (`/core:agent-loop`'s `references/researcher.md`), but that case does not use this pattern — hands remove `origin` entirely and never push.
