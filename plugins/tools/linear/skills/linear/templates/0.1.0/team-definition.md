# Team Definition Template

Add this as the `## Team` section in a VantageEx epic description.

## Minimal (Recommended Default)

```yaml
team:
  lead: sonnet
  default_model: haiku
  escalation: haiku -> sonnet -> opus
```

## With Role-Based Workers

```yaml
team:
  lead: sonnet
  default_model: haiku
  escalation: haiku -> sonnet -> opus
  workers:
    - role: implementation
      skills: [elixir, phoenix]
      model: haiku
    - role: validation
      skills: [tdd, security]
      model: haiku
    - role: documentation
      skills: [documentation]
      model: haiku
```

## With Custom Escalation

```yaml
team:
  lead: sonnet
  default_model: haiku
  escalation: haiku -> sonnet -> opus

escalation:
  on_agent_failure: promote_model
  on_ambiguity: ask_user
  on_dependency_conflict: ask_user
```

## Guidelines

- **lead**: Use `sonnet` for most epics. Use `opus` only for architecturally complex work.
- **default_model**: Start with `haiku`. The escalation policy promotes on failure.
- **escalation**: Standard is `haiku -> sonnet -> opus` with max 2 promotions per agent.
- **workers**: Optional. The team leader assigns roles during decomposition if omitted.
- **skills**: Per-worker skills are in addition to the epic's skill list.
