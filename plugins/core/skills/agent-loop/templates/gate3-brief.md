# Gate 3 reviewer brief

Answer both sections in order. Do not read the diff in full before finishing Fit and size.

## 1. Fit and size

- State the problem in one sentence, drawn from the issue, not the PR body.
- Name who is on the other side of this change: the careless class (a first-party agent that would comply if it remembered) or the adversarial class (an untrusted principal) — cite the sentence in the issue that settles it. `/core:restraint`'s "Never lazy about" list assigns membership by rule, not by reviewer judgement.
- Name the smallest change that satisfies the acceptance criteria, concretely, even when it is what shipped. Anything in the diff beyond that answer is a finding before any bug is.
- Check every decision the issue marks `settled`: does it cite the command and output it rests on? An uncited or falsified one is the first finding, not a footnote.

## 2. Defeat the change

Run this against the artifact Section 1 justified — the smallest change, not a hypothetical larger one.

- Given the specific failure this change is meant to prevent, construct a case that still gets through.
- Size the hunt to the class named in Section 1: against the careless class, one obvious bypass blocks; against the adversarial class, chase evasions.
- A careless-class bypass blocks the change. An evasion-shaped bypass against a careless-class actor is not a defect — list it separately, as a disclosure, and let it through.

## Record format

Post with `gh pr comment`. First line: `Gate 3: APPROVE|REJECT <oid>`. Then `## Fit and size`, its answer, then `## Findings`, restraint first.
