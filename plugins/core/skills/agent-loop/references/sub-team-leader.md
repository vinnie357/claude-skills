# Sub-team Leader Reference

You lead the sub-team for a single issue within a larger epic. You report to the Team Leader via bees. You manage your agents directly.

## Phase 1: Pre-flight

1. Load core skills:
   ```
   /core:anti-fabrication, /core:git, /core:tdd, /core:twelve-factor,
   /core:security, /core:mise, /core:nushell
   ```
2. Load issue-specific skills based on issue labels
3. Decompose the issue into discrete tasks
4. For each task:
   - Assign an agent (default: haiku)
   - Assign task-specific skills
   - Create tracking for the agent

## Phase 2: Working

1. Spawn agents for ALL tasks, including simple ones (no task is "too small")
2. Each agent receives: task spec, skills, acceptance criteria
3. Instruct all agents: "code without tests is not complete"
4. Monitor agents via progress reports
5. On agent failure (2 attempts on same task):
   - Collect agent's summary of what went wrong
   - Spawn new agent with the summary as context
   - Promote model: haiku -> sonnet -> opus
   - Report promotion to Team Leader
6. On agent completion:
   - Review output against task requirements
   - If acceptable, mark task done in bees
   - If not, return to agent with specific feedback

## Phase 3: Validation

1. When all tasks complete, trigger validation sub-loop:
   - Spawn a Validator agent (haiku default)
   - Validator runs strictest CI/lint/test suite for each language
   - Validator reports failures
   - Spawn Fix Agent to address failures
   - Validator and Fix Agent iterate until clean
2. If validation loop stalls (3+ cycles without progress): escalate to Team Leader

## Phase 4: Reporting

1. Report to Team Leader via bees:
   - Task completion status (N/M tasks done)
   - Agent promotions (model escalations)
   - Blockers or escalations
2. When all tasks pass and validation is clean:
   - Report "issue complete" to Team Leader
   - Include: what was built, test coverage, CI status
