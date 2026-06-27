# Tidewave v0.5.6 Research

## Release Information

**Version**: 0.5.6
**Release Date**: 2026-03-13
**Previous Version**: 0.5.5 (2026-02-10)
**Repository**: https://github.com/tidewave-ai/tidewave_phoenix
**Hex Package**: https://hex.pm/packages/tidewave
**Documentation**: https://hexdocs.pm/tidewave/

## Tidewave v0.5.6 Changes

### Verified Changes and Features

Based on research from the February 2026 Tidewave blog post ("OpenCode support, task boards, and more"):

1. **OpenCode Support** ✓ Verified
   - Tidewave now integrates with OpenCode, an open-source coding agent
   - Supports more than 75 LLM providers
   - Enables integration with additional providers like MiniMax and Kimi
   - Facilitates contributions to open standards like the Agent Client Protocol
   - Link: https://tidewave.ai/blog/opencode-task-board-more

2. **Task Board** ✓ Verified
   - New visualization tool for tracking work progress
   - Enables "developers and agents collaborate in real time"
   - Common workflow: planning tasks in one browser tab while agents implement them from the board in another
   - Link: https://tidewave.ai/blog/opencode-task-board-more

3. **Message Queue** ✓ Verified
   - Users can send messages to agents during their work cycles
   - Messages are "queued and delivered at the end of its turn, one by one"
   - Link: https://tidewave.ai/blog/opencode-task-board-more

4. **UI/UX Enhancements** ✓ Verified
   - Configurable font sizing
   - Optional auto-collapse toggle for thinking and tool calls
   - Direct Claude Code login from Tidewave's interface
   - Improved file path handling for WSL
   - API naming refinements
   - Link: https://tidewave.ai/blog/opencode-task-board-more

### Unverified Changes (Requires Verification)

The following features were mentioned in the research task brief but could not be explicitly verified in v0.5.6 release notes:

- **`:extra_apps` config** - **Requires verification** - Not found in publicly available documentation
- **Prompts/Resources listing** - **Requires verification** - Not found in publicly available documentation

### Note on Documentation

