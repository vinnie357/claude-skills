# Dagu Plugin Sources

This file documents the sources used to create the dagu plugin skills.

Structured tracking: [sources.toml](sources.toml) — versions, check methods, and skill coverage live there.

## Dagu Workflows Skill

### Dagu Official Documentation
- **URL**: https://docs.dagu.cloud/
- **Purpose**: Workflow orchestration tool with web UI and REST API
- **Date Accessed**: 2025-11-15
- **Key Topics**: Workflow authoring, web UI operations, REST API integration

### Workflow Authoring Guide
- **URL**: https://docs.dagu.cloud/workflows/
- **Purpose**: Guide for creating Dagu workflows
- **Key Topics**:
  - YAML workflow syntax
  - Step definitions
  - Executors (command, http, email, etc.)
  - Scheduling and cron expressions
  - Dependencies between steps
  - Environment variables
  - Parameters and variables
  - Conditional execution
  - Error handling and retries

### Workflow Configuration
- **URL**: https://docs.dagu.cloud/config/
- **Purpose**: Detailed workflow configuration options
- **Key Topics**:
  - Global settings
  - Step configuration
  - Preconditions and postconditions
  - Timeout settings
  - Resource limits

## Web UI Skill

### Dagu Web UI Documentation
- **URL**: https://docs.dagu.cloud/web-ui/
- **Purpose**: Using the Dagu Web UI to manage and monitor workflows
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Dashboard overview
  - Workflow management (create, edit, delete)
  - Execution monitoring
  - Log viewing
  - Manual workflow triggering
  - Execution history
  - Workflow status and visualization

## REST API Skill

### Dagu REST API Documentation
- **URL**: https://docs.dagu.cloud/api/
- **Purpose**: Programmatically manage and execute workflows via REST API
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - API endpoints overview
  - Authentication
  - Workflow CRUD operations
  - Triggering workflow executions
  - Querying execution status
  - Retrieving execution logs
  - Canceling running workflows
  - Listing workflows and executions

### API Integration Patterns
- **URL**: https://docs.dagu.cloud/integration/
- **Purpose**: Integrating Dagu with external systems
- **Key Topics**:
  - Webhook integration
  - CI/CD pipeline integration
  - Event-driven workflows
  - External service triggers
