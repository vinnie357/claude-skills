# Workflow Orchestration Patterns

Composable shapes for workflow scripts. Pick by task and combine freely. Source: the Claude Code Workflow tool contract.

## Table of contents

- [Pipeline by default](#pipeline-by-default)
- [Barrier when stage N needs all of stage N-1](#barrier-when-stage-n-needs-all-of-stage-n-1)
- [Adversarial verify](#adversarial-verify)
- [Perspective-diverse verify](#perspective-diverse-verify)
- [Judge panel](#judge-panel)
- [Loop-until-count](#loop-until-count)
- [Loop-until-budget](#loop-until-budget)
- [Loop-until-dry](#loop-until-dry)
- [Multi-modal sweep](#multi-modal-sweep)
- [Completeness critic](#completeness-critic)
- [No silent caps](#no-silent-caps)
- [Scaling to the request](#scaling-to-the-request)

## Pipeline by default

Each dimension verifies as soon as its review completes — no wasted wall-clock.

```javascript
const DIMENSIONS = [{ key: 'bugs', prompt: '...' }, { key: 'perf', prompt: '...' }]
const results = await pipeline(
  DIMENSIONS,
  d => agent(d.prompt, { label: `review:${d.key}`, phase: 'Review', schema: FINDINGS }),
  review => parallel(review.findings.map(f => () =>
    agent(`Adversarially verify: ${f.title}`, { label: `verify:${f.file}`, phase: 'Verify', schema: VERDICT })
      .then(v => ({ ...f, verdict: v })))),
)
const confirmed = results.flat().filter(Boolean).filter(f => f.verdict?.isReal)
```

## Barrier when stage N needs all of stage N-1

Dedup across all findings before expensive verification — a genuine barrier reason.

```javascript
const all = await parallel(DIMENSIONS.map(d => () => agent(d.prompt, { schema: FINDINGS })))
const deduped = dedupeByFileAndLine(all.filter(Boolean).flatMap(r => r.findings))
const verified = await parallel(deduped.map(f => () => agent(verifyPrompt(f), { schema: VERDICT })))
```

## Adversarial verify

Spawn N independent skeptics per finding, each prompted to refute. Kill the finding if a majority refute. Stops plausible-but-wrong findings from surviving.

```javascript
const votes = await parallel(Array.from({ length: 3 }, () => () =>
  agent(`Try to refute: ${claim}. Default to refuted=true if uncertain.`, { schema: VERDICT })))
const survives = votes.filter(Boolean).filter(v => !v.refuted).length >= 2
```

## Perspective-diverse verify

When a finding can fail in more than one way, give each verifier a distinct lens instead of N identical refuters. Diversity catches failure modes redundancy misses.

```javascript
const vs = await parallel(['correctness', 'security', 'repro'].map(lens => () =>
  agent(`Judge "${finding.desc}" via the ${lens} lens — real?`, { schema: VERDICT })))
const real = vs.filter(Boolean).filter(v => v.real).length >= 2
```

## Judge panel

Generate N independent attempts from different angles (MVP-first, risk-first, user-first), score with parallel judges, synthesize from the winner while grafting the best ideas from runners-up. Beats one-attempt-iterated when the solution space is wide.

## Loop-until-count

Accumulate to a target.

```javascript
const bugs = []
while (bugs.length < 10) {
  const r = await agent('Find bugs in this codebase.', { schema: BUGS })
  bugs.push(...r.bugs)
  log(`${bugs.length}/10 found`)
}
```

## Loop-until-budget

Scale depth to the user's token directive. Guard on `budget.total` — with no target, `remaining()` is `Infinity` and the loop runs to the 1000-agent cap.

```javascript
const bugs = []
while (budget.total && budget.remaining() > 50_000) {
  const r = await agent('Find bugs in this codebase.', { schema: BUGS })
  bugs.push(...r.bugs)
  log(`${bugs.length} found, ${Math.round(budget.remaining() / 1000)}k remaining`)
}
```

## Loop-until-dry

For unknown-size discovery, keep spawning finders until K consecutive rounds return nothing new. Simple `while (count < N)` counters miss the tail. Dedup against everything seen, not just confirmed findings — else judge-rejected items reappear every round and the loop never converges.

```javascript
const seen = new Set(), confirmed = []
let dry = 0
while (dry < 2) {
  const found = (await parallel(FINDERS.map(f => () =>
    agent(f.prompt, { phase: 'Find', schema: BUGS })))).filter(Boolean).flatMap(r => r.bugs)
  const fresh = found.filter(b => !seen.has(key(b)))
  if (!fresh.length) { dry++; continue }
  dry = 0; fresh.forEach(b => seen.add(key(b)))
  const judged = await parallel(fresh.map(b => () =>
    parallel(['correctness', 'security', 'repro'].map(lens => () =>
      agent(`Judge "${b.desc}" via the ${lens} lens — real?`, { phase: 'Verify', schema: VERDICT })))
      .then(vs => ({ b, real: vs.filter(Boolean).filter(v => v.real).length >= 2 }))))
  confirmed.push(...judged.filter(v => v.real).map(v => v.b))
}
```

## Multi-modal sweep

Parallel agents each search a different way — by container, by content, by entity, by time. Each is blind to what the others surface; useful when one search angle alone won't find everything.

## Completeness critic

A final agent that asks "what's missing — a modality not run, a claim unverified, a source unread?" What it finds becomes the next round of work.

## No silent caps

When a workflow bounds coverage (top-N, no-retry, sampling), `log()` what was dropped. Silent truncation reads as "covered everything" when it did not.

## Scaling to the request

Match orchestration depth to what the user asked for. "Find any bugs" → a few finders, single-vote verify. "Thoroughly audit this" or "be comprehensive" → a larger finder pool, a 3–5 vote adversarial pass, and a synthesis stage. When unsure, lean toward thoroughness for research/review/audit requests and toward brevity for quick checks.

These patterns are not exhaustive — compose novel harnesses when the task calls for it (tournament brackets, self-repair loops, staged escalation).
