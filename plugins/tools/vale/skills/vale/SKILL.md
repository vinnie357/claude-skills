---
name: vale
description: Guide for Vale prose linting — the eleven extension points, .vale.ini scoping and section globs, alert-level burn-down, and suppression comments. Use when authoring or editing a Vale style rule, debugging a prose-lint false positive, or choosing which extension point fits a new rule. Use when wiring a section glob in .vale.ini or scoping a rule to one frontmatter field.
license: MIT
---

# Vale

Vale is a command-line prose linter. It applies declarative YAML rules to Markdown, checking word choice, sentence shape, and terminology. It works the way a compiler checks syntax — deterministically, on every run, without a human rereading the diff.

## When to reach for it

Reach for Vale when a team wants a style rule enforced in CI, not just repeated in review comments. Typical rules: banned words, hedged directives, sentence-length caps, terminology consistency, passive-voice detection. A rule written once as a Vale style runs on every PR. A rule stated only in a CLAUDE.md runs only when a reviewer remembers it.

## Install and pin

```toml
# mise.toml
[tools]
vale = "3.18.0"
```

```bash
mise install
mise exec -- vale --version   # vale version 3.18.0
```

`vale` is a mise registry short name; the pin needs no backend prefix. It resolves to `aqua:vale-cli/vale` — confirm with `mise registry | grep '^vale'`.

Pin the exact version, not `latest`. Rule semantics shift between Vale minor releases — a new default, a changed regex engine, an added extension point. An unpinned `latest` lets CI absorb that drift silently. A pinned version fails loudly on `mise install` instead, at the moment someone chooses to bump it.

## The eleven extension points

Every Vale rule extends exactly one of these. Pick the point by what the rule needs to see, not by habit.

| Extension | Fits |
|---|---|
| `existence` | Flag a fixed list of banned or watched tokens |
| `substitution` | Flag a token and suggest its replacement |
| `occurrence` | Cap how many times a pattern appears in a scope |
| `repetition` | Catch an immediate word repeated back to back |
| `consistency` | Force one spelling of a term across the whole document set |
| `conditional` | Require a second pattern wherever a first pattern appears |
| `capitalization` | Enforce a heading or title case convention |
| `metric` | Gate on a computed formula, such as a readability score |
| `spelling` | Check against a dictionary, with custom word lists |
| `sequence` | Match a sequence of tokens by part-of-speech tag |
| `script` | Run a custom Tengo script for logic no built-in extension covers |

`sequence` is the one extension able to see grammar, not just characters. It matches part-of-speech tags — a verb, a determiner, a past participle. That is what lets it catch passive voice ("the file was deleted") without flagging every unrelated use of the word was. A regex-based `existence` rule only sees text, not grammar.

## Scopes

A rule's `scope` field controls what part of the document it reads. The default scope is the whole raw file, and that includes YAML frontmatter. A plain `existence` rule with no `scope` set flags a banned word inside a `description:` field exactly as it would flag one in the body.

`text.frontmatter.<field>` narrows a rule to one named frontmatter field only, ignoring the body and every other field. Use it for a check that only makes sense on one field, such as a length cap on a skill's `description`. It does not also cap every heading in the file.

Fenced code blocks are skipped by default under the standard Markdown scope. A rule that must reach inside a fence needs an explicit `scope: raw`.

## Alert levels — the burn-down mechanism

Each rule sets a `level` of `suggestion`, `warning`, or `error`. Only `error` findings make `vale`'s process exit non-zero. `warning` and `suggestion` findings print but never fail a run.

That gap is the intended mechanism, not a defect to close immediately. Ship a new rule at `warning` while its findings burn down across the existing corpus. Promote it to `error` once the count reaches zero. A rule that lands at `error` on day one either fails every open PR at once, or gets disabled outright.

## `.vale.ini` structure and section globs

```ini
StylesPath = styles
MinAlertLevel = warning

[*.md]
BasedOnStyles = Flavored

[plugins/*/agents/*.md]
BasedOnStyles = Flavored, Strict
```

`StylesPath` points at the directory holding one subdirectory per style — `Strict/` and `Flavored/` here. Each `[glob]` section maps a path pattern to the styles active for matching files.

**Verified**: two sections with **different** globs do not merge. When a file matches both, the **last matching section wins wholesale** — not the most specific one. A third overlapping section does not change that; the last one still wins. Repeating the **same** glob string is the one exception: those styles accumulate. Two style sets in separate sections gave a deeper file only the later section's findings. Flipping the section order flipped which one applied. So a section that lists one style silently drops every other style from those files. That is why this repo's strict sections list `Flavored, Strict` rather than `Strict` alone.

**Verified**: a `*` in a Vale section glob crosses `/`. `plugins/*/agents/*.md` matches both `plugins/aaa/agents/x.md` and a file three levels deeper, `plugins/aaa/bbb/ccc/agents/x.md`. Fixtures at each depth, tested directly against the Vale binary, both flagged by the same section. A second, more specific pattern written to catch deeper nesting is dead configuration — the shallow glob already covers it.

## Suppression

```markdown
<!-- vale Flavored.Clutter = NO -->
"In order to" means "to." "At this point in time" means "now."
<!-- vale Flavored.Clutter = YES -->
```

Suppress a rule only where there is nothing to fix. The most common case is a document that teaches the rule by naming the exact words it bans. A banned-word list trips its own rule on every listed example, and so does a clutter-phrase table. That is correct, not a bug — rewriting the examples to dodge the linter would make them useless as examples. Reach for suppression there, never as a shortcut past a real finding elsewhere in the same file.

## Running it

```bash
mise run test:prose
```

The task runs `vale` once to print every finding at any level. It runs `vale` a second time, with `--minAlertLevel error`, to decide the gate. Piping either run to `| ignore` in Nushell discards the exit code along with the output. Verified: `nu -c '^false | ignore; print "reached"'` prints and still exits `0`. The shipped task avoids this trap. It captures the second run with `complete` and re-raises `$gate.exit_code` itself, so a real error finding still fails the build.

## Anti-fabrication

Every claim this skill makes about Vale's behavior comes from running the Vale binary against a fixture and reading its output. It does not come from documentation alone, or from memory. A reference claim can stay undemonstrated when no fixture ran against that extension point. The note there says so, rather than claiming the syntax as tested. Follow `/core:anti-fabrication` for the full rule set this inherits.

## References

- [references/extension-points.md](references/extension-points.md) — a worked YAML example for each of the eleven extension points
- [references/rule-authoring.md](references/rule-authoring.md) — the false-positive discipline, scoping a new rule, and testing it before it ships
- [references/repo-setup.md](references/repo-setup.md) — how this repo wires the pin, `.vale.ini`, the two style directories, the mise task, and CI end to end
