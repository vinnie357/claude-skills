# Linear Plugin Sources

## Linear Skill

### Linear MCP Documentation
- **URL**: https://linear.app/docs/mcp
- **Purpose**: MCP server setup, OAuth flow, client configurations
- **Key Topics**: Streamable HTTP transport, OAuth 2.1, Claude Code integration
- **Date Accessed**: 2026-04-04

### Linear GraphQL API Documentation
- **URL**: https://developers.linear.app/docs/graphql/working-with-the-graphql-api
- **Purpose**: GraphQL API reference for fallback operations
- **Key Topics**: Authentication, queries, mutations, pagination, introspection

### Symphony Linear Skill
- **Path**: ~/github/symphony/.codex/skills/linear/SKILL.md
- **Purpose**: Existing Linear GraphQL skill with query patterns
- **Key Topics**: Issue queries, state transitions, comments, attachments, introspection

### VantageEx Linear Client
- **Path**: ~/github/vantageex/lib/vantageex/linear/client.ex
- **Purpose**: Production Linear GraphQL client implementation
- **Key Topics**: Issue polling, state management, description parsing

### VantageEx ADR-027: Epic Messaging
- **Path**: ~/github/vantage_ex/architecture/decisions/027-epic-messaging.md
- **Purpose**: Description sections and comment channels specification
- **Key Topics**: Instructions section, PR section, comment polling, re-queue flow

### VantageEx ADR-025: Epic Lifecycle and Status Workflow
- **Path**: ~/github/vantage_ex/architecture/decisions/025-epic-lifecycle-and-status-workflow.md
- **Purpose**: Status workflow and kanban gating
- **Key Topics**: ready/up_next/in_progress/needs_help/review/complete/archived states

### VantageEx ADR-016: Layered Tasking Structure
- **Path**: ~/github/vantage_ex/architecture/decisions/016-layered-tasking-structure.md
- **Purpose**: Three-level hierarchy (Epic -> Issue -> Task)
- **Key Topics**: Decomposition model, responsibility boundaries

### VantageEx Epic Authoring Guide
- **Path**: ~/github/vantage_ex/architecture/prompts/EPIC-AUTHORING.md
- **Purpose**: User guide for writing machine-executable epics
- **Key Topics**: Required fields, optional fields, anti-patterns

### VantageEx Epic Template
- **Path**: ~/github/vantage_ex/epics/TEMPLATE.md
- **Purpose**: Epic description template with field definitions
- **Key Topics**: Title, slug, objective, skills, constraints

### CLAUDE.md Template
- **Path**: ~/github/claude-skills/plugins/tools/claude-code/templates/CLAUDE.md
- **Purpose**: Standard project workflow template (4-phase)
- **Key Topics**: Pre-flight checks, working items, validation, submit loop
