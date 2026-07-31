# Registration

How this skill is registered in the marketplace and the validators to run.

## Files involved in registration

Three files must be updated when adding or updating this skill:

1. **marketplace.json** (repo root `.claude-plugin/marketplace.json`): the `github` plugin entry. Bump `version`; extend `description` to mention Dependabot; add `"dependabot"` and `"dependencies"` to `keywords`.

2. **plugin.json** (`plugins/tools/github/.claude-plugin/plugin.json`): the github plugin manifest. Bump `version`; add `"./skills/dependabot-consolidator"` to `skills[]`; add a top-level `"agents"` array listing the two agent files.

3. **sources.toml** (`plugins/tools/github/skills/sources.toml`): add `dependabot-consolidator` to the `skills` array of the entry that covers its upstream, or add a new `[[sources]]` entry. `test/validate-sources.nu` compares the union of every entry's `skills` array against the plugin's declared skills by set difference — a skill missing from all of them fails `a2_uncovered`.

4. **sources.md** (`plugins/tools/github/skills/sources.md`): add a `## Dependabot Consolidation` section. Every `sources.toml` entry `name` must appear in this file's **prose** — URLs do not count, since `c2_md_no_mention` strips them before matching. If the prose does not already name the source, append it to the `Entries:` sentence on the index-pointer line.

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

- [ ] `name:` in SKILL.md frontmatter equals the directory name `dependabot-consolidator`
- [ ] No `allowed-tools:` in SKILL.md frontmatter
- [ ] `description:` contains "Use when", is ≤1024 chars, uses third person
- [ ] SKILL.md body is ≤500 lines (code fences exempt from content checks but count toward line limit)
- [ ] Every reference and agent file basename is mentioned in SKILL.md body
- [ ] Every path written in prose (e.g., `agents/dependabot-collector.md`) exists on disk
- [ ] No cross-skill invocation (`/plugin:skill`) that does not resolve to a real local skill
- [ ] Agent files use `tools:` as a comma-separated string, not a YAML list
- [ ] `model:` in each agent is one of `haiku`, `sonnet`, `opus`
- [ ] `sources.toml` covers `dependabot-consolidator` in some entry's `skills` array
- [ ] every `sources.toml` entry `name` appears in `sources.md` prose (not only inside a URL)
- [ ] `nu test/validate-plugin.nu github` passes
- [ ] `nu test/validate-skills-quality.nu` passes with no new failures

## Version bump policy

- Skill-only changes (no new skills added): increment the patch segment of `version` in plugin.json and marketplace.json.
- New skill added: increment the minor segment.
- Breaking change to existing skill interface: increment the minor segment and document in sources.md.
