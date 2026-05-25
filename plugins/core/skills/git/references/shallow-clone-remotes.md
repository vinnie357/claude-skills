# Shallow clones and remote verification

When a worker operates in a shallow clone (a `/tmp/agent-*/<repo>/` directory cloned from a local canonical clone for isolation), the `origin` remote points at the LOCAL canonical clone path, NOT at GitHub. `git push origin` writes to the local clone's branch ref but does not propagate to GitHub.

## The pattern

For every shallow-clone worker that creates commits:

1. Add `github` as a named remote in the shallow clone, pointing at the GitHub HTTPS URL:

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

When this gap is caught after the fact, the file-based remote's branch tip is the source of truth for the work done. Push it to GitHub from inside the shallow clone via the `github` remote, or from the canonical clone using `git push origin <branch>` if the canonical's `origin` is GitHub.

## Pairs with

- Build-time source-cache staleness — same family of file-based-remote silent absorption (`references/build-source-staleness.md`).
- Worker isolation via shallow clones — the shallow-clone pattern itself is the right isolation choice; the verification step is the gap to close.
