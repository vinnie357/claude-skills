# Epic: OAuth2 PKCE Authentication

**ID:** VIN-42
**Branch:** feature/vin-42-oauth-pkce
**Labels:** feat, security
**spec:** ./docs/specs/vin-42-oauth-pkce.allium

## Objective

Implement OAuth2 PKCE flow for the VantageEx API so that clients authenticate without exposing client secrets. The implementation must handle code exchange, token refresh, and session revocation as specified in the attached Allium spec.

## Acceptance Criteria

Behavioral acceptance criteria are encoded in the attached spec (`spec:` field above). The following criteria supplement the spec with integration-level expectations:

- [ ] `/api/auth/login` initiates PKCE challenge and returns `code_challenge`
- [ ] `/api/auth/token` exchanges code + verifier for access token
- [ ] `/api/auth/revoke` revokes an authorized session
- [ ] All state transitions from the spec are covered by ExUnit tests (seeded by `/allium:propagate`)
- [ ] `allium weed` reports zero divergences after CI passes

## Team

| Role | Model |
|---|---|
| Team Leader | opus |
| Worker A (API endpoints) | sonnet |
| Worker B (ExUnit tests) | sonnet |
| Validator | haiku |

## Notes

- The spec at `docs/specs/vin-42-oauth-pkce.allium` is the authoritative source for behavioral requirements. Do not invent acceptance criteria that contradict it.
- Worker B runs `/allium:propagate docs/specs/vin-42-oauth-pkce.allium` before writing any implementation code.
- Validator runs `/allium:weed` after `mise run ci` passes; any reported divergences are treated as CI failures.
