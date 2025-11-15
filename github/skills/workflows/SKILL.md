---
name: github-workflows
description: Write, configure, and optimize GitHub Actions workflows including syntax, triggers, jobs, contexts, expressions, artifacts, and CI/CD patterns
---

# GitHub Workflows

Activate when creating, modifying, debugging, or optimizing GitHub Actions workflow files. This skill covers workflow syntax, structure, best practices, and common CI/CD patterns.

## When to Use This Skill

Activate when:
- Writing .github/workflows/*.yml files
- Configuring workflow triggers and events
- Defining jobs, steps, and dependencies
- Using expressions and contexts
- Managing secrets and environment variables
- Implementing CI/CD pipelines
- Optimizing workflow performance
- Debugging workflow failures

## Workflow File Structure

### Basic Anatomy

```yaml
name: CI                              # Workflow name (optional)

on:                                   # Trigger events
  push:
    branches: [main, develop]
  pull_request:

env:                                  # Global environment variables
  NODE_VERSION: '20'

jobs:                                 # Job definitions
  build:
    name: Build and Test            # Job name (optional)
    runs-on: ubuntu-latest          # Runner environment

    steps:
      - name: Checkout code         # Step name (optional)
        uses: actions/checkout@v4   # Use an action

      - name: Run tests
        run: npm test               # Run command
```

### File Location

Workflows must be in `.github/workflows/` directory:
```
.github/
└── workflows/
    ├── ci.yml
    ├── deploy.yml
    └── release.yml
```

## Trigger Events (on:)

### Push Events

```yaml
on:
  push:
    branches:
      - main
      - 'release/**'        # Glob patterns
    tags:
      - 'v*'                # Version tags
    paths:
      - 'src/**'            # Only when these paths change
      - '!docs/**'          # Ignore docs changes
```

### Pull Request Events

```yaml
on:
  pull_request:
    types:
      - opened
      - synchronize       # New commits pushed
      - reopened
    branches:
      - main
    paths-ignore:
      - '**.md'
```

### Schedule (Cron)

```yaml
on:
  schedule:
    # Every day at 2am UTC
    - cron: '0 2 * * *'
    # Every Monday at 9am UTC
    - cron: '0 9 * * 1'
```

### Manual Trigger (workflow_dispatch)

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Deployment environment'
        required: true
        type: choice
        options:
          - development
          - staging
          - production
      debug:
        description: 'Enable debug logging'
        required: false
        type: boolean
        default: false
```

### Multiple Events

```yaml
on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
```

## Jobs

### Basic Job Configuration

```yaml
jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
```

### Runner Selection

```yaml
jobs:
  test:
    runs-on: ubuntu-latest        # Ubuntu (fastest, most common)

  test-macos:
    runs-on: macos-latest         # macOS

  test-windows:
    runs-on: windows-latest       # Windows

  test-specific:
    runs-on: ubuntu-22.04         # Specific version
```

### Matrix Strategy

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        node: [18, 20, 21]
        exclude:
          - os: macos-latest
            node: 18
      fail-fast: false            # Continue on failure
      max-parallel: 4             # Concurrent jobs limit

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

### Job Dependencies

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: npm run build

  test:
    needs: build                  # Wait for build
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  deploy:
    needs: [build, test]          # Wait for multiple jobs
    runs-on: ubuntu-latest
    steps:
      - run: npm run deploy
```

### Conditional Execution

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - run: npm run deploy

  notify:
    if: failure()                 # Run only if previous jobs failed
    needs: [build, test]
    runs-on: ubuntu-latest
    steps:
      - run: echo "Build failed"
```

## Steps

### Using Actions

```yaml
steps:
  - name: Checkout repository
    uses: actions/checkout@v4
    with:
      fetch-depth: 0              # Full history
      submodules: recursive       # Include submodules

  - name: Setup Node.js
    uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
```

### Running Commands

```yaml
steps:
  - name: Single command
    run: npm install

  - name: Multi-line script
    run: |
      echo "Installing dependencies"
      npm ci
      npm run build

  - name: Shell selection
    shell: bash
    run: echo "Using bash"
```

### Conditional Steps

```yaml
steps:
  - name: Run on main branch only
    if: github.ref == 'refs/heads/main'
    run: npm run deploy

  - name: Run on PR only
    if: github.event_name == 'pull_request'
    run: npm run test:pr
```

### Continue on Error

```yaml
steps:
  - name: Lint (optional)
    continue-on-error: true
    run: npm run lint

  - name: Test (required)
    run: npm test
```

## Environment Variables and Secrets

### Global Variables

```yaml
env:
  NODE_ENV: production
  API_URL: https://api.example.com

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo $NODE_ENV
```

### Job-Level Variables

```yaml
jobs:
  build:
    env:
      BUILD_TYPE: release
    steps:
      - run: echo $BUILD_TYPE
```

### Step-Level Variables

```yaml
steps:
  - name: Configure
    env:
      CONFIG_PATH: ./config.json
    run: cat $CONFIG_PATH
```

### Using Secrets

```yaml
steps:
  - name: Deploy
    env:
      API_KEY: ${{ secrets.API_KEY }}
      DB_PASSWORD: ${{ secrets.DB_PASSWORD }}
    run: ./deploy.sh
```

### Setting Variables Between Steps

```yaml
steps:
  - name: Set version
    id: version
    run: echo "VERSION=$(cat version.txt)" >> $GITHUB_OUTPUT

  - name: Use version
    run: echo "Version is ${{ steps.version.outputs.VERSION }}"
```

## Contexts

### github Context

```yaml
steps:
  - name: Context information
    run: |
      echo "Repository: ${{ github.repository }}"
      echo "Branch: ${{ github.ref_name }}"
      echo "SHA: ${{ github.sha }}"
      echo "Actor: ${{ github.actor }}"
      echo "Event: ${{ github.event_name }}"
      echo "Run ID: ${{ github.run_id }}"
```

### env Context

```yaml
env:
  MY_VAR: value

steps:
  - run: echo "${{ env.MY_VAR }}"
```

### job Context

```yaml
steps:
  - name: Job status
    if: job.status == 'success'
    run: echo "Job succeeded"
```

### steps Context

```yaml
steps:
  - id: first-step
    run: echo "output=hello" >> $GITHUB_OUTPUT

  - run: echo "${{ steps.first-step.outputs.output }}"
```

### runner Context

```yaml
steps:
  - run: |
      echo "OS: ${{ runner.os }}"
      echo "Arch: ${{ runner.arch }}"
      echo "Temp: ${{ runner.temp }}"
```

### matrix Context

```yaml
strategy:
  matrix:
    version: [18, 20]

steps:
  - run: echo "Node ${{ matrix.version }}"
```

## Expressions

### Operators

```yaml
steps:
  # Comparison
  - if: github.ref == 'refs/heads/main'

  # Logical
  - if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  - if: github.event_name == 'pull_request' || github.event_name == 'push'

  # Negation
  - if: "!cancelled()"

  # Contains
  - if: contains(github.event.head_commit.message, '[skip ci]')

  # StartsWith/EndsWith
  - if: startsWith(github.ref, 'refs/tags/v')
  - if: endsWith(github.ref, '-beta')
```

### Functions

```yaml
steps:
  # Status functions
  - if: success()        # Previous steps succeeded
  - if: failure()        # Any previous step failed
  - if: always()         # Always run
  - if: cancelled()      # Workflow cancelled

  # String functions
  - run: echo "${{ format('Hello {0}', github.actor) }}"
  - if: contains(github.event.pull_request.labels.*.name, 'deploy')

  # JSON functions
  - run: echo '${{ toJSON(github.event) }}'
  - run: echo '${{ fromJSON(env.CONFIG).database.host }}'

  # Hash function
  - run: echo "${{ hashFiles('**/package-lock.json') }}"
