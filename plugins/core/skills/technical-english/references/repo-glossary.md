# Repo Glossary

One term, one meaning, held across every skill, agent, command, and doc in this repo. Each entry states the approved sense and names the word it gets confused with.

## Skill, agent, command, hook, output style

**Skill** — a `SKILL.md` directory Claude loads on demand for domain knowledge or procedure. Confusable with **agent**: a skill is passive content; an agent is an active process that runs it.

**Agent** — a spawned process (Task/Agent tool call) that runs with its own context and tool access. Confusable with **skill**: an agent can load a skill, but a skill cannot spawn itself.

**Command** — a slash command (`/name`) that a user types to trigger a specific, named action. Confusable with **skill**: a command is user-invoked; a skill can activate on its own when the model judges it relevant.

**Hook** — a script the harness runs automatically at a lifecycle event (PreToolUse, SessionStart, and similar). Confusable with **command**: a hook never has a user-typed trigger; the event is the trigger.

**Output style** — a response-format contract that shapes how the main-loop conversation replies. Confusable with **skill**: an output style governs shape and tone; a skill supplies knowledge and procedure.

## Check, test, gate, validator

**Check** — one verification step, human or automated, with a pass/fail outcome. The general term; every test, gate, and validator run is a check.

**Test** — a check defined in code (ExUnit, a validator script) that runs the same way every time. Confusable with **check**: not every check is automated, but every test is.

**Gate** — a checkpoint a change must clear before it advances (Gate 1 local CI, Gate 2 remote CI, Gate 3 adversarial review). Confusable with **check**: a gate blocks progress; a check only reports a result.

**Validator** — the specific tool or script that performs a check (`validate-plugin.nu`, `validate-sources.nu`). Confusable with **test**: a validator is the tool; a test is one run of it.

## Issue, epic, slice, phase

**Issue** — one trackable unit of work in bees or Linear, with a title and acceptance criteria. The base unit everything else decomposes into.

**Epic** — a body of work spanning multiple issues, tracked in Linear with `## Objective / ## Skills / ## Repos`. Confusable with **issue**: an epic is never worked directly; it decomposes into issues first.

**Slice** — one issue's worth of work inside an epic's decomposition, sized for one pipeline pass. Confusable with **phase**: a slice is a unit of scope; a phase is a stage every slice passes through.

**Phase** — one stage of the 4-phase execution model (plan, test, implement, review) that every slice moves through in order. Confusable with **slice**: phases repeat per slice; a slice happens once.

## Reference, template, asset

**Reference** — a `references/*.md` file loaded only when a specific scenario needs its detail. Confusable with **asset**: a reference loads into context; an asset does not.

**Template** — a copyable starting document (an ADR template, an eval-checklist template) meant to be filled in, not read for facts. Confusable with **reference**: a template supplies structure; a reference supplies content.

**Asset** — an output file a skill produces or ships (an image, a boilerplate config) that never itself loads into context. Confusable with **reference**: an asset is a deliverable; a reference is instructional material.
