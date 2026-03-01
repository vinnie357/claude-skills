# Skill Catalog for Task Matching

This reference maps marketplace skills to trigger keywords for suggesting relevant skills when creating beads tasks.

## Matching Rules (Two-Tier Discovery)

When creating a task, match skills to the task using this priority:

1. **Explicit `skill:` labels** - Author specified skills directly (highest priority)
2. **Tier 1 - Static catalog keyword match** - Task labels or description match trigger keywords in the tables below
3. **Tier 2 - Runtime skill discovery** - Check available skills in the current session for additional matches beyond the catalog
4. **Description keyword match** - Task title/description contains trigger keywords from either tier

Suggest **1-3 skills** per task. Prefer fewer, more relevant skills over many loosely related ones.

### Tier 1: Static Catalog (Known Skills)

The keyword mapping tables below cover known marketplace skills with curated trigger keywords. These provide reliable keyword-based matching for skills in this repository.

### Tier 2: Runtime Discovery (All Loaded Skills)

The static catalog does not cover every possible skill. Users may have skills installed from other marketplaces or plugins. To discover these:

1. Check the available skills listing in the current session (visible in the system prompt as loaded skill names and descriptions)
2. For any loaded skill **not** in the static catalog, analyze its name and description against the task domain
3. If a runtime-discovered skill is relevant, suggest it with a `skill:` label just like catalog skills

Runtime discovery ensures that third-party or user-created skills can be suggested even without curated keyword mappings.

## Skill-to-Keyword Mapping

### claude-code Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `plugin-marketplace` | marketplace, plugin registry, marketplace.json, plugin distribution |
| `claude-plugins` | plugin.json, plugin schema, plugin validation, plugin creation |
| `claude-commands` | slash command, custom command, command argument |
| `claude-agents` | custom agent, agent tools, specialized agent, subagent |
| `claude-skills` | skill creation, SKILL.md, progressive disclosure, skill structure |
| `claude-hooks` | hooks, event-driven, lifecycle event, tool call automation |
| `claude-teams` | agent team, multi-agent, teammate, team lead, task coordination, parallel agents |

### core Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `git` | git, commit, branch, rebase, merge, conflict, version control |
| `mise` | mise, tool version, runtime, environment variable, project task |
| `nushell` | nushell, nu script, structured data, pipeline, cross-platform script |
| `documentation` | documentation, README, API docs, guide, technical writing |
| `code-review` | code review, pull request review, audit, code quality, feedback |
| `accessibility` | accessibility, WCAG, a11y, screen reader, WAI, ARIA |
| `material-design` | material design, material you, android theme, dynamic color |
| `twelve-factor` | twelve-factor, 12-factor, microservice, cloud-native, kubernetes |
| `anti-fabrication` | validation, claims verification, factual accuracy, metrics |
| `security` | security, secret detection, gitleaks, credential scan, API key leak |
| `beads` | beads, task management, dependency tracking, issue tracker |
| `container` | container, OCI, linux container, apple container, macOS container |

### dagu Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `dagu-workflows` | dagu, workflow definition, DAG, YAML workflow, scheduling |
| `dagu-webui` | dagu UI, workflow monitoring, DAG browser |
| `dagu-rest-api` | dagu API, workflow API, execution status API |

### elixir Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `elixir-anti-patterns` | elixir anti-pattern, elixir smell, elixir refactor |
| `phoenix` | phoenix, liveview, phoenix context, phoenix channel |
| `otp` | OTP, genserver, supervision tree, fault-tolerant, BEAM |
| `testing` | elixir test, ExUnit, property-based test, elixir mock |
| `config` | elixir config, runtime.exs, config.exs, Application.get_env |

### github Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `actions` | github action, custom action, action runner, action marketplace |
| `workflows` | github workflow, CI/CD pipeline, workflow trigger, workflow artifact |
| `act` | act, local action test, workflow debug local |
| `community-health` | community health, code of conduct, contributing guide, security policy, issue template, PR template, open source |

### rust Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `rust` | rust, ownership, borrowing, cargo, async rust, lifetime |

### slidev Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `slidev` | slidev, sli.dev, presentation, slides, deck |
| `slidev-syntax` | slide syntax, slide layout, frontmatter, markdown slides, presenter notes |
| `slidev-code` | code block, syntax highlighting, monaco, magic move, twoslash, code group |
| `slidev-export` | export PDF, export PPTX, slidev build, static SPA, slidev export |
| `slidev-troubleshooting` | slidev error, export failure, font issue, slidev debug |

### ui Plugin

| Skill | Trigger Keywords |
|-------|-----------------|
| `daisyui` | daisyUI, tailwind component, UI theme, responsive design |

## Matching Examples

### Example 1: Explicit labels

Task: `bd create "Add pre-commit secret scanning" --labels "type:feature,skill:security,skill:git"`

Skills come directly from labels: `security`, `git`.

### Example 2: Label keyword match

Task: `bd create "Fix Phoenix LiveView crash" --labels "type:bug,elixir"`

Label `elixir` matches the elixir plugin. Title contains "Phoenix" and "LiveView" which trigger `phoenix`. Suggested: `skill:phoenix`.

### Example 3: Description keyword match

Task: `bd create "Set up CI/CD pipeline" --description "Create GitHub Actions workflow for running tests and deploying"`

Description contains "GitHub Actions" and "workflow" which trigger `workflows` and `actions`. Suggested: `skill:workflows`, `skill:actions`.

### Example 4: Cross-plugin match

Task: `bd create "Containerize Elixir app" --labels "type:feature"`

Title contains "Container" (triggers `container`) and "Elixir" (triggers elixir skills). Description analysis needed to narrow elixir skills. Suggested: `skill:container`, `skill:twelve-factor`.

### Example 5: Runtime discovery (third-party skill)

Task: `bd create "Add type hints to data pipeline" --labels "type:feature"`

Title contains "type hints" and "data pipeline". No static catalog match. However, a `python` skill from another marketplace is loaded in the current session with description "Python development patterns and type system." The skill name and description match the task domain. Suggested: `skill:python`.
