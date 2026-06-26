# Registration

How this skill is registered in the marketplace and the validators to run.

## Files involved in registration

Three files must be updated when adding or updating this skill:

1. **marketplace.json** (repo root `.claude-plugin/marketplace.json`): the `github` plugin
   entry. Bump `version`; extend `description` to mention PR review; add `"pr-review"`,
   `"code-review"`, and `"collaborator"` to `keywords`.

2. **plugin.json** (`plugins/tools/github/.claude-plugin/plugin.json`): the github plugin
   manifest. Bump `version`; add `"./skills/pr-review"` to `skills[]`; add the two agent
   files to the top-level `agents[]` array.

3. **sources.md** (`plugins/tools/github/skills/sources.md`): add a `## PR Review` section.
   The validator (check `source`) requires the skill directory name or frontmatter name to
   appear here.

## Two validators to run

After every change to skill files or registration:

```bash
# Validate the github plugin structure
nu test/validate-plugin.nu github

# Validate skill quality across all plugins
nu test/validate-skills-quality.nu
```

Both must pass (no new failures beyond the baseline) before committing.

## Build checklist

- [ ] `name:` in SKILL.md frontmatter equals the directory name `pr-review`
- [ ] No `allowed-tools:` in SKILL.md frontmatter
- [ ] `description:` contains "Use when", is ≤1024 chars, uses third person
- [ ] SKILL.md body is ≤500 lines
- [ ] Every reference and agent file basename is mentioned in SKILL.md body
- [ ] Every path written in prose (e.g., `agents/pr-collector.md`) exists on disk
- [ ] No cross-skill invocation (`/plugin:skill`) that does not resolve to a real local skill
- [ ] Agent files use `tools:` as a comma-separated string, not a YAML list
- [ ] `model:` in each agent is one of `haiku`, `sonnet`, `opus`
- [ ] `sources.md` contains `pr-review` (or the frontmatter name)
- [ ] `nu test/validate-plugin.nu github` passes
- [ ] `nu test/validate-skills-quality.nu` passes with no new failures

## Version bump policy

- Skill-only changes (no new skills added): increment the patch segment of `version` in
  plugin.json and marketplace.json.
- New skill added: increment the minor segment (this skill: 0.2.0 → 0.3.0).
- Breaking change to an existing skill interface: increment the minor segment and document in
  sources.md.
