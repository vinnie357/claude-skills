# Memory-Writing Guidance

Memory entries in Claude Code (user memory, feedback memories, and reference guides) must generalize across sessions, repositories, and contexts. Memory that describes a single incident or issue, tied to a specific issue ID or one-off situation, becomes useless once that context closes.

**The Rule:** Write memory that answers "what should I remember for future work?" not "what happened in this past incident?" A memory entry should apply to the next session, the next repository, and the next person picking up similar work.

**One-line rationale:** Incident-specific memory silently becomes dead knowledge once the issue closes; generalizable memory compounds in value across every future session.

## Good vs. Bad Examples

### Example 1: Test Assertion Validation

**Bad:** "VIN-201 failed because the mock returned nil and the test didn't distinguish it from a real call—double-check mocks in future feedback-skill work."

- Why it's bad: Tied to one closed issue; only makes sense to someone who worked that specific ticket.
- Next session: "feedback-skill work?" Could refer to any number of issues. Useless.
- Other repos: Doesn't apply—no feedback-skill exists elsewhere.

**Good:** "When a test asserts on a value that could plausibly come from either the mock or the real system, verify which source produced it before trusting the assertion. Use spy/recorder calls or env-var markers to confirm the mock was invoked."

- Why it's good: Applies to any future test suite, any repo, any mock-based unit test.
- Generalizable pattern: Tells the reader what to do without naming the incident.
- Reusable: Next session, other repos, other team members all benefit immediately.

### Example 2: Configuration Defaults

**Bad:** "In issue VIN-145, forgot to check what the default was in the config file before adding a new field—cost 20 minutes of debugging."

- Why it's bad: Describes a person's mistake in one incident; not actionable for future work.
- Next session: Vague guidance that doesn't prevent similar oversights.

**Good:** "Before adding a new configuration option, read the existing config file defaults and environment overrides at the point where the config is loaded. Check if a parent config or global defaults already define it. Document the precedence chain (env var → local config → defaults) in the code comment."

- Why it's good: Prescriptive and generalizable; applies to every future config change.
- Prevents the pattern: Clear steps to follow, not a cautionary tale.

### Example 3: Dependency Version Constraints

**Bad:** "VIN-202 broke because Nushell 0.97.0 changed the parse-date syntax. Upgrade our Nushell carefully next time."

- Why it's bad: Describes one version bump; won't apply to future changes (Nushell version, different tool).
- Single-issue context: Only matters if you're upgrading Nushell, and only if you remember this note.

**Good:** "When upgrading a scripting-language version (Nushell, Python, Node, etc.), check the changelog for breaking changes in built-in commands and functions before upgrading. Run the full test suite (`mise run ci`) with the new version on a feature branch, and test the specific commands the project uses most heavily."

- Why it's good: Applies to any language upgrade, any future session.
- Actionable: Gives specific steps—changelog, test suite, heavy-use commands.
- Durable: Remains relevant as tools evolve.

### Example 4: Merge Gotchas

**Bad:** "VIN-203 PR #XYZ took 4 hours to merge because GitHub's API cache was stale. Remember to double-check the PR status page on the web UI before merging."

- Why it's bad: GitHub API caching is an infrastructure detail, not a reproducible pattern.
- Doesn't generalize: Workaround for one flaky API call in one point-in-time.

**Good:** "Before applying a force-push or merging a stacked PR, verify the PR state through multiple channels: check the web UI, run `gh pr view <N> --json state,mergedAt`, and confirm the git branches match expected commits. API clients and dashboards can report stale state; cross-checking catches divergence before the merge lands."

- Why it's good: Applies to any GitHub workflow, any PR structure.
- Defensive: Prevents silent merge state mismatches.
- Reusable: Multiple sessions, multiple projects, multiple operators.

## When to Record Memory

Record memory when you discover:
- A pattern that appears in multiple places (test isolation, config precedence, dependency resolution)
- A verification step that should become routine (cross-check before merge, run full CI before commit)
- A gotcha or failure mode that could recur (stale API state, enum validation missing, race condition on concurrent writes)
- A tool's actual behavior that differs from its documentation or your intuition

**Skip recording memory for:**
- One-off incident details ("VIN-XYZ broke because...")
- Closed-issue-specific workarounds
- Context that only makes sense to one person or one repository
- Observations that are already captured in the codebase (ADRs, comments, documentation)

## Anti-Pattern: Issue ID as a Memory Anchor

The most common memory-writing mistake is anchoring to an issue ID or epic number:

- ❌ "When using VIN-204, remember to..."
- ❌ "In VIN-205, the problem was..."
- ❌ "After working feature/auth-redesign, always check..."

Replace these with generalizable context:

- ✅ "When writing reference documentation for a skill, distinguish between incident-specific observations and durable patterns before committing to memory."
- ✅ "When debugging async test isolation, check for shared mutable state (Application.put_env, Process.put) leaking across test cases."
- ✅ "After a multi-file refactor, re-run the full test suite with max concurrency to catch race conditions that single-threaded test runs miss."

## Benefits of Generalizable Memory

**Across time:** A memory written in Session 1 remains actionable in Session 10, even though Session 1's specific work is long closed.

**Across team:** A memory written by one person helps the next person working the same class of problem, without requiring them to re-read the closed issue.

**Across repos:** A pattern discovered in one repository (e.g., Elixir test isolation) applies to another repository using the same stack.

**Across tools:** A verification step discovered with GitHub (PR state mismatch) generalizes to other version-control systems and APIs.

## How to Audit Existing Memory

