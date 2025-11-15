# Elixir Plugin Sources

This file documents the sources used to create the elixir plugin skills.

## Anti-Patterns Skill

### Elixir Anti-Patterns Documentation
- **URL**: https://hexdocs.pm/elixir/what-anti-patterns.html
- **Purpose**: Foundation for the Elixir anti-patterns skill
- **Date Accessed**: 2025-11-15
- **Categories**:
  - Code-related anti-patterns
  - Design-related anti-patterns
  - Process-related anti-patterns
  - Meta-programming-related anti-patterns

### Code-Related Anti-Patterns
- **URL**: https://hexdocs.pm/elixir/code-anti-patterns.html
- **Purpose**: Detailed code-level anti-patterns in Elixir
- **Key Topics**: Comments overuse, complex else clauses, dynamic atom creation, namespace trespassing

### Design-Related Anti-Patterns
- **URL**: https://hexdocs.pm/elixir/design-anti-patterns.html
- **Purpose**: Design and architectural anti-patterns in Elixir
- **Key Topics**: Alternative return types, boolean obsession, exceptions for control-flow, primitive obsession

## Phoenix Skill

### Phoenix Framework Documentation
- **URL**: https://hexdocs.pm/phoenix/
- **Purpose**: Official Phoenix web framework documentation
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Phoenix LiveView
  - Contexts and domain design
  - Channels and real-time features
  - Ecto integration
  - Testing Phoenix applications

### Phoenix Guides
- **URL**: https://hexdocs.pm/phoenix/overview.html
- **Purpose**: Comprehensive guides for building Phoenix applications
- **Key Topics**: Routing, controllers, views, templates, contexts, testing

## OTP Skill

### Elixir OTP Documentation
- **URL**: https://hexdocs.pm/elixir/GenServer.html
- **Purpose**: Building concurrent, fault-tolerant systems using OTP
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - GenServer: Generic server behavior
  - Supervisor: Process supervision trees
  - Task: Async/await operations
  - Agent: Simple state management
  - DynamicSupervisor: Runtime child processes

### Erlang OTP Design Principles
- **URL**: https://www.erlang.org/doc/design_principles/des_princ.html
- **Purpose**: Understanding OTP design patterns and principles
- **Key Topics**: Behaviors, supervision trees, applications, releases

## Testing Skill

### ExUnit Documentation
- **URL**: https://hexdocs.pm/ex_unit/
- **Purpose**: Elixir's built-in testing framework
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Test organization and structure
  - Assertions and refutations
  - Test setup and teardown
  - Async testing
  - Test tagging and filtering

### Property-Based Testing
- **URL**: https://hexdocs.pm/stream_data/
- **Purpose**: Property-based testing with StreamData
- **Key Topics**: Generators, properties, shrinking, stateful testing

## Config Skill

### Elixir Config Module
- **URL**: https://hexdocs.pm/elixir/Config.html
- **Purpose**: Foundation for the Elixir config skill - application configuration management
- **Date Accessed**: 2025-11-15
- **Key Topics**:
  - Config module overview and migration from Mix.Config
  - config/config.exs (compile-time configuration)
  - config/runtime.exs (runtime configuration)
  - Configuration functions: config/2, config/3, config_env(), config_target()
  - import_config/1 for file imports
  - Deep-merging behavior for keyword lists
  - Library configuration limitations

### Elixir Application Module
- **URL**: https://hexdocs.pm/elixir/Application.html
- **Purpose**: Accessing application configuration at runtime vs compile-time
- **Key Topics**:
  - Application.compile_env/3 and Application.compile_env!/2 (compile-time)
  - Application.get_env/3 (runtime with defaults)
  - Application.fetch_env/2 and Application.fetch_env!/2 (runtime with explicit errors)
  - Runtime vs compile-time configuration trade-offs
  - Best practices for library vs application configuration
  - Configuration access patterns and anti-patterns

## Plugin Information

- **Name**: elixir
- **Version**: 0.1.0
- **Description**: Elixir development skills: Phoenix, OTP, testing, configuration, and anti-patterns
- **Skills**: 5 skills covering Elixir language, framework, and best practices
- **Created**: 2025-11-15
