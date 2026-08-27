# Strict-Mode Rules — Worked Examples

Each rule below carries a before/after pair. Seven pairs cite a real repo line, verified by reading the file. The other five use a constructed example, since no repo line failed that specific rule.

## 1. One term, one meaning

A document set that lets "check," "test," and "gate" drift into synonyms forces the reader to guess which one is load-bearing.

```
Before: Run the check, then verify the test passes before the gate opens.
After:  Run the check. Confirm the check passes before the gate opens.
```

## 2. Active voice for instructions

```
Before: The branch should be created by the author before work starts.
After:  Create the branch before work starts.
```

## 3. Passive voice only when the actor is unknown

`plugins/core/skills/code-review/SKILL.md:48` names no actor for a claim about the code itself. The actor — the code — is known, so passive voice hides information the sentence could state directly.

```
Before: Authentication and authorization are properly implemented.
After:  The code authenticates and authorizes every request.
```

## 4. Simple tenses only

A question is not one of the five simple tenses, and it turns a checklist item into something the reader must answer instead of verify. `plugins/core/skills/code-review/SKILL.md:101` phrases a checklist row as a question.

```
Before: Is the code properly tested?
After:  Test the code.
```

## 5. One instruction per sentence

`plugins/core/skills/agent-loop/SKILL.md:355` carries three separate claims — a stage-gate change, a retry-ladder change, and a loop-bound change — inside one 57-word sentence.

```
Before: [...] the adversarial separation and stage gates [...] become deterministic
        script assertions, model escalation becomes a retry ladder, and the
        validator↔fix iteration becomes a bounded loop.
After:  Stage gates become deterministic script assertions. Model escalation becomes
        a retry ladder. The validator-fix loop becomes bounded. Three changes,
        three sentences.
```

## 6. Sentence-length caps

`plugins/core/skills/agent-loop/SKILL.md:3` — the skill description's second sentence runs 69 words and lists eight trigger conditions in one breath.

```
Before: Use when coordinating any feature delivery, working an issue or epic
        [...], picking up an epic in a fresh session [...] or with
        pre-existing issues [...], implementing a multi-step task that benefits
        from plan→test→implement→review phases, asking clarifying questions
        before decomposing, forming a team and assigning models per tier, or
        orchestrating multi-agent workflows.
After:  Use when coordinating feature delivery, or working an issue or epic.
        Use when picking up an epic fresh or with pre-existing issues.
        Use for a multi-step task that benefits from plan-test-implement-review
        phases. Use when forming a team, assigning models, or asking
        clarifying questions before decomposing.
```

Longest rewritten sentence: 26 words — inside the descriptive cap, and none carries more than one topic.

## 7. Paragraph length and topic

```
Before: The picker claims the epic. It writes agent_label. It dispatches to
        the local Runex. Runex reports the run id back. The dashboard
        polls the run id. The dashboard renders a status badge. The badge
        color maps to run state. Green means complete.
After:  The picker claims the epic, writes agent_label, and dispatches to the
        local Runex, which reports a run id back.

        The dashboard polls that run id and renders a status badge whose
        color maps to run state; green means complete.
```

## 8. Never drop the article, subject, or verb

`plugins/core/skills/security/SKILL.md:47` opens with a dropped subject — the sentence never says who observed the behavior.

```
Before: Observed on macOS 26.6, against a mise-installed binary: ps -E output
        grew from an 11-word baseline to 105 words.
After:  A tester observed this on macOS 26.6, against a mise-installed binary:
        ps -E output grew from an 11-word baseline to 105 words.
```

## 9. Warnings precede the step

`plugins/core/skills/security/SKILL.md:45` already follows this rule: "Do not run these commands to check whether they leak" appears immediately before the command table it governs, not after. No rewrite needed — cite it as the model to copy, not a defect to fix.

## 10. Short word, concrete noun, verb over nominalization

```
Before: Perform the implementation of the retry logic.
After:  Implement the retry logic.
```

## 11. Delete restating qualifiers and adverbs

`plugins/core/skills/documentation/SKILL.md:299` pairs a checklist item with an adverb that restates nothing measurable — "actually" adds no information "work" did not already carry.

```
Before: Ensure examples actually work.
After:  Run each example. Confirm it produces the documented output.
```

## 12. Reread once after drafting

```
Before: In terms of the way that the validator generally tends to
        operate, it is the case that it will check for the
        presence of a description field.
After:  The validator checks for a description field.
```