When reviewing or updating memory entries:

1. **Is this issue-specific?** If the entry names an issue ID or PR number, check whether the pattern remains relevant after that issue closes.
2. **Would the next person understand this?** Remove insider references; spell out the pattern so someone unfamiliar with the context can apply it.
3. **Does it apply to other work?** If only one class of changes or one repository would benefit, generalize it or merge it into broader guidance.
4. **Is it already documented elsewhere?** If an ADR or skill already covers this, don't duplicate it in memory—link instead.

These four questions cover generalizability at write time. They say nothing about an entry
that was generalizable when written and has since decayed — the referent it names moved, or
the rule it stated got reversed. Decay is a separate failure mode from the four above, and it
needs its own pass, covered below.

## The Work-vs-Fact Boundary

Memory is not a second issue tracker, and repo-scoped content is not automatically
tracker-bound either. Two different questions get conflated here; keep them apart.

**A work item never lives in memory.** Live work — something still to be done, something
in progress, something waiting on a decision — belongs in the tracker: bees for local
tracking, an epic for cross-session or cross-repo tracking. A memory file describing an
open task is not a durable fact; it is a tracker row that escaped its tracker. When work
closes, its bees/epic row records that outcome — memory does not need a second copy, and a
closed-but-still-asserted item ("RESOLVED 2026-07-28") is dead weight, not a fact.

A durable fact does not stop being a fact because it narrates a closed incident as evidence
for a rule that still applies — the discriminator is whether removing the closure sentence
leaves a transferable rule behind. Only an entry whose entire content IS the closure status
is dead weight.

**A durable fact stays in memory even when it names a specific repo.** The discriminator is
work-vs-fact, not project-scoped-vs-general. "This repo is on a private GitHub remote, so
the mise github backend needs `GITHUB_TOKEN` or `ls-remote` returns empty" names one repo by
name and is exactly the kind of thing memory exists for — it will bite again, unchanged, the
next time any session touches that repo. A gotcha, a tool's undocumented behavior, or a
one-time environment fact does not stop being durable because it is scoped to one place.

Do not read "work-vs-fact" as "repo-mentioning entries get deleted." That naive reading
destroys exactly the gotchas this section means to protect, and is the mistake this
paragraph exists to head off. Ask which question applies: is this something still
to be *done* (tracker), or something now *known* (memory) — regardless of how narrow its
scope is?

**Retire the `project` metadata type.** It invited the naive reading above by suggesting
"about a project" was itself the classification. Valid `metadata.type` values are now
`user`, `feedback`, and `reference`. A repo-scoped durable fact is typed `reference`, the
same as any other lookup-style fact — its scope is in the body text, not the type.

## Decay Checks

The four audit questions above judge an entry against the moment it was written. An entry
that passed them can still decay afterward — the world it described moved on. Run these five
checks against existing memory; each names whether it is mechanical (a command settles it) or
a judgment call.

1. **Superseded or self-reversing content — judgment to rewrite, mechanical to flag.** Grep
   for `REVERSED`, `RESOLVED`, `no longer`, or a second date superseding the first. An entry
   carrying one of these markers is storing its own history instead of stating the current
   rule. Detection is a grep; producing the corrected, single-current-rule text is a judgment
   call — decide what the rule now says, not what it used to say. **Precedence:** an entry
   that carries one of these markers AND also reads as dead work under the work-vs-fact
   boundary is a rewrite candidate, not a delete candidate — this check wins the tiebreak,
   because rewriting preserves whatever durable half the entry still carries and deleting
   does not. **Exception:** if the rewrite would leave no durable content — nothing
   transferable once the marker and its closure narration are stripped — the entry is a
   delete, not a rewrite, and takes the dead-work evidence requirement (closure verification)
   before deletion.
2. **Stale referent — mechanical.** The entry names a file, function, flag, or command.
   Grep the repo it names for that exact symbol. A miss means either the referent moved (fix
   the name) or the referent is gone (the entry may be dead). Confirm the grep ran against the
   right repo before trusting a miss — an empty result from the wrong directory is not
   evidence of anything.
3. **Fragmentation — judgment.** Several entries cover one topic that a single recall should
   surface together (five separate `mise_*` files is the shape to watch for). No command
   detects this; it takes reading the index and noticing the topic split. Propose a merge
   rather than applying one — merging loses the operator's original wording, and that loss is
   a decision for the operator, not the auditor.
4. **Index-file drift — mechanical to detect, but the two directions are not symmetric to
   fix.** Every file in the memory directory has exactly one line in the index; every index
   line points at a file that exists. `diff` the file listing against the index to catch both
   directions. A dangling index line — no backing file — is judgment-free: delete the line.
   An orphaned file — exists on disk, no index line — is NOT safe to delete on sight: the
   write-then-append convention (write the file, then append its index line) means a session
   that dies between those two steps leaves a valid, unindexed entry, and deleting it destroys
   good content over a bookkeeping race. Route an orphaned file through the same content
   evaluation as any other entry; the default disposition for a well-formed one is to
   re-index it, not to delete it.
5. **Shape violations — mechanical to detect.** Missing YAML frontmatter, a `feedback`-typed
   entry missing its `**Why:**` or `**How to apply:**` lines, a relative date ("yesterday",
   "last week") never converted to absolute, or a file that reads as a multi-topic document
   rather than one fact — the multi-topic case routes to the propose-only split path (decay
   check 3), never an autonomous rewrite. Each other case is a grep or a line-count check
   against the frontmatter schema this skill's memory instructions define.
