---
description: "Research topics and create comprehensive planning documentation"
argument-hint: "<category> <topic> [--complexity=low|medium|high]"
---

Research a topic and create comprehensive documentation for planning, understanding, and working with the subject.

**Document Creation:**
- **Directory Structure**: Creates `research/<category>/<topic>/`
- **File Generation**: Produces `overview.md`, `troubleshooting.md`, and optional guides
- **Planning Focus**: Helps understand topics before implementation
- **Reference Material**: Creates searchable knowledge base

**Features:**
- **Automatic Complexity Assessment**: Evaluates topic complexity (1-10 scale)
- **Thinking Mode Selection**: Standard/Extended/Deep based on complexity
- **Manual Override**: Use `--complexity=<level>` to force thinking depth
- **Structured Content**: Consistent templates for reliability
- **Authoritative Sources**: Links to official docs and best practices
- **Practical Examples**: Real-world usage patterns and code samples

**Examples:**
```
/research development docker-compose
# Creates: research/development/docker-compose/
#          - overview.md
#          - troubleshooting.md

/research infrastructure kubernetes-networking --complexity=high
# Creates: research/infrastructure/kubernetes-networking/
#          - overview.md (with deep analysis)
#          - troubleshooting.md
#          - best-practices.md

/research frontend react-state-management --complexity=medium
# Creates: research/frontend/react-state-management/
#          - overview.md
#          - troubleshooting.md
#          - comparison.md (Redux vs Context vs Zustand)
```

**Document Structure:**

### overview.md
- **Purpose & Use Cases**: When and why to use this technology
- **Core Concepts**: Fundamental principles and architecture
- **Implementation Patterns**: Common approaches and best practices
- **Code Examples**: Practical, runnable examples
- **Integration Guidelines**: How it fits into larger systems
- **Performance Considerations**: Optimization and scaling
- **Security**: Common vulnerabilities and protections
- **Resources**: Official docs, tutorials, community resources

### troubleshooting.md
- **Common Issues**: Frequently encountered problems
- **Error Messages**: Interpretation and solutions
- **Diagnostic Tools**: How to investigate problems
- **Solutions**: Step-by-step fixes
- **Prevention**: How to avoid issues
- **Escalation**: When and where to get help

### Additional Files (generated as needed)
- `best-practices.md`: Detailed guidelines and patterns
- `comparison.md`: Technology alternatives and trade-offs
- `migration.md`: Upgrade paths and migration strategies
- `quick-start.md`: Fast setup and basic usage

**Quality Standards:**
- Use authoritative sources (official docs, RFCs, reputable blogs)
- Include version information where relevant
- Provide working code examples
- Link to external resources
- Note common pitfalls and gotchas
- Include date of research for freshness tracking

**Task Instructions:**
Use Task tool with subagent_type: "general-purpose" to:

1. **Research Phase**:
   - Search authoritative sources and documentation
   - Gather best practices and common patterns
   - Identify common issues and solutions
   - Collect practical examples

2. **Structure Phase**:
   - Create `research/<category>/<topic>/` directory
   - Determine which documents are needed based on topic
   - Plan document organization

3. **Content Generation**:
   - Write comprehensive `overview.md` with:
     * Clear purpose and use cases
     * Core concepts and architecture
     * Implementation patterns
     * Practical examples
     * Integration guidance
   - Write practical `troubleshooting.md` with:
     * Common issues and solutions
     * Error message interpretations
     * Diagnostic approaches
     * Prevention strategies
   - Generate additional guides as needed

4. **Quality Assurance**:
   - Verify all sources are authoritative
   - Ensure examples are practical and correct
   - Check for completeness and clarity
   - Add timestamps and version info

The agent should produce comprehensive, actionable documentation that helps users understand and work with the topic effectively.