```

## Artifacts

### Upload Artifacts

```yaml
steps:
  - name: Build
    run: npm run build

  - name: Upload artifacts
    uses: actions/upload-artifact@v4
    with:
      name: build-files
      path: |
        dist/
        build/
      retention-days: 7
      if-no-files-found: error
```

### Download Artifacts

```yaml
jobs:
  build:
    steps:
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  test:
    needs: build
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: dist
          path: dist/
      - run: npm test
```

## Caching

### npm Cache

```yaml
steps:
  - uses: actions/checkout@v4
  - uses: actions/setup-node@v4
    with:
      node-version: '20'
      cache: 'npm'
  - run: npm ci
```

### Manual Cache

```yaml
steps:
  - uses: actions/cache@v4
    with:
      path: |
        ~/.npm
        node_modules
      key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
      restore-keys: |
        ${{ runner.os }}-node-
```

## Permissions

### Repository Token Permissions

```yaml
permissions:
  contents: read              # Repository content
  pull-requests: write        # PR comments
  issues: write              # Issue creation/comments
  checks: write              # Check runs
  statuses: write            # Commit statuses
  deployments: write         # Deployments
  packages: write            # Package registry

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
```

### Job-Level Permissions

```yaml
jobs:
  build:
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v4
```

## Concurrency

### Prevent Concurrent Runs

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true    # Cancel running workflows

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

### Job-Level Concurrency

```yaml
jobs:
  deploy:
    concurrency:
      group: deploy-${{ github.ref }}
      cancel-in-progress: false
    steps:
      - run: ./deploy.sh
