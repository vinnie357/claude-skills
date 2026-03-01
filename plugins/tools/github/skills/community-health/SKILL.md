---
name: github-community-health
description: Guide for setting up GitHub community health files for open source repositories. Use when preparing repos for public release, adding community standards files, or configuring issue/PR templates.
---

# GitHub Community Health

Activate when setting up or auditing community health files for GitHub repositories. This skill covers the files GitHub checks in its Community Standards profile, plus related repo configuration.

## When to Use This Skill

Activate when:
- Preparing a repository for public/open-source release
- Adding or updating community standards files (CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, etc.)
- Setting up issue or pull request templates
- Configuring CODEOWNERS or FUNDING.yml
- Auditing a repo against GitHub's community profile checklist
- Setting repo-level configuration (merge strategy, branch protection, topics)

## Community Profile Checklist

GitHub checks these 6 items on the `/community` tab:

1. **README** — project overview, usage, and getting started
2. **LICENSE** — open-source license file in repo root
3. **CODE_OF_CONDUCT.md** — community behavior standards
4. **CONTRIBUTING.md** — how to contribute
5. **Issue templates** — structured bug/feature reporting
6. **SECURITY.md** — vulnerability disclosure policy

Check current status:
```bash
# View community profile metrics via API
gh api repos/{owner}/{repo}/community/profile
```

## GitHub Template APIs

GitHub provides APIs to fetch common templates at runtime. Always fetch rather than hardcode — templates get updated.

```bash
# List available license templates (13 licenses)
gh api licenses --jq '.[].key'

# Fetch a specific license body
gh api licenses/mit --jq '.body'

# Fetch Code of Conduct (note: API serves v2.0, not latest v3.0)
gh api codes_of_conduct/contributor_covenant --jq '.body'

# List available gitignore templates
gh api gitignore/templates

# Fetch a specific gitignore template
gh api gitignore/templates/Node --jq '.source'
```

## LICENSE

Use the GitHub API to list and fetch license templates:

```bash
# List all available licenses
gh api licenses --jq '.[] | "\(.key): \(.name)"'

# Fetch license text (has [year] and [fullname] placeholders)
gh api licenses/mit --jq '.body'
gh api licenses/apache-2.0 --jq '.body'
gh api licenses/gpl-3.0 --jq '.body'
```

After fetching, replace placeholders:
- `[year]` — current year (or year range)
- `[fullname]` — copyright holder name

Place the file as `LICENSE` (no extension) in the repository root.

## CODE_OF_CONDUCT.md

The GitHub API serves Contributor Covenant **v2.0**, but the latest version is **v3.0** (available at contributor-covenant.org).

**Preferred approach** — fetch latest from the source:
```bash
# Fetch Contributor Covenant v3.0 (latest)
curl -sL https://www.contributor-covenant.org/version/3/0/code_of_conduct.md
```

**Fallback** — use the GitHub API (v2.0):
```bash
gh api codes_of_conduct/contributor_covenant --jq '.body'
```

Customize these fields:
- **Contact method** — email, issue tracker, or reporting form
- **Project name** — replace placeholder with actual project name
- **Scope** — define where the CoC applies (repo, events, social media)

Place as `CODE_OF_CONDUCT.md` in the repo root or `.github/` directory.

## CONTRIBUTING.md

Structure the guide with these sections:

```markdown
# Contributing to {project}

## Getting Started
- Fork and clone the repo
- Install dependencies
- Run the test suite

## Development Setup
- Required tools and versions
- Environment configuration
- Build commands

## How to Contribute

### Bug Reports
- Use the bug report issue template
- Include reproduction steps
- Attach logs or screenshots

### Feature Requests
- Use the feature request issue template
- Describe the use case
- Explain expected behavior

### Pull Requests
- Branch from `main`
- Follow the code style guide
- Write/update tests
- Update documentation
- Reference related issues

## Style Guide
- Language-specific conventions
- Linting and formatting tools
- Commit message format

## Code of Conduct
This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
```

Place as `CONTRIBUTING.md` in the repo root or `.github/` directory.

## Issue Templates

GitHub supports YAML-based issue forms. Place templates in `.github/ISSUE_TEMPLATE/`.

### Configuration

`.github/ISSUE_TEMPLATE/config.yml` — controls the template chooser:
```yaml
blank_issues_enabled: false
contact_links:
  - name: Questions & Discussions
    url: https://github.com/{owner}/{repo}/discussions
    about: Ask questions in Discussions instead of opening issues
```

### Bug Report Template

`.github/ISSUE_TEMPLATE/bug_report.yml`:
```yaml
name: Bug Report
description: Report a bug or unexpected behavior
title: "[Bug]: "
labels: ["bug", "triage"]
body:
  - type: markdown
    attributes:
      value: Thanks for reporting a bug!
  - type: textarea
    id: description
    attributes:
      label: Description
      description: What happened? What did you expect?
    validations:
      required: true
  - type: textarea
    id: reproduction
    attributes:
      label: Steps to Reproduce
      description: Minimal steps to reproduce the issue
      placeholder: |
        1. Run '...'
        2. See error
    validations:
      required: true
  - type: input
    id: version
    attributes:
      label: Version
      description: Which version are you using?
    validations:
      required: true
  - type: dropdown
    id: os
    attributes:
      label: Operating System
      options:
        - macOS
        - Linux
        - Windows
    validations:
      required: true
  - type: textarea
    id: logs
    attributes:
      label: Relevant Logs
      description: Paste any error output or logs
      render: shell
```

