# Jobs and Steps Reference

Job configuration, runner selection, matrix strategies, step mechanics, and environment variable
scoping. Workflow file shape and triggers live in workflow-syntax.md; contexts and expression
syntax in contexts-and-expressions.md.

## Contents

- [Jobs](#jobs)
- [Steps](#steps)
- [Environment Variables and Secrets](#environment-variables-and-secrets)

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