```

## Reusable Workflows

### Define Reusable Workflow

```yaml
# .github/workflows/reusable-test.yml
name: Reusable Test Workflow

on:
  workflow_call:
    inputs:
      node-version:
        required: true
        type: string
      coverage:
        required: false
        type: boolean
        default: false
    outputs:
      test-result:
        description: "Test execution result"
        value: ${{ jobs.test.outputs.result }}
    secrets:
      token:
        required: true

jobs:
  test:
    runs-on: ubuntu-latest
    outputs:
      result: ${{ steps.test.outputs.result }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
      - run: npm test
        id: test
```

### Call Reusable Workflow

```yaml
jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      node-version: '20'
      coverage: true
    secrets:
      token: ${{ secrets.GITHUB_TOKEN }}
```

## Common CI/CD Patterns

### Node.js CI

```yaml
name: Node.js CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: [18, 20, 21]

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm test
      - run: npm run build
```

### Docker Build and Push

```yaml
name: Docker

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
```

### Deploy on Release

```yaml
name: Deploy

on:
  release:
    types: [published]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com

    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        env:
          DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
        run: ./deploy.sh
```

### Monorepo with Path Filtering

```yaml
name: Monorepo CI

on:
  pull_request:
    paths:
      - 'packages/**'

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.filter.outputs.frontend }}
      backend: ${{ steps.filter.outputs.backend }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            frontend:
              - 'packages/frontend/**'
            backend:
              - 'packages/backend/**'

  test-frontend:
    needs: detect-changes
    if: needs.detect-changes.outputs.frontend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: npm test --workspace=frontend

  test-backend:
    needs: detect-changes
    if: needs.detect-changes.outputs.backend == 'true'
    runs-on: ubuntu-latest
    steps:
      - run: npm test --workspace=backend
```

## Debugging Workflows

### Enable Debug Logging

Set repository secrets:
- `ACTIONS_RUNNER_DEBUG`: true
- `ACTIONS_STEP_DEBUG`: true

### Debug Steps

```yaml
steps:
  - name: Debug context
    run: |
      echo "Event: ${{ github.event_name }}"
      echo "Ref: ${{ github.ref }}"
      echo "SHA: ${{ github.sha }}"
      echo "Actor: ${{ github.actor }}"

  - name: Dump GitHub context
    run: echo '${{ toJSON(github) }}'

  - name: Dump runner context
    run: echo '${{ toJSON(runner) }}'
```

### Tmate Debugging

```yaml
steps:
  - name: Setup tmate session
    if: failure()
    uses: mxschmitt/action-tmate@v3
    timeout-minutes: 30
```

## Performance Optimization

### Use Caching

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
```

### Optimize Checkout

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 1              # Shallow clone
    sparse-checkout: |          # Partial checkout
      src/
      tests/
```

### Concurrent Jobs

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  build:
    needs: [lint, test]         # Parallel lint and test
    runs-on: ubuntu-latest
    steps:
      - run: npm run build
```

## Anti-Fabrication Requirements

- Execute Read tool to verify workflow files exist before claiming structure
- Use Bash with `gh workflow list` to confirm actual workflow names before referencing them
- Execute `gh workflow view <workflow>` to verify trigger configuration before documenting it
- Use Glob to find actual workflow files before claiming their presence
- Execute `gh run list` to verify actual workflow runs before discussing execution patterns
- Never claim workflow success rates without actual run history analysis
- Validate YAML syntax using yamllint or similar tools via Bash before claiming correctness
- Report actual permission errors from workflow runs, not fabricated authorization issues
- Execute actual cache operations before claiming cache hit/miss percentages
- Use Read tool on action.yml files to verify action inputs/outputs before documenting usage
