# Extension Points, Worked

One YAML example per extension point. Each example marked **Verified** ran against the Vale 3.18.0 binary during authoring, against a fixture built for that example. The result is described alongside it. Each example marked **Documented, untested** comes from Vale's own documentation (`docs.vale.sh/checks/<name>`). It did not run against a fixture in this session. The syntax is accurate to the source, but no local run confirmed its firing behavior.

## existence

Flags a fixed list of tokens. Abridged from this repo's `styles/Strict/HedgedDirective.yml` — the shipped file lists six tokens and a `link:` field:

```yaml
extends: existence
message: "'%s' hedges an instruction — state the directive plainly."
level: warning
ignorecase: true
tokens:
  - should probably
  - you may want to
  - you might want to
```

**Verified**: a fixture line reading "You should probably check the config before running" produced this finding: `'should probably' hedges an instruction`, at the matched column.

## substitution

Flags a token and names its replacement in the same rule. Abridged from this repo's `styles/Flavored/Clutter.yml` — the shipped file carries eleven swaps:

```yaml
extends: substitution
message: "Use '%s' instead of '%s'."
level: error
ignorecase: true
swap:
  "in order to": to
  "prior to": before
```

**Verified** by positive control, not by a clean run: a file containing `in order to` produces a `Flavored.Clutter` error and exits 1. A clean CI run alone would prove nothing here, since a typo in a swap key also yields no findings.

## occurrence

Caps how many times a pattern appears within a scope — most often a sentence, for a word-count cap. Abridged from this repo's `styles/Strict/SentenceLength.yml` — the shipped file also sets `ignorecase: false`:

```yaml
extends: occurrence
message: "Sentence runs past the 25-word cap for description text — split it."
level: warning
scope: sentence
max: 25
token: '\b\w+\b'
```

**Verified**: `occurrence` with `token: '\b\w+\b'` counts words per sentence; a sentence at or under the `max` produces no finding, one over it does. This rule gates the sentence-length discipline this skill's own files follow.

## repetition

Catches a word repeated back to back — "the the," "and and."

```yaml
extends: repetition
message: "'%s' is repeated."
level: error
alpha: true
tokens:
  - '\w+'
```

**Verified**: against the fixture "cat cat sat on the the mat," the rule reported both `'cat' is repeated` and `'the' is repeated`. Each finding matched its own span. Vale's own documented example token (`'[^s.!?]+'`) did not reproduce a finding in this session's fixture. `'\w+'` did, so this reference keeps the form that measurably worked.

## consistency

Forces one spelling of a term pair across the document set.

```yaml
extends: consistency
message: "Inconsistent spelling of '%s'."
level: error
ignorecase: true
either:
  advisor: adviser
```

**Verified**: against a fixture using both "advisor" and "adviser" in the same file, this rule flagged the second-seen variant ("adviser") once, at its position.

## conditional

Requires a second pattern wherever a first pattern appears — the standard use is "flag an acronym with no defined expansion nearby."

```yaml
extends: conditional
message: "'%s' has no definition"
level: error
first: '\b([A-Z]{3,5})\b'
second: '(?:\b[A-Z][a-z]+ )+\(([A-Z]{3,5})\)'
exceptions:
  - ABC
```

**Documented, untested.** Source: `docs.vale.sh/checks/conditional`.

## capitalization

Enforces a heading-case convention.

```yaml
extends: capitalization
message: "'%s' should be in sentence case"
level: warning
scope: heading
match: $sentence
```

**Verified**: against a fixture with one title-case heading and one sentence-case heading, only the title-case heading fired.

## metric

Gates on a computed formula over the whole document, most often a readability score.

```yaml
extends: metric
message: 'Keep the Flesch-Kincaid grade level (%s) below 8.'
formula: |
  (0.39 * (words / sentences)) + (11.8 * (syllables / words)) - 15.59
condition: '> 8.0'
```

**Documented, untested.** Source: `docs.vale.sh/checks/metric`. Note the `condition` value needs a decimal (`8.0`, not `8`) per the same source.

## spelling

Checks tokens against a dictionary, with optional custom dictionaries and ignore filters.

```yaml
extends: spelling
message: "'%s' is a typo!"
level: error
custom: true
dictionaries:
  - en_US
filters:
  - '[pP]y.*\b'
```

**Documented, untested.** Source: `docs.vale.sh/checks/spelling`.

## sequence

Matches a sequence of tokens by part-of-speech tag, the only extension able to see grammar rather than raw text. A passive-voice detector:

```yaml
extends: sequence
message: "Possible passive voice — rewrite in active voice."
level: warning
ignorecase: true
tokens:
  - pattern: (is|are|was|were|be|been|being)
  - tag: VBN
```

**Verified**: two fixture sentences, one passive ("The file was deleted by the script.") and one active ("The script deletes the file."). Only the passive sentence fired, matching the words was deleted. A regex `existence` rule matching the literal word "was" would flag both sentences, since "was" also turns up in ordinary non-passive prose. `sequence`'s POS tag requirement (`VBN`, a past participle) is what tells the two apart.

## script

Runs a custom Tengo script for checks no built-in extension covers.

```yaml
extends: script
message: 'Consider a section heading here.'
scope: raw
script: MyScript.tengo
```

**Documented, untested.** Source: `docs.vale.sh/checks/script`. The script file lives at `$StylesPath/config/scripts` and must populate a `matches` array of `{begin, end}` spans.
