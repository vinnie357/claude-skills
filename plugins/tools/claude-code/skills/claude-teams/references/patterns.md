# Multi-Agent Patterns

Proven patterns for coordinating multiple Claude Code agents.

## When to Use Agent Teams

Strong use cases:
- **Research and review**: Multiple teammates investigate different aspects simultaneously, then share and challenge findings
- **New modules or features**: Each teammate owns a separate piece without stepping on each other
- **Debugging with competing hypotheses**: Teammates test different theories in parallel
- **Cross-layer coordination**: Changes spanning frontend, backend, and tests, each owned by a different teammate

## Scaling Guidance

The recommended sweet spot is **2-5 teammates with 5-6 tasks each**.

3 teammates often outperform 6. Adding more agents increases coordination overhead and the risk of merge conflicts.

## File Ownership

Two teammates editing the same file leads to overwrites. Break work so each teammate owns a different set of files.

Strategies:
- **Module boundaries**: Each agent owns a distinct module or package
- **Layer separation**: Frontend agent, backend agent, test agent
- **Feature slicing**: Each agent implements a complete vertical slice

## Task Decomposition

Effective task decomposition for agent teams:

1. **Independent tasks**: Break work into pieces that do not depend on each other
2. **Clear boundaries**: Each task should have well-defined inputs and outputs
3. **Right granularity**: Not too small (overhead) or too large (bottleneck)
4. **Dependency ordering**: Declare dependencies so blocked tasks auto-unblock

## Quality Gates

Use hooks to enforce quality standards:

### TeammateIdle Hook

Prevent teammates from going idle prematurely:

```bash
#!/bin/bash
# Exit code 2 keeps the teammate working
if [ "$(git diff --stat)" != "" ]; then
  echo "You have uncommitted changes. Run tests before going idle."
  exit 2
fi
```

### TaskCompleted Hook

Validate work before marking tasks complete:

```bash
#!/bin/bash
# Exit code 2 prevents completion
if ! npm test 2>/dev/null; then
  echo "Tests are failing. Fix tests before completing this task."
  exit 2
fi
```

## Coordination via Shared Task List

The `CLAUDE_CODE_TASK_LIST_ID` environment variable points multiple Claude instances at the same task list, enabling coordination without the full Agent Teams feature.

Task primitives:
- **TaskCreate**: Initialize work units with subject, description, and activeForm
- **TaskUpdate**: Claim tasks, set status, declare dependencies
- **TaskList**: View all tasks with status and ownership
- **TaskGet**: Retrieve full task details

The status field prevents duplicate work: when a task is `in_progress` with an owner, other agents skip it.

## Git Worktree Isolation

For truly independent parallel work, use git worktrees:

```yaml
---
name: experimental-worker
description: Works on experimental changes in isolation
isolation: worktree
---
```

Each agent gets its own copy of the repository. Worktrees are cleaned up if no changes are made.

For manual multi-agent setups, create worktrees explicitly:

```bash
git worktree add ../project-agent-1 -b agent-1-branch
git worktree add ../project-agent-2 -b agent-2-branch
```

## Case Study: C Compiler with 16 Agents

Anthropic used 16 parallel Claude Code agents to build a Rust-based C compiler capable of compiling the Linux kernel.

**Source**: https://www.anthropic.com/engineering/building-c-compiler

Architecture:
- Bare git repo with Docker containers per agent
- Each agent clones a local copy, pushes results upstream
- Agents lock tasks by writing text files to `current_tasks/`
- Each agent picks the "next most obvious" failing test or sub-task
- Merge conflicts are frequent but agents resolve them independently

Scale: ~2,000 sessions, ~100,000 lines of output code.

## Anti-Patterns

### Too Many Agents
More agents does not mean faster results. Coordination overhead and merge conflicts increase with team size.

### Shared File Editing
Multiple agents editing the same file causes overwrites and lost work. Assign clear file ownership.

### Monolithic Tasks
Large tasks that cannot be parallelized negate the benefit of multiple agents. Decompose into independent units.

### Missing Dependencies
Failing to declare task dependencies leads to agents working on blocked tasks or building on incomplete foundations.

### Lead Doing Implementation
The team lead should coordinate, not implement. Use delegate mode (`Shift+Tab`) to enforce this.
