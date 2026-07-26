# Task Files and Project Workflow Examples

Task-definition syntax and the `[tasks.*]` schema live in `SKILL.md`; this file holds file-based tasks and complete worked project setups.

## Table of Contents

- [Task files](#task-files)
- [Node.js project setup](#nodejs-project-setup)
- [Python project setup](#python-project-setup)
- [Monorepo setup](#monorepo-setup)
- [Multi-tool project](#multi-tool-project)

## Task files

Create separate task files:

```bash
# .mise/tasks/deploy
#!/bin/bash
# mise description="Deploy to production"
# mise depends=["build", "test"]

echo "Deploying..."
npm run deploy
```

Make executable:
```bash
chmod +x .mise/tasks/deploy
```

## Node.js project setup

```toml
# .mise.toml
[tools]
node = "20"

[env]
NODE_ENV = "development"

[tasks.install]
run = "npm install"

[tasks.dev]
run = "npm run dev"
depends = ["install"]

[tasks.build]
run = "npm run build"
depends = ["install"]

[tasks.test]
run = "npm test"
depends = ["install"]
```

```bash
# Setup and run
cd project
mise install      # Installs Node 20
mise dev         # Runs dev server
```

## Python project setup

```toml
# .mise.toml
[tools]
python = "3.12"

[env]
PYTHONPATH = "{{ config_root }}/src"

[tasks.venv]
run = "python -m venv .venv"

[tasks.install]
run = "pip install -r requirements.txt"
depends = ["venv"]

[tasks.test]
run = "pytest"
depends = ["install"]

[tasks.format]
run = "black src tests"
```

## Monorepo setup

```toml
# Root .mise.toml
[tools]
node = "20"
python = "3.12"

[env]
WORKSPACE_ROOT = "{{ config_root }}"

[tasks.install-all]
run = """
npm install
cd services/api && npm install
cd services/web && npm install
"""

[tasks.test-all]
depends = ["install-all"]
run = """
mise run test --dir services/api
mise run test --dir services/web
"""
```

## Multi-tool project

```toml
# .mise.toml
[tools]
node = "20"
python = "3.12"
ruby = "3.3"
go = "1.21"
terraform = "latest"

[env]
PROJECT_ROOT = "{{ config_root }}"
PATH = ["{{ config_root }}/bin", "$PATH"]

[tasks.setup]
description = "Setup all dependencies"
run = """
npm install
pip install -r requirements.txt
bundle install
go mod download
"""
```
