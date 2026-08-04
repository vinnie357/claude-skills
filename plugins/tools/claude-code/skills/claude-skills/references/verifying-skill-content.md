# Verifying skill content by loading it

Skill bodies are preprocessed before the model sees them: shell-injection patterns run, and substitution
placeholders expand. **Reading the source therefore tells you nothing about what a reader receives.** Any
change to content that contains those patterns has to be verified by loading the skill and reading what
arrives.

Two bugs were found this way and could not have been found any other way. One skill could not be loaded
at all — it documented the injection syntax with a command that exits non-zero, so the load hard-failed.
Sibling skills used the same pattern with a command that exits zero, so they "worked" while silently
replacing the syntax they teach with that command's output. A skill can score full marks on every validator
while being unloadable, because no check ever loads a skill.

## The loop

1. Fix the file in the repo.
2. Copy it over its counterpart in the plugin cache:
   `~/.claude/plugins/cache/<owner>/<plugin>/<version>/skills/<skill>/`.
   Check `installed_plugins.json` for the **active** version — stale version directories linger and
   editing one of those changes nothing. **Re-derive it every time.** Merging a version bump for the
   plugin changes which directory is active, so a path that worked earlier in the same session can
   silently go stale; this was hit while writing this very file.
3. **Ask the operator to run `/reload-plugins`.** See the trap below; without this the loop silently
   measures nothing.
4. Invoke the skill and read what arrives — not the source.
5. Restore the cache from your backup and `diff` to prove byte-identical restoration. Never leave an
   operator's cache modified.

Back up before step 2, not after.

## The trap that makes step 3 mandatory

Invoking any skill from a plugin appears to snapshot that whole plugin's content for the session. Later
edits to any skill in that plugin are never re-read, so every subsequent load replays the frozen text.

This is easy to mistake for a failed fix. A worker iterating on candidate escapes got the *identical*
stale error after every edit, and only diagnosed it by injecting a unique marker into a skill it had
never touched and finding the marker absent from a fresh invocation.

Because the mandatory session-start skill list already touches several plugins, anyone fixing a skill in
one of those hits this immediately. `/reload-plugins` is the only escape, and only the operator can run
it.

## Verifying a fix per-site, not globally

"No expanded value appears anywhere in the body" is the wrong criterion when a skill legitimately uses
expansion. The plugin-root token is the clearest case: in a runnable command it *should* expand, because
that is what yields an absolute path the agent can execute; in a copyable config example or a sentence
about the token, it should not.

Decide per occurrence what the correct arrival looks like, then check that. A global rule will force the
wrong treatment on the sites that are working as intended.

## What actually protects content

Established by experiment, not inference:

| Technique | Works? |
|---|---|
| Visible non-whitespace character immediately before the bang (`KEY=`) | **Yes** |
| Fencing, at any nesting depth including a five-backtick outer fence | No |
| Removing the space between a code-span delimiter and the bang | No — delimiters are stripped before the scan |
| Leading backslash before a bare `$NAME` placeholder | **Yes** — consumed, token preserved |
| Leading backslash before a braced `${NAME}` placeholder | No — backslash survives *and* the token expands |
| Moving copyable examples into `references/` | **Yes** — `Read` returns raw bytes, no substitution |

For a braced token there is no escape. Write the name bare and describe the wrapper in prose, or move the
example into a reference file.

**Never use an invisible character as an escape.** A zero-width space makes the page load and leaves every
reader copy-pasting something that silently does not work.

## Frontmatter is not delivered

Substitution applies to the body. Frontmatter is not sent to the model on load, so a token in a `hooks:`
block is functional and correct — verified by loading a skill whose only occurrence sat there and finding
nothing expanded. Do not "fix" those.

## When editing this material

The section in `SKILL.md` that documents these substitutions contains the very syntax that expands.
Editing it and checking the diff proves nothing. Run the loop above.
