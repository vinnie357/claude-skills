# Presentation Frameworks Reference

Deep reference for the core presentation strategy frameworks used in the `slidev-presentations` skill.

## Table of Contents

1. [Pyramid Principle](#pyramid-principle)
2. [SCQA Framework](#scqa-framework)
3. [Assertion-Evidence Methodology](#assertion-evidence-methodology)
4. [Nancy Duarte Sparkline / Resonate](#nancy-duarte-sparkline--resonate)
5. [Presentation Zen](#presentation-zen)
6. [10/20/30 Rule](#102030-rule)

---

## Pyramid Principle

Developed by Barbara Minto at McKinsey in the 1970s. The core insight: human brains process top-down, not bottom-up. State the conclusion first, then the supporting arguments, then the supporting data.

### Structure

```
Governing Thought (the answer)
├── Key Line Argument 1
│   ├── Supporting data 1a
│   └── Supporting data 1b
├── Key Line Argument 2
│   ├── Supporting data 2a
│   └── Supporting data 2b
└── Key Line Argument 3
    ├── Supporting data 3a
    └── Supporting data 3b
```

### Rules

1. **Ideas at each level summarize the ideas below them** — the governing thought summarizes the key line; each key line summarizes its supporting data
2. **Ideas in each group are the same kind of thing** — do not mix apples (business arguments) and oranges (technical arguments) at the same level
3. **Ideas in each group follow a logical order** — either deductive (if A, then B, therefore C) or inductive (three reasons why X)

### Example

**Without Pyramid Principle (bottom-up):**
> "We analyzed server logs for three months. We found 47 timeout errors per hour on average. The database query cache was disabled in the November config change. We recommend re-enabling the cache and adding connection pooling."

**With Pyramid Principle (top-down):**
> "Re-enable the query cache and add connection pooling — this will eliminate the 47 timeouts per hour degrading user experience. The root cause is the November config change that disabled caching, which we can confirm from server logs."

### Application to Slides

- **Title slide / first content slide**: States the governing thought
- **Section headers**: State each key line argument
- **Content slides**: Show the supporting data for the argument above

---

## SCQA Framework

Situation → Complication → Question → Answer. A storytelling scaffold that creates a natural narrative arc and makes the Pyramid Principle feel conversational.

### Components

| Step | Definition | Purpose |
|------|-----------|---------|
| **Situation** | Stable context the audience accepts as true | Establishes shared ground |
| **Complication** | What changed, went wrong, or created tension | Creates the need for action |
| **Question** | The question the complication raises | Aligns audience with the presenter |
| **Answer** | The recommendation or conclusion | Delivers the Pyramid governing thought |

### Worked Example: Infrastructure Migration

**Situation:**
> Our application has run on on-premises servers for 6 years, and the team understands the environment well.

**Complication:**
> Hardware is approaching end-of-life, and the 3-year renewal quote is $2.4M. Our current architecture cannot scale to handle the projected 4x traffic growth by Q4.

**Question:**
> How do we handle both the cost pressure and the scaling requirement without disrupting the current 99.9% uptime?

**Answer:**
> Migrate to AWS using a phased approach over 8 months, starting with the read-heavy services. Projected annual cost reduction of $400K after migration and elimination of hardware refresh cycle.

### Positioning SCQA in a Deck

- **Short deck (10 slides)**: SCQA maps to slides 1-2. Situation + Complication on slide 1, Question + Answer on slide 2.
- **Long deck (20+ slides)**: SCQA is the narrative skeleton of the entire deck. Each major section follows its own mini-SCQA.
- **One-pager**: SCQA maps to the problem/opportunity section header and the first paragraph.

---

## Assertion-Evidence Methodology

Developed by Michael Alley at Penn State. Research shows audiences retain information better when slide titles state conclusions rather than topics.

### The Two-Element Rule

Every slide has exactly two elements:

1. **Assertion** (top): A complete declarative sentence, 2 lines maximum
2. **Evidence** (body): A visual — diagram, chart, photograph, table, or short quote — that proves the assertion

### Assertion Writing Rules

- Write a complete sentence with a verb, not a noun phrase
- State the claim, not the category
- Keep to 10-15 words
- Use past or present tense for findings; imperative for recommendations

| Type | Bad (Topic) | Good (Assertion) |
|------|-------------|-----------------|
| Finding | "API Performance" | "API latency dropped below 100ms after caching rollout" |
| Recommendation | "Database Strategy" | "Move to read replicas to handle 3x read load" |
| Problem | "User Retention" | "30-day retention fell 12 points after the November update" |
| Process | "Deployment Flow" | "Blue-green deployment eliminates downtime during releases" |

### Evidence Types

Ranked by audience retention:

1. **Diagrams / Schematics** — highest retention for spatial/process information
2. **Charts / Graphs** — best for numerical comparison and trends
3. **Photographs / Screenshots** — best for concrete real-world examples
4. **Tables** — best for structured comparisons of multiple attributes
5. **Short quotes** — for testimonials or specification references
6. **Bullet lists** — lowest retention; use only when no visual alternative exists

### The 20-Word Target

Count words on a slide: assertion + all labels + all legend text. Target is ≤20 words. If over 30 words, the slide is carrying too much text and needs redesign.

---

## Nancy Duarte Sparkline / Resonate

From Nancy Duarte's book *Resonate* (2010). The Sparkline maps presentation structure as an alternating wave between "what is" (current reality) and "what could be" (future vision).

### Narrative Arc

```
START          MIDDLE                              END
  │                                                │
  │   WHAT IS ──────╮    ╭──── WHAT IS ───╮       │
  │                  ╰────╯                ╰────   │
  │               WHAT COULD BE        WHAT COULD BE
  │                                                │
Opening       Rising tension (alternating)    New Bliss
```

- **Opening**: Establish "what is" — the current reality the audience lives in
- **Middle**: Alternate between "what is" (the problems, the friction) and "what could be" (the vision, the solution glimpses)
- **Call to action**: The moment when the audience chooses to cross from "what is" to "what could be"
- **New Bliss**: The transformed future state

### Making the Audience the Hero

- The audience is the hero of the story, not the presenter or product
- The presenter is the mentor (like Yoda, not Luke)
- The product or solution is the tool that empowers the hero
- Frame benefits as what the audience gains, not what the solution provides

**Hero-centered framing:**
> "Imagine shipping a feature without waiting for a manual QA cycle" (audience as hero)
> vs.
> "Our CI system runs automated tests on every commit" (product as subject)

### Structuring the Sparkline in Slides

| Slide Group | Content |
|-------------|---------|
| Opening slides | Show current reality — the audience's world today |
| Problem slides | Amplify the friction/pain in "what is" |
| Vision slides | Paint "what could be" — aspirational, vivid |
| Evidence slides | Prove "what could be" is achievable (case studies, data) |
| Call to action | Name the specific action the audience must take |

---

## Presentation Zen

From Garr Reynolds' *Presentation Zen* (2008). Five design principles that distinguish signal from noise.

### Five Principles

**1. Simplicity**
Remove everything that does not directly serve the core message. Ask of every element: "Does this help the audience understand the point?" If no, delete it.

Test: Cover each element with a hand. Does the slide still communicate the assertion? If yes, the element may be noise.

**2. Clarity**
One idea per slide. When two ideas share a slide, neither gets full attention. If a slide requires a long title to distinguish its idea from the previous slide, it should be its own slide.

**3. Restraint**
Fewer colors, fewer fonts, fewer animations. Each additional element competes for attention. Standard restraint guidelines:
- Maximum 2 fonts per deck (one for headings, one for body)
- Maximum 3 colors per slide (primary, secondary, accent)
- No transition animations except when they carry meaning (e.g., a build revealing information progressively)

**4. Harmony**
Consistent visual language throughout. If architecture diagrams use blue boxes on slide 3, all architecture diagrams use blue boxes. Inconsistency signals carelessness and breaks trust.

**5. Connection**
Design for the specific audience in the room, not for a generic viewer. A slide deck that works for developers may not work for executives. Connection means knowing who will sit in those seats and designing for them.

---

## 10/20/30 Rule

From Guy Kawasaki's *The Art of the Start* (2004). A practical constraint for investor and business pitches, broadly applicable.

### The Three Numbers

| Constraint | Value | Rationale |
|-----------|-------|-----------|
| Maximum slides | 10 | Human attention can sustain 10 ideas in one sitting |
| Maximum time | 20 minutes | Leaves time for questions; respects calendars |
| Minimum font | 30pt | Forces simplicity; visible from the back of the room |

### Applying the 10-Slide Constraint

When a draft deck exceeds 10 slides, apply this triage:

1. **Merge**: Two slides covering the same argument belong on one slide
2. **Appendix**: Supporting data that defends an argument but is not the argument itself → appendix slide
3. **Cut**: If a slide does not advance the SCQA narrative, remove it
4. **Reframe**: If three points all point to one conclusion, they belong on one assertion slide with a three-item visual

### Font Size Enforcement

30pt minimum means approximately 8-10 words per line and 3-4 lines per slide. This is a feature, not a limitation — it forces the presenter to use visuals instead of text.

Fonts below 30pt on a slide indicate the presenter is reading from the slide rather than presenting. The audience can read faster than the presenter speaks, so they will disengage.
