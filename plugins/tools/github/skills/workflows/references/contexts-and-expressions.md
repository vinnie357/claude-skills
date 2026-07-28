# Contexts and Expressions Reference

Context objects available inside `${{ }}` expressions, plus operators and built-in functions.
Workflow file shape and triggers live in workflow-syntax.md; job and step mechanics in
jobs-and-steps.md.

## Contents

- [Contexts](#contexts)
- [Expressions](#expressions)

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

  # Negation — quote it: a bare leading ! is a YAML tag
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
