# No agent attribution in Git or forge output

Apply the main skill's rule to every outgoing field, regardless of whether the
operation uses Git, a forge CLI, an API tool, or a browser. Never add a robot emoji,
generation footer, assistant signature, or authorship trailer. Include issues,
branch names/descriptions, tags, releases, reviews and comments in this check.
Ordinary references to a product and required source/license notices are allowed.

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
