# Epic Audit Report

**Generated**: [DATE]
**Project**: [PROJECT-SLUG]
**Issues Audited**: [COUNT]

## Summary

| Severity | Count |
|----------|-------|
| Error    | [N]   |
| Warning  | [N]   |
| Info     | [N]   |
| Pass     | [N]   |

## Findings

### [ISSUE-IDENTIFIER]: [TITLE]

**Status**: [LINEAR-STATE]
**URL**: [LINEAR-URL]

| Check | Severity | Status | Detail |
|-------|----------|--------|--------|
| Objective present | error | pass/fail | |
| Objective quality | warning | pass/fail | |
| Skills present | error | pass/fail | |
| Skills valid | warning | pass/fail | Unknown: [list] |
| Skills not listing core | info | pass/fail | Core listed: [list] |
| Repos present | error | pass/fail | |
| Team defined | warning | pass/fail | |
| PR on completed | error | pass/fail/n-a | |
| Branch convention | warning | pass/fail/n-a | |
| No implementation details | warning | pass/fail | |

**Remediation**:
- [Action item 1]
- [Action item 2]

---

> Repeat the findings section for each audited issue.
> Sort issues by number of errors (most errors first).

## Next Steps

1. Run `/linear:groom-epics` to fix errors and warnings automatically
2. Review info-level findings manually
3. Re-run `/linear:audit-epics` to verify fixes
