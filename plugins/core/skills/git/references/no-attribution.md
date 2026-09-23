# No agent attribution in Git or forge output

Apply the main skill's rule to every outgoing field, regardless of whether the
operation uses Git, a forge CLI, an API tool, or a browser. Never add a robot emoji,
generation footer, assistant signature, or authorship trailer. Include issues,
branch names/descriptions, tags, releases, reviews and comments in this check.
Ordinary references to a product and required source/license notices are allowed.

## Claude Code settings

When configuring Claude Code to follow this policy, merge this object into the
selected settings file. Preserve existing permissions, hooks and other settings.

```json
{
  "attribution": {
    "commit": "",
    "pr": "",
    "sessionUrl": false
  }
}
```

Empty `commit` and `pr` strings suppress Claude Code's built-in commit trailer
and PR attribution text. `sessionUrl: false` also suppresses the session link
for web and Remote Control commits and PRs; blanking the two strings alone does
not disable that separate link.

Choose the scope that matches the request:

- `~/.claude/settings.json`: the user's projects on this machine. If
  `CLAUDE_CONFIG_DIR` is set, use its `settings.json` instead.
- `.claude/settings.json`: shared project configuration; commit it for teammates.
- `.claude/settings.local.json`: a personal project override; keep it untracked.

Check higher-priority sources when a value does not apply. Managed settings take
precedence over command-line settings, then project-local, shared project and
user settings. A user-level setting alone does not enforce a team policy or
configure a cloud session. Installing this skill does not write these settings.

Use the object form for compatibility. `attribution` replaced the deprecated
`includeCoAuthoredBy` setting in v2.0.62; `sessionUrl` was added in v2.1.183.
The shorter `"attribution": false` form requires v2.1.281; older clients skip
a settings file containing that Boolean form. Check `claude --version` before
choosing a form, especially for a file shared by multiple client versions.

Keep the hook and the publication checks below. Native settings control Claude
Code's generated commit/PR attribution; they do not filter arbitrary issue
comments, branch names, other tools or inherited message content.

### Verify the configuration

1. Check the installed version and parse the selected settings file as JSON.
   Inspect only the attribution fields when reporting configuration evidence.
2. Start a fresh Claude Code session in the target project. Use `/status` to
   inspect setting sources and check higher-priority files for overrides.
3. For a behavior test, use a disposable repository and have Claude create a
   local commit. Inspect the actual message with `git log -1 --format=%B`.
   Record whether a hook blocked an attempted signature: a clean result after
   hook intervention does not prove that the native setting prevented it.
4. Inspect the actual title and body on the next authorized PR. A local commit
   test does not verify PR behavior or web/Remote Control session-link behavior.
   Do not publish a test PR solely to validate settings without authorization.

Evidence recorded on 2026-09-23: the installed v2.1.280 binary's help text
described empty strings as hiding attribution, and its session-link code checked
`sessionUrl: false`. This was static inspection, not an end-to-end commit/PR
test. The hook suite below tests a separate mechanism. Report these evidence
levels separately; configuration presence alone does not prove live behavior.

Sources: [settings scopes and precedence](https://code.claude.com/docs/en/settings)
and [release history](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md).

## Before publication

1. Prepare the final title, name, description, message and body file.
2. Inspect every field for attribution, including content copied from templates
   or commit history. Remove signatures before issuing the write.
3. Publish exactly the inspected content. Recheck edits and follow-up comments.
4. When an input cannot be inspected, prepare a readable UTF-8 file in a separate
   tool call and use its literal path. Do not bypass a hook rejection.

## Hook coverage

Core's `hooks/hooks.json` registers `block-attribution.nu` for Bash PreToolUse.
The all-skills package registers the same script using its nested core path in
the root `hooks/hooks.json`. These are plugin-level hooks; invoking the Git skill
is not required to register them. Nushell must be available to the hook process.

The script inspects ordinary explicit `git`, `gh`, and `glab` write commands,
including inline fields, supported message-file flags and API file inputs.
It reads files relative to the tool payload's working directory and follows
literal `cd` and `git -C` paths. It blocks attribution with exit 2 and rejects
explicit message inputs it cannot inspect, including missing files and stdin.
It never executes the command being inspected or rewrites outgoing content.
Matching is lexical: quoting a forbidden footer in an issue reproduction also
triggers the guard. Describe that reproduction without repeating the footer.
The hook does not distinguish a signature from the same text inside a quotation.

This is a guard against common mistakes, not a shell interpreter or a universal
publication filter. Aliases, wrapper scripts, indirect commands, other tools,
encoded API content, editor/default/generated bodies and inherited commit
messages are not fully inspected. In particular, automatic fill and merge
messages still require manual inspection before publication. Hook registration
does not prove that a running client loaded it; validate the installed client
after updating the plugin. A missing runtime or disabled hooks removes this
backstop. Keep the pre-publication instruction active for every agent.

## Validation

Run `mise test:attribution-hook`. The regression suite feeds JSON payloads to the
real hook, checks allow/deny outcomes and invokes both packages' configured hook
commands with their respective plugin roots. Fixture command strings are never
executed against Git or a forge. These tests verify the guard and package paths,
not an installed client's hook lifecycle or a remote server policy.
