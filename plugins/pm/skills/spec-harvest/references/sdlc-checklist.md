# SDLC Checklist

The checklist pm-sdlc-assessor runs against a prototype in phase 3, producing findings for `templates/sdlc-assessment.md`. Three areas: licensing, security, supportability. Every row needs a confidence tag (`[seen-in-code: <path>]` or `[inferred — needs verification]`) on its finding.

## Using This Checklist

Walk every row in all three tables against the prototype, one finding per row. A row with no observed problem still gets a finding entry recording that the check passed and what evidence supports it — an absent row is indistinguishable from an unchecked row. Severity guidance:

- **High** — blocks production use until mitigated (e.g. hardcoded production secrets, no `LICENSE` file on a distributed proprietary codebase).
- **Medium** — carries real risk but has a known, bounded mitigation path (e.g. missing timeout on an outbound call).
- **Low** — a gap worth recording but unlikely to cause incident-level impact on its own (e.g. a dashboard not yet built for a low-traffic internal tool).

Assign severity from the evidence collected, not from the check's position in the table — a licensing gap and a security gap use the same three-level scale and sit side by side in the risk summary.

## Licensing

Source: https://spdx.org/licenses/ (fetched 2026-07-15). SPDX short identifiers (`MIT`, `Apache-2.0`, `GPL-3.0-only`) are the canonical scheme; license expressions combine identifiers with `OR`, `AND`, `WITH`; SPDX maintains a deprecated-identifier list. The permissive-vs-copyleft distinction below is standard engineering background, not a claim sourced from the SPDX page itself.

| Check | Evidence to collect | Typical prototype failure |
|---|---|---|
| Every direct dependency has a declared SPDX license | Manifest license field per ecosystem | License field missing or free text instead of an SPDX identifier |
| No copyleft (GPL/AGPL) dependency in a proprietary distribution without sign-off | Dependency tree + license list | Copyleft dependency pulled in transitively and never reviewed |
| Vendored or copy-pasted code has source and license recorded | Comment headers, `NOTICE`/`THIRD_PARTY` files | Copied code with no attribution or license note |
| The project's own `LICENSE` file exists | Repo root listing | No `LICENSE` file at all |
| Transitive dependency licenses are checked, not just direct | SBOM or lockfile-driven scan | Only top-level `package.json`/`mix.exs` dependencies reviewed |
| AI-generated code blocks are spot-reviewed for provenance | Commit messages, code review notes | No record of provenance review for generated blocks |
| Manifest license field is a valid SPDX identifier, not free text | Manifest file contents | Field reads something like `"see license file"` |
| Dual-licensed dependencies have the chosen leg selected explicitly | Manifest or build config | Dual license present with no explicit selection |

Manifest locations (verify per ecosystem — do not assume a field exists without reading the file):

- `package.json` → `license` field.
- `Cargo.toml` → `[package]` `license` field.
- `pyproject.toml` → `[project]` `license` field.
- `mix.exs` → `package/0` `:licenses` key, often absent in internal projects — its absence is itself a shortcut signal.
- `go.mod` has no license field — check the module's `LICENSE` file directly.

## Security

Anchor: OWASP Top 10 2025, source https://owasp.org/Top10/2025/ (fetched 2026-07-15). Category names below are the 2025 list, not the 2021 list.

| Check | OWASP 2025 category | Evidence to collect |
|---|---|---|
| Authorization is enforced server-side, not hidden in the UI | A01 Broken Access Control | Request the endpoint as a lower-privilege user and compare the response |
| Debug mode and verbose error pages are off in the running build | A02 Security Misconfiguration | Trigger an error path and inspect the response body |
| Dependencies resolve from a lockfile, no branch refs or `*` versions | A03 Software Supply Chain Failures | Lockfile presence and dependency version pins |
| No hardcoded secrets; standard crypto in use | A04 Cryptographic Failures | Gitleaks scan output, crypto library usage |
| No string-interpolated SQL or shell commands | A05 Injection | Grep for string interpolation into a query or shell call |
| Sensitive features show design-consideration evidence | A06 Insecure Design | Design notes, ADRs, or comments explaining a security-relevant tradeoff |
| Vetted auth library in use; no hand-rolled sessions or tokens | A07 Authentication Failures | Dependency list, auth module source |
| CI verifies artifact integrity before deploy | A08 Software or Data Integrity Failures | CI workflow definitions |
| Authentication failures are actually logged | A09 Security Logging and Alerting Failures | Log output from a failed-login attempt |
| Error paths fail closed — an exception in an authorization check denies, not allows | A10 Mishandling of Exceptional Conditions | Authorization code path under an injected exception |

## Supportability

Source: https://getdx.com/blog/production-readiness-checklist/ (fetched 2026-07-15).

| Check | Evidence to collect |
|---|---|
| Metrics instrumentation exists on key operations | Metrics/telemetry calls in source |
| Dashboards exist for the service | Dashboard config or screenshot reference |
| Alerts exist with defined thresholds | Alerting config |
| Logging is structured and queryable, not leftover debug prints | Log statements — `print`/`IO.puts` vs. structured logger calls |
| A rollback path is defined and has been exercised | Rollback runbook or deployment history |
| A runbook exists for known failure modes | Runbook document |
| Secrets live in env/vault, not source | Grep for hardcoded credentials |
| A dependency vulnerability scan has run and been reviewed | Scan output or CI job |
| Downstream failures are handled — no HTTP call without a timeout | Timeout/retry configuration on outbound calls |
| Docs are sufficient for a non-author to operate the service | README/runbook completeness against an operate-it test |

## Typical Prototype Shortcuts (Cross-Cutting)

- **Licensing** — unattributed vendored code, an unreviewed copyleft dependency, no `LICENSE` file.
- **Security** — hardcoded keys "for the demo," stubbed authentication, missing input validation, raw SQL interpolation, verbose error pages.
- **Supportability** — hardcoded seed data, single-instance in-memory state, hand-applied schema changes, zero structured logging, an untested rollback path.

## Feeding Findings into the Feature Inventory

A shortcut identified here is not automatically a spec defect — it is evidence for the separation phase's "Prototype Shortcuts (do NOT carry forward)" section in `templates/feature-inventory.md`. Cross-reference: if pm-separator already flagged hardcoded seed data as a shortcut in phase 2, pm-sdlc-assessor's supportability finding on the same shortcut cites the same evidence rather than re-deriving it independently. Findings duplicated across the two artifacts point at one shared piece of evidence, not two separately-worded observations of the same fact.
