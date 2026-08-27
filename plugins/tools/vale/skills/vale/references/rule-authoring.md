# Rule Authoring

## A rule is only as good as its false-positive rate

The first `Qualifiers` rule in this repo listed `rather` among its watched words. Run against the repo's corpus, it produced 227 findings. 156 of those, most of the total, were the word `rather` inside the phrase `rather than`. That is a legitimate construction, not a qualifier in the sense the rule intended to catch. Dropping `rather` from the token list left 69 findings, all real.

`styles/Flavored/Qualifiers.yml` carries the fix and the finding as a comment:

```yaml
# "rather" is deliberately absent: 156 of 227 corpus hits were "rather than",
# a legitimate construction and not a qualifier. A rule whose most frequent
# match is a false positive teaches authors to ignore the gate.
extends: existence
message: "'%s' weakens the sentence without adding information — cut it."
level: warning
ignorecase: true
tokens:
  - very
  - quite
  - fairly
  - somewhat
  - really
  - basically
  - actually
  - simply
```

Take the lesson generally. Before shipping a new `existence`, `substitution`, or `occurrence` rule, run it against the real corpus. Read every match, not a sample. A rule whose most frequent match is a false positive does not just waste one review cycle. It teaches every author who hits it that the gate cries wolf. The next real finding from the same rule gets the same dismissal.

## A document that teaches a rule will trip it

`plugins/core/skills/anti-fabrication/SKILL.md`'s banned-superlative list and `plugins/core/skills/technical-english/references/flavored-prose.md`'s clutter-phrase examples are rule definitions written in prose. Both name, as examples, the exact words their corresponding Vale rules watch for. Vale flags them, correctly — the rule is doing its job; the text does contain the banned token.

The right fix there is inline suppression, not a rewrite that dodges the linter by paraphrasing the banned word out of its own definition:

```markdown
<!-- vale Flavored.Clutter = NO -->
"In order to" means "to." "At this point in time" means "now."
<!-- vale Flavored.Clutter = YES -->
```

Without the suppression, a rule like `Flavored.Clutter` can never reach zero findings on this corpus. A rule that never reaches zero can never promote from `warning` to `error`. Recognize this case with one question: does the flagged text state the bad pattern as a fact? Or does it use the bad pattern as its own prose? A definition does the former. Ordinary writing that happens to contain a banned word does the latter, and needs a real edit, not a suppression comment.

## Scoping a new rule

Default scope is the whole raw file, frontmatter included — verified in `SKILL.md`'s Scopes section. Before writing a new rule, decide on purpose whether that default is right:

- A rule about prose quality (hedging, clutter, sentence length) usually wants the default scope. Bad prose in a frontmatter `description` is still bad prose.
- A rule for one structured field only — a length cap on a `description`, a format check on a `name` — wants `text.frontmatter.<field>`. Otherwise it fires on unrelated fields and the body too.
- A rule about heading style wants `scope: heading`, not the default. Otherwise every non-heading sentence resembling a heading becomes a false match.

Getting the scope wrong reads downstream exactly like a false-positive rate problem. Decide it deliberately, rather than accepting whatever a copied example happened to set.

## Testing a rule before it ships

Run the exact binary CI runs, not a different local install, against a fixture built for the new rule:

```bash
mise exec -- vale --output=line path/to/fixture.md
```

Build two fixtures at minimum: one that should fire the rule, one that resembles it closely but should not. A rule tested only against the positive case has an unmeasured false-positive rate by definition. The `rather`/`rather than` case above is exactly that gap. It surfaced only because someone ran the rule against the full corpus, not a single crafted example.

`--output=JSON` gives the full match span and severity when `--output=line` is ambiguous. Test the rule at every level it might ship at. A rule destined for `error` should also get one run with `--minAlertLevel error`. That confirms the exit code a CI gate would see, not just what the printed findings show.
