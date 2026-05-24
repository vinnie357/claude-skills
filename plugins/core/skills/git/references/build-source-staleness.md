# Build chains and local-cache staleness

Build workflows that clone from a local source cache (`file:///<path>/<repo>` rather than GitHub) read whatever HEAD the local working tree currently points at. `git fetch origin` advances only remote-tracking refs (`refs/remotes/origin/main`); the local checkout's HEAD does not move.

A worker that runs `git fetch origin && git rev-parse origin/main` confirms remote knowledge of the target commit but does NOT confirm the local working tree contains it. The build clones from the local working tree and produces a binary built from the prior HEAD.

## The pattern

Before submitting any build workflow that reads from a local source cache:

```bash
cd /<path>/<repo>
git fetch origin             # updates remote-tracking refs
git pull origin <branch>     # advances the LOCAL checkout — required
git rev-parse HEAD           # must equal the expected build sha
```

`git rev-parse origin/<branch>` is INSUFFICIENT proof. The local HEAD is what the build sees.

## How to apply

- Worker prompts for deploy chains include a `git pull origin <branch>` step before any build submit call.
- Pre-flight sha confirmation compares `git rev-parse HEAD` (local), not `git rev-parse origin/<branch>` (remote-tracking).
- After any new commit lands on the target branch, the first deploy-dispatch step is "pull <branch> on the local source cache".

## Pairs with

- `references/shallow-clone-remotes.md` — sibling stale-cache class. Both come from file-based git interactions silently absorbing operations that should reach (or read from) GitHub.
