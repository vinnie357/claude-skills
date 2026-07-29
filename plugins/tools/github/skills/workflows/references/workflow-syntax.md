# Workflow Syntax Reference

Workflow file structure, trigger events, artifacts, caching, permissions, concurrency, reusable
workflows, performance optimization, and complete workflow examples. Job and step mechanics live in
jobs-and-steps.md; contexts and expression syntax in contexts-and-expressions.md.

## Contents

- [Workflow File Structure](#workflow-file-structure)
- [Trigger Events (on:)](#trigger-events-on)
- [Artifacts](#artifacts)
- [Caching](#caching)
- [Permissions](#permissions)
- [Concurrency](#concurrency)
- [Reusable Workflows](#reusable-workflows)
- [Performance Optimization](#performance-optimization)
- [Complete Workflow Examples](#complete-workflow-examples)

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
        uses: actions/checkout@v7   # Use an action

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

## Artifacts

### Upload Artifacts

```yaml
steps:
  - name: Build
    run: npm run build

  - name: Upload artifacts
    uses: actions/upload-artifact@v7
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
      - uses: actions/upload-artifact@v7
        with:
          name: dist
          path: dist/

  test:
    needs: build
    steps:
      - uses: actions/download-artifact@v8
        with:
          name: dist
          path: dist/
      - run: npm test
```

## Caching

### npm Cache

```yaml
steps:
  - uses: actions/checkout@v7
  - uses: actions/setup-node@v7
    with:
      node-version: '22'
      cache: 'npm'
  - run: npm ci
```

### Manual Cache

```yaml
steps:
  - uses: actions/cache@v6
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
      - uses: actions/checkout@v7
```

### Job-Level Permissions

```yaml
jobs:
  build:
    permissions:
      contents: read
      pull-requests: write
    steps:
      - uses: actions/checkout@v7
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
      - uses: actions/checkout@v7
      - uses: actions/setup-node@v7
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
      node-version: '22'
      coverage: true
    secrets:
      token: ${{ secrets.GITHUB_TOKEN }}
```

## Performance Optimization

### Use Caching

Cache dependencies to avoid re-downloading on every run — see [Caching](#caching) above for the
`setup-node` built-in cache and manual `actions/cache` configuration.

### Optimize Checkout

```yaml
- uses: actions/checkout@v7
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

## Complete Workflow Examples

Complete workflow artifacts to copy and adapt. The Node.js CI and monorepo path-filtering patterns
stay in the skill body because agents adapt them in-conversation.

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
      - uses: actions/checkout@v7

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build and push
        uses: docker/build-push-action@v7
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
      - uses: actions/checkout@v7
      - name: Deploy to production
        env:
          DEPLOY_KEY: ${{ secrets.DEPLOY_KEY }}
        run: ./deploy.sh
```
