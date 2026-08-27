# Flavored Prose

Flavored mode governs explanatory writing: SKILL.md context sections, references, READMEs, ADR rationale, and PR bodies. It borrows its shape from four principles William Zinsser set out in *On Writing Well*, restated here in this repo's own words. See [attribution.md](attribution.md) for the source.

## The four principles, restated

**Clarity.** A reader finds the point on the first pass, or the sentence needs a rewrite, not a footnote.

**Simplicity.** Strip every sentence to its working parts, then check what still moves the meaning forward. A sentence survives on what it does, not on how it sounds.

**Brevity.** Every word earns its place, or it goes. A long document is not a thorough one; it is usually an unedited one.

**Humanity.** The writer has a voice, and flavored prose keeps it — a turn of phrase, a dry aside, a metaphor that lands. This is the one principle strict mode gives up entirely. That gap is why the two registers exist as separate things, not one rule set with exceptions.

## Why the split matters

`plugins/core/skills/restraint/SKILL.md:75` — "Boring over clever — clever is what someone decodes at 3am" — is flavored prose doing real work. Strict mode would flatten it to "Write plain code, not clever code," which is accurate and forgettable. The image is what makes the line stick during a 3am incident, which is exactly when the rule matters most. Run that same line through the strict cap (20 words, one instruction, no metaphor) and the thing that made it memorable is the first casualty.

Flavored prose is not strict prose with the leash off. It still owes the reader clarity, simplicity, and brevity — Humanity is additive, not a license for clutter.

## Clutter, qualifiers, adverbs

Clutter is any word doing no work. "In order to" means "to." "At this point in time" means "now." "Due to the fact that" means "because."

A qualifier that restates its verb is clutter wearing a technical excuse. Delete words like "actually," "properly," or "really" and check whether the sentence lost anything. It almost never has.

## The rewriting loop

Draft first, without editing mid-sentence. Then read the draft once as a stranger would, cutting clutter, weak qualifiers, and any sentence that repeats a point already made. Read it again for voice — does it still sound like someone wrote it, or does it read like a form. Stop after two passes; a third pass polishes prose that was already fine on pass two.

## Where flavored prose stays disciplined

Flavored register does not waive the anti-fabrication rules, the banned-superlatives list, or the ban on unmeasured time estimates — see `/core:anti-fabrication`. A vivid sentence and a fabricated metric are not the same kind of freedom; only the first belongs to this register.
