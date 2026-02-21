---
description: "Research topics and create Agent Skills with proper structure and documentation"
argument-hint: "<skill-name> [--complexity=low|medium|high]"
---

Research a topic and create a properly structured Agent Skill following the Agent Skills Specification.

**Skill Creation:**
- **Directory Structure**: Creates `skills/<skill-name>/SKILL.md` with proper frontmatter
- **Progressive Disclosure**: Generates reference files in `references/` for deep context
- **Source Documentation**: Updates `promptlog/sources.md` with all research sources
- **Specification Compliance**: Follows Agent Skills Specification v1.0

**Features:**
- **Automatic Complexity Assessment**: Evaluates topic complexity (1-10 scale)
- **Thinking Mode Selection**: Standard/Extended/Deep based on complexity
- **Manual Override**: Use `--complexity=<level>` to force thinking depth
- **YAML Frontmatter**: Auto-generates name, description, license, metadata
- **Reference Management**: Creates separate files for detailed documentation
- **Source Tracking**: Maintains traceability in promptlog/sources.md

**Examples:**
```
/research-skill elixir-genserver
# Creates: skills/elixir-genserver/SKILL.md
# Updates: promptlog/sources.md

/research-skill kubernetes-operators --complexity=high
# Creates: skills/kubernetes-operators/SKILL.md
#          skills/kubernetes-operators/references/
# Updates: promptlog/sources.md

/research-skill react-hooks --complexity=medium
# Creates: skills/react-hooks/SKILL.md with enhanced analysis
```

**SKILL.md Structure:**
```markdown
---
name: skill-name
description: When Claude should use this skill (concise, activation-focused)
license: MIT
---

# Skill Name

## When to Use This Skill
[Activation criteria]

## Core Concepts
[Essential knowledge]

## Best Practices
[Guidelines and patterns]

## Examples
[Concrete usage examples]

## References
[Links to reference files if needed]
```

**Workflow:**
1. **Research**: Gather authoritative sources and best practices
2. **Structure**: Create skill directory following spec
3. **Generate SKILL.md**: Write frontmatter and core content
4. **Create References**: Add detailed docs in references/ for progressive disclosure
5. **Document Sources**: Update promptlog/sources.md with all sources used
6. **Validate**: Ensure spec compliance and activation clarity

**Task Instructions:**
Use Task tool with subagent_type: "general-purpose" to:

1. Research the topic thoroughly using web search and authoritative sources
2. Create the skill directory: `skills/<skill-name>/`
3. Generate SKILL.md with:
   - Proper YAML frontmatter (name, description, license)
   - Clear activation criteria in description
   - Core procedural knowledge in markdown body
   - Concrete examples and patterns
4. Create `skills/<skill-name>/references/` if detailed documentation is needed
5. Update `promptlog/sources.md` with:
   - All URLs and documentation sources used
   - Purpose of each source
   - Key concepts extracted
   - Date accessed
6. Follow the 7-step skill creation workflow from CLAUDE.md
7. Use imperative/infinitive language (not second-person)
8. Keep commonly-used context in SKILL.md, detailed references separate

The agent should produce a complete, spec-compliant skill ready for use.
