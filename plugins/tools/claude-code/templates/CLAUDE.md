Before starting any work, make sure you have used `bees ready` (/core:bees) or `bd ready` (/core:beads).
load our /core:bees or /core:beads skill depending on which tracker is initialized in the project.
if you find neither, use our /core:bees skill to setup bees.
to ensure we are working on an epic or task created and tracked by one of these project tracking tools.
all epics should be aware of claude-code teams, and have teams defined in the epic with models assigned by complexity of the task, all epics should have
tasks that are claude skills aware, the primary library of skills available is here: https://github.com/vinnie357/claude-skills/blob/main/.claude-plugin/marketplace.json
if the task needs a skill you don't have suggest or ask the user for this new skill.

Phase 1: Pre flight checks
- use `bees ready` or `bd ready` to look for open work items
- make sure the epic you are working, has a team defined with the relevent models for each team member
- a members model should attempt to use haiku first if possible based on the complexity of their task
- all tasks must have relevent skills for the work, eg: elixir skill when working with elixir
- ensure all the core skills are loaded:  /core:*
- instruct team members/tasks to always load these core skills first:
    - /core:anti-fabrication
    - /core:git
    - /core:tdd
    - /core:twelve-factor
    - /core:security
    - /core:mise
    - /core:nushell
- all tasks must use the claude task-list tool to work their items
- check that we are working on a feature branch per epic
- verify feature branch exists for the epic
- label all team members with their model

Phase 2: Working the items
- ask clarifying questions to the user
- spawn teamm members for all tasks including simple ones, like research or running tests
- instruct team members to use the claude task-list tool for all their work items
- instruct team members to load their tasks labels skills on start
- instruct team members that code without tests is not complete /core:tdd
- include existing code references (file paths, function names) in every agent prompt
- use jq for JSON parsing, nushell for scripts
- if a team member fails in a task twice, collect the members summary,then spawn the agent agent with the summary and promote the model it is using, haiku -> sonnet -> opus

Phase 3: Validation
- assign a haiku agent by default to run the strictest linting and validation possible for each language
    - eg: elixir code, mix format, mix compile --warnings-as-errors, mix test --warnings-as-errors --max-failures=1, mix credo --strict ( mise run ci, or mix ci task)
- have the agent pass each test runs results to another agent to address fixes and issues
- this validation group should work in concert to address all issues found by `mise run ci`, or the languages strictest test/linting/ci suite.
- if the project doesn't have a `mise run ci` command, we should use the /core:mise skill to make one
- run gitleaks between commit and push
- Code without tests is not complete /core:tdd

Phase 4: Submit loop
- we never commit or pr with attribution
- we give summary prs without a changes section as git has the diff
- agents never merge — they report PR URL and wait
- step order: local CI → commit → gitleaks → push → PR → watch remote CI → notify
- we wait for ci to pass then ask the user to squash merge and delete the merged branch
- once merged, close the tracker issue (bees or beads), commit the tracker state, and push
- we checkout main, pull and delete our merged feature branch
- we go back to Phase1 to work a new epic