### Feature Request Template

`.github/ISSUE_TEMPLATE/feature_request.yml`:
```yaml
name: Feature Request
description: Suggest a new feature or improvement
title: "[Feature]: "
labels: ["enhancement"]
body:
  - type: textarea
    id: problem
    attributes:
      label: Problem
      description: What problem does this solve?
    validations:
      required: true
  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: How should this work?
    validations:
      required: true
  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: What other approaches did you consider?
  - type: textarea
    id: context
    attributes:
      label: Additional Context
      description: Any other relevant information
```

## Pull Request Template

`.github/PULL_REQUEST_TEMPLATE.md`:
```markdown
## Summary
<!-- Brief description of changes -->

## Changes
-

## Testing
- [ ] Tests pass locally
- [ ] New tests added for new functionality

## Checklist
- [ ] Code follows project style guide
- [ ] Documentation updated
- [ ] No breaking changes (or documented in summary)

## Related Issues
<!-- Closes #123 -->
```

## SECURITY.md

Define a vulnerability disclosure policy:

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| x.x.x   | :white_check_mark: |
| < x.x.x | :x:                |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

To report a vulnerability:
1. Use [GitHub Security Advisories](https://github.com/{owner}/{repo}/security/advisories/new)
2. Or email: security@example.com

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

## Response Timeline

- **Acknowledgment**: within 48 hours
- **Initial assessment**: within 1 week
- **Fix timeline**: depends on severity

## Disclosure Policy

We follow coordinated disclosure. We ask reporters to:
- Allow reasonable time for a fix before public disclosure
- Avoid exploiting the vulnerability beyond what is needed to demonstrate it
```

Place as `SECURITY.md` in the repo root or `.github/` directory. GitHub detects it automatically and shows a "Security policy" link on the Security tab.

## .gitignore

Use the GitHub API to fetch language-specific templates:

```bash
# List all available templates
gh api gitignore/templates --jq '.[]'

# Fetch a single template
gh api gitignore/templates/Node --jq '.source'

# Combine multiple templates
{
  echo "# Node"
  gh api gitignore/templates/Node --jq '.source'
  echo ""
  echo "# macOS"
  gh api gitignore/templates/macOS --jq '.source'
} > .gitignore
```

Always fetch from the API rather than writing from memory — templates evolve with tooling changes.

## CODEOWNERS

Define code ownership for automatic PR review assignment. Place as `CODEOWNERS` in the repo root, `docs/`, or `.github/` directory.

**Syntax:**
```
# Default owners for everything
*       @org/team-leads

# Specific paths
/src/auth/       @security-team
/docs/           @docs-team
*.tf             @infra-team

# Multiple owners (all are requested)
/src/api/        @backend-team @api-reviewers

# Override for specific files
/src/api/README.md  @docs-team
```

**Key behaviors:**
- Later rules override earlier ones for the same file
- Owners are requested as reviewers automatically on PRs
- Pair with branch protection's "Require review from Code Owners" for enforcement

```bash
# Enable required reviews from CODEOWNERS via branch protection
gh api repos/{owner}/{repo}/branches/main/protection -X PUT \
  -f 'required_pull_request_reviews[dismiss_stale_reviews]=true' \
  -f 'required_pull_request_reviews[require_code_owner_reviews]=true' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -F 'enforce_admins=true'
```

## FUNDING.yml

Configure the GitHub Sponsors button. Place as `.github/FUNDING.yml`:

```yaml
# GitHub Sponsors
github: [username]

# Other platforms
patreon: username
open_collective: project-name
ko_fi: username
custom: ["https://example.com/donate"]
```

Supported platforms: `github`, `patreon`, `open_collective`, `ko_fi`, `tidelift`, `community_bridge`, `liberapay`, `issuehunt`, `lfx_crowdfunding`, `polar`, `buy_me_a_coffee`, `thanks_dev`, `custom`.

## Repo Settings via gh

Configure repository settings using the GitHub CLI:

```bash
# Set repo description and topics
gh repo edit --description "Project description here"
gh repo edit --add-topic "topic1" --add-topic "topic2"

# Configure merge settings
gh repo edit --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false
gh repo edit --delete-branch-on-merge

# Enable features
gh repo edit --enable-discussions
gh repo edit --enable-wiki=false

# Set default branch
gh api repos/{owner}/{repo} -X PATCH -f default_branch=main

# Branch protection
gh api repos/{owner}/{repo}/branches/main/protection -X PUT \
  -f 'required_status_checks[strict]=true' \
  -f 'required_status_checks[contexts][]=ci' \
  -F 'required_pull_request_reviews[required_approving_review_count]=1' \
  -f 'required_pull_request_reviews[dismiss_stale_reviews]=true' \
  -F 'enforce_admins=false' \
  --input /dev/null
```

## Anti-Fabrication Requirements

- Use `gh api repos/{owner}/{repo}/community/profile` to check which community files exist before claiming status
- Fetch license and CoC templates from the GitHub API rather than generating from memory
- Use `gh api repos/{owner}/{repo}` to verify repo settings before reporting them
- Read existing files with the Read tool before suggesting modifications
- Verify `.github/ISSUE_TEMPLATE/` contents with Glob before claiming template status
- Run `gh repo view` to confirm repository visibility and features
- Never fabricate template content — always fetch from API or reference actual file contents
