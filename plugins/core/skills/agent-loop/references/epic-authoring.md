# Epic Authoring Guide

This guide helps users write epics that agent teams can autonomously decompose and execute.

## The Layered Model

The system uses a three-level hierarchy:

- **Epic** -- what the user authors. The assignment: objective, skills, constraints. No implementation details.
- **Issues** -- created by the team leader. Independently deliverable slices of the epic with acceptance criteria.
- **Tasks** -- created by agents while working an issue. Granular implementation steps, invisible to the user.

The user's job is to write a great epic. The team leader handles decomposition into issues. Agents create their own tasks.

## Epic Structure (Required Fields)

### Title

A clear, imperative statement of what gets built.

- Good: "Implement OAuth2 PKCE flow for API gateway"
- Bad: "Auth stuff" / "Fix login"

### Objective

2-3 sentences. What does success look like? The team leader uses this to validate completion.

- Good: "Users can authenticate via Google/GitHub OAuth2 with PKCE. Tokens refresh automatically. All auth endpoints pass OWASP top-10 checks."
- Bad: "Make auth work better"

### Skills

Which skill sets does this epic require? The team leader uses these to assign agents.

```yaml
skills: [elixir, oauth, security, tdd]
```

Core skills (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell) are always loaded. Only list domain-specific extras here.

### Constraints (Optional)

Constraints that apply to the entire epic:

```yaml
constraints:
  - All code must pass `mise run ci`
  - No attribution in commits
  - Feature branch per epic: feature/<epic-slug>
  - Squash merge only
```

## What NOT to Put in Epics

- Implementation details (let agents decide HOW)
- Specific file paths (let agents discover the codebase)
- Step-by-step instructions (that is what skills are for)
- Acceptance criteria per issue (the team leader writes those)
- Model assignments per task (the system optimizes this)

## What Makes a Great Epic

1. Clear objective -- agents and the team leader know what done looks like
2. Explicit skills -- agents get the right tools loaded
3. Constraints that matter -- not noise, just real boundaries
4. Short, URL-safe slug -- used in branch names and tracking
   - Good: `oauth-pkce-flow` (20 chars, clean)
   - Bad: `implement-the-full-oauth2-pkce-flow-for-our-api-gateway` (too long)

## Optional Fields

### Team Shape

```yaml
team:
  lead: sonnet
  default_model: haiku
  escalation: haiku -> sonnet -> opus
```

### Escalation Policy

```yaml
escalation:
  on_agent_failure: promote_model
  on_ambiguity: ask_user
  on_dependency_conflict: ask_user
```

## The User Loop

What the user does day-to-day:

- Write epics following the structure above
- Review status for escalations and blockers
- Respond to escalation requests (ambiguity, dependency conflicts)
- Approve PRs when CI passes -- squash merge and confirm
- Create new epics -- the system picks them up
- Occasionally: add new skills to the skill library
- Occasionally: author new workflow bundles for repeated patterns

The user NEVER spawns agents directly. The team leader handles all decomposition and agent assignment. The user's leverage is in writing excellent epics.