The Tidewave hex.pm package page and hexdocs.pm only show that "Publish documentation for release 0.5.6" occurred on 2026-03-13, but the GitHub releases page (https://github.com/tidewave-ai/tidewave_phoenix/releases) shows "There aren't any releases here," suggesting release notes are not published in the traditional GitHub releases format.

## MCP Tools Status

### Current MCP Tools in v0.5.6

Confirmed available MCP tools for Phoenix (and other frameworks):

1. **`project_eval`** - Execute Elixir code within the running application runtime
2. **`execute_sql_query`** - Run SQL queries against the application database
3. **`get_ecto_schemas`** - List all Ecto schema modules with fields and associations (Phoenix-specific)
4. **`get_ash_resources`** - List all Ash resources (when using the Ash framework)
5. **`get_docs`** - Retrieve documentation for modules/functions using exact project versions
6. **`search_package_docs`** - Query hexdocs.pm filtered to project dependencies (Next.js only in v0.5.5)
7. **`get_source_location`** - Find module/function source code file paths and line numbers
8. **`get_models`** - List all application modules with their file locations
9. **`get_logs`** - Access server logs written during development

**Status**: The existing reference documentation lists 9 MCP tools. Based on v0.5.6 documentation, all 9 appear to still be available. **Requires verification** - Whether any new tools were added in v0.5.6 beyond these 9.

**Framework Support Note**: Tool availability varies by framework. For Phoenix specifically:
- Available: project_eval, get_docs, get_source_location, get_logs, get_models/get_schemas, execute_sql_query, get_ecto_schemas, get_ash_resources
- Not available in Phoenix: search_package_docs (Next.js only)

Source: https://hexdocs.pm/tidewave/mcp.html

## Tidewave CLI App (tidewave_app)

### Overview
- **Repository**: https://github.com/tidewave-ai/tidewave_app
- **Language**: Rust
- **Type**: Desktop application + CLI tool
- **License**: Apache 2.0
- **Build Tool**: Tauri (v2.8.0)
- **Build Command**: `cargo tauri dev`

### Purpose and Functionality ✓ Verified
The CLI is a server component that:
- Runs as a standalone MCP server (not requiring Phoenix)
- Useful for running applications remotely, inside containers, or other cases where the desktop application is not an option
- Operates as an alternative to requiring a running Phoenix application with the Tidewave plug

### Installation ✓ Verified

**Desktop Application** (cross-platform):
- macOS: Apple Silicon and Intel versions
- Windows: Native executable
- Linux: AppImage formats for x86_64 and ARM64
- Installation available at: https://tidewave.ai/install

**CLI Installation** (Development):
```bash
cargo run -p tidewave-cli [-- --help]
```

### CLI Commands and Flags ✓ Partially Verified

**Default Operation**:
- Default HTTP server runs on: `http://localhost:9832`
- Access via browser at `http://localhost:9832`

**Available Flags** (for development purposes):
- `--https-port` - Configure HTTPS port
- `--https-cert-path` - Specify certificate location
- `--https-key-path` - Specify private key location
- `--help` - Display all available options and CLI flags

**Security**:
- CLI only allows access from the same machine by default
- Enforces localhost or 127.0.0.1 access only
- Server requires proper certificate/key configuration for HTTPS

### Relationship to Elixir MCP Server ✓ Verified

The tidewave_app CLI serves as:
- A **standalone alternative** to the Tidewave plug for Phoenix applications
- Enables MCP server functionality **without requiring a running Phoenix app**
- Useful for:
  - Container deployments
  - Remote development environments
  - Non-Phoenix Elixir projects
  - Development/testing MCP integrations

The Rust CLI and the Elixir plug provide **different deployment models** for the same MCP server capabilities - Phoenix applications use the plug (in `lib/my_app_web/endpoint.ex`), while other use cases use the standalone CLI.

Source: https://github.com/tidewave-ai/tidewave_app

## Current Version Verification

| Package | Version | Release Date | Status |
|---------|---------|--------------|--------|
| tidewave (Hex) | 0.5.6 | 2026-03-13 | Current |
| tidewave | 0.5.5 | 2026-02-10 | Previous |
| tidewave | 0.5.4 | 2026-01-06 | Earlier |
| tidewave-phoenix (GitHub) | Latest | Varies by tag | No releases published in GitHub Releases UI |
| tidewave-app (GitHub) | Latest | Varies by tag | No traditional releases page |

## Summary of Findings

### What We Know

1. **v0.5.6 released on 2026-03-13** - Confirmed
2. **OpenCode support, task board, message queue** - Confirmed features from February 2026 updates
3. **MCP tools unchanged at 9 tools** - Appears consistent between v0.5.5 and v0.5.6
4. **CLI app is Rust-based Tauri application** - Confirmed
5. **CLI provides standalone MCP server** - Confirmed
6. **Default port is 9832** - Confirmed

### What Requires Verification

1. **`:extra_apps` configuration** - Not found in public documentation
2. **Prompts/resources listing** - Not found in public documentation
3. **New MCP tools beyond the existing 9** - Not confirmed as new in v0.5.6
4. **Specific changelog/release notes for v0.5.6** - Not published in traditional GitHub releases format

## Sources

- https://hex.pm/packages/tidewave - Package information and version history
- https://hexdocs.pm/tidewave/ - Official v0.5.6 documentation
- https://hexdocs.pm/tidewave/mcp.html - MCP tools reference for v0.5.6
- https://tidewave.ai/blog/opencode-task-board-more - Blog post on recent features
- https://github.com/tidewave-ai/tidewave_phoenix - Tidewave for Phoenix repository
- https://github.com/tidewave-ai/tidewave_app - Tidewave CLI/Desktop app repository
- https://tidewave.ai/install - Desktop app installation page
