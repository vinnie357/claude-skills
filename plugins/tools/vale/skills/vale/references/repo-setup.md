# Repo Setup

How this repository wires Vale end to end: the pin, the config, the two style directories, the mise task, and CI.

## The pin

```toml
# mise.toml
[tools]
vale = "3.18.0"  # Prose linter, pinned — rule semantics shift between minors and CI would absorb it silently (claude-skills-306)
```

`vale` is pinned to an exact patch version, not a fuzzy `3` or `latest`. A tool bump is now a deliberate, reviewed diff to this one line. It runs through `mise install` and `mise run test` before merge. It is not a silent behavior change picked up by whichever runner happens to install the newest release that week.

## `.vale.ini`

```ini
# Prose gate for this marketplace (claude-skills-306).
#
# Two registers, per /core:technical-english:
#   Strict   — procedural text a reader acts on. Agent definitions, slash
#              commands, ADR decisions. Ambiguity here changes behaviour.
#   Flavored — explanatory prose a human reads for understanding. Skill
#              bodies, references, READMEs. Voice earns its place.
#
# A rule ships at `warning` while its findings burn down, then moves to
# `error` once it reaches zero — per rule, not as one flag day. Only `error`
# exits non-zero. Clutter is already at zero and gates today; the rest report.
# Burn-down is tracked as claude-skills-307.
StylesPath = styles
MinAlertLevel = warning

[*.md]
BasedOnStyles = Flavored

# Procedural surfaces take the strict register. Vale's section globs let `*`
# cross `/`, so one pattern covers every nesting depth — plugins/core/agents/
# and plugins/tools/github/skills/pr-review/agents/ alike. Verified against
# the real tree; a `plugins/*/*/agents/*.md` twin would be dead config.
[plugins/*/agents/*.md]
BasedOnStyles = Flavored, Strict

[plugins/*/commands/*.md]
BasedOnStyles = Flavored, Strict
```

Every Markdown file in the repo matches `[*.md]` and gets the `Flavored` style. A file under a `plugins/<any>/agents/` or `plugins/<any>/commands/` directory, at any depth, matches a later section too.

That later section wins outright: Vale takes the last matching section's `BasedOnStyles` and discards the earlier one. Two sections with different globs never merge. Only a repeated identical glob accumulates styles. A strict-scoped file keeps its flavored findings — clutter, superlatives, weak qualifiers — only because those sections spell out `Flavored, Strict`. Writing `Strict` alone there would silently drop every flavored rule from exactly the files held to the tightest standard.

## The two style directories

```
styles/
├── Strict/
│   ├── SentenceLength.yml     # occurrence — 25-word cap on description sentences
│   ├── HedgedDirective.yml    # existence  — flags hedge phrases in instructions
│   └── Nominalization.yml     # substitution — verb over noun-phrase
└── Flavored/
    ├── Superlatives.yml       # existence  — banned unverified superlatives
    ├── Clutter.yml            # substitution — wordy phrase → plain word, at error
    └── Qualifiers.yml         # existence  — weak qualifier words, `rather` excluded
```

`StylesPath = styles` tells Vale to treat each subdirectory here as one named style; `Strict.HedgedDirective` and `Flavored.Clutter` in a finding's check name are `<StyleDir>.<RuleFile-without-extension>`.

## The mise task

```toml
[tasks."test:prose"]
description = "Prose gate: Vale, two registers (strict for agents/commands, flavored elsewhere)"
run = """
nu -c '
  let files = (
    git ls-files "*.md"
    | lines
    | where {|f| ($f | path exists) and (($f | path expand) == ($f | path expand --no-symlink)) }
  )
  if ($files | is-empty) { print "no markdown files"; exit 0 }
  vale --no-exit --output=line ...$files
  let gate = (vale --minAlertLevel error --output=JSON ...$files | complete)
  if $gate.exit_code != 0 {
    print $"(ansi red_bold)Prose gate failed: error-level findings above.(ansi reset)"
    exit 1
  }
'
"""
```

Three things this task does deliberately:

1. **Filters out symlinks.** `AGENTS.md` is a symlink to `CLAUDE.md`. `git ls-files` lists both paths. Without the filter, Vale would scan the same bytes under two names, double-counting every finding in that file. The `path expand` vs `path expand --no-symlink` comparison drops the symlink and keeps the real file.
2. **Runs `vale` twice on purpose.** The first run, with `--no-exit`, prints every finding at every level. A human reading the CI log sees the full picture, warnings included. The second run, filtered to `--minAlertLevel error`, decides pass or fail. One run alone would either hide warnings from the log, or let a warning-level finding block the merge.
3. **Captures the gate run's exit code explicitly.** `| ignore` discards the exit code along with the piped output. Verified: `nu -c '^false | ignore; print "reached"'` prints "reached" and exits `0`. The task instead wraps the second `vale` call in `| complete`, then reads `$gate.exit_code` and re-raises it with an explicit `exit 1`. That is the only path that keeps a real error-level finding failing the build.

`test:prose` is one dependency of the aggregate `[tasks.test]` in `mise.toml`. `[tasks.test]` is itself the one dependency of `[tasks.ci]`. `mise run ci` runs it along with every other repo-wide check.

## CI

The repository's GitHub Actions workflow, `.github/workflows/validate.yml`, runs `mise run test` in its marketplace-validation job. That job pulls in `test:prose` through the dependency chain above. There is no separate "run vale" step naming the task directly. A contributor confirms the gate locally with `mise run ci` before pushing, matching what CI runs.
