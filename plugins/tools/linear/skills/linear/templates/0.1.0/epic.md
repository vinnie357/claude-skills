# Epic: [TITLE]

> A clear, imperative statement of what gets built.
> - Good: "Implement OAuth2 PKCE flow for API gateway"
> - Bad: "Auth stuff" / "Fix login"

## Slug

> Short, URL-safe identifier. kebab-case, max ~30 chars.
> Used in branch names: `feature/<slug>`

```
slug: [epic-slug]
```

## Objective

> 2-3 sentences. What does success look like?
> The team leader uses this to validate completion and decompose into issues.

[Write objective here]

## Skills

> Domain-specific skills only.
> Core skills (anti-fabrication, git, tdd, twelve-factor, security, mise, nushell) are always loaded.

```yaml
skills: [skill-1, skill-2]
```

## Repos

> Target repositories this epic touches.

- org/repo-name

## Constraints (Optional)

> Real boundaries only. Defaults apply if omitted:
> mise run ci, no attribution, squash merge, feature/<slug> branch.

```yaml
constraints:
  - Constraint 1
  - Constraint 2
```

## Team (Optional)

> Team composition. Inferred from epic complexity if omitted.

```yaml
team:
  lead: opus
  default_model: haiku
  escalation: haiku -> sonnet -> opus
```

## Escalation (Optional)

> Failure and ambiguity policies.

```yaml
escalation:
  on_agent_failure: promote_model
  on_ambiguity: ask_user
```

---

> **That's it.** The team leader handles decomposition into issues and task assignment.
> Do not add acceptance criteria, implementation steps, file paths, or model assignments per task.
