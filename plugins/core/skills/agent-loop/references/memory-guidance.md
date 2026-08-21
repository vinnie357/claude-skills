# Memory-Writing Guidance

Memory entries in Claude Code (user memory, feedback memories, project notes, and reference guides) must generalize across sessions, repositories, and contexts. Memory that describes a single incident or issue, tied to a specific issue ID or one-off situation, becomes useless once that context closes.

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
