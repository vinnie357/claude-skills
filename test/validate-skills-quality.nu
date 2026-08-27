#!/usr/bin/env nu
# Validate skill quality across all plugins
#
# Runs static analysis checks on every skill and produces a scorecard table.
# Checks are sourced from Anthropic's skill best practices and the Agent Skills Specification.
#
# Enforcement uses a ratchet baseline (test/quality-baseline.json). Each
# allowed_failures entry is a record {key, class, issue, first_seen,
# detail_count} — see validate-baseline-entries for the schema.
# - A failing check NOT in the baseline fails the run (new violations cannot land).
# - A baselined check that now passes fails the run with a prompt to remove the
#   stale entry (the baseline only shrinks).
# - For detail-producing checks (see DETAIL_CHECKS below)
#   the entry's detail_count ratchets BOTH directions: current above the stored
#   count fails as a regression, current below it fails as a stale count.
#   Accepted residual: the ratchet bounds the NUMBER of findings per waived
#   check, not their identity — a same-commit swap of one finding for another
#   of equal size passes. Closing that needs per-finding identities/hashes.
# Regenerate the baseline with: nu test/validate-skills-quality.nu --update-baseline
#
# Usage:
#   nu test/validate-skills-quality.nu              # scan all plugins
#   nu test/validate-skills-quality.nu --self-test  # verify the skills: frontmatter, baseline schema/ratchet, check-fix fixtures, Pass-2 agents/commands links, and the shared detail-count accumulators

# Checks whose findings are countable at runtime; their baseline entries must
# carry an integer detail_count so a waiver covers the recorded count, not
# unbounded growth of the same check.
const DETAIL_CHECKS = ["lines" "links" "orphans" "invocations" "version_pin" "ref_depth" "duplicate_block" "vocab_disjoint" "fm_schema" "ref_unsafe"]

# Sliding-window size for the corpus-wide duplicate-block check: 8 normalised
# lines. Measured in the claude-skills-124 plan (revision 2): at N=8 with no
# single-word-line filter the corpus yields a reviewable group count and the
# core-list load-list duplication surfaces as a single cross-file group.
const DUPE_WINDOW = 8

# Slash-invocable targets shipped by an upstream plugin whose namespace a local
# skill-only mirror shares. Upstream ships these as SKILLS rather than commands
# (verified against github.com/juxt/allium); either way they are invocable as
# /ns:target, which is what this resolves. Enumerated per-target — never a
# blanket namespace exemption — so a typo like /allium:nonexistent still fails.
# The list is static so CI runs with zero external dependencies. Re-verify
# against the upstream repo when adding or changing an entry.
const UPSTREAM_COMMANDS = [
    {ns: "allium", upstream: "https://github.com/juxt/allium", commands: ["elicit" "distill" "propagate" "tend" "weed"]}
]

# Resolve every /plugin:skill token in `content` against the Pass-1 registry
# (list of {name, dir, invocables}). Unknown (external) plugin namespaces are
# skipped — only same-marketplace references are checked. Shared by check 16
# (per-skill SKILL.md + references) and the Pass 2 agents/commands surfaces
# so invocation resolution has exactly one implementation.
def find-bad-invocations [content: string, registry: list] {
    let no_urls = ($content | str replace --regex --all '[a-zA-Z][a-zA-Z0-9+.-]*://[^\s)]+' ' ')
    # Leading boundary required so image refs like REGISTRY/claude-code:v1
    # or ghcr.io/anthropics/claude-code:latest do not match.
    let invocations = ($no_urls
        | parse --regex '(?m)(?:^|[\s`(\[<"])/(?P<ns>[a-z][a-z0-9-]*):(?P<target>[a-z][a-z0-9-]*)'
        | select ns target | uniq)
    mut bad = []
    for inv in $invocations {
        let known = ($registry | where name == $inv.ns)
        if ($known | is-not-empty) {
            if not ($inv.target in ($known | first | get invocables)) {
                $bad = ($bad | append $"/($inv.ns):($inv.target)")
            }
        }
    }
    $bad
}

# Full directory path for a skill name, resolved via the Pass-1
# skill_dir_map (built once for all local plugins). When `plugin` is
# non-empty and a (skill, plugin) pair exists, that scoped match wins —
# this is what makes resolution namespace-aware for a skill name that
# collides across two local plugins. Otherwise (no plugin given, or the
# plugin doesn't carry that skill) falls back to the prior skill-name-only
# first-match, preserving lenient handling for unknown/external
# namespaces. Returns "" when the skill name is not a known local skill.
def lookup-skill-dir [skill_dir_map: list, skill: string, plugin: string = ""]: nothing -> string {
    if ($plugin | is-not-empty) {
        let scoped = ($skill_dir_map | where skill == $skill and plugin == $plugin)
        if ($scoped | is-not-empty) {
            return ($scoped | first | get dir)
        }
    }
    let m = ($skill_dir_map | where skill == $skill)
    if ($m | is-not-empty) { $m | first | get dir } else { "" }
}

# A references/<path> token is cross-skill qualified when the qualifier
# immediately preceding it on the same line — either a /plugin:skill token
# (the common case: "see `/core:restraint`'s references/foo.md") or a full
# plugins/<...>/skills/<other>/ prefix — names a DIFFERENT, REAL skill whose
# own directory actually contains that reference file. Existence is
# resolved against skill_dir_map (the Pass-1 registry of local skill
# directories), so an unrelated qualifier earlier on the line that doesn't
# actually own the path, or a broken cross-skill pointer, is NOT exempted —
# both fall through to the normal same-skill checks. When the /plugin:skill
# token's namespace names a known local plugin (checked against
# known_plugins, the Pass-1 registry's plugin names), resolution is scoped
# to that plugin's own tree — so a skill name that collides across two
# local plugins resolves against the plugin the token actually names,
# never whichever plugin's skill_dir_map entry happened to register first.
# Unknown/external skill names and unknown plugin namespaces (not in the
# local marketplace) cannot be existence-checked, so they stay exempted to
# preserve prior handling of genuinely external references — check 16
# (invocations) independently flags unresolvable /plugin:skill tokens
# naming a real-but-wrong local skill. Shared by check 9 (ref_depth) and
# check 14 (links).
def cross-skill-qualified [prefix_line: string, dir_name: string, path: string, skill_dir_map: list, known_plugins: list]: nothing -> bool {
    let qual_match = ($prefix_line | parse --regex '/(?P<ns>[a-z][a-z0-9-]*):(?P<skill>[a-z][a-z0-9-]*)')
    let candidate = if ($qual_match | is-not-empty) {
        $qual_match | last | get skill
    } else {
        let plugins_match = ($prefix_line | parse --regex 'skills/(?P<skill>[a-z][a-z0-9-]*)/$')
        if ($plugins_match | is-not-empty) {
            $plugins_match | first | get skill
        } else {
            ""
        }
    }
    if ($candidate | is-empty) or ($candidate == $dir_name) {
        return false
    }
    let candidate_ns = if ($qual_match | is-not-empty) { $qual_match | last | get ns } else { "" }
    let scoped_ns = if ($candidate_ns in $known_plugins) { $candidate_ns } else { "" }
    let target_dir = (lookup-skill-dir $skill_dir_map $candidate $scoped_ns)
    if ($target_dir | is-empty) {
        return true
    }
    ($target_dir | path join $path) | path exists
}

# Text preceding the first occurrence of `path` in `content`, truncated to
# just its own line (so cross-skill-qualified only sees same-line context).
# The same truncation makes the exemption order-sensitive for checks 14 and
# Pass-2 too — see has-unqualified-references-token's header for the rationale.
def preceding-line [content: string, path: string]: nothing -> string {
    let idx = ($content | str index-of $path)
    if $idx < 0 {
        ""
    } else {
        let before = ($content | str substring 0..<$idx)
        ($before | split row "\n" | last)
    }
}

# Path tokens naming a skill-spec directory (references/, templates/,
# scripts/, agents/, hooks/), extracted from already fence-stripped content.
# Shared by check 14 (per-skill SKILL.md links) and the Pass-2 agents/*.md +
# commands/*.md links check so the extraction regex has exactly one
# implementation. The extension class permits hyphens AND its quantifier is
# widened to {1,20} (was {1,6}) — the original check-14 regex both excluded
# hyphens from the class AND capped length at 6, so `templates/Dockerfile.
# claude-code`'s 11-character extension truncated to `.claude` (the first 6
# alnum characters, stopping right before the hyphen the class couldn't
# match) even after the class alone was widened: {1,6} is exhausted by
# "claude" before the hyphenated remainder is ever reached. 20 comfortably
# covers the corpus's longest observed extension (`claude-code`, 11 chars)
# with headroom (pointer-validation-gap plan, revision 2).
def extract-link-path-tokens [content: string]: nothing -> list<string> {
    ($content
        | parse --regex '(?m)(?:^|[\s`(\[<"])(?P<path>(?:references|templates|scripts|agents|hooks)/[A-Za-z0-9._/-]+\.[A-Za-z0-9-]{1,20})'
        | get path | uniq)
}

# Resolve a references/templates/scripts/agents/hooks path token cited from
# an agent or command file (the Pass-2 surfaces — these have no single
# "skill_dir" the way a per-skill SKILL.md check does). Four filesystem-
# existence bases, tried in order; the first that resolves wins. Each is a
# plain existence test — no heuristics, no fuzzy matching:
#   1. own_dir/path — own_dir is the enclosing skill's dir for a
#      skill-nested agents/*.md, or the plugin dir for a plugin-level
#      agents/*.md or commands/*.md (commands are plugin-level only).
#   2. cross-skill-qualified — reuses the SAME helper checks 9 and 14 use: a
#      /plugin:skill (or plugins/.../skills/<skill>/) qualifier immediately
#      preceding the token on its line names a real, different skill whose
#      own tree contains the path. Load-bearing, not a nicety — e.g.
#      beads-worker.md's references/skill-catalog.md citation resolves only
#      here, since that file lives under core/skills/bees/references/.
#      Inherited exemption: an UNKNOWN skill/plugin name (not in the local
#      marketplace) cannot be existence-checked, so cross-skill-qualified
#      treats it as exempt (resolved) rather than broken — the same
#      leniency checks 9, 14, and 16 already apply to genuinely external
#      references. A citation qualified by a namespace this repo doesn't
#      know about therefore passes silently; that is accepted, documented
#      behavior, not a gap in this check.
#   3. <plugin>/skills/*/<path> — exactly one sibling skill in the SAME
#      plugin contains the path. More than one match is AMBIGUOUS, which
#      counts as unresolved — this never silently picks the first match.
#   4. <plugin>/<path> — the path exists directly under the plugin root
#      (a plugin-level scripts/ or templates/ dir not owned by any one skill).
def resolve-pass2-path [
    path: string
    prefix_line: string
    own_dir: string
    dir_name: string
    plugin_dir: string
    skill_dir_map: list
    known_plugins: list
]: nothing -> bool {
    if (($own_dir | path join $path) | path exists) {
        return true
    }
    if (cross-skill-qualified $prefix_line $dir_name $path $skill_dir_map $known_plugins) {
        return true
    }
    let skills_root = ($plugin_dir | path join "skills")
    let sibling_matches = if ($skills_root | path exists) {
        (glob ($skills_root | path join "*")
            | where {|d| ($d | path type) == "dir"}
            | where {|d| ($d | path join $path) | path exists})
    } else {
        []
    }
    if ($sibling_matches | length) == 1 {
        return true
    }
    if ($sibling_matches | length) > 1 {
        return false
    }
    ($plugin_dir | path join $path) | path exists
}

# Directory-gating scope test for the Pass-2 scripts/templates/hooks tokens
# (references/agents are never gated — see the two call sites). A dir-gated
# token is only evaluated when that top-level directory exists SOMEWHERE
# resolve-pass2-path would actually look: the citing file's own level, ANY
# sibling skill in the same plugin, or the plugin root. Gating on own-level
# alone (the per-skill check-14 rule) excluded 6 of 33 real Pass-2 pointers
# from evaluation entirely — e.g. a plugin-level agent citing
# `templates/prd.md` when that plugin has no plugin-level templates/ dir,
# only a sibling skill's — so a rename under that sibling skill would have
# landed green (Gate 3 finding, PR 160). The gate checks the citing file's
# own level, every sibling skill in the plugin, and the plugin root — i.e.
# bases 1, 3, and 4. It deliberately does NOT consult base 2's cross-plugin
# target, so a dir-gated token qualified into a DIFFERENT plugin, cited from
# a plugin with no such dir anywhere, stays out of scope. Zero corpus cases;
# the error direction is silence on an exotic layout, not a false positive.
#
# The original anti-false-positive intent survives: a mention of
# `templates/foo.md` when no templates/ dir exists ANYWHERE in the plugin
# stays unflagged. The accepted cost is that an ILLUSTRATIVE mention in a
# plugin where some sibling skill does own the dir now gets flagged — the
# same tension check 14 already accepts for a skill that owns its own dir.
def pass2-dir-in-scope [top: string, own_dir: string, plugin_dir: string]: nothing -> bool {
    if (($own_dir | path join $top) | path exists) { return true }
    if (($plugin_dir | path join $top) | path exists) { return true }
    let skills_root = ($plugin_dir | path join "skills")
    if not ($skills_root | path exists) { return false }
    (glob ($skills_root | path join "*")
        | where {|d| ($d | path type) == "dir"}
        | any {|d| ($d | path join $top) | path exists})
}

# True when `content` contains at least one "references/" token that is NOT
# cross-skill qualified (i.e. a genuine same-skill nested reference).
# Two token shapes are exempt because they are not followable hops:
# - Markdown heading lines (a heading is a section label, not a link).
#   Accepted residual: a genuine sibling link placed inside a heading would
#   escape this scan.
# - Bare directory mentions ("move material to references/") that name no
#   concrete sibling file. Accepted residual: a sibling pointer written
#   without a file extension escapes (check 14's link regex shares this
#   extension requirement).
# - The cross-skill exemption is evaluated against the text BEFORE the
#   `references/` token only (the prefix/rest split just below), so it
#   fires only when the `/ns:skill` (or `plugins/<...>/skills/<other>/`)
#   qualifier PRECEDES the path on the same line. This residual differs in
#   kind from the two above: those silently PASS things that should fail;
#   this one silently FAILS something legitimate. Flagged:
#   ``Per `references/x.md` in `/core:tdd`: ...``. Exempt:
#   ``Per `/core:tdd`'s `references/x.md`: ...``. Both name the same real
#   file — fix by reordering the sentence. Not widened to whole-line
#   matching: measured against this corpus (claude-skills-195 plan), that
#   breaks the `plugins/<...>/skills/<other>/` qualifier form (its regex is
#   `$`-anchored, so it can only match a line-ending prefix), costing 1
#   corpus exemption, while a later mention of an unknown namespace or of a
#   sibling skill sharing the same reference basename (19 such basenames in
#   this corpus) would silently exempt a genuine same-skill link — against
#   0 current false positives from the order requirement. A gated design
#   (prefix-first, whole-line fallback only when the citing skill does not
#   own the cited path) was evaluated and deferred until a real instance
#   needs it.
# - claude-skills-309: `sibling_basenames` (the current skill's own
#   references/*.md basenames, e.g. "attribution.md") is the caller-supplied
#   list a bare same-skill markdown link (`[attribution.md](attribution.md)`,
#   naming no `references/` prefix at all) must be checked against. The
#   original token scan above only ever inspects lines containing the
#   literal substring "references/", so a bare sibling link carries no such
#   token and is invisible to it (PR #263: `attribution.md` linking
#   `[flavored-prose.md](flavored-prose.md)` was never flagged, even though
#   the reverse direction was). This is a separate branch of logic, checked
#   per line alongside the references/ token scan (either one flags the
#   line): a markdown link `[text](target)` whose target, after stripping a
#   trailing link title (`target "Title"`) and then a trailing `#fragment`,
#   EXACTLY equals an entry in `sibling_basenames` (no suffix/basename
#   extraction beyond that — a path with any directory component never
#   matches a bare filename). The fragment strip keeps this branch aligned
#   with the references/ token branch above, which already flags
#   `references/foo.md#anchor` (Gate 3 finding: the two branches used to
#   disagree on the identical evasion applied to a bare link). No explicit
#   URL-scheme rejection: exact-match after stripping already can't equate a
#   full URL string (which still carries its `scheme://host/` prefix once
#   the fragment is gone) with a bare basename — verified against
#   `https://example.com/attribution.md#usage`, which still fails the
#   equality check with no separate guard. Accepted residuals: a link
#   written with a directory prefix to the same file (e.g.
#   `[x](./attribution.md)`), an angle-bracket target
#   (`[x](<attribution.md>)`), and nested brackets in the link text
#   (`[see [note]](attribution.md)`), and a title delimited by anything
#   other than double quotes (`[x](attribution.md 'Title')`, CommonMark also
#   allows single quotes and parentheses) all escape — no path normalization,
#   angle-bracket unwrapping, or bracket-nesting-aware link parsing is
#   attempted, matching this function's existing minimalism.
def has-unqualified-references-token [content: string, dir_name: string, skill_dir_map: list, known_plugins: list, sibling_basenames: list]: nothing -> bool {
    ($content | lines | any {|line|
        let ref_flag = if not ($line | str contains "references/") {
            false
        } else if (($line | parse --regex '^\s{0,3}#{1,6} ') | is-not-empty) {
            false
        } else {
            let idx = ($line | str index-of "references/")
            let prefix = ($line | str substring 0..<$idx)
            let rest = ($line | str substring $idx..)
            let path_match = ($rest | parse --regex '^(?P<path>references/[A-Za-z0-9._/-]+\.[A-Za-z0-9-]{1,20})')
            if ($path_match | is-empty) {
                false
            } else {
                not (cross-skill-qualified $prefix $dir_name ($path_match | first | get path) $skill_dir_map $known_plugins)
            }
        }
        if $ref_flag {
            true
        } else {
            let link_matches = ($line | parse --regex '\[[^\]]*\]\((?P<target>[^)]+)\)')
            ($link_matches | any {|m|
                let raw_target = ($m.target | str trim)
                let de_titled = ($raw_target | parse --regex '^(?P<base>.*?)\s+"[^"]*"$')
                let after_title = if ($de_titled | is-not-empty) { $de_titled | first | get base } else { $raw_target }
                let de_fragmented = ($after_title | parse --regex '^(?P<base>[^#]*)#.*$')
                let target = if ($de_fragmented | is-not-empty) { $de_fragmented | first | get base } else { $after_title }
                $target in $sibling_basenames
            })
        }
    })
}

# Parse an agent's `skills:` frontmatter field out of its already-extracted
# fm_lines. Three shapes: absent (no `skills:` key at all), inline scalar
# (`skills: foo` — invalid, flagged via shape_ok: false), or a YAML list of
# `- ns:skill` entries. Entry values are NOT shape-validated here (that's
# check-agent-skills' job) — this function only parses structure.
def parse-skills-frontmatter [fm_lines: list] {
    let hits = ($fm_lines | enumerate | where {|l| ($l.item | str starts-with "skills:")})
    if ($hits | is-empty) { return {present: false, entries: [], shape_ok: true} }
    let first = ($hits | first)
    if (($first.item | str replace "skills:" "" | str trim) | is-not-empty) {
        return {present: true, entries: [], shape_ok: false}   # inline scalar form
    }
    mut entries = []
    for line in ($fm_lines | skip ($first.index + 1)) {
        let t = ($line | str trim)
        if ($t | str starts-with "- ") { $entries = ($entries | append ($t | str substring 2.. | str trim)) } else { break }
    }
    {present: true, entries: $entries, shape_ok: true}
}

# Validate an agent's `skills:` frontmatter (claude-skills-119): well-formed
# `ns:skill` entries, no duplicates, and each entry resolves against the
# registry's `skills` list — NEVER `invocables`, since invocables also
# carries command names and a command token is not preloadable via an
# agent's `skills:` field. Unknown/external plugin namespaces are skipped,
# mirroring find-bad-invocations' external-namespace leniency. Shared by the
# Pass-2 agent loop and run-skills-self-test so there is exactly one
# implementation to keep in sync.
def check-agent-skills [fm_lines: list, registry: list] {
    let parsed = (parse-skills-frontmatter $fm_lines)
    if not $parsed.present {
        return {failed: [], bad_tokens: []}
    }
    mut failed = []
    let shape_bad = (not $parsed.shape_ok) or ($parsed.entries | any {|e|
        ($e | parse --regex '^[a-z][a-z0-9-]*:[a-z][a-z0-9-]*$') | is-empty
    })
    if $shape_bad { $failed = ($failed | append "skills_shape") }
    if ($parsed.entries | length) != ($parsed.entries | uniq | length) {
        $failed = ($failed | append "skills_duplicate")
    }
    mut bad_tokens = []
    for entry in $parsed.entries {
        let m = ($entry | parse --regex '^(?P<ns>[a-z][a-z0-9-]*):(?P<skill>[a-z][a-z0-9-]*)$')
        if ($m | is-not-empty) {
            let ns = ($m | first | get ns)
            let skill = ($m | first | get skill)
            let known = ($registry | where name == $ns)
            if ($known | is-not-empty) and ($skill not-in ($known | first | get skills)) {
                $bad_tokens = ($bad_tokens | append $entry)
            }
        }
    }
    if ($bad_tokens | is-not-empty) { $failed = ($failed | append "skills_unresolved") }
    {failed: $failed, bad_tokens: $bad_tokens}
}

# Remove fenced code blocks so code examples don't trip content checks
# (e.g. a `name: CI` line inside a GitHub Actions YAML example).
# Fence-length-aware per CommonMark: a fence closes only on a marker whose
# backtick run is at least as long as the opener's, so a 4-backtick outer
# fence can embed 3-backtick inner fences as literal content.
def strip-fences [content: string] {
    mut open_len = 0
    mut kept = []
    for line in ($content | lines) {
        let fence = ($line | str trim | parse --regex '^(?P<ticks>`{3,})')
        let tick_len = if ($fence | is-not-empty) { $fence | first | get ticks | str length } else { 0 }
        if $open_len == 0 {
            if $tick_len > 0 {
                $open_len = $tick_len
            } else {
                $kept = ($kept | append $line)
            }
        } else if $tick_len >= $open_len {
            $open_len = 0
        }
    }
    $kept | str join "\n"
}

# Reserved-name check: only an EXACT name of "claude" or "anthropic" is
# reserved. Substring matching flagged every skill in a plugin whose domain
# IS Claude Code (claude-agents, claude-skills, ...) — 11 of 11 findings in
# the check's life were such false positives. A prefix rule would be wrong
# too: names like claude-api or anthropic-sdk are legitimate domains.
def is-reserved-name [name: string]: nothing -> bool {
    $name in ["claude" "anthropic"]
}

# Guards a single reference-file read against three failure modes that used
# to abort the whole run via an unhandled `open --raw` error (claude-skills-222):
# a dangling path, an unreadable-permissions file, and a path that resolves
# outside the repo. The first two are read attempts that fail; the third
# succeeds but must never happen — reading it would scan arbitrary filesystem
# content into the corpus, so it is quarantined (content never read) rather
# than opened. The outside-the-repo guard covers a symlinked ANCESTOR as well
# as a symlinked leaf, because the whole path is canonicalized before either
# check runs. Returns {name, content, unsafe, reason} where
# reason is "broken" | "unreadable" | "external" | null. Content is "" for
# every unsafe case.
def safe-read-ref [f: string, repo_root: string]: nothing -> record {
    let name = ($f | path basename)
    # Canonicalize unconditionally, not just when the leaf itself is a symlink:
    # a symlinked ANCESTOR (e.g. the whole references/ directory pointing outside
    # the repo) leaves every leaf a plain file, so a leaf-only check would read
    # arbitrary filesystem content into the corpus. `path expand` resolves the
    # entire path, so both shapes land on the same guard.
    let resolved = ($f | path expand)
    if not ($resolved | path exists) {
        return {name: $name, content: "", unsafe: true, reason: "broken"}
    }
    let root = ($repo_root | path expand)
    if not ($resolved | str starts-with $"($root)/") {
        return {name: $name, content: "", unsafe: true, reason: "external"}
    }
    let read = (try {
        {ok: true, data: (open --raw $f)}
    } catch {
        {ok: false, data: ""}
    })
    if not $read.ok {
        return {name: $name, content: "", unsafe: true, reason: "unreadable"}
    }
    {name: $name, content: $read.data, unsafe: false, reason: null}
}

# Examples check: the skill presents at least one example — a code fence or
# an example header in SKILL.md itself, or a code fence in a reference file
# that SKILL.md mentions by basename (the same reachability rule check 15
# enforces). An orphaned fenced reference file does NOT satisfy the check.
# `refs` is a list of {name (basename), content} records.
def has-examples [content: string, refs: list]: nothing -> bool {
    let code_fence = (['`' '`' '`'] | str join)
    if ($content | str contains $code_fence) { return true }
    if ($content | str downcase | str contains "## example") { return true }
    # Match the `references/<basename>` token, not the bare basename: a bare
    # match lets an unrelated mention count, e.g. SKILL.md naming
    # `counterexamples.md` would satisfy a reference file called `examples.md`.
    ($refs | any {|r| ($content | str contains $"references/($r.name)") and ($r.content | str contains $code_fence)})
}

# Anti-fabrication presence check (claude-skills-202, claude-skills-203).
# Presence-only: does NOT validate that a claim is true, only that the
# content carries recognizable verification language SOMEWHERE — either the
# core:anti-fabrication skill's own vocabulary (its header text, a direct
# skill reference, or the literal "fabricat" substring) or an explicit
# per-claim verification citation ("verified against <tool> <version>",
# e.g. "verified against bees 0.4.0"). Two failure directions this cannot
# close, in either form: content that says "verified" without having
# actually checked, and content that is accurate but omits the phrase.
# Both require semantic review, not a keyword search — this check only
# answers "is there SOME verification vocabulary present", never "is the
# claim correct".
def has-anti-fab-evidence [content: string]: nothing -> bool {
    let content_lower = ($content | str downcase)
    let has_header = ($content_lower | str contains "anti-fabrication")
    let has_ref = ($content | str contains "core:anti-fabrication")
    let has_fabricat = ($content_lower | str contains "fabricat")
    let has_verified = (($content_lower | parse --regex 'verified against \S+ [0-9]') | is-not-empty)
    $has_header or $has_ref or $has_fabricat or $has_verified
}

# Strip a leading YAML frontmatter block (--- ... ---) and return the
# remaining body. Content with no opening "---" as its first line, or an
# unterminated frontmatter block, passes through unchanged — used by the
# braced-CLAUDE_* check (claude-skills-205) so a harness-expanded value in
# frontmatter (e.g. a hooks: command field) is never mistaken for the
# disallowed body form.
#
# Known gap, not engineered around: this treats ANY first-line "---" as a
# frontmatter opener, so a file whose first line is a genuine Markdown
# horizontal rule (rather than real frontmatter) has everything up to the
# next "---" silently swallowed, exempting a braced var in that span. Zero
# corpus impact today — every real SKILL.md and commands/*.md carries valid
# frontmatter starting at byte 0 — but a hand-written fixture could trigger
# it. Not worth a stricter YAML-shape check for a gap the corpus never hits.
def strip-frontmatter [content: string]: nothing -> string {
    let all_lines = ($content | lines)
    if ($all_lines | first | default "" | str trim) != "---" {
        return $content
    }
    let rest = ($all_lines | skip 1)
    let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
    if ($end_matches | is-empty) {
        return $content
    }
    let end_idx = ($end_matches | first | get index)
    ($rest | skip ($end_idx + 1) | str join "\n")
}

# Braced CLAUDE_* env var check (claude-skills-205). The braced form
# (`${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_SKILL_DIR}`, ...) expands at load time
# wherever the harness treats it as a live substitution — correct in
# frontmatter and manifests, a bug in prose/example bodies, where it bakes
# one machine's absolute cache path into the text. The documented body-safe
# form is bare or angle-bracketed (see claude-plugins's `CLAUDE_SKILL_DIR`
# usage note): `<CLAUDE_SKILL_DIR>/scripts/foo.sh`. The trailing `[^}]*`
# also matches shell-default-value forms like
# `${CLAUDE_PLUGIN_ROOT:-/some/default}` — whether the harness actually
# expands that form is unverified, but it is still the same var name inside
# braces, so flagging it errs toward catching the bug rather than missing it.
def has-braced-claude-var [body: string]: nothing -> bool {
    ($body | parse --regex '\$\{CLAUDE_[A-Z_]+[^}]*\}' | is-not-empty)
}

# Redundant "When to Use" check (claude-skills-296). Per the Claude Code
# Skills docs, the frontmatter `description` is the ONLY text Claude sees
# during discovery (Level 1) — a body "## When to Use" / "## When to
# Activate" section that is JUST a restated trigger-bullet list duplicates
# work the description must already carry and never reaches discovery. H2
# only ("^##\s+" requires whitespace immediately after the second `#`, so an
# H3 "### When to Use" — real decision content in references/, agents/,
# commands/ — never matches). Structural, no thresholds: flags a heading
# whose section has at least one bullet line and NOTHING else structural (no
# H3 subheading, no fenced code block, no table). Trailing prose (a scope
# note, a references/*.md pointer) does NOT exempt a section — only
# structural content does.
#
# Fence-AWARE, not fence-STRIPPED. Unlike has-anti-fab-evidence and the
# invocation check, this does not run strip-fences over the body first:
# strip-fences deletes an entire fenced block (markers and content) with no
# trace, which would erase the "this section has a code fence" signal the
# self-test's fenced-block case depends on to exempt it. Fence state is
# tracked inline instead, for exactly one purpose: a "## When to
# (Use|Activate)" heading found while still inside an open fence is a
# documentation EXAMPLE of the anti-pattern (illustrating what not to write),
# not a real structural heading, and must not be matched.
def has-redundant-when-to-use-section [content: string]: nothing -> bool {
    let body = (strip-frontmatter $content)
    let all_lines = ($body | lines)

    # Pass 1: fence-aware scan for the first REAL (non-fenced) heading line.
    # -1 is the not-found sentinel (rather than null) so the arithmetic below
    # stays on a single int type throughout.
    mut open_len = 0
    mut heading_idx = -1
    for pair in ($all_lines | enumerate) {
        let trimmed = ($pair.item | str trim)
        let fence = ($trimmed | parse --regex '^(?P<ticks>`{3,})')
        let tick_len = if ($fence | is-not-empty) { $fence | first | get ticks | str length } else { 0 }
        if $open_len == 0 {
            if $tick_len > 0 {
                $open_len = $tick_len
            } else if $heading_idx == -1 {
                let is_heading = ($trimmed | str downcase | parse --regex '^##\s+when to (use|activate)\b')
                if ($is_heading | is-not-empty) {
                    $heading_idx = $pair.index
                }
            }
        } else if $tick_len >= $open_len {
            $open_len = 0
        }
    }
    if $heading_idx == -1 {
        return false
    }

    # Pass 2: section = lines after the heading up to the next "## " line
    # (fence-aware, so a "## "-shaped line inside a fence never ends the
    # section early) or EOF.
    let after = ($all_lines | skip ($heading_idx + 1))
    mut section_lines = []
    mut open_len2 = 0
    mut ended = false
    for line in $after {
        if $ended { continue }
        let trimmed = ($line | str trim)
        let fence = ($trimmed | parse --regex '^(?P<ticks>`{3,})')
        let tick_len = if ($fence | is-not-empty) { $fence | first | get ticks | str length } else { 0 }
        if $open_len2 == 0 {
            if $tick_len > 0 {
                $open_len2 = $tick_len
                $section_lines = ($section_lines | append $line)
            } else if ($trimmed | str starts-with "## ") {
                $ended = true
            } else {
                $section_lines = ($section_lines | append $line)
            }
        } else {
            $section_lines = ($section_lines | append $line)
            if $tick_len >= $open_len2 {
                $open_len2 = 0
            }
        }
    }

    let content_lines = ($section_lines | where {|l| ($l | str trim | str length) > 0 })
    if ($content_lines | is-empty) {
        return false
    }

    let has_bullet = ($content_lines | any {|l| let t = ($l | str trim); ($t | str starts-with "- ") or ($t | str starts-with "* ") })
    let has_subheading = ($content_lines | any {|l| ($l | str trim | str starts-with "#") })
    let has_fence = ($content_lines | any {|l| ($l | str trim | str starts-with "```") })
    let has_table = ($content_lines | any {|l| ($l | str trim | str starts-with "|") })

    $has_bullet and (not $has_subheading) and (not $has_fence) and (not $has_table)
}

# Embedded self-test for has-redundant-when-to-use-section (claude-skills-296).
# 13 cases: three heading-spelling variants that flag, four structural
# exemptions (H3 subheading, fenced code, table, zero bullets), a
# non-matching heading, fence-awareness in both directions (a whole flagged
# section wrapped in a fence must NOT match; a real heading followed by a
# real fenced block inside its section must still see the fence and pass),
# H2-only, a trailing-prose line that does not exempt, EOF-terminated
# sections, and the "* " bullet alternation.
def run-redundant-when-to-use-self-test [] {
    mut failed = false

    # Case 1: heading + "Activate when:" + 3 bullets -> FLAG
    if not (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 1 (basic bullets) not flagged(ansi reset)"
        $failed = true
    }

    # Case 2: heading "When to Activate" -> FLAG
    if not (has-redundant-when-to-use-section "## When to Activate\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 2 ('When to Activate') not flagged(ansi reset)"
        $failed = true
    }

    # Case 3: heading "When to use" (lowercase) -> FLAG
    if not (has-redundant-when-to-use-section "## When to use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 3 (lowercase 'use') not flagged(ansi reset)"
        $failed = true
    }

    # Case 4: same bullets + one "### Sub" line -> pass
    if (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n\n### Sub\n\nMore decision content.\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 4 (H3 subheading) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 5: same bullets + one fenced code block -> pass
    if (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n\n```bash\nexample command\n```\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 5 (fenced code block) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 6: same bullets + one "|" table line -> pass
    if (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n\n| A | B |\n|---|---|\n| 1 | 2 |\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 6 (table) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 7: heading present, prose only, zero bullets -> pass
    if (has-redundant-when-to-use-section "## When to Use\n\nThis activates when the user asks about X or Y, described only in prose.\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 7 (zero bullets) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 8: non-matching heading -> pass
    if (has-redundant-when-to-use-section "## When Nushell over bash\n\n- bash one-liners\n- structured pipelines\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 8 (non-matching heading) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 9: whole flagged section wrapped in a markdown fence -> pass
    # (proves fence-awareness: a heading found while inside an open fence is
    # an example, not real document structure).
    if (has-redundant-when-to-use-section "```markdown\n## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n```\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 9 (whole section fenced) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 10: H3 "### When to Use" + bullets, NO H2 -> pass (proves H2-only)
    if (has-redundant-when-to-use-section "### When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 10 (H3-only heading) wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 11: intro+bullets+trailing "See references/x.md" line -> FLAG
    # (trailing prose does not exempt).
    if not (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z\nSee references/x.md for details.\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 11 (trailing pointer prose) not flagged(ansi reset)"
        $failed = true
    }

    # Case 12: section is the LAST thing in the file (EOF-terminated, no
    # trailing "## ") with bullets ending at EOF -> FLAG.
    if not (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n- doing X\n- doing Y\n- doing Z") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 12 (EOF-terminated section) not flagged(ansi reset)"
        $failed = true
    }

    # Case 13: same as case 1 but using "* " bullets instead of "- " -> FLAG
    # (proves the bullet-marker alternation).
    if not (has-redundant-when-to-use-section "## When to Use\n\nActivate when:\n* doing X\n* doing Y\n* doing Z\n") {
        print $"(ansi red_bold)❌ redundant-when-to-use self-test: case 13 (star bullets) not flagged(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ redundant-when-to-use self-test passed \(13 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for the skills: frontmatter checks (claude-skills-119):
# every bad case must be flagged, every good case must pass clean. Exercises
# check-agent-skills directly — the same implementation the Pass-2 agent
# loop calls — so there is no drift between what's tested and what runs.
# Returns true when any case failed (main aggregates suites, then exits).
def run-skills-self-test [] {
    let fake_registry = [
        {name: "rust", dir: "", invocables: [], skills: ["rust" "testing" "error-handling"]}
        {name: "core", dir: "", invocables: [], skills: ["tdd" "anti-fabrication"]}
    ]
    mut failed = false

    # Case 1: inline scalar form (`skills: rust:rust` instead of a list)
    let inline = (check-agent-skills ["skills: rust:rust"] $fake_registry)
    if "skills_shape" not-in $inline.failed {
        print $"(ansi red_bold)❌ skills self-test: inline scalar form not flagged(ansi reset)"
        $failed = true
    }

    # Case 2: malformed token shape (uppercase / underscore violates ns:skill regex)
    let malformed = (check-agent-skills ["skills:" "  - Rust:BAD_Name"] $fake_registry)
    if "skills_shape" not-in $malformed.failed {
        print $"(ansi red_bold)❌ skills self-test: malformed token not flagged(ansi reset)"
        $failed = true
    }

    # Case 3: duplicate entries (both individually well-formed)
    let duplicate = (check-agent-skills ["skills:" "  - rust:rust" "  - rust:rust"] $fake_registry)
    if "skills_duplicate" not-in $duplicate.failed {
        print $"(ansi red_bold)❌ skills self-test: duplicate entries not flagged(ansi reset)"
        $failed = true
    }

    # Case 4: unresolvable token against a known namespace
    let unresolved = (check-agent-skills ["skills:" "  - rust:nonexistent"] $fake_registry)
    if ("skills_unresolved" not-in $unresolved.failed) or ("rust:nonexistent" not-in $unresolved.bad_tokens) {
        print $"(ansi red_bold)❌ skills self-test: unresolvable token not flagged(ansi reset)"
        $failed = true
    }

    # Case 5: clean list, plus an external/unknown namespace token that must
    # be skipped (leniency), not flagged unresolved
    let clean = (check-agent-skills ["skills:" "  - rust:rust" "  - core:tdd" "  - someexternal:thing"] $fake_registry)
    if ($clean.failed | is-not-empty) {
        print $"(ansi red_bold)❌ skills self-test: clean list flagged \(($clean.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ Agent skills: frontmatter self-test passed \(5 cases\)(ansi reset)"
    }
    $failed
}

# Self-test for has-anti-fab-evidence (claude-skills-202, claude-skills-203).
# Exercises the exact function the Pass-1 loop calls, so there is no drift
# between what is tested and what runs.
def run-anti-fab-self-test [] {
    mut failed = false

    # Case 1: the literal "fabricat" substring alone satisfies the check.
    if not (has-anti-fab-evidence "This skill guards against fabricated claims.") {
        print $"(ansi red_bold)❌ anti-fab self-test: 'fabricat' substring not recognized(ansi reset)"
        $failed = true
    }

    # Case 2: an "anti-fabrication" header/mention alone satisfies the check.
    if not (has-anti-fab-evidence "## Anti-fabrication\n\nRules go here.") {
        print $"(ansi red_bold)❌ anti-fab self-test: 'anti-fabrication' header not recognized(ansi reset)"
        $failed = true
    }

    # Case 3 (claude-skills-203): an explicit "verified against <tool>
    # <version>" citation satisfies the check even with neither of the above
    # two markers present — this is core/bees's actual shape (six such
    # citations, zero mentions of "fabricat" or "anti-fabrication").
    if not (has-anti-fab-evidence "Verified against bees 0.4.0 in a throwaway .bees/ directory.") {
        print $"(ansi red_bold)❌ anti-fab self-test: 'verified against X <version>' citation not recognized(ansi reset)"
        $failed = true
    }

    # Case 4: content with none of the three markers still fails — the check
    # must not become unconditionally lenient.
    if (has-anti-fab-evidence "This skill does whatever it wants with no evidence markers.") {
        print $"(ansi red_bold)❌ anti-fab self-test: content with no markers wrongly passed(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ anti-fab self-test passed \(4 cases\)(ansi reset)"
    }
    $failed
}

# Self-test for strip-frontmatter and has-braced-claude-var
# (claude-skills-205). AC requires one case each for: flagged (body), and
# not-flagged (frontmatter, references/templates-shaped content, and the
# documented body-safe angle-bracket form).
def run-braced-claude-self-test [] {
    mut failed = false

    # Case 1: braced form in a SKILL.md/commands body is flagged.
    if not (has-braced-claude-var "Run `${CLAUDE_SKILL_DIR}/scripts/foo.sh` from the body.") {
        print $"(ansi red_bold)❌ braced-claude self-test: braced form in body not flagged(ansi reset)"
        $failed = true
    }

    # Case 2: the documented body-safe bare/angle-bracket form is NOT
    # flagged — this is the skill-authoring convention that lets bodies
    # reference the var without triggering harness expansion.
    if (has-braced-claude-var "Run `bash <CLAUDE_SKILL_DIR>/scripts/foo.sh` from the body.") {
        print $"(ansi red_bold)❌ braced-claude self-test: bare angle-bracket form wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case 2b (Gate 3): the shell-default-value form is flagged too — the
    # var name is still braced-CLAUDE_*, just with a `:-default` suffix
    # before the closing brace.
    if not (has-braced-claude-var "Run `${CLAUDE_PLUGIN_ROOT:-/some/default}/scripts/foo.sh` from the body.") {
        print $"(ansi red_bold)❌ braced-claude self-test: shell-default-value form not flagged(ansi reset)"
        $failed = true
    }

    # Case 3: strip-frontmatter removes a braced occurrence living inside
    # frontmatter (the harness-expanded, allowed case — e.g. a hooks:
    # command field, per core/skills/security/SKILL.md) so the per-file
    # check never sees it.
    let fm_content = "---\nname: x\nhooks:\n  command: \"${CLAUDE_PLUGIN_ROOT}/hooks/x.sh\"\n---\n\n# X\n\nClean body, no braced vars here.\n"
    if (has-braced-claude-var (strip-frontmatter $fm_content)) {
        print $"(ansi red_bold)❌ braced-claude self-test: frontmatter-only occurrence leaked into stripped body(ansi reset)"
        $failed = true
    }

    # Case 4: a braced occurrence AFTER the frontmatter closing marker
    # survives stripping and is still flagged — proves strip-frontmatter
    # only removes the frontmatter block itself, not the whole file.
    let mixed_content = "---\nname: x\n---\n\nBody uses ${CLAUDE_SKILL_DIR} directly.\n"
    if not (has-braced-claude-var (strip-frontmatter $mixed_content)) {
        print $"(ansi red_bold)❌ braced-claude self-test: body occurrence after frontmatter not flagged(ansi reset)"
        $failed = true
    }

    # Case 5: content with no frontmatter markers at all (the references/
    # and templates/ shape — those directories are never passed through
    # this check by the Pass-1/Pass-2 call sites, but this confirms
    # strip-frontmatter itself does not silently alter non-frontmatter
    # content, which is the structural guarantee those exemptions rely on).
    let ref_like = "# Reference doc\n\nExample: `${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh`\n"
    if (strip-frontmatter $ref_like) != $ref_like {
        print $"(ansi red_bold)❌ braced-claude self-test: strip-frontmatter altered content with no frontmatter markers(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ braced-claude self-test passed \(6 cases\)(ansi reset)"
    }
    $failed
}

# Validate the baseline's allowed_failures entries. Records only — a bare
# string entry (the pre-claude-skills-132 shape) is a hard failure, because a
# hand-added string would bypass class/issue/detail_count permanently.
# Required: key, class (BUG|DEBT|CHECK_DEFECT|ACCEPTED), issue. first_seen is
# an ISO date for new entries or the literal "migrated" for pre-schema ones.
# detail_count must be an integer for detail-producing checks (DETAIL_CHECKS),
# null otherwise. Returns a list of error strings; empty means valid.
def validate-baseline-entries [entries: list] {
    let valid_classes = ["BUG" "DEBT" "CHECK_DEFECT" "ACCEPTED"]
    mut errors = []
    for entry in $entries {
        let kind = ($entry | describe)
        if not ($kind | str starts-with "record") {
            if ($kind == "string") {
                $errors = ($errors | append $"bare string entry '($entry)' — every allowed_failures entry must be a record with key/class/issue \(see _comment\)")
            } else {
                $errors = ($errors | append $"non-record entry of type ($kind): ($entry | to json --raw) — every allowed_failures entry must be a record with key/class/issue \(see _comment\)")
            }
            continue
        }
        let key = ($entry | get -o key | default "")
        if ($key | is-empty) {
            $errors = ($errors | append $"entry missing 'key': ($entry | to json --raw)")
            continue
        }
        let class = ($entry | get -o class | default "")
        if ($class | is-empty) {
            $errors = ($errors | append $"($key): missing required 'class' \(BUG | DEBT | CHECK_DEFECT | ACCEPTED\)")
        } else if ($class not-in $valid_classes) {
            $errors = ($errors | append $"($key): invalid class '($class)' — must be BUG, DEBT, CHECK_DEFECT, or ACCEPTED")
        }
        if (($entry | get -o issue | default "") | is-empty) {
            $errors = ($errors | append $"($key): missing required 'issue' \(tracker id the waiver is filed under\)")
        }
        let check = ($key | split row ":" | last)
        if ($check in $DETAIL_CHECKS) and (($entry | get -o detail_count | describe) != "int") {
            $errors = ($errors | append $"($key): '($check)' is a detail-producing check — detail_count must be an integer")
        } else if ($check not-in $DETAIL_CHECKS) and (($entry | get -o detail_count) != null) {
            # Mirror rule: a count on a boolean check would be silently
            # accepted and never compared — reject it so the entry can't
            # masquerade as ratcheted.
            $errors = ($errors | append $"($key): '($check)' is a boolean check — detail_count must be null")
        }
    }
    # Duplicate keys: the ratchet compares by key, so a duplicate would let
    # one entry's count shadow the other. Hard failure.
    let keys = ($entries
        | where {|e| ($e | describe) | str starts-with "record"}
        | each {|e| $e | get -o key | default ""}
        | where {|k| $k | is-not-empty})
    for pair in ($keys | group-by | transpose key entries) {
        if ($pair.entries | length) > 1 {
            $errors = ($errors | append $"duplicate baseline entries for key '($pair.key)' — keep exactly one")
        }
    }
    $errors
}

# Ratchet a validated baseline against the current run. Pure — returns the
# four finding lists for main to print:
# - hard_failures: failing keys with no baseline entry (new violations)
# - stale_keys: baselined keys that no longer fail (fix landed — shrink)
# - count_regressions: current detail count ABOVE the stored count (a waived
#   check absorbed new findings — the bug claude-skills-132 exists to stop)
# - stale_counts: current detail count BELOW the stored count (improvement
#   not locked in — mirror of stale_keys, one level down)
def ratchet-baseline [baseline: list, failing_keys: list, failing_counts: list] {
    let baseline_keys = ($baseline | each {|e| $e.key})
    mut count_regressions = []
    mut stale_counts = []
    for entry in $baseline {
        if (($entry | get -o detail_count | describe) != "int") { continue }
        let current = ($failing_counts | where key == $entry.key)
        if ($current | is-empty) { continue }
        let current_count = ($current | first | get count)
        if $current_count > $entry.detail_count {
            $count_regressions = ($count_regressions | append {key: $entry.key, stored: $entry.detail_count, current: $current_count})
        } else if $current_count < $entry.detail_count {
            $stale_counts = ($stale_counts | append {key: $entry.key, stored: $entry.detail_count, current: $current_count})
        }
    }
    {
        hard_failures: ($failing_keys | where {|k| $k not-in $baseline_keys})
        stale_keys: ($baseline_keys | where {|k| $k not-in $failing_keys})
        count_regressions: $count_regressions
        stale_counts: $stale_counts
    }
}

# Feed detail-producing checks' counts into the ratchet ledger
# (claude-skills-151, claude-skills-175). `failed` is a pass's set of check
# names that fired for one finding; `key_base` is the finding's stable
# key prefix (e.g. "<plugin>/<skill>" or "<plugin>/agents/<file>"); each
# `{check, count}` pair whose check name is present in `failed` contributes
# one `{key, count}` entry.
#
# This is the single call site the two recorded defects both trace back to:
# a hand-rolled loop with two independent statements — append the key,
# append the count — lets one half (the count) be deleted while the other
# (done separately by the caller before this ever runs) survives untouched.
# The per-skill Pass-1 loop already had this exact shape inline; Pass-2's
# agent/command loops computed the same detail counts (`links`, `fm_schema`)
# but never fed them here at all (claude-skills-175) — not a partial
# mutation, the wiring was simply never written for that surface. Routing
# every pass's detail-count accumulation through this one function turns
# "a pass computed a count but never fed the ratchet" into a single,
# reviewable call site instead of N independently-forgettable inline loops.
#
# What this DOES and does NOT close (corrected after a Gate 3 review of the
# first version of this comment, which overclaimed): the accumulation VALUE
# is now correct and directly unit-tested (run-accumulator-self-test,
# run-pass2-eval-self-test) wherever a caller routes through this function
# instead of hand-rolling the loop. It does NOT remove the two-statement
# shape from every call site — Pass 3 and Pass 4 still unpack this
# function's `{failing_keys, failing_counts}` result into two separate
# assignment lines, and the Gate 3 reviewer proved that pair is exactly as
# half-deletable as the original inline loop was: deleting only the
# failing_counts unpack line reproduces claude-skills-151 with both
# --self-test and the full run staying green. Two things genuinely did
# change: (1) the VALUE this function computes, given its inputs, is now
# provably correct in isolation — a bug in the accumulation logic itself,
# as opposed to a caller forgetting to use it, is caught directly; (2) a
# *whole* call-site deletion (removing this function's call along with
# BOTH unpack lines) IS caught by a full run against a real baseline,
# because the finding's key also disappears from failing_keys, which
# trips the baseline's stale-key check — not self-test-visible, but not
# silent either. The genuinely invisible mutation, in both Pass 3 and
# Pass 4, remains the half delete. Pass 2 (agents/commands) closes this
# further via evaluate-agent-file / evaluate-command-file below, which
# fold the wiring call and its result into one function that IS
# hermetically self-tested directly — see that pair's doc comment for
# what residual remains even there.
def accumulate-detail-counts [failing_counts: list, key_base: string, failed: list, detail_entries: list] {
    mut fc = $failing_counts
    for e in $detail_entries {
        if $e.check in $failed {
            $fc = ($fc | append {key: $"($key_base):($e.check)", count: $e.count})
        }
    }
    $fc
}

# Feed whole findings (key AND count together) into both ratchet
# accumulators in one call (claude-skills-151). Used by passes where every
# finding IS a detail-producing check by construction (corpus-wide
# duplicate-block groups, syntax-vs-usage vocabulary findings) — unlike
# accumulate-detail-counts, there is no separate "all failing keys"
# superset to reconcile against, so key and count travel together.
def accumulate-findings [failing_keys: list, failing_counts: list, entries: list] {
    mut fk = $failing_keys
    mut fc = $failing_counts
    for e in $entries {
        $fk = ($fk | append $e.key)
        $fc = ($fc | append {key: $e.key, count: $e.count})
    }
    {failing_keys: $fk, failing_counts: $fc}
}

# Burn-down split for the summary line. Two classes are excluded from the
# burn total, for different reasons, and both must be reported separately so
# neither exclusion can read as progress:
# - CHECK_DEFECT: defects in the checks themselves (each entry's issue field
#   names the tracker item), not skill debt.
# - ACCEPTED (claude-skills-259): a reviewed, closed verdict that the finding
#   stays — e.g. dupe/28ccd32d's assess-no-dedupe call under claude-skills-148
#   (21 shared lines vs core:git's 222, ~20:1 against; cross-plugin
#   self-containment rules out a pointer). Permanent by design, not
#   outstanding debt still to burn down; counting it in the burn total made
#   the total not shrink even after the verdict was final.
def burn-down-counts [baseline: list] {
    let excluded = ($baseline | where {|e| ($e | get -o class) == "CHECK_DEFECT"} | length)
    let accepted = ($baseline | where {|e| ($e | get -o class) == "ACCEPTED"} | length)
    {burn: (($baseline | length) - $excluded - $accepted), excluded: $excluded, accepted: $accepted}
}

# Embedded self-test for the baseline schema + count ratchet
# (claude-skills-132). Exercises validate-baseline-entries, ratchet-baseline,
# and burn-down-counts directly — the same implementations main calls.
# Cases 1-15 are hermetic in-memory fixtures. Cases 16-17 (claude-skills-184)
# depart from that: they read real repo artifacts (test/quality-baseline.json,
# plugins/*/skills/sources.md), because they assert on the flip-enforcement
# epic's atomic data changes rather than on a callable pure function — see
# each case's comment for why no pure function exists to test instead.
# Returns true when any case failed.
def run-baseline-self-test [] {
    mut failed = false

    # Case 1: bare string entry rejected
    if (validate-baseline-entries ["core/mise:anti_fab"] | is-empty) {
        print $"(ansi red_bold)❌ baseline self-test: bare string entry not rejected(ansi reset)"
        $failed = true
    }

    # Case 2: missing class rejected
    let no_class = (validate-baseline-entries [{key: "core/mise:anti_fab", issue: "claude-skills-131"}])
    if not ($no_class | any {|e| $e | str contains "class"}) {
        print $"(ansi red_bold)❌ baseline self-test: missing class not rejected(ansi reset)"
        $failed = true
    }

    # Case 3: missing issue rejected
    let no_issue = (validate-baseline-entries [{key: "core/mise:anti_fab", class: "DEBT"}])
    if not ($no_issue | any {|e| $e | str contains "issue"}) {
        print $"(ansi red_bold)❌ baseline self-test: missing issue not rejected(ansi reset)"
        $failed = true
    }

    # Case 4: invalid class value rejected (WONTFIX must be a hard failure)
    let bad_class = (validate-baseline-entries [{key: "core/mise:anti_fab", class: "WONTFIX", issue: "claude-skills-131"}])
    if not ($bad_class | any {|e| $e | str contains "WONTFIX"}) {
        print $"(ansi red_bold)❌ baseline self-test: invalid class WONTFIX not rejected(ansi reset)"
        $failed = true
    }

    # Case 5: detail-producing check without an integer detail_count rejected
    let no_count = (validate-baseline-entries [{key: "core/beads:lines", class: "DEBT", issue: "claude-skills-121", first_seen: "migrated", detail_count: null}])
    if not ($no_count | any {|e| $e | str contains "detail_count"}) {
        print $"(ansi red_bold)❌ baseline self-test: null detail_count on a detail check not rejected(ansi reset)"
        $failed = true
    }

    # Case 6: valid entries pass clean (non-detail check with null count,
    # detail check with int count)
    let valid = (validate-baseline-entries [
        {key: "core/mise:anti_fab", class: "DEBT", issue: "claude-skills-131", first_seen: "migrated", detail_count: null}
        {key: "core/beads:lines", class: "DEBT", issue: "claude-skills-121", first_seen: "migrated", detail_count: 735}
    ])
    if ($valid | is-not-empty) {
        print $"(ansi red_bold)❌ baseline self-test: valid entries flagged \(($valid | str join '; ')\)(ansi reset)"
        $failed = true
    }

    let lines_entry = [{key: "x/y:lines", class: "DEBT", issue: "claude-skills-121", first_seen: "migrated", detail_count: 505}]

    # Case 7: current count above stored fails as a regression
    let above = (ratchet-baseline $lines_entry ["x/y:lines"] [{key: "x/y:lines", count: 600}])
    if ($above.count_regressions | is-empty) {
        print $"(ansi red_bold)❌ baseline self-test: count above stored not flagged as regression(ansi reset)"
        $failed = true
    }

    # Case 8: current count below stored fails as a stale count
    let below = (ratchet-baseline $lines_entry ["x/y:lines"] [{key: "x/y:lines", count: 400}])
    if ($below.stale_counts | is-empty) {
        print $"(ansi red_bold)❌ baseline self-test: count below stored not flagged as stale(ansi reset)"
        $failed = true
    }

    # Case 9: current count equal to stored passes clean
    let equal = (ratchet-baseline $lines_entry ["x/y:lines"] [{key: "x/y:lines", count: 505}])
    if ($equal.count_regressions | is-not-empty) or ($equal.stale_counts | is-not-empty) or ($equal.hard_failures | is-not-empty) or ($equal.stale_keys | is-not-empty) {
        print $"(ansi red_bold)❌ baseline self-test: count equal to stored did not pass clean(ansi reset)"
        $failed = true
    }

    # Case 10: CHECK_DEFECT and ACCEPTED entries both excluded from the
    # burn-down total but reported in their own separate figures
    let bd = (burn-down-counts [
        {key: "a/b:anti_fab", class: "DEBT", issue: "i"}
        {key: "c/d:reserved", class: "CHECK_DEFECT", issue: "claude-skills-130"}
        {key: "e/f:duplicate_block", class: "ACCEPTED", issue: "claude-skills-148"}
    ])
    if not ($bd.burn == 1 and $bd.excluded == 1 and $bd.accepted == 1) {
        print $"(ansi red_bold)❌ baseline self-test: burn-down split wrong \(burn ($bd.burn), excluded ($bd.excluded), accepted ($bd.accepted)\)(ansi reset)"
        $failed = true
    }

    # Case 11: a fixed-but-still-waived key still fails as stale (the ratchet
    # never lets a landed fix sit behind its old waiver)
    let fixed = (ratchet-baseline [{key: "a/b:anti_fab", class: "DEBT", issue: "i", first_seen: "migrated", detail_count: null}] [] [])
    if $fixed.stale_keys != ["a/b:anti_fab"] {
        print $"(ansi red_bold)❌ baseline self-test: fixed-but-still-waived key not flagged as stale(ansi reset)"
        $failed = true
    }

    # Case 12: integer detail_count on a boolean check rejected (it would be
    # silently accepted and never compared)
    let bool_count = (validate-baseline-entries [{key: "core/mise:anti_fab", class: "DEBT", issue: "claude-skills-131", first_seen: "migrated", detail_count: 7}])
    if not ($bool_count | any {|e| $e | str contains "boolean check"}) {
        print $"(ansi red_bold)❌ baseline self-test: integer detail_count on a boolean check not rejected(ansi reset)"
        $failed = true
    }

    # Case 13: duplicate keys rejected (the ratchet compares by key)
    let dup_entry = {key: "core/mise:anti_fab", class: "DEBT", issue: "claude-skills-131", first_seen: "migrated", detail_count: null}
    let dup = (validate-baseline-entries [$dup_entry $dup_entry])
    if not ($dup | any {|e| $e | str contains "duplicate"}) {
        print $"(ansi red_bold)❌ baseline self-test: duplicate key not rejected(ansi reset)"
        $failed = true
    }

    # Case 14: non-record, non-string entry rejected with a type-accurate
    # message (not the bare-string wording)
    let non_record = (validate-baseline-entries [[1 2 3]])
    if not ($non_record | any {|e| ($e | str contains "non-record") and (not ($e | str contains "bare string"))}) {
        print $"(ansi red_bold)❌ baseline self-test: non-record non-string entry not rejected with type-accurate message(ansi reset)"
        $failed = true
    }

    # Case 15: ref_depth is a detail-producing check — null count rejected,
    # and its count ratchets in the regression direction
    let rd_null = (validate-baseline-entries [{key: "x/y:ref_depth", class: "DEBT", issue: "claude-skills-134", first_seen: "migrated", detail_count: null}])
    if not ($rd_null | any {|e| $e | str contains "detail_count"}) {
        print $"(ansi red_bold)❌ baseline self-test: null detail_count on ref_depth not rejected(ansi reset)"
        $failed = true
    }
    let rd_entry = [{key: "x/y:ref_depth", class: "DEBT", issue: "claude-skills-134", first_seen: "migrated", detail_count: 2}]
    let rd_above = (ratchet-baseline $rd_entry ["x/y:ref_depth"] [{key: "x/y:ref_depth", count: 3}])
    if ($rd_above.count_regressions | is-empty) {
        print $"(ansi red_bold)❌ baseline self-test: ref_depth count above stored not flagged as regression(ansi reset)"
        $failed = true
    }

    # Case 16 (claude-skills-184, C3 — data half): the baseline must carry
    # zero waivers for the retired "source" check (whole-file substring check
    # 11). This reads the REAL test/quality-baseline.json rather than a
    # fixture, because the epic's scope note makes this an atomic pair:
    # removing check 11 without shrinking the baseline leaves stale passing
    # keys (a hard failure), and shrinking without removing leaves the check
    # still firing. check 11 itself lives inline in `main`'s corpus loop, not
    # in a callable pure function, so its removal cannot be unit-tested here —
    # this case proves only the baseline side of the atomic pair.
    let repo_root_184 = (git rev-parse --show-toplevel | str trim)
    let source_keys = (
        open ($repo_root_184 | path join "test" "quality-baseline.json")
        | get allowed_failures
        | where {|e| ($e.key | str ends-with ":source") }
        | get key
    )
    if ($source_keys | is-not-empty) {
        print $"(ansi red_bold)❌ baseline self-test: baseline still carries ':source' waivers, must shrink atomically with check 11's removal: ($source_keys | str join ', ')(ansi reset)"
        $failed = true
    }

    # Case 17 (claude-skills-184, C2 — data half): the stale '(current)'
    # sources.md annotation lines PR1 left behind must be deleted so the
    # toml-only version_pin flip has no residual sources.md acceptance
    # signal. Reads the real sources.md files for the three plugins that
    # carry a version-pin phrase in their SKILL.md prose. This proves the
    # annotations are gone; it does NOT exercise the sources.md-acceptance-
    # path removal itself — like check 11, that logic is inline in main's
    # per-skill loop (the `stale_pins` computation), not a callable function.
    let annotated_files = (
        ["core" "languages/elixir" "languages/rust"]
        | each {|p| ($repo_root_184 | path join "plugins" $p "skills" "sources.md") }
        | where {|f| $f | path exists }
    )
    let current_lines = (
        $annotated_files
        | each {|f| open --raw $f | lines | where {|l| $l =~ '\(current\)' } }
        | flatten
    )
    if ($current_lines | is-not-empty) {
        print $"(ansi red_bold)❌ baseline self-test: ($current_lines | length) stale '\(current\)' annotation line\(s\) remain in sources.md — delete them so the toml-only version_pin flip has no residual acceptance signal(ansi reset)"
        $failed = true
    }

    # Case 18 (claude-skills-192): find-stale-version-pins is the pure
    # function extracted from main's per-skill loop (lines ~2141-2146, the
    # `stale_pins` computation). Cases 16/17 above prove only that the
    # retired sources.md acceptance path is gone from the real corpus; they
    # do not exercise this parse/trim/dedup/membership logic directly. These
    # fixtures do, without needing a plugin's sources.toml or SKILL.md on
    # disk. Contract: `find-stale-version-pins [content: string, toml_versions: list]`
    # runs both "Current stable: X" / "Currently at version X" regexes over
    # `content`, trims trailing dots off each captured version, dedupes, and
    # returns the subset absent from `toml_versions` — the same list whose
    # length feeds the version_pin failure/count today.
    #
    # The function does not exist yet, so every case wraps the call in
    # try/catch rather than calling it bare. main aggregates eight self-test
    # suites sequentially (line ~1844+) and this one runs second; an unguarded
    # call raises `nu::shell::external_command` at runtime and aborts the
    # WHOLE script unhandled, which would silently skip the six suites still
    # queued behind this one (checks, duplicate, vocab, pass2_links, orphans,
    # fm_schema) — confirmed by probe, not assumed. The catch turns that into
    # one red line per case plus a sentinel string result instead, so this
    # function keeps returning $failed normally, main's aggregation and every
    # other suite still runs, and cases 1-17 above are unaffected. Once the
    # implementer adds the function, the try block just returns its real
    # result and these become normal got-vs-want comparisons.
    let pin_cases = [
        {
            label: "pin only in prose, absent from toml_versions -> stale"
            content: "Current stable: 2.0.0"
            toml_versions: ["1.0.0"]
            want: ["2.0.0"]
        }
        {
            label: "pin present in toml_versions -> not stale"
            content: "Current stable: 1.0.0"
            toml_versions: ["1.0.0"]
            want: []
        }
        {
            label: "no pin at all -> empty result (soft check)"
            content: "This skill has no version claim anywhere."
            toml_versions: ["1.0.0"]
            want: []
        }
        {
            label: "'Currently at version X' form, absent from toml -> stale"
            content: "Currently at version 3.1.4"
            toml_versions: ["1.0.0"]
            want: ["3.1.4"]
        }
        {
            label: "trailing dot is trimmed before comparison"
            content: "Current stable: 1.2.3."
            toml_versions: ["1.2.3"]
            want: []
        }
        {
            label: "both regex forms present with different versions, only the un-pinned one is stale"
            content: "Current stable: 1.0.0. Currently at version 2.0.0."
            toml_versions: ["1.0.0"]
            want: ["2.0.0"]
        }
        {
            label: "same version pinned via both forms dedupes to one stale entry"
            content: "Current stable: 1.0.0. Currently at version 1.0.0."
            toml_versions: []
            want: ["1.0.0"]
        }
    ]
    for c in $pin_cases {
        let got = (try {
            find-stale-version-pins $c.content $c.toml_versions | sort
        } catch {|e|
            print $"(ansi red_bold)❌ find-stale-version-pins: ($c.label): call raised \(($e.msg)\)(ansi reset)"
            "FIND-STALE-VERSION-PINS-NOT-IMPLEMENTED"
        })
        if ($got | describe) == "string" {
            $failed = true
            continue
        }
        let want = ($c.want | sort)
        if $got != $want {
            print $"(ansi red_bold)❌ find-stale-version-pins: ($c.label): want ($want), got ($got)(ansi reset)"
            $failed = true
        }
    }

    if not $failed {
        print $"(ansi green_bold)✅ Baseline schema/ratchet self-test passed \(18 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for the shared detail-count accumulators
# (claude-skills-151, claude-skills-175): accumulate-detail-counts and
# accumulate-findings. These are the single call sites every pass now routes
# through instead of a hand-rolled loop; testing them directly proves the
# accumulation VALUE is correct. It does not prove every pass in main still
# CALLS them — that whole-call-site wiring gap is the recorded limitation of
# this fix (see the accumulate-detail-counts doc comment and the PR body).
# Case 6 goes one step further and chains accumulate-findings' own output
# into ratchet-baseline, the closest a hermetic test gets to the real
# pipeline shape without executing main.
def run-accumulator-self-test [] {
    mut failed = false

    # Case 1: only checks present in `failed` contribute a count entry
    let c1 = (accumulate-detail-counts [] "p/s" ["links"] [
        {check: "links", count: 2}
        {check: "fm_schema", count: 5}
    ])
    if $c1 != [{key: "p/s:links", count: 2}] {
        print $"(ansi red_bold)❌ accumulator self-test: accumulate-detail-counts included a check absent from failed(ansi reset)"
        $failed = true
    }

    # Case 2: an empty `failed` list contributes nothing, regardless of the
    # detail_entries offered — this is the exact shape claude-skills-175 hit
    # (a check computed its count but the failing_counts append was simply
    # never written for that pass).
    let c2 = (accumulate-detail-counts [] "p/s" [] [{check: "links", count: 3}])
    if ($c2 | is-not-empty) {
        print $"(ansi red_bold)❌ accumulator self-test: accumulate-detail-counts fired with an empty failed list(ansi reset)"
        $failed = true
    }

    # Case 3: multiple detail_entries all present in `failed` all append,
    # keyed off the given key_base, and prior failing_counts are preserved
    let c3 = (accumulate-detail-counts [{key: "existing:check", count: 9}] "p/agents/a.md" ["links" "fm_schema"] [
        {check: "links", count: 1}
        {check: "fm_schema", count: 4}
    ])
    if ($c3 | length) != 3 or ({key: "p/agents/a.md:links", count: 1} not-in $c3) or ({key: "p/agents/a.md:fm_schema", count: 4} not-in $c3) or ({key: "existing:check", count: 9} not-in $c3) {
        print $"(ansi red_bold)❌ accumulator self-test: accumulate-detail-counts multi-entry accumulation wrong \(($c3 | to json --raw)\)(ansi reset)"
        $failed = true
    }

    # Case 4: accumulate-findings appends the SAME key to both failing_keys
    # and failing_counts in lockstep — this is what Pass 3 (dupe) and Pass 4
    # (vocab) now call instead of a two-statement inline loop.
    let c4 = (accumulate-findings ["prior:key"] [{key: "prior:key", count: 1}] [
        {key: "dupe/abc:duplicate_block", count: 3}
    ])
    if $c4.failing_keys != ["prior:key" "dupe/abc:duplicate_block"] or ($c4.failing_counts != [{key: "prior:key", count: 1} {key: "dupe/abc:duplicate_block", count: 3}]) {
        print $"(ansi red_bold)❌ accumulator self-test: accumulate-findings did not append key and count together(ansi reset)"
        $failed = true
    }

    # Case 5: an empty entries list is a no-op — accumulators are additive,
    # never destructive of what the caller already accumulated.
    let c5 = (accumulate-findings ["x"] [{key: "x", count: 1}] [])
    if $c5.failing_keys != ["x"] or $c5.failing_counts != [{key: "x", count: 1}] {
        print $"(ansi red_bold)❌ accumulator self-test: accumulate-findings mutated on an empty entries list(ansi reset)"
        $failed = true
    }

    # Case 6: chain accumulate-findings' own output into ratchet-baseline —
    # a waived dupe group whose real window count GREW must still surface as
    # a count_regression when accumulate-findings is the thing that produced
    # failing_counts, not a hand-assembled fixture list (as case 13 in
    # run-duplicate-self-test does). This is the closest a hermetic test
    # gets to reproducing the actual claude-skills-151 defect shape without
    # running main.
    let key = "dupe/repro151:duplicate_block"
    let baseline = [{key: $key, class: "DEBT", issue: "claude-skills-900", first_seen: "2026-07-26", detail_count: 1}]
    let acc = (accumulate-findings [] [] [{key: $key, count: 4}])
    let ratchet = (ratchet-baseline $baseline $acc.failing_keys $acc.failing_counts)
    if ($ratchet.count_regressions | is-empty) or ($ratchet.count_regressions | first | get current) != 4 {
        print $"(ansi red_bold)❌ accumulator self-test: accumulate-findings -> ratchet-baseline chain did not catch a grown waived group(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ Accumulator self-test passed \(6 cases\)(ansi reset)"
    }
    $failed
}

# Check 15 (orphans) predicate, extracted so it can be self-tested.
# A bundled file counts as mentioned only when SKILL.md cites it by a path
# that RESOLVES from the skill dir — `references/x.md`, never a bare `x.md`.
# See the call site for why the bare form used to pass.
def find-orphan-files [content: string, files: list]: nothing -> list {
    $files | where {|f|
        let subdir = ($f | path dirname | path basename)
        not ($content | str contains $"($subdir)/($f | path basename)")
    }
}

# Check 17 (version_pin) predicate, extracted so it can be self-tested
# (claude-skills-192). A "Current stable: X" / "Currently at version X"
# claim must match a current_version recorded in the plugin's sources.toml;
# skills without a pin pass (soft check) — hence the empty-result cases.
def find-stale-version-pins [content: string, toml_versions: list]: nothing -> list<string> {
    let pins = ($content
        | parse --regex 'Current stable: (?P<ver>v?[0-9][0-9A-Za-z.]*)'
        | append ($content | parse --regex 'Currently at version (?P<ver>v?[0-9][0-9A-Za-z.]*)')
        | get ver | each {|v| $v | str trim -c '.'} | uniq)
    $pins | where {|v| $v not-in $toml_versions }
}

def run-orphans-self-test [] {
    mut failed = false
    let refs = ["/tmp/skill/references/alpha.md"]
    let agents = ["/tmp/skill/agents/worker.md"]

    let cases = [
        # [label, content, files, expect_orphan_count]
        ["dir-prefixed reference cited" "See `references/alpha.md` for detail." $refs 0]
        ["bare basename does NOT satisfy" "See `alpha.md` for detail." $refs 1]
        ["uncited reference is an orphan" "No mention here." $refs 1]
        ["dir-prefixed agent cited" "Hand off to `agents/worker.md`." $agents 0]
        ["bare agent basename does NOT satisfy" "Hand off to `worker.md`." $agents 1]
        ["wrong subdir does NOT satisfy" "See `agents/alpha.md` for detail." $refs 1]
    ]

    for c in $cases {
        let got = (find-orphan-files ($c | get 1) ($c | get 2) | length)
        let want = ($c | get 3)
        if $got != $want {
            print $"(ansi red_bold)❌ orphans self-test: ($c | get 0) — want ($want) orphan\(s\), got ($got)(ansi reset)"
            $failed = true
        }
    }

    if not $failed {
        print $"(ansi green_bold)✅ Orphans self-test passed \(($cases | length) cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for safe-read-ref (claude-skills-222): a broken symlink
# under references/ used to abort the ENTIRE run via an unhandled `open --raw`
# error before this function existed — zero tables printed, every other
# finding masked (reproduced against the pre-fix script: exit 1, only a raw
# nu error trace, no scorecard). Exercises all three unsafe modes against a
# REAL filesystem fixture (dangling symlink, chmod-000 file, symlink
# resolving outside the fixture's own tree) plus the normal-read path, so a
# regression that lets any one of them raise again is caught here instead of
# by a crash with no diagnostic. A green run on a corpus with no broken
# symlinks proves nothing — this fixture manufactures the failure modes
# directly. Fixture tree removed at the end. Returns true when any case
# failed.
def run-safe-read-ref-self-test [] {
    mut failed = false

    let root = (mktemp -d)
    let repo = ($root | path join "repo")
    let refs = ($repo | path join "references")
    mkdir $refs
    "normal content" | save ($refs | path join "good.md")
    ^ln -s /nonexistent-target-claude-skills-222 ($refs | path join "broken.md")
    "" | save ($refs | path join "unreadable.md")
    ^chmod 000 ($refs | path join "unreadable.md")
    # The outside target must exist and be readable, so this case proves
    # "resolves outside the repo", not "happens to also be broken".
    let outside = ($root | path join "outside.md")
    "outside content" | save $outside
    ^ln -s $outside ($refs | path join "external.md")

    # Case: normal file reads through unchanged.
    let good = (safe-read-ref ($refs | path join "good.md") $repo)
    if $good.unsafe or $good.content != "normal content" {
        print $"(ansi red_bold)❌ safe-read-ref self-test: normal file wrongly flagged unsafe \(got: ($good)\)(ansi reset)"
        $failed = true
    }

    # Case: broken (dangling) symlink is reported, not raised.
    let broken = (safe-read-ref ($refs | path join "broken.md") $repo)
    if not $broken.unsafe or $broken.reason != "broken" {
        print $"(ansi red_bold)❌ safe-read-ref self-test: broken symlink not reported \(got: ($broken)\)(ansi reset)"
        $failed = true
    }

    # Case: unreadable permissions is reported, not raised.
    let unreadable = (safe-read-ref ($refs | path join "unreadable.md") $repo)
    if not $unreadable.unsafe or $unreadable.reason != "unreadable" {
        print $"(ansi red_bold)❌ safe-read-ref self-test: unreadable file not reported \(got: ($unreadable)\)(ansi reset)"
        $failed = true
    }

    # Case: symlink resolving outside the repo is quarantined — reported, and
    # its content is never read (empty), even though the target itself is
    # perfectly readable.
    let external = (safe-read-ref ($refs | path join "external.md") $repo)
    if not $external.unsafe or $external.reason != "external" or $external.content != "" {
        print $"(ansi red_bold)❌ safe-read-ref self-test: external symlink not quarantined \(got: ($external)\)(ansi reset)"
        $failed = true
    }

    ^chmod 644 ($refs | path join "unreadable.md")
    rm -rf $root
    if not $failed {
        print $"(ansi green_bold)✅ safe-read-ref self-test passed \(4 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for the check fixes from claude-skills-130: reserved
# exact-match, examples-via-reachable-reference, fence-length-aware
# stripping, ref_depth heading/bare-token exemptions, and enumerated
# upstream commands. Every fix is exercised in BOTH directions — the false
# positive must be gone AND a genuine violation must still be caught — so a
# check cannot stop misfiring by becoming permissive. Exercises the same
# functions main calls. Returns true when any case failed.
# Frontmatter schema (claude-skills-175). Nothing validated which KEYS a
# frontmatter block may carry, so a typo or an invented field shipped silently.
#
# SKILL_FM_KEYS is the upstream Claude Code frontmatter reference
# (https://code.claude.com/docs/en/skills#frontmatter-reference), verified
# against the live docs rather than against our own — checking our schema with
# our schema is circular. Commands share this schema: custom commands merged
# into skills upstream. `license` and `metadata` come from the Agent Skills
# open standard (agentskills.io) that Claude Code skills follow; they are not
# in the Claude Code table but are valid and 57 skills here use `license`.
#
# NOTE: `allowed-tools` is upstream-valid but rejected on skills by THIS
# marketplace — that is a separate, stricter check (`allowed_tools`), not this
# one. This check answers "is the key real", not "do we permit it".
const SKILL_FM_KEYS = [
    "name" "description" "when_to_use" "license" "metadata" "compatibility"
    "argument-hint" "arguments" "disable-model-invocation" "user-invocable"
    "allowed-tools" "disallowed-tools" "model" "effort" "context" "agent"
    "background" "hooks" "paths" "shell"
]

# Agent frontmatter is a DIFFERENT schema — verified against the upstream
# sub-agents reference (https://code.claude.com/docs/en/sub-agents), 16 fields.
# Five are camelCase; an earlier extraction regex assumed lowercase-and-hyphen
# and silently dropped all five, which would have made this check fire on
# `maxTurns` — a field our own claude-agents skill recommends. Any future edit
# here must be re-extracted case-insensitively.
const AGENT_FM_KEYS = [
    "name" "description" "tools" "disallowedTools" "model" "permissionMode"
    "maxTurns" "skills" "mcpServers" "hooks" "memory" "background" "effort"
    "isolation" "color" "initialPrompt"
]

# Output-style frontmatter is a THIRD schema — verified against the upstream
# output-styles reference (https://code.claude.com/docs/en/output-styles)
# during PR #264: exactly four documented fields. `name` and `description`
# are optional upstream (name defaults to filename, description is merely
# shown in the `/config` picker) but are required by THIS marketplace's
# house rule — an undescribed style is invisible in the picker (claude-skills-310).
const OUTPUT_STYLE_FM_KEYS = [
    "name" "description" "keep-coding-instructions" "force-for-plugin"
]

# Returns frontmatter keys not present in `allowed`. Keys only — values are
# other checks' business. A block with no frontmatter yields no findings.
#
# Known residual: the key must abut its colon. `descriptoin : y` is valid YAML
# but matches nothing here, so a typo written with a space before the colon is
# not caught. Dotted keys (`foo.bar:`) are likewise skipped. Both are rare
# enough to leave; widening the regex risks matching prose lines.
def unknown-frontmatter-keys [fm_lines: list, allowed: list]: nothing -> list {
    $fm_lines
        | each {|line|
            let m = ($line | parse --regex '^(?P<key>[A-Za-z_][A-Za-z0-9_-]*):')
            if ($m | is-empty) { null } else { $m | first | get key }
        }
        | compact
        | where {|k| $k not-in $allowed }
        | uniq
}

def run-frontmatter-schema-self-test [] {
    mut failed = false
    let cases = [
        # [label, fm_lines, allowed, expected unknown keys]
        ["all keys valid" ["name: x" "description: y"] $SKILL_FM_KEYS []]
        ["hooks is valid on a skill" ["name: x" "hooks:"] $SKILL_FM_KEYS []]
        ["license is valid (open standard)" ["name: x" "license: MIT"] $SKILL_FM_KEYS []]
        ["typo is caught" ["name: x" "descriptoin: y"] $SKILL_FM_KEYS ["descriptoin"]]
        ["invented field is caught" ["name: x" "hook: y"] $SKILL_FM_KEYS ["hook"]]
        ["nested values are not keys" ["hooks:" "  PreToolUse:" "    - matcher: Bash"] $SKILL_FM_KEYS []]
        ["agent schema differs from skill" ["name: x" "tools: Read"] $AGENT_FM_KEYS []]
        ["skill-only key rejected on an agent" ["name: x" "paths: '*.md'"] $AGENT_FM_KEYS ["paths"]]
        ["agent-only key rejected on a skill" ["name: x" "isolation: worktree"] $SKILL_FM_KEYS ["isolation"]]
        ["camelCase agent keys are valid" ["name: x" "maxTurns: 5" "disallowedTools: Bash"] $AGENT_FM_KEYS []]
        ["compatibility is valid (open standard)" ["name: x" "compatibility: needs git"] $SKILL_FM_KEYS []]
        ["empty frontmatter yields nothing" [] $SKILL_FM_KEYS []]
        ["output-style schema accepts all four documented keys" ["name: x" "description: y" "keep-coding-instructions: true" "force-for-plugin: false"] $OUTPUT_STYLE_FM_KEYS []]
        ["unknown key rejected on an output style" ["name: x" "description: y" "badkey: z"] $OUTPUT_STYLE_FM_KEYS ["badkey"]]
    ]
    for c in $cases {
        let got = (unknown-frontmatter-keys ($c | get 1) ($c | get 2))
        let want = ($c | get 3)
        if $got != $want {
            print $"(ansi red_bold)❌ frontmatter-schema self-test: ($c | get 0) — want ($want), got ($got)(ansi reset)"
            $failed = true
        }
    }
    if not $failed {
        print $"(ansi green_bold)✅ Frontmatter-schema self-test passed \(($cases | length) cases\)(ansi reset)"
    }
    $failed
}

def run-check-fixes-self-test [] {
    mut failed = false
    let tick1 = '`'
    let tick3 = ([$tick1 $tick1 $tick1] | str join)
    let tick4 = ([$tick1 $tick1 $tick1 $tick1] | str join)

    # --- reserved (exact match only) ---
    if not (is-reserved-name "claude") {
        print $"(ansi red_bold)❌ check-fix self-test: exact name 'claude' not flagged reserved(ansi reset)"
        $failed = true
    }
    if not (is-reserved-name "anthropic") {
        print $"(ansi red_bold)❌ check-fix self-test: exact name 'anthropic' not flagged reserved(ansi reset)"
        $failed = true
    }
    if (is-reserved-name "claude-agents") {
        print $"(ansi red_bold)❌ check-fix self-test: 'claude-agents' wrongly flagged reserved(ansi reset)"
        $failed = true
    }
    if (is-reserved-name "claude-code-on-sandbox") {
        print $"(ansi red_bold)❌ check-fix self-test: 'claude-code-on-sandbox' wrongly flagged reserved(ansi reset)"
        $failed = true
    }

    # --- examples (fence in a reachable reference counts; orphaned doesn't) ---
    let fenced_ref = [{name: "patterns.md", content: ([$"($tick3)nu" "code" $tick3] | str join "\n")}]
    if not (has-examples "See references/patterns.md for worked examples." $fenced_ref) {
        print $"(ansi red_bold)❌ check-fix self-test: reachable fenced reference did not satisfy examples(ansi reset)"
        $failed = true
    }
    if (has-examples "Prose that mentions no reference file." $fenced_ref) {
        print $"(ansi red_bold)❌ check-fix self-test: ORPHANED fenced reference satisfied examples(ansi reset)"
        $failed = true
    }
    if not (has-examples ([$tick3 "code" $tick3] | str join "\n") []) {
        print $"(ansi red_bold)❌ check-fix self-test: fence in SKILL.md itself did not satisfy examples(ansi reset)"
        $failed = true
    }
    if (has-examples "Prose only, no fences, no example header." []) {
        print $"(ansi red_bold)❌ check-fix self-test: skill with no examples anywhere passed(ansi reset)"
        $failed = true
    }

    # --- strip-fences (fence-length-aware per CommonMark) ---
    let nested = ([$"($tick4)markdown" $tick3 "inner content" $tick3 "see references/foo.md" $tick4 "kept after"] | str join "\n")
    let stripped = (strip-fences $nested)
    if ($stripped | str contains "references/foo.md") or ($stripped | str contains "inner content") or (not ($stripped | str contains "kept after")) {
        print $"(ansi red_bold)❌ check-fix self-test: 4-backtick outer fence did not contain 3-backtick inner fences(ansi reset)"
        $failed = true
    }
    let plain = (strip-fences ([$tick3 "secret" $tick3 "kept"] | str join "\n"))
    if ($plain | str contains "secret") or (not ($plain | str contains "kept")) {
        print $"(ansi red_bold)❌ check-fix self-test: plain 3-backtick fence no longer stripped(ansi reset)"
        $failed = true
    }

    # --- ref_depth token scan (heading + bare-directory exemptions) ---
    if (has-unqualified-references-token "### references/command-reference.md (if present)" "myskill" [] [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: heading line wrongly counted as nested reference(ansi reset)"
        $failed = true
    }
    if not (has-unqualified-references-token "See references/foo.md for detail." "myskill" [] [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: genuine sibling reference link not flagged(ansi reset)"
        $failed = true
    }
    if (has-unqualified-references-token $"- Move detailed reference material to ($tick1)references/($tick1)" "myskill" [] [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: bare references/ directory mention wrongly flagged(ansi reset)"
        $failed = true
    }
    # Composition with strip-fences: a sibling link INSIDE a 4-backtick outer
    # fence is example content (not flagged); outside any fence it is flagged.
    if (has-unqualified-references-token (strip-fences $nested) "myskill" [] [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: sibling link inside nested fence wrongly flagged(ansi reset)"
        $failed = true
    }
    if not (has-unqualified-references-token (strip-fences ([$tick3 "code" $tick3 "see references/foo.md"] | str join "\n")) "myskill" [] [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: sibling link outside fences not flagged after stripping(ansi reset)"
        $failed = true
    }

    # --- ref_depth bare sibling link detection (claude-skills-309) ---
    # A markdown link naming a sibling reference file by bare filename
    # (`[attribution.md](attribution.md)`, no `references/` prefix) violates
    # the same one-level rule as a `references/foo.md` token but carries no
    # such token, so the scan above never sees it (shipped in PR #263:
    # `attribution.md` linking `references/flavored-prose.md` WAS flagged;
    # `flavored-prose.md` linking `[attribution.md](attribution.md)` was
    # NOT). These cases pin the fix via the new `sibling_basenames`
    # parameter — the current skill's own references/*.md basenames, as
    # computed at the real call site from the other files in the same
    # references/ dir.
    let rd_siblings = ["attribution.md" "flavored-prose.md"]
    if not (has-unqualified-references-token "[attribution.md](attribution.md)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: bare sibling markdown link not flagged(ansi reset)"
        $failed = true
    }
    if not (has-unqualified-references-token "See [flavored-prose.md](flavored-prose.md) for detail." "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: bare sibling markdown link in prose not flagged(ansi reset)"
        $failed = true
    }
    if (has-unqualified-references-token "[other.md](other.md)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: bare link to a NON-sibling file wrongly flagged(ansi reset)"
        $failed = true
    }
    # Composition with strip-fences: a bare sibling link inside a fence is
    # example content (not flagged), same rule as a references/ token.
    let fenced_sibling_link = (strip-fences ([$tick3 "code" "[attribution.md](attribution.md)" $tick3] | str join "\n"))
    if (has-unqualified-references-token $fenced_sibling_link "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: bare sibling link inside fence wrongly flagged(ansi reset)"
        $failed = true
    }
    # An external URL whose final path segment happens to match a sibling
    # basename is not a same-skill link — must not be flagged.
    if (has-unqualified-references-token "[link](https://example.com/attribution.md)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: external URL ending in a sibling basename wrongly flagged(ansi reset)"
        $failed = true
    }
    # Existing glob-in-prose exemption (references/*.md as prose, not a
    # concrete path) must still pass with the new parameter threaded through.
    if (has-unqualified-references-token "See a `references/*.md` file for the pattern." "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: glob-in-prose exemption wrongly flagged(ansi reset)"
        $failed = true
    }
    # Anchor and title forms on a bare sibling link (Gate 3 finding): the OLD
    # `references/` token branch DOES flag `references/foo.md#anchor`, so a
    # bare-link branch that misses `attribution.md#usage` disagrees with the
    # established behavior for the identical evasion. Both must still flag.
    if not (has-unqualified-references-token "[attribution.md](attribution.md#usage)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: bare sibling link with anchor not flagged(ansi reset)"
        $failed = true
    }
    if not (has-unqualified-references-token $"[x]\(attribution.md \"Some Title\"\)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: bare sibling link with title not flagged(ansi reset)"
        $failed = true
    }
    # Guard the widening: fragment-stripping must not make an external URL
    # match, and an anchor must not turn a NON-sibling target into a match.
    if (has-unqualified-references-token "[x](https://example.com/attribution.md#usage)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: external URL with anchor wrongly flagged(ansi reset)"
        $failed = true
    }
    if (has-unqualified-references-token "[x](other.md#usage)" "myskill" [] [] $rd_siblings) {
        print $"(ansi red_bold)❌ check-fix self-test: NON-sibling link with anchor wrongly flagged(ansi reset)"
        $failed = true
    }

    # --- ref_depth cross-skill exemption is word-order sensitive (claude-skills-195) ---
    # These four cases pin the documented residual on
    # has-unqualified-references-token's header comment (accepted-residual
    # bullet three): the exemption fires only when the /ns:skill qualifier
    # PRECEDES the references/ path on the same line. Unlike the cases
    # above, they build a REAL skill_dir_map fixture — the existing ref_depth
    # cases all pass `[] []`, which makes every qualifier resolve as
    # "unknown -> exempt" and would make an order check vacuous. This
    # fixture (a synthetic mktemp tree, never a real corpus skill, so a
    # future reference-file rename in this repo can't break it) makes the
    # `path exists` branch of cross-skill-qualified genuinely fire. otherskill
    # owns BOTH foo.md and bar.md — the bar.md duplicate basename is what
    # makes case 3 below load-bearing (the 19-colliding-basenames shape).
    let rd_root = (mktemp -d)
    mkdir ($rd_root | path join "otherns" "skills" "otherskill" "references")
    "content" | save ($rd_root | path join "otherns" "skills" "otherskill" "references" "foo.md")
    "content" | save ($rd_root | path join "otherns" "skills" "otherskill" "references" "bar.md")
    let rd_map = [{skill: "otherskill", dir: ($rd_root | path join "otherns" "skills" "otherskill"), plugin: "otherns"}]
    let rd_plugins = ["otherns"]

    # Case: qualifier BEFORE the path — a real cross-skill pointer whose
    # target file exists in the other skill's own tree. NOT flagged.
    if (has-unqualified-references-token "Per `/otherns:otherskill`'s `references/foo.md`: see there for detail." "myskill" $rd_map $rd_plugins []) {
        print $"(ansi red_bold)❌ check-fix self-test: qualifier-before cross-skill pointer wrongly flagged(ansi reset)"
        $failed = true
    }

    # Case: the SAME pointer, reordered so the qualifier comes AFTER the
    # path. This is the documented residual, not a bug — the test's purpose
    # is to make a silent future widening (to whole-line matching)
    # impossible without a failing test alerting the author.
    if not (has-unqualified-references-token "Per `references/foo.md` in `/otherns:otherskill`: see there for detail." "myskill" $rd_map $rd_plugins []) {
        print $"(ansi red_bold)❌ check-fix self-test: qualifier-after cross-skill pointer no longer flagged \(documented residual regressed\)(ansi reset)"
        $failed = true
    }

    # Case: a genuine same-skill reference (references/bar.md, owned by
    # THIS skill, "myskill") followed by an unrelated mention of a
    # DIFFERENT, real sibling skill (otherskill) that happens to own a
    # DIFFERENT file sharing the same basename bar.md — the 19-colliding-
    # basenames shape the header comment cites. Under prefix-only matching
    # (shipped) the trailing mention is irrelevant since it comes after the
    # path — correctly flagged. This is the load-bearing regression guard
    # against whole-line widening: gate-verified that widening resolves
    # `otherskill` and finds ITS bar.md exists, flipping this to wrongly
    # exempt even though the path never named otherskill at all.
    if not (has-unqualified-references-token "See references/bar.md for detail, mirroring the layout in /otherns:otherskill." "myskill" $rd_map $rd_plugins []) {
        print $"(ansi red_bold)❌ check-fix self-test: same-skill link with trailing same-basename sibling mention wrongly exempted(ansi reset)"
        $failed = true
    }

    # Case: a genuine same-skill reference (references/qux.md — no fixture
    # file needed; the same-skill link never reaches the `path exists`
    # branch since no qualifier precedes it) followed by a mention of a
    # namespace/skill this marketplace does NOT know about at all
    # (unknown skill "codex" under unknown plugin "openai" — neither is in
    # rd_map/rd_plugins). Correctly flagged today: no qualifier precedes
    # the path, so cross-skill-qualified never reaches the "unknown ->
    # exempt" leniency branch. The second documented false-negative shape:
    # gate-verified that whole-line widening resolves `codex` via
    # lookup-skill-dir, gets "" back (truly unknown), and that empty-target
    # branch (line ~128-130) returns true unconditionally — flipping this
    # to wrongly exempt via a namespace that owns nothing at all.
    if not (has-unqualified-references-token "See references/qux.md for detail; the equivalent for Codex lives in /openai:codex." "myskill" $rd_map $rd_plugins []) {
        print $"(ansi red_bold)❌ check-fix self-test: same-skill link with trailing unknown-namespace mention wrongly exempted(ansi reset)"
        $failed = true
    }

    rm -rf $rd_root

    # --- invocations (enumerated upstream commands, no namespace exemption) ---
    let allium_cmds = ($UPSTREAM_COMMANDS | where ns == "allium" | first | get commands)
    let reg = [
        {name: "allium", dir: "", invocables: (["allium"] | append $allium_cmds), skills: ["allium"]}
        {name: "core", dir: "", invocables: ["tdd"], skills: ["tdd"]}
    ]
    if (find-bad-invocations "/allium:elicit and /allium:weed" $reg | is-not-empty) {
        print $"(ansi red_bold)❌ check-fix self-test: upstream allium commands not resolvable(ansi reset)"
        $failed = true
    }
    if ("/allium:nonexistent" not-in (find-bad-invocations "/allium:nonexistent" $reg)) {
        print $"(ansi red_bold)❌ check-fix self-test: /allium:nonexistent not flagged \(namespace became exempt\)(ansi reset)"
        $failed = true
    }
    if ("/core:nonexistent" not-in (find-bad-invocations "/core:nonexistent" $reg)) {
        print $"(ansi red_bold)❌ check-fix self-test: bad target in another local namespace not flagged(ansi reset)"
        $failed = true
    }
    if (find-bad-invocations "/unknownexternal:thing" $reg | is-not-empty) {
        print $"(ansi red_bold)❌ check-fix self-test: unknown external namespace no longer skipped(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ Check-fix self-test passed \(23 cases\)(ansi reset)"
    }
    $failed
}

# Normalise one file's content for the duplicate-block scan: keep only lines
# that carry comparable content. Fence DELIMITERS are dropped but fenced code
# stays in the corpus — a duplicated example block is real duplication. Each
# kept line is trimmed, stripped of leading -/*/+ bullets and N. ordered
# markers, stripped of backticks, and has internal whitespace collapsed, so
# a re-bulleted or re-backticked copy still unifies with its source. Blank
# and punctuation-only lines (---, |---|, >) are dropped. Single-word lines
# are KEPT: the core-list load lists are single-word lines, and filtering
# them hides exactly the flagship cross-file duplication this check exists
# to find (claude-skills-124 plan, revision 2 measurement).
def normalise-dupe-lines [content: string] {
    $content | lines
        | where {|l| not ($l | str trim | str starts-with '```')}
        | each {|l|
            $l | str trim
               | str replace --regex '^[-*+]\s+' ''
               | str replace --regex '^\d+\.\s+' ''
               | str replace --all '`' ''
               | str replace --regex --all '\s+' ' '
               | str trim
        }
        | where {|l| $l =~ '[A-Za-z0-9]'}
}

# Corpus-wide duplicate-block scan (claude-skills-124): slide a DUPE_WINDOW
# window of normalised lines over every file and report each SET of files
# sharing at least one window. Grouping by file set means one duplicated
# section is ONE finding, not N overlapping windows — the group's `windows`
# count is how many distinct windows the set shares, which is what the
# baseline's detail_count ratchets. Scope is cross-file only (sets of ≥2
# distinct files): within-file repetition is a style concern, not the
# copy-drift this check exists to catch. Returns [{files: sorted list,
# windows: int}].
# Split a corpus path list into files present on disk and files that are
# git-tracked but missing from the working tree (an uncommitted deletion).
# Callers MUST report the missing list rather than dropping it silently.
def split-corpus-paths [entries: list] {
    let missing = ($entries | where {|e| not $e.exists} | get path)
    {
        present: ($entries | where exists | get path)
        missing: $missing
        # The announcement is RETURNED rather than printed inside main, so a
        # self-test can assert it exists. A caller that drops it reintroduces
        # the silent-shrink failure this helper exists to prevent, and an
        # unenforced "callers MUST report" comment does not stop that.
        warnings: (if ($missing | is-empty) { [] } else {
            ([$"⚠  duplicate-block scan skipped ($missing | length) tracked file\(s\) missing from the working tree \(uncommitted deletions\):"]
                | append ($missing | each {|m| $"     ($m)"}))
        })
    }
}
def find-duplicate-groups [files: list] {
    let window_hits = ($files | each {|f|
        let kept = (normalise-dupe-lines $f.content)
        if ($kept | length) < $DUPE_WINDOW {
            []
        } else {
            $kept | window $DUPE_WINDOW
                | each {|w| $w | str join "\n" | hash md5}
                | uniq
                | each {|h| {hash: $h, path: $f.path}}
        }
    } | flatten)
    $window_hits
        | group-by hash
        | transpose hash hits
        | each {|g| ($g.hits | get path | uniq | sort)}
        | where {|paths| ($paths | length) >= 2}
        | each {|paths| {set_id: ($paths | str join "\n"), paths: $paths}}
        | group-by set_id
        | transpose set_id members
        | each {|g| {files: ($g.members | first | get paths), windows: ($g.members | length)}}
}

# Exemptions for the duplicate-block check. Each is deliberate; a file set
# matching none of them is a finding.
def dupe-exempt [file_set: list, satellites: list] {
    # Exemption 1: every member lives under a templates/ dir. Template dirs
    # are deliberately preserved upstream doc snapshots — identical copies
    # are their job, not drift.
    if ($file_set | all {|p| $p | str contains "/templates/"}) { return true }
    # Exemption 2: the file set is confined to a single skill. A worked
    # example shared between SKILL.md and its own references (or between two
    # references of one skill) is intentional.
    let skill_prefixes = ($file_set | each {|p|
        let m = ($p | parse --regex '^(?P<skill>plugins/.+?/skills/[^/]+)/')
        if ($m | is-empty) { "" } else { $m | first | get skill }
    })
    if (($skill_prefixes | uniq) == [($skill_prefixes | first)]) and (($skill_prefixes | first) != "") { return true }
    # Exemption 3: the file set is owned by test/validate-core-list.nu, which
    # drift-checks the core-list satellites with per-file anchors and its own
    # self-test suite. One concern, one owner — defer rather than
    # double-report the same duplication.
    if ($file_set | all {|p| $p in $satellites}) { return true }
    false
}

# Stable baseline key for a duplicate group: dupe/<md5-8 of the sorted member
# set>:duplicate_block. The hash makes the key independent of unrelated
# corpus changes — it changes only when the group's file set changes. The
# :duplicate_block suffix keeps the existing `<prefix>:check` key contract:
# validate-baseline-entries derives the check name from the last :-segment
# (so the detail_count rules apply), and ratchet-baseline is key-agnostic.
# Member paths are printed alongside the key in main's report so a human can
# act on a bare hash.
def dupe-key [file_set: list] {
    let h = ($file_set | sort | str join "\n" | hash md5 | str substring 0..7)
    $"dupe/($h):duplicate_block"
}

# Satellite file list owned by test/validate-core-list.nu (its SATELLITES
# const plus CANONICAL_FILE), derived by parsing that script rather than
# hardcoding a second copy — a hardcoded copy would be the exact duplication
# this check exists to find. If the parse ever breaks it returns fewer
# entries and exemption 3 stops firing, which surfaces LOUDLY as new hard
# failures (and the self-test asserts the known shapes are present).
# Lines between `const SATELLITES = [` and the matching top-level `]` in
# validate-core-list.nu. Scoping to this block (claude-skills-151 follow-up)
# matters because the unscoped form matched `path: "..."` ANYWHERE in the
# file — a future test fixture or self-test case adding that literal
# substring elsewhere would silently widen exemption 3 beyond the real
# satellite list. Entries in SATELLITES are flat `{ path: ... anchor: ... }`
# records with no nested `[`/`]`, so the first bare `]` after the opener is
# always the block's own close.
def satellites-block-lines [all_lines: list] {
    let start_matches = ($all_lines | enumerate | where {|item| $item.item | str starts-with "const SATELLITES = ["})
    if ($start_matches | is-empty) {
        []
    } else {
        let start_idx = ($start_matches | first | get index)
        let rest = ($all_lines | skip ($start_idx + 1))
        let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "]"})
        if ($end_matches | is-not-empty) {
            let end_idx = ($end_matches | first | get index)
            $rest | first $end_idx
        } else {
            []
        }
    }
}

def core-list-satellites [script_path: string] {
    let raw = (open --raw $script_path)
    # Full-line comments are dropped before parsing (claude-skills-151 Gate 3
    # finding): satellites-block-lines only bounds WHERE the parse looks
    # (inside vs outside the SATELLITES block); a comment line INSIDE the
    # block that happens to contain the literal substring `path: "..."` —
    # documentation, a worked example, a commented-out entry — would
    # otherwise leak into the result exactly as if it were a real record.
    let block_lines = (satellites-block-lines ($raw | lines)
        | where {|l| not ($l | str trim | str starts-with "#")})
    let block = ($block_lines | str join "\n")
    let sat = ($block | parse --regex 'path: "(?P<p>[^"]+)"' | get p)
    let canonical = ($raw | parse --regex 'const CANONICAL_FILE = "(?P<p>[^"]+)"' | get p)
    $sat | append $canonical | uniq
}

# Embedded self-test for the corpus-wide duplicate-block check
# (claude-skills-124). Exercises normalise-dupe-lines, find-duplicate-groups,
# dupe-exempt, dupe-key, core-list-satellites, and the baseline integration
# (key shape + detail_count ratchet) — the same implementations main calls.
# Returns true when any case failed.
def run-duplicate-self-test [] {
    mut failed = false
    let tick1 = '`'
    let tick3 = ([$tick1 $tick1 $tick1] | str join)

    let block_lines = [
        "alpha one" "beta two" "gamma three" "delta four"
        "epsilon five" "zeta six" "eta seven" "theta eight"
    ]
    let block = ($block_lines | str join "\n")
    let file_a = "plugins/a/skills/x/SKILL.md"
    let file_b = "plugins/b/skills/y/SKILL.md"

    # Case 1: an 8-line block shared by two files is found as one group of
    # one window, with the member files sorted
    let found = (find-duplicate-groups [
        {path: $file_a, content: $block}
        {path: $file_b, content: ([$block "unshared trailer line"] | str join "\n")}
    ])
    if ($found | length) != 1 or ($found | first | get windows) != 1 or (($found | first | get files) != [$file_a $file_b]) {
        print $"(ansi red_bold)❌ duplicate self-test: shared 8-line block not found as one 1-window group(ansi reset)"
        $failed = true
    }

    # Case 2: a 10-line duplicated section is ONE group whose window count is
    # the overlapping-window count (3), never three separate findings
    let long_block = ($block_lines | append ["iota nine" "kappa ten"] | str join "\n")
    let overlapping = (find-duplicate-groups [
        {path: $file_a, content: $long_block}
        {path: $file_b, content: $long_block}
    ])
    if ($overlapping | length) != 1 or ($overlapping | first | get windows) != 3 {
        print $"(ansi red_bold)❌ duplicate self-test: 10-line section not grouped as one 3-window finding(ansi reset)"
        $failed = true
    }

    # Case 3: normalisation unifies bullet markers, ordered markers, backticks
    # and internal whitespace; blank, punctuation-only, and fence-delimiter
    # lines are dropped so they cannot break a window
    let decorated = ([
        $"- ($tick1)alpha   one($tick1)"
        "---"
        "* beta two"
        ""
        $"($tick3)nu"
        "1. gamma three"
        "delta    four"
        ">"
        $tick3
        "2. epsilon five"
        $"($tick1)zeta six($tick1)"
        "|---|"
        "+ eta seven"
        "theta  eight"
    ] | str join "\n")
    let unified = (find-duplicate-groups [
        {path: $file_a, content: $block}
        {path: $file_b, content: $decorated}
    ])
    if ($unified | length) != 1 {
        print $"(ansi red_bold)❌ duplicate self-test: normalisation did not unify decorated variant(ansi reset)"
        $failed = true
    }

    # Case 4: single-word lines are corpus lines — the flagship core-list
    # load lists are single-word lines and a single-word filter hides them
    let words = (["one" "two" "three" "four" "five" "six" "seven" "eight"] | str join "\n")
    let single_word = (find-duplicate-groups [
        {path: $file_a, content: $words}
        {path: $file_b, content: $words}
    ])
    if ($single_word | length) != 1 {
        print $"(ansi red_bold)❌ duplicate self-test: single-word lines were dropped \(flagship case hidden\)(ansi reset)"
        $failed = true
    }

    # Case 5: repetition confined to ONE file is out of scope (cross-file check)
    let within = (find-duplicate-groups [
        {path: $file_a, content: ([$block "solo divider line" $block] | str join "\n")}
        {path: $file_b, content: "entirely unrelated content"}
    ])
    if ($within | is-not-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: within-one-file repetition wrongly reported(ansi reset)"
        $failed = true
    }

    # Case 6: exemption 1 — a file set entirely under templates/ dirs is
    # exempt; a mixed set is not
    if not (dupe-exempt ["plugins/a/skills/x/templates/CLAUDE.md" "plugins/tools/claude-code/templates/CLAUDE.md"] []) {
        print $"(ansi red_bold)❌ duplicate self-test: all-templates file set not exempted(ansi reset)"
        $failed = true
    }
    if (dupe-exempt ["plugins/a/skills/x/templates/CLAUDE.md" $file_b] []) {
        print $"(ansi red_bold)❌ duplicate self-test: mixed templates/non-templates set wrongly exempted(ansi reset)"
        $failed = true
    }

    # Case 7: exemption 2 — a file set confined to a single skill is exempt;
    # two skills, or a file with no skill prefix (root CLAUDE.md), is not
    if not (dupe-exempt ["plugins/core/skills/tdd/SKILL.md" "plugins/core/skills/tdd/references/beck-tdd.md"] []) {
        print $"(ansi red_bold)❌ duplicate self-test: same-skill file set not exempted(ansi reset)"
        $failed = true
    }
    if (dupe-exempt ["plugins/core/skills/tdd/SKILL.md" "plugins/core/skills/restraint/SKILL.md"] []) {
        print $"(ansi red_bold)❌ duplicate self-test: two-skill file set wrongly exempted(ansi reset)"
        $failed = true
    }
    if (dupe-exempt ["CLAUDE.md" "plugins/core/skills/tdd/SKILL.md"] []) {
        print $"(ansi red_bold)❌ duplicate self-test: root CLAUDE.md + skill file wrongly exempted(ansi reset)"
        $failed = true
    }

    # Case 8: exemption 3 — a file set that is a subset of the core-list
    # satellites is deferred to validate-core-list.nu; one non-satellite
    # member breaks the exemption
    let sats = ["plugins/core/commands/work.md" "plugins/core/hooks/session-start.sh" "plugins/core/skills/agent-loop/SKILL.md"]
    if not (dupe-exempt ["plugins/core/commands/work.md" "plugins/core/hooks/session-start.sh"] $sats) {
        print $"(ansi red_bold)❌ duplicate self-test: satellite-subset file set not exempted(ansi reset)"
        $failed = true
    }
    if (dupe-exempt ["plugins/core/commands/work.md" "CLAUDE.md"] $sats) {
        print $"(ansi red_bold)❌ duplicate self-test: set with non-satellite member wrongly exempted(ansi reset)"
        $failed = true
    }

    # Case 9: key shape — stable under member order, sensitive to membership,
    # and shaped dupe/<md5-8>:duplicate_block
    let k_ab = (dupe-key [$file_a $file_b])
    let k_ba = (dupe-key [$file_b $file_a])
    let k_abc = (dupe-key [$file_a $file_b "CLAUDE.md"])
    if $k_ab != $k_ba {
        print $"(ansi red_bold)❌ duplicate self-test: key not stable under member order(ansi reset)"
        $failed = true
    }
    if $k_ab == $k_abc {
        print $"(ansi red_bold)❌ duplicate self-test: key not sensitive to membership change(ansi reset)"
        $failed = true
    }
    if (($k_ab | parse --regex '^dupe/[0-9a-f]{8}:duplicate_block$') | is-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: key '($k_ab)' does not match dupe/<md5-8>:duplicate_block(ansi reset)"
        $failed = true
    }

    # Case 10: baseline round-trip — a valid dupe entry passes
    # validate-baseline-entries; duplicate_block is a detail-producing check,
    # so a null detail_count is rejected
    let dupe_entry = {key: $k_ab, class: "DEBT", issue: "claude-skills-900", first_seen: "2026-07-26", detail_count: 3}
    let rt = (validate-baseline-entries [$dupe_entry])
    if ($rt | is-not-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: valid dupe baseline entry flagged \(($rt | str join '; ')\)(ansi reset)"
        $failed = true
    }
    let rt_null = (validate-baseline-entries [($dupe_entry | update detail_count null)])
    if not ($rt_null | any {|e| $e | str contains "detail_count"}) {
        print $"(ansi red_bold)❌ duplicate self-test: null detail_count on duplicate_block not rejected(ansi reset)"
        $failed = true
    }

    # Case 11: a new duplicate group (not baselined) is a hard failure
    let new_group = (ratchet-baseline [] [$k_ab] [{key: $k_ab, count: 3}])
    if $new_group.hard_failures != [$k_ab] {
        print $"(ansi red_bold)❌ duplicate self-test: new unbaselined group not a hard failure(ansi reset)"
        $failed = true
    }

    # Case 12: a waived group that no longer exists is a stale key (shrink)
    let gone = (ratchet-baseline [$dupe_entry] [] [])
    if $gone.stale_keys != [$k_ab] {
        print $"(ansi red_bold)❌ duplicate self-test: disappeared waived group not flagged stale(ansi reset)"
        $failed = true
    }

    # Case 13: a waived group that GREW fails as a count regression — the
    # waiver covers the recorded window count, not absorption of new copies
    let grew = (ratchet-baseline [$dupe_entry] [$k_ab] [{key: $k_ab, count: 4}])
    if ($grew.count_regressions | is-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: grown waived group not flagged as count regression(ansi reset)"
        $failed = true
    }

    # Case 14: satellite derivation — the list parsed out of
    # test/validate-core-list.nu carries the canonical file and the known
    # satellite shapes; if the parse silently broke, exemption 3 would too.
    # Bounded to a LOWER bound plus "every derived path resolves on disk"
    # (claude-skills-151 Gate 3 finding) rather than an exact count: an
    # exact-count assertion collided with claude-skills-198 registering two
    # more satellites — green on either branch alone, red once both merge,
    # in EITHER merge order, since each branch only sees its own addition.
    # A lower bound plus "every path is real" tolerates legitimate growth
    # with zero maintenance while still catching a leaked bogus path — a
    # comment-embedded `path: "..."` string won't resolve on disk.
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let derived = (core-list-satellites ($repo_root | path join "test" "validate-core-list.nu"))
    let missing_on_disk = ($derived | where {|p| not (($repo_root | path join $p) | path exists)})
    if ("plugins/core/skills/agent-loop/SKILL.md" not-in $derived) or ("plugins/core/hooks/session-start.sh" not-in $derived) or (($derived | length) < 5) or ($missing_on_disk | is-not-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: satellite derivation from validate-core-list.nu broke \(got ($derived | length) entries; missing on disk: ($missing_on_disk | str join ', ')\)(ansi reset)"
        $failed = true
    }

    # Case 14c (claude-skills-151 Gate 3 finding): a comment LINE inside the
    # SATELLITES block that happens to contain the literal substring
    # `path: "..."` — documentation, a worked example, a commented-out
    # entry — must not leak into the parsed satellite list. Exercises
    # core-list-satellites end-to-end (not just satellites-block-lines) via
    # a real fixture file, since the comment-filter lives in
    # core-list-satellites itself.
    let cl_root = (mktemp -d)
    let cl_script = ($cl_root | path join "fixture.nu")
    ('const SATELLITES = [' + (char newline)
        + '  # example: path: "fake/example.md" -- not a real satellite' + (char newline)
        + '  { path: "real/entry.md"' + (char newline)
        + '    anchor: "x" }' + (char newline)
        + ']' + (char newline)) | save $cl_script
    let cl_derived = (core-list-satellites $cl_script)
    if ("fake/example.md" in $cl_derived) {
        print $"(ansi red_bold)❌ duplicate self-test: a path: \"...\" string inside a comment line leaked through core-list-satellites(ansi reset)"
        $failed = true
    }
    if ("real/entry.md" not-in $cl_derived) {
        print $"(ansi red_bold)❌ duplicate self-test: core-list-satellites dropped a genuine in-block path after comment filtering(ansi reset)"
        $failed = true
    }
    rm -rf $cl_root

    # Case 14b (claude-skills-151 follow-up): a `path: "..."` line OUTSIDE
    # the SATELLITES block — e.g. a future test fixture or self-test case in
    # the same file — must not widen exemption 3. satellites-block-lines
    # scopes the parse to between `const SATELLITES = [` and the matching
    # `]`; a line before the opener and a line after the closer both carry
    # the `path: "..."` substring and neither must appear in the result.
    let scoped_fixture = [
        "const OTHER = ["
        '  { path: "before/the/block.md" }'
        "]"
        "const SATELLITES = ["
        '  { path: "inside/the/block.md"'
        "    anchor: \"x\" }"
        "]"
        "def some-later-fn [] {"
        '  path: "after/the/block.md"'
        "}"
    ]
    let scoped = (satellites-block-lines $scoped_fixture)
    let scoped_paths = ($scoped | str join "\n" | parse --regex 'path: "(?P<p>[^"]+)"' | get p)
    if ("before/the/block.md" in $scoped_paths) or ("after/the/block.md" in $scoped_paths) {
        print $"(ansi red_bold)❌ duplicate self-test: satellites-block-lines leaked a path outside the SATELLITES block \(got ($scoped_paths | str join ', ')\)(ansi reset)"
        $failed = true
    }
    if ("inside/the/block.md" not-in $scoped_paths) {
        print $"(ansi red_bold)❌ duplicate self-test: satellites-block-lines dropped a genuine in-block path(ansi reset)"
        $failed = true
    }

    # Case 15: a git-tracked file deleted from the working tree but not yet
    # committed must not crash the corpus scan (claude-skills-155). It is
    # skipped, and the skip is REPORTED — a corpus that silently shrinks is
    # how this check would go quiet.
    let split = (split-corpus-paths [
        {path: "plugins/a/SKILL.md", exists: true}
        {path: "plugins/gone/SKILL.md", exists: false}
        {path: "CLAUDE.md", exists: true}
    ])
    if ($split.present | length) != 2 {
        print $"(ansi red_bold)❌ duplicate self-test: corpus split dropped or kept the wrong present paths(ansi reset)"
        $failed = true
    }
    if $split.missing != ["plugins/gone/SKILL.md"] {
        print $"(ansi red_bold)❌ duplicate self-test: deleted-but-tracked path was not reported as missing(ansi reset)"
        $failed = true
    }
    let none_missing = (split-corpus-paths [{path: "plugins/a/SKILL.md", exists: true}])
    if ($none_missing.missing | is-not-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: clean corpus wrongly reported missing paths(ansi reset)"
        $failed = true
    }
    # The announcement is the point of the skip, so it is asserted here — a
    # warning that only lived in main could be deleted with every test green.
    if ($split.warnings | is-empty) or (not (($split.warnings | str join "\n") | str contains "plugins/gone/SKILL.md")) {
        print $"(ansi red_bold)❌ duplicate self-test: skip warning missing or did not name the skipped path(ansi reset)"
        $failed = true
    }
    if ($none_missing.warnings | is-not-empty) {
        print $"(ansi red_bold)❌ duplicate self-test: clean corpus emitted a skip warning(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ Duplicate-block self-test passed \(17 cases\)(ansi reset)"
    }
    $failed
}

# Frontmatter lines of a markdown file's content (between the leading ---
# markers), or [] when there is no frontmatter block.
def frontmatter-lines [content: string] {
    let all_lines = ($content | lines)
    if ($all_lines | is-empty) { return [] }
    if (($all_lines | first | str trim) != "---") { return [] }
    let rest = ($all_lines | skip 1)
    let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
    if ($end_matches | is-empty) { return [] }
    $rest | first ($end_matches | first | get index)
}

# --- syntax-vs-usage vocabulary cross-check (claude-skills-141) ---
#
# For each format this repo both documents and contains, compare the
# DOCUMENTED token vocabulary against the REAL one and fire when the sets
# are disjoint or the doc carries a foreign-family token. Extraction scope
# for the doc side is the RAW text — prose and tables included, never just
# fenced blocks: the current claude-commands/SKILL.md keeps every token in
# prose/tables (zero fences), so a fence-scoped extractor would return
# empty and silence the format forever. Families are markers, not
# enumerations: named args are arbitrary identifiers, so both sides
# normalise them to one "$name" family token instead of enumerating.

# Drop a doc file's own leading frontmatter block before doc-side token
# extraction. The documenting skills' OWN frontmatter contaminates the doc
# vocabulary: claude-agents' frontmatter keys (name:, description:) are
# always in the real agent key set, so without stripping, the agents leg
# could never fire and its doc-empty canary was unreachable;
# claude-commands' description mentions $ARGUMENTS/$N and claude-hooks'
# mentions SessionStart, which would keep those legs intersecting even
# after a fabricated body rewrite. Skill-activation metadata is not
# documentation content.
def strip-doc-frontmatter [content: string] {
    let fm = (frontmatter-lines $content)
    if ($fm | is-empty) { return $content }
    # Skip the frontmatter lines plus the two --- marker lines.
    $content | lines | skip (($fm | length) + 2) | str join "\n"
}

# Documented command-token vocabulary from doc content (SKILL.md or a
# reference file; the file's own frontmatter is stripped, everything else
# — prose, tables, fences — is in scope). Tokens: "$ARGUMENTS", "$N" (any
# $<digit> or the literal $N), "$name" (named-arg family: any
# $<lowercase-identifier>), "!`cmd`" (bash injection), and "{{}}" (brace
# family — FOREIGN for this format; its presence in a doc is itself a
# finding, see check-vocab-disjoint).
def extract-command-doc-vocab [content: string] {
    let content = (strip-doc-frontmatter $content)
    mut vocab = []
    if ($content | str contains "$ARGUMENTS") { $vocab = ($vocab | append "$ARGUMENTS") }
    if (($content | parse --regex '\$\d') | is-not-empty) or ($content | str contains "$N") {
        $vocab = ($vocab | append "$N")
    }
    if (($content | parse --regex '\$[a-z][a-zA-Z_]*') | is-not-empty) { $vocab = ($vocab | append "$name") }
    if (($content | parse --regex '!`[^`]+`') | is-not-empty) { $vocab = ($vocab | append ('!' + '`cmd`')) }
    if ($content | str contains '{{') { $vocab = ($vocab | append '{{}}') }
    $vocab
}

# Real command-token vocabulary from one command file's content. Deliberately
# narrow: "$ARGUMENTS" when literally present, plus the "$name" family
# marker ONLY when the file declares `arguments:` in its frontmatter. Never
# a general \$[a-z_]+ regex — real command files carry plain bash like
# $USER / $SESSION_ID / $BUILD_DIR in example scripts, and counting those
# would fabricate an intersection. Staleness direction: unknown tokens are
# dropped, so the real set shrinks toward empty and the check goes QUIET,
# never noisy — bounded by the doc-empty canary.
def extract-command-real-vocab [content: string] {
    mut vocab = []
    if ($content | str contains "$ARGUMENTS") { $vocab = ($vocab | append "$ARGUMENTS") }
    if (frontmatter-lines $content | any {|l| $l | str starts-with "arguments:"}) {
        $vocab = ($vocab | append "$name")
    }
    $vocab
}

# Documented agent-frontmatter keys: line-start `key:` tokens anywhere in
# the doc body (prose, tables, and fenced YAML examples alike; the doc
# file's own frontmatter is stripped — see strip-doc-frontmatter).
# Lowercase first letter keeps prose labels like "See:" / "Example:" out;
# residual doc-side pollution (a prose line like "note: ...") only
# inflates the documented set and cannot mask a disjointness finding.
def extract-agent-doc-keys [content: string] {
    strip-doc-frontmatter $content | parse --regex '(?m)^(?P<key>[a-z][a-zA-Z_-]*):' | get key | uniq
}

# Real agent-frontmatter keys: top-level keys of the file's frontmatter
# block only — body content never contributes.
def extract-agent-real-keys [content: string] {
    frontmatter-lines $content
        | each {|l| $l | parse --regex '^(?P<key>[a-z][a-zA-Z_-]*):'}
        | flatten | get -o key | default [] | uniq
}

# Documented hook event names: CamelCase multi-hump tokens in the doc body
# (SessionStart, PreToolUse, ...; own frontmatter stripped). Non-event
# CamelCase words (MultiEdit) are doc-side pollution — harmless for
# disjointness, same argument as extract-agent-doc-keys.
def extract-hook-doc-events [content: string] {
    strip-doc-frontmatter $content | parse --regex '\b(?P<ev>[A-Z][a-z]+(?:[A-Z][a-z]*)+)\b' | get ev | uniq
}

# Real hook event names: the top-level keys of a parsed hooks.json's
# `hooks` object. Malformed wrappers contribute nothing here — Pass 2's
# bad_wrapper check already owns that failure.
def extract-hook-real-events [parsed] {
    $parsed | get -o hooks | default {} | columns
}

# Minimum real-instance file counts per syntax-vs-usage format (measured
# 2026-07-27: 25 command files, 29 agent files, 2 hooks.json). The real
# side's mirror of the doc-empty canary: "empty real vocabulary → silent"
# cannot distinguish a format with no instances from broken glob plumbing,
# and an under-matching glob can even leave the VOCABULARY intact —
# plugins/*/commands/*.md matches 9 of the 25 files including both
# $ARGUMENTS users — so the matched FILE COUNT is the only observable that
# catches it. A count below the floor is a hard error naming the format.
# Adding instances never requires an update; deliberately removing
# instances below a floor means lowering the measured value here.
const VOCAB_REAL_FLOORS = {commands: 25, agents: 29, hooks: 2}

# Real-side glob canary: the formats whose matched file count fell below
# their VOCAB_REAL_FLOORS floor. Input [{format, matched}]; returns
# [{format, matched, floor}] — non-empty is a hard error in main.
def vocab-real-floor-errors [format_counts: list] {
    $format_counts
        | each {|fc| $fc | insert floor ($VOCAB_REAL_FLOORS | get $fc.format)}
        | where {|fc| $fc.matched < $fc.floor}
}

# Core rule. Returns {status, disjoint} where status is one of:
# - "doc_empty" — the documented vocabulary is empty. For the three known
#   formats this is a HARD ERROR (extractor canary): the documenting skill
#   is known to document tokens, so extracting none means the extractor
#   broke, and silence here would hide the format forever.
# - "fires" — the doc carries a foreign-family token (fires regardless of
#   intersection: pure disjointness has a one-token margin, since the real
#   command vocabulary is exactly $ARGUMENTS), OR the sets are disjoint
#   with a non-empty real side.
# - "silent" — vocabularies overlap and no foreign token, or the real side
#   is empty (a format with no instances proves nothing).
# `disjoint` is the documented-but-not-real set — the baseline's
# detail_count for a fired finding.
def check-vocab-disjoint [doc_vocab: list, real_vocab: list, foreign_tokens: list] {
    if ($doc_vocab | is-empty) {
        return {status: "doc_empty", disjoint: []}
    }
    let disjoint_doc = ($doc_vocab | where {|t| $t not-in $real_vocab})
    let foreign_hit = ($doc_vocab | any {|t| $t in $foreign_tokens})
    let no_overlap = (($disjoint_doc | length) == ($doc_vocab | length))
    if $foreign_hit or ($no_overlap and ($real_vocab | is-not-empty)) {
        {status: "fires", disjoint: $disjoint_doc}
    } else {
        {status: "silent", disjoint: []}
    }
}

# Doc corpus for a documenting skill: SKILL.md plus references/*.md when
# present, raw contents joined.
def vocab-doc-content [skill_dir: string] {
    let refs = (glob ($skill_dir | path join "references" "*.md"))
    $refs | prepend ($skill_dir | path join "SKILL.md") | each {|f| open --raw $f} | str join "\n"
}

# Embedded self-test for the syntax-vs-usage vocabulary cross-check
# (claude-skills-141). Exercises check-vocab-disjoint and the per-format
# extractors — the same implementations Pass 4 in main calls. The historical
# replay (case 7) inlines defect-era and fixed-era content as fixtures so
# the test does not depend on git history staying reachable. Returns true
# when any case failed.
def run-vocab-self-test [] {
    mut failed = false
    let tick1 = '`'
    let brace2 = '{{'

    # Case 1: disjoint vocabularies fire, and the disjoint set (which the
    # baseline's detail_count ratchets) is the full documented set
    let c1 = (check-vocab-disjoint ["alpha" "beta"] ["gamma"] [])
    if $c1.status != "fires" or ($c1.disjoint | sort) != ["alpha" "beta"] {
        print $"(ansi red_bold)❌ vocab self-test: disjoint vocabularies did not fire(ansi reset)"
        $failed = true
    }

    # Case 2: overlapping vocabularies are silent — exercised end-to-end
    # through the hook extractors (doc prose mentions SessionStart; real
    # hooks.json wires SessionStart)
    let hook_doc = (extract-hook-doc-events "Runs on SessionStart and PreToolUse. MultiEdit is unrelated prose.")
    let hook_real = (extract-hook-real-events {hooks: {SessionStart: []}})
    if ("SessionStart" not-in $hook_doc) or ($hook_real != ["SessionStart"]) {
        print $"(ansi red_bold)❌ vocab self-test: hook extractors missed SessionStart(ansi reset)"
        $failed = true
    }
    if (check-vocab-disjoint $hook_doc $hook_real []).status != "silent" {
        print $"(ansi red_bold)❌ vocab self-test: overlapping hook vocabularies not silent(ansi reset)"
        $failed = true
    }

    # Case 3: doc superset of real is silent (the agent shape — 16 keys
    # documented, 5 used — punishing good reference docs is a non-goal)
    let agent_doc = (extract-agent-doc-keys ([
        "name: reviewer" "description: reviews" "model: sonnet" "tools: Read"
        "skills:" "maxTurns: 3" "color: red" "permissionMode: default"
        "memory: user" "isolation: worktree" "effort: xhigh" "background: true"
        "disallowedTools: Bash" "systemPrompt: x" "outputStyle: terse" "hooks: none"
    ] | str join "\n"))
    let agent_real = (extract-agent-real-keys ([
        "---" "name: worker" "description: works" "model: haiku" "tools: Read, Grep" "skills:" "  - core:tdd" "---" "body prose"
    ] | str join "\n"))
    if ($agent_doc | length) != 16 or ($agent_real | sort) != ["description" "model" "name" "skills" "tools"] {
        print $"(ansi red_bold)❌ vocab self-test: agent extractors wrong \(doc ($agent_doc | length), real ($agent_real | sort | str join ' ')\)(ansi reset)"
        $failed = true
    }
    if (check-vocab-disjoint $agent_doc $agent_real []).status != "silent" {
        print $"(ansi red_bold)❌ vocab self-test: doc-superset-of-real not silent(ansi reset)"
        $failed = true
    }

    # Case 4: bash pollution — a doc that documents only brace-family syntax
    # still fires against a real file whose only $-tokens are plain bash
    # ($USER / $SESSION_ID in example scripts), because the real extractor
    # never runs a general \$[a-z_]+ regex; a named-arg token counts only
    # when declared in that file's arguments: frontmatter
    # Fixture carries lowercase bash vars ($file, $claim) as well as
    # uppercase ones: a mutated extractor using a general \$[a-z_]+ regex
    # would map them to the $name family marker and pass a purely
    # uppercase fixture ($claim is real — agent-sandboxing/commands/reap.md).
    let polluted_real = (extract-command-real-vocab ([
        "---" "description: deploy" "---"
        "Run the script as $USER with $SESSION_ID and $BUILD_DIR set."
        "Loop over each $file and post the $claim payload."
    ] | str join "\n"))
    if ($polluted_real | is-not-empty) {
        print $"(ansi red_bold)❌ vocab self-test: bash \$-vars polluted the real vocabulary \(($polluted_real | str join ' ')\)(ansi reset)"
        $failed = true
    }
    let declared_real = (extract-command-real-vocab ([
        "---" "description: fix" "arguments: [issue, branch]" "---"
        "Fix $issue on $branch."
    ] | str join "\n"))
    if ("$name" not-in $declared_real) {
        print $"(ansi red_bold)❌ vocab self-test: declared arguments: frontmatter did not yield the named-arg family marker(ansi reset)"
        $failed = true
    }
    let brace_doc = (extract-command-doc-vocab $"Use ($brace2)arg}} placeholders everywhere.")
    let c4 = (check-vocab-disjoint $brace_doc $polluted_real [$"($brace2)}}"])
    if $c4.status != "fires" {
        print $"(ansi red_bold)❌ vocab self-test: brace-only doc vs bash-polluted real did not fire(ansi reset)"
        $failed = true
    }

    # Case 5a: empty REAL vocabulary is silent (a format with no instances
    # proves nothing)
    if (check-vocab-disjoint ["$ARGUMENTS"] [] [$"($brace2)}}"]).status != "silent" {
        print $"(ansi red_bold)❌ vocab self-test: empty real vocabulary not silent(ansi reset)"
        $failed = true
    }

    # Case 5b: empty DOC vocabulary is a hard error, never silence — the
    # extractor canary (these skills are known to document tokens)
    if (check-vocab-disjoint [] ["$ARGUMENTS"] []).status != "doc_empty" {
        print $"(ansi red_bold)❌ vocab self-test: empty doc vocabulary did not report doc_empty(ansi reset)"
        $failed = true
    }

    # Case 6: mixed case — a doc carrying brace-family syntax AND one real
    # token still fires via family-presence (pure disjointness has a
    # one-token margin the foreign-family rule exists to close)
    let mixed_doc = (extract-command-doc-vocab $"Substitute with \$ARGUMENTS or ($brace2)arg}}.")
    let c6 = (check-vocab-disjoint $mixed_doc ["$ARGUMENTS"] [$"($brace2)}}"])
    if $c6.status != "fires" {
        print $"(ansi red_bold)❌ vocab self-test: doc with brace-family plus \$ARGUMENTS did not fire(ansi reset)"
        $failed = true
    }

    # Case 7: historical replay, both states inlined as fixtures. The
    # defect-era claude-commands/SKILL.md (pre-#134, 5ec8039~1) documented
    # Handlebars with zero $ARGUMENTS mentions; the rewrite documents the
    # real token families in prose/tables with zero fenced blocks.
    let defect_doc_content = ([
        "Hello, {{arg}}! Welcome to the project."
        "Deploy {{environment}} environment to {{region}}."
        "{{#if verbose}}"
        "{{shell:git status}}"
        "{{file:PROJECT_STRUCTURE.md}}"
    ] | str join "\n")
    let fixed_doc_content = ([
        $"| ($tick1)\$ARGUMENTS($tick1) | The full argument string as typed |"
        $"| ($tick1)\$N($tick1) | Shorthand for ($tick1)\$ARGUMENTS[N]($tick1) |"
        $"| ($tick1)\$name($tick1) | The named argument declared in ($tick1)arguments:($tick1) frontmatter |"
        $"- **Inline:** ($tick1)($tick1) !($tick1)git diff HEAD($tick1) ($tick1)($tick1) on a line"
    ] | str join "\n")
    let replay_real = (extract-command-real-vocab "Fix the issue described in $ARGUMENTS.")
    if $replay_real != ["$ARGUMENTS"] {
        print $"(ansi red_bold)❌ vocab self-test: real \$ARGUMENTS usage not extracted(ansi reset)"
        $failed = true
    }
    let defect_vocab = (extract-command-doc-vocab $defect_doc_content)
    if (check-vocab-disjoint $defect_vocab $replay_real [$"($brace2)}}"]).status != "fires" {
        print $"(ansi red_bold)❌ vocab self-test: defect-era doc fixture did not fire(ansi reset)"
        $failed = true
    }
    let fixed_vocab = (extract-command-doc-vocab $fixed_doc_content)
    if ($fixed_vocab | sort) != (["$ARGUMENTS" "$N" $"!($tick1)cmd($tick1)" "$name"] | sort) {
        print $"(ansi red_bold)❌ vocab self-test: fixed-era doc fixture extracted \(($fixed_vocab | str join ' ')\) — prose/table extraction broke(ansi reset)"
        $failed = true
    }
    if (check-vocab-disjoint $fixed_vocab $replay_real [$"($brace2)}}"]).status != "silent" {
        print $"(ansi red_bold)❌ vocab self-test: fixed-era doc fixture not silent(ansi reset)"
        $failed = true
    }

    # Case 9: the documenting skill's OWN frontmatter never contaminates
    # the doc vocabulary. Without stripping, claude-agents' frontmatter
    # keys (name:, description:) always intersect the real agent key set,
    # so the agents leg could NEVER fire — a check that reports clean
    # without checking.
    # `role:` is deliberately the FIRST body line, and the assertion is set
    # EQUALITY rather than membership: a strip that overshoots by one line
    # (eating the first body line) would still satisfy a membership check.
    let fabricated_agent_doc = (extract-agent-doc-keys ([
        "---" "name: claude-agents" "description: fabricated rewrite" "---"
        "role: what the agent does"
        "capabilities: tool grants"
        "persona: voice and tone"
    ] | str join "\n"))
    if ("name" in $fabricated_agent_doc) or ("description" in $fabricated_agent_doc) {
        print $"(ansi red_bold)❌ vocab self-test: doc skill's own frontmatter keys leaked into the doc vocabulary(ansi reset)"
        $failed = true
    }
    if ($fabricated_agent_doc | sort) != ["capabilities" "persona" "role"] {
        print $"(ansi red_bold)❌ vocab self-test: doc frontmatter strip did not preserve the first body line \(got ($fabricated_agent_doc | sort))(ansi reset)"
        $failed = true
    }
    let c9 = (check-vocab-disjoint $fabricated_agent_doc ["name" "description" "model" "tools" "skills"] [])
    if $c9.status != "fires" {
        print $"(ansi red_bold)❌ vocab self-test: fabricated agent-doc rewrite \(role/capabilities/persona\) did not fire(ansi reset)"
        $failed = true
    }
    # Same contamination path for hooks (description mentions SessionStart)
    # and commands (description mentions $ARGUMENTS): a doc whose only
    # tokens live in its own frontmatter must extract EMPTY, hitting the
    # doc-empty canary instead of silently intersecting.
    let hooks_fm_only = (extract-hook-doc-events ([
        "---" "description: Configure SessionStart and PreToolUse hooks" "---"
        "Body prose documenting nothing."
    ] | str join "\n"))
    let commands_fm_only = (extract-command-doc-vocab ([
        "---" "description: writing $ARGUMENTS or $N substitutions" "---"
        "Body prose documenting nothing."
    ] | str join "\n"))
    if ($hooks_fm_only | is-not-empty) or ($commands_fm_only | is-not-empty) {
        print $"(ansi red_bold)❌ vocab self-test: hooks/commands doc frontmatter values leaked \(hooks: ($hooks_fm_only | str join ' '); commands: ($commands_fm_only | str join ' ')\)(ansi reset)"
        $failed = true
    }

    # Case 10: real-side glob floor — a matched file count below the
    # known floor is a hard error per format. "Empty real → silent"
    # cannot distinguish a format with no instances from broken glob
    # plumbing, and an under-matching glob can even keep the vocabulary
    # intact (plugins/*/commands/*.md matches 9 of 25 files INCLUDING
    # both $ARGUMENTS users), so the count is the only observable.
    let floor_zero = (vocab-real-floor-errors [
        {format: "commands", matched: 0} {format: "agents", matched: 0} {format: "hooks", matched: 0}
    ])
    if ($floor_zero | length) != 3 {
        print $"(ansi red_bold)❌ vocab self-test: zero matched files did not floor-error for all three formats(ansi reset)"
        $failed = true
    }
    # Every format gets an under-match row, not just commands: pinning one
    # format leaves the others' floors free to drift toward 1 unnoticed, and
    # a floor of 1 is a guard that cannot fire.
    let floor_under = (vocab-real-floor-errors [
        {format: "commands", matched: 9} {format: "agents", matched: 9} {format: "hooks", matched: 1}
    ])
    if ($floor_under | length) != 3 {
        print $"(ansi red_bold)❌ vocab self-test: under-matched globs did not floor-error for all three formats(ansi reset)"
        $failed = true
    }
    let floor_ok = (vocab-real-floor-errors [
        {format: "commands", matched: 25} {format: "agents", matched: 40} {format: "hooks", matched: 2}
    ])
    if ($floor_ok | is-not-empty) {
        print $"(ansi red_bold)❌ vocab self-test: at-or-above-floor counts wrongly floor-errored(ansi reset)"
        $failed = true
    }

    if not $failed {
        print $"(ansi green_bold)✅ Vocab self-test passed \(10 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for the Pass-2 agents/commands links check
# (claude-skills-164, pointer-validation-gap plan PR 1): exercises
# extract-link-path-tokens and resolve-pass2-path directly — the same
# implementations the Pass-2 loops call — against REAL temporary
# directories. A real filesystem fixture is unavoidable here (unlike the
# other self-test suites in this file, which stay hermetic in-memory):
# resolve-pass2-path's whole job is a `path exists` decision across four
# bases, so faking that away would test nothing. The fixture tree is built
# fresh and removed at the end of the suite. Returns true when any case
# failed.
def run-pass2-links-self-test [] {
    mut failed = false

    # --- extract-link-path-tokens: hyphenated extension parses whole ---
    let hyphen_content = "See `templates/Dockerfile.claude-code` for the base image."
    let hyphen_tokens = (extract-link-path-tokens $hyphen_content)
    if "templates/Dockerfile.claude-code" not-in $hyphen_tokens {
        print $"(ansi red_bold)❌ pass2-links self-test: hyphenated extension truncated \(got: ($hyphen_tokens)\)(ansi reset)"
        $failed = true
    }

    # --- fixture tree ---
    # root/
    #   pluginA/
    #     own/                      <- an agent file's own_dir (base 1)
    #       references/foo.md
    #     skills/
    #       skillOne/references/dup.md   <- base-3 single match
    #       skillTwo/references/dup.md   <- base-3 ambiguous partner
    #     scripts/run.nu            <- base-4 / plugin-root direct path
    #   pluginB/
    #     skills/qualified/references/bar.md   <- base-2 cross-skill target
    let root = (mktemp -d)
    let plugin_a = ($root | path join "pluginA")
    let plugin_b = ($root | path join "pluginB")
    let own_dir = ($plugin_a | path join "own")
    mkdir ($own_dir | path join "references")
    "content" | save ($own_dir | path join "references" "foo.md")
    mkdir ($plugin_a | path join "skills" "skillOne" "references")
    "content" | save ($plugin_a | path join "skills" "skillOne" "references" "dup.md")
    mkdir ($plugin_a | path join "skills" "skillTwo" "references")
    "content" | save ($plugin_a | path join "skills" "skillTwo" "references" "dup.md")
    mkdir ($plugin_a | path join "scripts")
    "content" | save ($plugin_a | path join "scripts" "run.nu")
    mkdir ($plugin_b | path join "skills" "qualified" "references")
    "content" | save ($plugin_b | path join "skills" "qualified" "references" "bar.md")

    let empty_map = []
    let no_plugins = []

    # Case: resolvable pointer in an agent file, own directory (base 1)
    if not (resolve-pass2-path "references/foo.md" "" $own_dir "" $plugin_a $empty_map $no_plugins) {
        print $"(ansi red_bold)❌ pass2-links self-test: base 1 \(own_dir\) did not resolve an existing sibling(ansi reset)"
        $failed = true
    }

    # Case: broken pointer in an agent file — resolves against none of the
    # four bases.
    if (resolve-pass2-path "references/nonexistent.md" "" $own_dir "" $plugin_a $empty_map $no_plugins) {
        print $"(ansi red_bold)❌ pass2-links self-test: nonexistent path wrongly resolved(ansi reset)"
        $failed = true
    }

    # Case: resolvable pointer in a command file — commands are always
    # plugin-level, so own_dir == plugin_dir (bases 1 and 4 collapse).
    if not (resolve-pass2-path "scripts/run.nu" "" $plugin_a "" $plugin_a $empty_map $no_plugins) {
        print $"(ansi red_bold)❌ pass2-links self-test: plugin-level command path did not resolve(ansi reset)"
        $failed = true
    }

    # Case: base 2 — cross-skill-qualified. own_dir/plugin_dir carry
    # neither the file nor a skills/ tree containing it; only the
    # /pluginb:qualified qualifier on the preceding line resolves it,
    # against pluginB's own skill dir.
    let cross_map = [{skill: "qualified", dir: ($plugin_b | path join "skills" "qualified"), plugin: "pluginb"}]
    let isolated_dir = ($root | path join "isolated")
    mkdir $isolated_dir
    if not (resolve-pass2-path "references/bar.md" "see /pluginb:qualified for detail" $isolated_dir "" $isolated_dir $cross_map ["pluginb"]) {
        print $"(ansi red_bold)❌ pass2-links self-test: base 2 \(cross-skill-qualified\) did not resolve(ansi reset)"
        $failed = true
    }

    # Case: base 2 negative — a real /ns:skill qualifier naming a real,
    # KNOWN skill whose directory does NOT contain the cited path. Must
    # NOT resolve: cross-skill-qualified's leniency is for UNKNOWN skill
    # names only (see resolve-pass2-path's docstring); a known skill that
    # genuinely lacks the file is a real broken pointer. Without this case,
    # every case above would still pass even if cross-skill-qualified
    # started over-triggering for known-but-wrong skills, since the
    # broken-pointer case above uses an empty (unqualified) prefix line.
    if (resolve-pass2-path "references/nonexistent-in-qualified.md" "see /pluginb:qualified for detail" $isolated_dir "" $isolated_dir $cross_map ["pluginb"]) {
        print $"(ansi red_bold)❌ pass2-links self-test: base 2 wrongly resolved a KNOWN skill's nonexistent path(ansi reset)"
        $failed = true
    }

    # Case: base 3 — exactly one sibling skill under the SAME plugin
    # contains the path. own_dir here has neither the path nor a matching
    # qualifier, so only the single-match sibling scan can resolve it.
    # skillOne alone is scoped by giving skillTwo's copy a different name.
    let single_root = ($root | path join "pluginSingle")
    mkdir ($single_root | path join "skills" "only" "references")
    "content" | save ($single_root | path join "skills" "only" "references" "solo.md")
    if not (resolve-pass2-path "references/solo.md" "" $isolated_dir "" $single_root $empty_map $no_plugins) {
        print $"(ansi red_bold)❌ pass2-links self-test: base 3 single sibling match did not resolve(ansi reset)"
        $failed = true
    }

    # Case: base 3 ambiguity — skillOne AND skillTwo both contain
    # references/dup.md under pluginA. Must NOT silently pick the first
    # match; the token stays unresolved.
    if (resolve-pass2-path "references/dup.md" "" $isolated_dir "" $plugin_a $empty_map $no_plugins) {
        print $"(ansi red_bold)❌ pass2-links self-test: base 3 ambiguous \(two sibling matches\) was silently resolved(ansi reset)"
        $failed = true
    }

    rm -rf $root

    if not $failed {
        print $"(ansi green_bold)✅ Pass-2 links self-test passed \(8 cases\)(ansi reset)"
    }
    $failed
}

# Evaluate one plugin-level or skill-nested agent file against Pass-2's
# agent-surface checks (claude-skills-119/164/175), returning everything the
# caller needs in one record: which checks fired (`failed`), the resulting
# `failing_keys` entries, the `failing_counts` entries (via
# accumulate-detail-counts), and the `surface_result` row for reporting.
#
# Extracted (claude-skills-151 Gate 3 finding) so the link between "a
# detail-producing check fired" and "failing_counts got an entry" — the
# exact wiring claude-skills-175 was missing — is a directly unit-tested
# function, not only provable by reading main's call site. Before this
# extraction, that wiring was a 4-line block inline in main's loop; the
# Gate 3 reviewer deleted it and both --self-test and the full run stayed
# green. That block now lives INSIDE this function, where
# run-pass2-eval-self-test exercises it directly against a real fixture
# file — deleting it now fails a hermetic test, not only a live corpus scan.
#
# Known residual (see accumulate-detail-counts doc comment for the general
# framing): this proves evaluate-agent-file's OWN wiring is correct — the
# accumulate-detail-counts call now lives where a hermetic test reaches it.
# It does not prove main's loop still USES the result. apply-surface-finding
# below merges `failing_keys`/`failing_counts`/`surface_result` in one call,
# so main's loop body is one function call plus three unpack lines; deleting
# the whole call is a loud, obvious diff (and is caught by the full run's
# stale-key check), but deleting only the `failing_counts` unpack line among
# the three remains exactly as invisible as the Pass 3/4 residual described
# there — apply-surface-finding computes the merge correctly, but nothing
# stops a caller from discarding one field of what it returns.
def evaluate-agent-file [f: string, plugin_name: string, own_dir: string, dir_name: string, plugin_dir: string, registry: list, skill_dir_map: list, known_models: list] {
    let content = (open --raw $f)
    let all_lines = ($content | lines)
    let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
        let rest = ($all_lines | skip 1)
        let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
        if ($end_matches | is-not-empty) {
            $rest | first ($end_matches | first | get index)
        } else { [] }
    } else { [] }

    mut failed = []
    if not ($fm_lines | any {|line| $line | str starts-with "name:"}) {
        $failed = ($failed | append "missing_name")
    }
    if not ($fm_lines | any {|line| $line | str starts-with "description:"}) {
        $failed = ($failed | append "missing_desc")
    }
    let model_lines = ($fm_lines | where {|line| $line | str starts-with "model:"})
    if ($model_lines | is-not-empty) {
        let model_val = ($model_lines | first | str replace "model:" "" | str trim | str trim -c '"' | str trim -c "'" | str downcase)
        if $model_val not-in $known_models { $failed = ($failed | append "bad_model") }
    }

    let skills_check = (check-agent-skills $fm_lines $registry)
    $failed = ($failed | append $skills_check.failed)

    let bad_invocations = (find-bad-invocations $content $registry)
    if ($bad_invocations | is-not-empty) { $failed = ($failed | append "bad_invocations") }

    let agent_stripped = (strip-fences $content)
    let agent_link_paths = (extract-link-path-tokens $agent_stripped)
    let agent_broken_links = ($agent_link_paths | where {|p|
        let top = ($p | split row "/" | first)
        let dir_gated = $top in ["scripts" "templates" "hooks"]
        let in_scope = (not $dir_gated) or (pass2-dir-in-scope $top $own_dir $plugin_dir)
        $in_scope and not (resolve-pass2-path $p (preceding-line $agent_stripped $p) $own_dir $dir_name $plugin_dir $skill_dir_map ($registry | get name))
    })
    if ($agent_broken_links | is-not-empty) { $failed = ($failed | append "links") }

    let agent_fm_unknown = (unknown-frontmatter-keys $fm_lines $AGENT_FM_KEYS)
    if ($agent_fm_unknown | is-not-empty) { $failed = ($failed | append "fm_schema") }

    let key_base = $"($plugin_name)/agents/($f | path basename)"
    {
        failed: $failed
        failing_keys: ($failed | each {|c| $"($key_base):($c)"})
        failing_counts: (accumulate-detail-counts [] $key_base $failed [
            {check: "links", count: ($agent_broken_links | length)}
            {check: "fm_schema", count: ($agent_fm_unknown | length)}
        ])
        surface_result: {
            plugin: $plugin_name, kind: "agent", file: ($f | path basename), failed: ($failed | str join " ")
            details: ($bad_invocations | append $skills_check.bad_tokens | append $agent_broken_links | append ($agent_fm_unknown | each {|k| $"frontmatter:($k)"}) | str join " ")
        }
    }
}

# Evaluate one plugin-level command file against Pass-2's command-surface
# checks. Same shape and same claude-skills-151/175 rationale as
# evaluate-agent-file above.
def evaluate-command-file [f: string, plugin_name: string, plugin_dir: string, registry: list, skill_dir_map: list] {
    let content = (open --raw $f)
    let all_lines = ($content | lines)
    let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
        let rest = ($all_lines | skip 1)
        let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
        if ($end_matches | is-not-empty) {
            $rest | first ($end_matches | first | get index)
        } else { [] }
    } else { [] }

    mut failed = []
    if not ($fm_lines | any {|line| $line | str starts-with "description:"}) {
        $failed = ($failed | append "missing_desc")
    }
    let bad_invocations = (find-bad-invocations $content $registry)
    if ($bad_invocations | is-not-empty) { $failed = ($failed | append "bad_invocations") }

    let cmd_stripped = (strip-fences $content)
    let cmd_link_paths = (extract-link-path-tokens $cmd_stripped)
    let cmd_broken_links = ($cmd_link_paths | where {|p|
        let top = ($p | split row "/" | first)
        let dir_gated = $top in ["scripts" "templates" "hooks"]
        let in_scope = (not $dir_gated) or (pass2-dir-in-scope $top $plugin_dir $plugin_dir)
        $in_scope and not (resolve-pass2-path $p (preceding-line $cmd_stripped $p) $plugin_dir "" $plugin_dir $skill_dir_map ($registry | get name))
    })
    if ($cmd_broken_links | is-not-empty) { $failed = ($failed | append "links") }

    let cmd_fm_unknown = (unknown-frontmatter-keys $fm_lines $SKILL_FM_KEYS)
    if ($cmd_fm_unknown | is-not-empty) { $failed = ($failed | append "fm_schema") }

    # No braced CLAUDE_* env var in the command body (claude-skills-205).
    # Same rule and exemption as the Pass-1 SKILL.md check — frontmatter is
    # harness-expanded and exempt, the body form is a bug.
    if (has-braced-claude-var (strip-frontmatter $content)) {
        $failed = ($failed | append "braced_claude")
    }

    let key_base = $"($plugin_name)/commands/($f | path basename)"
    {
        failed: $failed
        failing_keys: ($failed | each {|c| $"($key_base):($c)"})
        failing_counts: (accumulate-detail-counts [] $key_base $failed [
            {check: "links", count: ($cmd_broken_links | length)}
            {check: "fm_schema", count: ($cmd_fm_unknown | length)}
        ])
        surface_result: {
            plugin: $plugin_name, kind: "command", file: ($f | path basename), failed: ($failed | str join " ")
            details: ($bad_invocations | append $cmd_broken_links | append ($cmd_fm_unknown | each {|k| $"frontmatter:($k)"}) | str join " ")
        }
    }
}

# Merge one evaluate-agent-file/evaluate-command-file result into the
# running failing_keys/failing_counts/surface_results accumulators. The
# merge ITSELF is atomic — a caller either gets all three fields correctly
# appended together or, on a failed-empty result, none of them touched;
# there is no way to independently break "append the keys" vs "append the
# counts" from INSIDE this function, and run-pass2-eval-self-test's noop/
# merged cases test exactly that.
#
# What this does NOT close: main still unpacks this function's return value
# into three separate `$failing_keys = $acc.failing_keys` /
# `$failing_counts = $acc.failing_counts` / `$surface_results =
# $acc.surface_results` lines (nushell's `mut` variables cannot be
# destructure-assigned from one record in one statement). Deleting only the
# middle line remains exactly as invisible as the Pass 3/4 residual
# documented at accumulate-detail-counts and dupe_acc above — this function
# moves where the risk lives, not whether it exists.
def apply-surface-finding [failing_keys: list, failing_counts: list, surface_results: list, res: record] {
    if ($res.failed | is-empty) {
        {failing_keys: $failing_keys, failing_counts: $failing_counts, surface_results: $surface_results}
    } else {
        {
            failing_keys: ($failing_keys | append $res.failing_keys)
            failing_counts: ($failing_counts | append $res.failing_counts)
            surface_results: ($surface_results | append $res.surface_result)
        }
    }
}

# Embedded self-test for evaluate-agent-file, evaluate-command-file, and
# apply-surface-finding (claude-skills-151 Gate 3 finding, claude-skills-175).
# The load-bearing assertions are the failing_counts checks: every
# detail-producing check present in `failed` MUST also appear in
# `failing_counts` with the right count. That is precisely the wiring the
# Gate 3 reviewer found invisible to every prior test when it lived as an
# inline 4-line block in main — deleting the accumulate-detail-counts call
# now inside evaluate-agent-file/evaluate-command-file fails THIS self-test
# directly, hermetically, without depending on a corpus scan.
def run-pass2-eval-self-test [] {
    mut failed = false
    let root = (mktemp -d)
    let plugin_dir = ($root | path join "pluginX")
    mkdir ($plugin_dir | path join "agents")
    mkdir ($plugin_dir | path join "commands")

    "---
name: broken-agent
description: test fixture
badkey: nope
---

See references/does-not-exist.md for detail.
" | save ($plugin_dir | path join "agents" "broken-agent.md")

    let registry = [{name: "pluginX", dir: $plugin_dir, invocables: [], skills: []}]
    let empty_map = []
    let known_models = ["haiku" "sonnet" "opus"]

    let agent_res = (evaluate-agent-file ($plugin_dir | path join "agents" "broken-agent.md") "pluginX" $plugin_dir "" $plugin_dir $registry $empty_map $known_models)
    let agent_key_base = "pluginX/agents/broken-agent.md"

    if ("links" not-in $agent_res.failed) or ("fm_schema" not-in $agent_res.failed) {
        print $"(ansi red_bold)❌ pass2-eval self-test: evaluate-agent-file missed a check \(got ($agent_res.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }
    if ({key: $"($agent_key_base):links", count: 1} not-in $agent_res.failing_counts) {
        print $"(ansi red_bold)❌ pass2-eval self-test: evaluate-agent-file computed a links finding but failing_counts is missing it \(got ($agent_res.failing_counts | to json --raw)\)(ansi reset)"
        $failed = true
    }
    if ({key: $"($agent_key_base):fm_schema", count: 1} not-in $agent_res.failing_counts) {
        print $"(ansi red_bold)❌ pass2-eval self-test: evaluate-agent-file computed an fm_schema finding but failing_counts is missing it(ansi reset)"
        $failed = true
    }
    if ($"($agent_key_base):links" not-in $agent_res.failing_keys) or ($"($agent_key_base):fm_schema" not-in $agent_res.failing_keys) {
        print $"(ansi red_bold)❌ pass2-eval self-test: evaluate-agent-file's failing_keys missing an expected entry(ansi reset)"
        $failed = true
    }

    "---
name: clean-agent
description: test fixture
---

Nothing to see here.
" | save ($plugin_dir | path join "agents" "clean-agent.md")
    let clean_res = (evaluate-agent-file ($plugin_dir | path join "agents" "clean-agent.md") "pluginX" $plugin_dir "" $plugin_dir $registry $empty_map $known_models)
    if ($clean_res.failed | is-not-empty) or ($clean_res.failing_counts | is-not-empty) {
        print $"(ansi red_bold)❌ pass2-eval self-test: clean agent file wrongly flagged(ansi reset)"
        $failed = true
    }

    "---
description: test fixture
badkey: nope
---

See references/does-not-exist.md for detail.
" | save ($plugin_dir | path join "commands" "broken-command.md")
    let cmd_res = (evaluate-command-file ($plugin_dir | path join "commands" "broken-command.md") "pluginX" $plugin_dir $registry $empty_map)
    let cmd_key_base = "pluginX/commands/broken-command.md"
    if ({key: $"($cmd_key_base):links", count: 1} not-in $cmd_res.failing_counts) {
        print $"(ansi red_bold)❌ pass2-eval self-test: evaluate-command-file computed a links finding but failing_counts is missing it(ansi reset)"
        $failed = true
    }
    if ({key: $"($cmd_key_base):fm_schema", count: 1} not-in $cmd_res.failing_counts) {
        print $"(ansi red_bold)❌ pass2-eval self-test: evaluate-command-file computed an fm_schema finding but failing_counts is missing it(ansi reset)"
        $failed = true
    }

    # apply-surface-finding: a failed-empty result is a no-op; a non-empty
    # result appends all three accumulators together in one call.
    let noop = (apply-surface-finding ["x"] [{key: "x", count: 1}] [{plugin: "p", kind: "agent", file: "f", failed: "", details: ""}] {failed: [], failing_keys: [], failing_counts: [], surface_result: {}})
    if $noop.failing_keys != ["x"] or $noop.failing_counts != [{key: "x", count: 1}] or ($noop.surface_results | length) != 1 {
        print $"(ansi red_bold)❌ pass2-eval self-test: apply-surface-finding mutated on a failed-empty result(ansi reset)"
        $failed = true
    }
    let merged = (apply-surface-finding [] [] [] $agent_res)
    if $merged.failing_keys != $agent_res.failing_keys or $merged.failing_counts != $agent_res.failing_counts or ($merged.surface_results | length) != 1 {
        print $"(ansi red_bold)❌ pass2-eval self-test: apply-surface-finding did not append all three accumulators together(ansi reset)"
        $failed = true
    }

    rm -rf $root
    if not $failed {
        print $"(ansi green_bold)✅ Pass-2 eval self-test passed \(9 cases\)(ansi reset)"
    }
    $failed
}

# Evaluate one output-style file against Pass-2's output-style-surface
# checks (claude-skills-310): output-styles/ is the one plugin surface Pass
# 2 does not cover today (agents/, commands/, hooks/hooks.json are covered).
# Same shape as evaluate-agent-file/evaluate-command-file: missing_name and
# missing_desc are a house-rule addition on top of the upstream-optional
# schema (see OUTPUT_STYLE_FM_KEYS), fm_schema reuses unknown-frontmatter-keys.
#
def evaluate-output-style-file [f: string, plugin_name: string]: nothing -> record {
    let content = (open --raw $f)
    let all_lines = ($content | lines)
    let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
        let rest = ($all_lines | skip 1)
        let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
        if ($end_matches | is-not-empty) {
            $rest | first ($end_matches | first | get index)
        } else { [] }
    } else { [] }

    mut failed = []
    if not ($fm_lines | any {|line| $line | str starts-with "name:"}) {
        $failed = ($failed | append "missing_name")
    }
    if not ($fm_lines | any {|line| $line | str starts-with "description:"}) {
        $failed = ($failed | append "missing_desc")
    }

    let fm_unknown = (unknown-frontmatter-keys $fm_lines $OUTPUT_STYLE_FM_KEYS)
    if ($fm_unknown | is-not-empty) { $failed = ($failed | append "fm_schema") }

    let key_base = $"($plugin_name)/output-styles/($f | path basename)"
    {
        failed: $failed
        failing_keys: ($failed | each {|c| $"($key_base):($c)"})
        failing_counts: (accumulate-detail-counts [] $key_base $failed [
            {check: "fm_schema", count: ($fm_unknown | length)}
        ])
        surface_result: {
            plugin: $plugin_name, kind: "output-style", file: ($f | path basename), failed: ($failed | str join " ")
            details: ($fm_unknown | each {|k| $"frontmatter:($k)"} | str join " ")
        }
    }
}

# Flags a plugin.json whose `outputStyles` field points at a path that does
# not exist on disk (claude-skills-310). A plugin with no `outputStyles`
# field at all — the common case, and how `core` worked before an explicit
# field was added — is never flagged; this check only fires when the field
# is present and wrong. Each path is resolved relative to `plugin_dir`.
#
# The plugins reference documents `outputStyles` as EITHER a single string
# OR an array of output-style files/directories (claude-skills-310) —
# `[$output_styles] | flatten` normalizes both shapes to a flat list of
# strings (a bare string becomes a one-element list; a list stays as-is;
# an empty list stays empty) so the same existence check below applies to
# every entry without branching on `describe`.
def check-output-styles-path [plugin_json: record, plugin_dir: string]: nothing -> list {
    let output_styles = ($plugin_json | get -o outputStyles)
    if $output_styles == null {
        []
    } else {
        let paths = ([$output_styles] | flatten)
        if ($paths | any {|p| not ($plugin_dir | path join $p | path exists) }) {
            ["missing_path"]
        } else {
            []
        }
    }
}

# claude-skills-313: shared guard for `open`-ing a plugin.json manifest.
# Four call sites open a plugin.json with no guard today — a malformed
# manifest throws and aborts the WHOLE validator run instead of producing a
# finding ("Total skills" never prints and every other finding in that run
# is masked). Verified by grep at this branch point: check-root-manifest
# (below this comment), the $registry-building loop, the pass-2 skills
# loop, and the outputStyles plugin-json check. Same class of bug as the
# outputStyles array crash fixed in claude-skills-269 — a crash aborts, a
# finding reports.
#
# Contract: never throws. Returns {status, data, file} where status is one
# of four values: "ok" (parsed successfully, data is the record), "invalid"
# (path exists but failed to parse, or parsed to a non-record; data is
# null), "missing" (path does not exist, data is null), or
# "missing_required_field" (parsed to a record lacking `name`, data is
# null). `file` always echoes the input path, so a caller building a
# finding can name the offending manifest without threading the path
# through separately.
#
# Known residual (claude-skills-317): this validates that `name` is
# PRESENT, not that it is a string. A non-string `name` returns "ok" and
# then aborts the run at evaluate-agent-file's string-typed parameter —
# a type axis this helper does not cover.
#
# The "missing" branch needs no guard — a nonexistent path never reaches
# `open`. The parse step DOES need one: `open` on a path that exists but
# contains unparseable JSON throws, and an uncaught throw here would abort
# the whole validator run (the exact failure mode this function exists to
# prevent). try/catch turns that throw into a reported "invalid" status
# instead, with the offending path still in `file` so a caller can build a
# finding naming it.
def read-plugin-json [path: string]: nothing -> record {
    if not ($path | path exists) {
        {status: "missing", data: null, file: $path}
    } else {
        try {
            let parsed = (open $path)
            # A parse that succeeds but yields something other than a
            # record (a JSON list/string/null, an empty file, or a
            # BOM-prefixed file that falls back to raw text — claude-skills-
            # 314) is just as unusable to every downstream `get -o skills`/
            # `.name` field access as a throw would have been, so it's
            # normalized to the same "invalid" status here rather than
            # returning "ok" with unusable data. `describe` on a record
            # returns the full field signature (e.g. `record<name: string,
            # ...>`), not the bare word "record" — str starts-with is
            # required, an equality check would reject every well-formed
            # manifest too.
            if ($parsed | describe | str starts-with "record") {
                # A record that parses clean but lacks `name` is a distinct
                # failure from "invalid" (claude-skills-316): the JSON is
                # perfectly valid, it's a schema gap, not a parse failure.
                # `name` is checked for PRESENCE, not the record for
                # emptiness — {"foo": 1} has fields but still lacks `name`
                # and must be caught the same as {}.
                if ($parsed | get -o name) == null {
                    {status: "missing_required_field", data: null, file: $path}
                } else {
                    {status: "ok", data: $parsed, file: $path}
                }
            } else {
                {status: "invalid", data: null, file: $path}
            }
        } catch {
            {status: "invalid", data: null, file: $path}
        }
    }
}

# claude-skills-312: the root `.claude-plugin/plugin.json` (name
# "all-skills", the meta-plugin manifest that re-lists every other plugin's
# skills) is skipped when building $registry — `if ($plugin.name ==
# "all-skills") { continue }` — because including it would double-count the
# whole corpus. That exclusion is correct and must stay. The side effect:
# the root manifest is the ONLY manifest in this repo that sets
# `outputStyles` (verified via `grep -rl outputStyles --include=plugin.json
# .`), and being excluded from $registry means it never runs through
# check-output-styles-path — a typo there ships no output styles with no
# finding at all. check-root-manifest re-applies that same check to the root
# manifest specifically, independent of $registry, so the all-skills skip
# stays correct while the root manifest still gets checked.
def check-root-manifest [repo_root: string]: nothing -> list {
    let plugin_json_path = ($repo_root | path join ".claude-plugin" "plugin.json")
    let read = (read-plugin-json $plugin_json_path)
    if $read.status == "missing" {
        []
    } else if $read.status == "invalid" {
        ["invalid_json"]
    } else if $read.status == "missing_required_field" {
        ["missing_required_field"]
    } else {
        check-output-styles-path $read.data $repo_root
    }
}

# Embedded self-test for evaluate-output-style-file and
# check-output-styles-path (claude-skills-310). Mirrors run-pass2-eval-self-test's
# shape for the new output-styles surface. Cases 1-6 exercise
# evaluate-output-style-file (unknown key, missing name, missing
# description, a clean four-key file, and — as a regression guard — the one
# style this repo actually ships, plugins/core/output-styles/plain-technical.md,
# which must stay clean). Cases 7-10 exercise check-output-styles-path's
# STRING form (missing path, present path, no outputStyles field, and an
# output-styles/ dir with no outputStyles field — convention discovery,
# which must not be flagged either).
#
# Cases 11-14 exercise the ARRAY form the plugins reference also documents
# for `outputStyles` (string or array of output-style files/directories).
# `check-output-styles-path` throws on it today (`path join` against a
# list<string> is a type error, not a caught one) — a crash on documented
# valid input, and because it throws instead of returning a finding it
# would abort the WHOLE validator run, not just miss this one check. Each
# call is wrapped in try/catch so that crash is reported as a failed
# assertion here instead of aborting this self-test suite itself.
def run-output-style-self-test [] {
    mut failed = false
    let root = (mktemp -d)
    let plugin_dir = ($root | path join "pluginX")
    mkdir ($plugin_dir | path join "output-styles")

    "---
name: broken-style
description: test fixture
badkey: nope
---

Body prose.
" | save ($plugin_dir | path join "output-styles" "broken-style.md")
    let broken_res = (evaluate-output-style-file ($plugin_dir | path join "output-styles" "broken-style.md") "pluginX")
    let broken_key_base = "pluginX/output-styles/broken-style.md"
    if "fm_schema" not-in $broken_res.failed {
        print $"(ansi red_bold)❌ output-style self-test: unknown frontmatter key not flagged \(got ($broken_res.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }
    if ({key: $"($broken_key_base):fm_schema", count: 1} not-in $broken_res.failing_counts) {
        print $"(ansi red_bold)❌ output-style self-test: fm_schema finding missing from failing_counts(ansi reset)"
        $failed = true
    }

    "---
description: test fixture
---

Body prose.
" | save ($plugin_dir | path join "output-styles" "no-name.md")
    let no_name_res = (evaluate-output-style-file ($plugin_dir | path join "output-styles" "no-name.md") "pluginX")
    if "missing_name" not-in $no_name_res.failed {
        print $"(ansi red_bold)❌ output-style self-test: missing name not flagged \(got ($no_name_res.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }

    "---
name: no-desc
---

Body prose.
" | save ($plugin_dir | path join "output-styles" "no-desc.md")
    let no_desc_res = (evaluate-output-style-file ($plugin_dir | path join "output-styles" "no-desc.md") "pluginX")
    if "missing_desc" not-in $no_desc_res.failed {
        print $"(ansi red_bold)❌ output-style self-test: missing description not flagged \(got ($no_desc_res.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }

    "---
name: clean-style
description: test fixture
keep-coding-instructions: true
force-for-plugin: false
---

Body prose.
" | save ($plugin_dir | path join "output-styles" "clean-style.md")
    let clean_res = (evaluate-output-style-file ($plugin_dir | path join "output-styles" "clean-style.md") "pluginX")
    if ($clean_res.failed | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: style with all four documented keys wrongly flagged \(got ($clean_res.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }

    # Regression guard: the one style this repo actually ships must stay clean.
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let shipped_style = ($repo_root | path join "plugins" "core" "output-styles" "plain-technical.md")
    let shipped_res = (evaluate-output-style-file $shipped_style "core")
    if ($shipped_res.failed | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: shipped plain-technical.md wrongly flagged \(got ($shipped_res.failed | str join ' ')\)(ansi reset)"
        $failed = true
    }

    let missing_path_json = {name: "pluginX", outputStyles: "./does-not-exist/"}
    let missing_path_res = (check-output-styles-path $missing_path_json $plugin_dir)
    if ($missing_path_res | is-empty) {
        print $"(ansi red_bold)❌ output-style self-test: nonexistent outputStyles path not flagged(ansi reset)"
        $failed = true
    }

    let present_path_json = {name: "pluginX", outputStyles: "./output-styles/"}
    let present_path_res = (check-output-styles-path $present_path_json $plugin_dir)
    if ($present_path_res | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: existing outputStyles path wrongly flagged \(got ($present_path_res | str join ' ')\)(ansi reset)"
        $failed = true
    }

    let no_field_json = {name: "pluginX"}
    let no_field_res = (check-output-styles-path $no_field_json $plugin_dir)
    if ($no_field_res | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: plugin with no outputStyles field wrongly flagged \(got ($no_field_res | str join ' ')\)(ansi reset)"
        $failed = true
    }

    # A plugin with an output-styles/ dir but no `outputStyles` field in
    # plugin.json — convention discovery, how `core` worked before an
    # explicit field was added — must not be flagged either.
    let convention_plugin_dir = ($root | path join "pluginY")
    mkdir ($convention_plugin_dir | path join "output-styles")
    let convention_json = {name: "pluginY"}
    let convention_res = (check-output-styles-path $convention_json $convention_plugin_dir)
    if ($convention_res | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: convention-only output-styles/ dir wrongly flagged \(got ($convention_res | str join ' ')\)(ansi reset)"
        $failed = true
    }

    # Array form (claude-skills-310): the plugins reference documents
    # `outputStyles` as string OR array of output-style files/directories.
    # try/catch turns a crash into a reported failure rather than aborting
    # this whole self-test suite — see the doc comment above.
    let arr_one_bad_json = {name: "pluginX", outputStyles: ["./does-not-exist/"]}
    let arr_one_bad_res = (try { check-output-styles-path $arr_one_bad_json $plugin_dir } catch { |e| null })
    if ($arr_one_bad_res == null) or ($arr_one_bad_res | is-empty) {
        print $"(ansi red_bold)❌ output-style self-test: array outputStyles with one bad path crashed or was not flagged \(got ($arr_one_bad_res)\)(ansi reset)"
        $failed = true
    }

    let arr_mixed_json = {name: "pluginX", outputStyles: ["./output-styles/" "./also-missing/"]}
    let arr_mixed_res = (try { check-output-styles-path $arr_mixed_json $plugin_dir } catch { |e| null })
    if ($arr_mixed_res == null) or ($arr_mixed_res | is-empty) {
        print $"(ansi red_bold)❌ output-style self-test: array outputStyles with one good and one bad path crashed or was not flagged \(got ($arr_mixed_res)\)(ansi reset)"
        $failed = true
    }

    let arr_all_good_json = {name: "pluginX", outputStyles: ["./output-styles/"]}
    let arr_all_good_res = (try { check-output-styles-path $arr_all_good_json $plugin_dir } catch { |e| null })
    if ($arr_all_good_res == null) {
        print "❌ output-style self-test: array outputStyles with an existing path crashed"
        $failed = true
    } else if ($arr_all_good_res | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: array outputStyles with an existing path wrongly flagged \(got ($arr_all_good_res | str join ' ')\)(ansi reset)"
        $failed = true
    }

    let arr_empty_json = {name: "pluginX", outputStyles: []}
    let arr_empty_res = (try { check-output-styles-path $arr_empty_json $plugin_dir } catch { |e| null })
    if ($arr_empty_res == null) {
        print "❌ output-style self-test: empty array outputStyles crashed"
        $failed = true
    } else if ($arr_empty_res | is-not-empty) {
        print $"(ansi red_bold)❌ output-style self-test: empty array outputStyles wrongly flagged \(got ($arr_empty_res | str join ' ')\)(ansi reset)"
        $failed = true
    }

    rm -rf $root
    if not $failed {
        print $"(ansi green_bold)✅ Output-style self-test passed \(14 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for check-root-manifest (claude-skills-312). The root
# .claude-plugin/plugin.json is excluded from $registry (the "all-skills"
# check at the top of the $registry-building loop) to avoid double-counting
# the corpus; check-root-manifest re-checks that manifest's outputStyles
# field independent of $registry so the exclusion can stay. Case 1 is the
# must-flag red case (a root manifest with a broken outputStyles path).
# Cases 2-3 are regression guards: the real shipped root manifest
# (outputStyles -> ./plugins/core/output-styles/, which exists) must stay
# clean, and a root manifest with no outputStyles field must stay clean too.
# Case 4 is a structural guard, not a behavioral one: it greps this very
# script for the exact all-skills exclusion line and fails if it's gone or
# reworded — a numeric "skill count unchanged" assertion can't observe that
# line directly because the $registry-building loop lives inline in main()
# and isn't exposed as a callable unit, so this guard pins the source text
# instead, which is exactly what would break if an implementer "fixed" this
# gap by deleting the exclusion instead of adding a root-manifest call site.
def run-root-manifest-self-test [] {
    mut failed = false
    let root = (mktemp -d)
    mkdir ($root | path join ".claude-plugin")

    # Case 1 (must-flag, RED until implemented): outputStyles points at a
    # path that does not exist.
    {name: "all-skills", outputStyles: "./does-not-exist/"} | to json | save ($root | path join ".claude-plugin" "plugin.json")
    let broken_res = (check-root-manifest $root)
    if ($broken_res | is-empty) {
        print $"(ansi red_bold)❌ root-manifest self-test: broken outputStyles path on root manifest not flagged(ansi reset)"
        $failed = true
    }

    # Case 2 (regression guard, must already pass): the real shipped root
    # manifest sets outputStyles to ./plugins/core/output-styles/, which
    # exists — must stay clean.
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let shipped_res = (check-root-manifest $repo_root)
    if ($shipped_res | is-not-empty) {
        print $"(ansi red_bold)❌ root-manifest self-test: real root manifest wrongly flagged \(got ($shipped_res | str join ' ')\)(ansi reset)"
        $failed = true
    }

    # Case 3 (regression guard, must already pass): no outputStyles field at
    # all must not be flagged.
    let no_field_root = (mktemp -d)
    mkdir ($no_field_root | path join ".claude-plugin")
    {name: "all-skills"} | to json | save ($no_field_root | path join ".claude-plugin" "plugin.json")
    let no_field_res = (check-root-manifest $no_field_root)
    if ($no_field_res | is-not-empty) {
        print $"(ansi red_bold)❌ root-manifest self-test: root manifest with no outputStyles field wrongly flagged \(got ($no_field_res | str join ' ')\)(ansi reset)"
        $failed = true
    }
    rm -rf $no_field_root

    # Case 4 (structural guard, must already pass): the all-skills exclusion
    # at the top of the $registry-building loop must still exist verbatim —
    # deleting it would double-count the corpus. See doc comment above for
    # why this is a source-text guard and not a numeric one.
    #
    # A plain `str contains` for the needle is vacuous: this guard's own
    # source line is itself a match (the needle string is quoted right
    # here), so `str contains` returns true even after the real exclusion at
    # the top of the $registry-building loop is deleted — the guard would
    # match itself and never fire. Counting occurrences instead of checking
    # presence fixes it: this guard's own line always contributes exactly
    # one match, so requiring at least TWO occurrences means the literal must
    # appear somewhere besides this guard. Deleting or rewording the real
    # exclusion drops the count from 2 to 1 and fails.
    #
    # Known residual: this counts text, not behaviour. Commenting the real
    # line out while keeping the literal keeps the count at 2 and passes, and
    # any future comment quoting the literal verbatim would do the same. The
    # load-bearing guard is the corpus run itself — with the exclusion gone,
    # a full validation reports 216 skills instead of 108 and fails on the
    # duplicated anti_fab findings. This check is an early tripwire, not the
    # backstop.
    let script_path = ($repo_root | path join "test" "validate-skills-quality.nu")
    let script_text = (open --raw $script_path)
    let exclusion_needle = 'if ($plugin.name == "all-skills") { continue }'
    let exclusion_occurrences = (($script_text | split row $exclusion_needle | length) - 1)
    if $exclusion_occurrences < 2 {
        print $"(ansi red_bold)❌ root-manifest self-test: all-skills exclusion line missing from the \$registry-building loop — corpus would double-count \(found ($exclusion_occurrences) occurrence\(s\), need >= 2: this guard's own line plus the real exclusion\)(ansi reset)"
        $failed = true
    }

    rm -rf $root
    if not $failed {
        print $"(ansi green_bold)✅ Root-manifest self-test passed \(4 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for read-plugin-json (claude-skills-313) — the shared
# guard around `open`-ing a plugin.json manifest, defined above
# check-root-manifest. Case 1 and Case 2 are the must-flag red cases: a
# malformed manifest throws today (the stub has no try/catch around its
# `open` call), so both are RED until the implementer adds the guard.
# Case 3 and Case 4 are regression guards that already pass — well-formed
# manifests and missing manifests are handled correctly by the stub as
# shipped (the "missing" branch is real, not stubbed; parsing a real
# well-formed manifest never hits the missing try/catch at all).
#
# Every call is wrapped in try/catch, mirroring run-output-style-self-test's
# precedent for a stub that can still throw: a crash here must fail this
# case's assertion, not abort the whole self-test suite.
def run-invalid-manifest-self-test [] {
    mut failed = false

    # Case 1 (must-flag, RED until implemented): a malformed plugin.json —
    # unparseable JSON — must report status "invalid" rather than throwing.
    let bad_root = (mktemp -d)
    mkdir ($bad_root | path join ".claude-plugin")
    let bad_path = ($bad_root | path join ".claude-plugin" "plugin.json")
    "{ broken" | save $bad_path
    # The catch fallback deliberately does NOT know $bad_path — file: null,
    # not file: $bad_path. A fallback that echoed the known path back would
    # make Case 2 pass vacuously whenever the stub throws, regardless of
    # whether the real implementation ever names the file correctly. Only
    # the implementation's own return value may satisfy Case 2.
    let bad_res = (try {
        read-plugin-json $bad_path
    } catch {
        {status: "threw", data: null, file: null}
    })
    if $bad_res.status != "invalid" {
        print $"(ansi red_bold)❌ invalid-manifest self-test: malformed plugin.json not flagged as invalid \(got status: ($bad_res.status)\)(ansi reset)"
        $failed = true
    }

    # Case 2 (must-flag, RED until implemented): the result names the
    # offending file, so a finding built from it can say which manifest is
    # broken.
    if $bad_res.file != $bad_path {
        print $"(ansi red_bold)❌ invalid-manifest self-test: malformed-manifest result does not name the offending file \(got: ($bad_res.file)\)(ansi reset)"
        $failed = true
    }
    rm -rf $bad_root

    # Case 3 (regression guard, must already pass): a well-formed manifest
    # from the real corpus parses clean — status "ok", with the actual
    # parsed content, not "invalid".
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let real_manifest = ($repo_root | path join "plugins" "core" ".claude-plugin" "plugin.json")
    let real_res = (try {
        read-plugin-json $real_manifest
    } catch {
        {status: "threw", data: null, file: $real_manifest}
    })
    if $real_res.status != "ok" {
        print $"(ansi red_bold)❌ invalid-manifest self-test: real core plugin.json wrongly flagged \(got status: ($real_res.status)\)(ansi reset)"
        $failed = true
    }
    if ($real_res.data | get -o name) != "core" {
        print $"(ansi red_bold)❌ invalid-manifest self-test: real core plugin.json parsed content missing or wrong \(got name: ($real_res.data | get -o name)\)(ansi reset)"
        $failed = true
    }

    # Case 4 (regression guard, must already pass): a missing manifest is
    # status "missing", never "invalid" — absent and malformed are
    # different states, and the existing call sites already skip absent
    # manifests via a `path exists` check before opening.
    let missing_root = (mktemp -d)
    let missing_path = ($missing_root | path join ".claude-plugin" "plugin.json")
    let missing_res = (try {
        read-plugin-json $missing_path
    } catch {
        {status: "threw", data: null, file: $missing_path}
    })
    if $missing_res.status != "missing" {
        print $"(ansi red_bold)❌ invalid-manifest self-test: missing plugin.json wrongly reported as ($missing_res.status), expected missing(ansi reset)"
        $failed = true
    }
    rm -rf $missing_root

    if not $failed {
        print $"(ansi green_bold)✅ Invalid-manifest self-test passed \(4 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for read-plugin-json non-record handling
# (claude-skills-314). claude-skills-313 made an unparseable manifest report
# "invalid" instead of crashing the whole run, but a manifest that PARSES
# CLEAN to something other than a record (a list, a string, null, or an
# empty file) still slips through as status "ok" — the crash then lands
# downstream, at the first field access (`get -o skills`, `.name`) in the
# Pass-1 registry loop. This self-test pins the fix: a successful parse
# must ALSO check that the parsed value is a record before returning "ok".
#
# Case 5 (BOM) is the nastiest and does NOT behave like the others: a UTF-8
# BOM followed by otherwise-valid JSON does not throw in nushell's `open`
# — empirically verified (0.113.1): `open` on such a path returns status
# "ok" with `data` as a plain STRING containing the BOM character, not a
# record, because the BOM byte breaks `from json`'s auto-detection and nu
# falls back to returning raw text instead of raising. The existing
# try/catch in read-plugin-json never fires for this case — only a
# post-parse type check on the successfully-returned value catches it.
#
# `describe` on a record does NOT return the bare word "record" — it
# returns the full field signature, e.g. `record<name: string, ...>`
# (confirmed against the real core plugin.json below). A fix that checks
# `(... | describe) == "record"` will always be false and reject every
# well-formed manifest too. Check with `str starts-with "record"` instead.
def run-non-record-manifest-self-test [] {
    mut failed = false

    # Case 1 (must-flag, RED until implemented): a manifest that parses
    # clean to a JSON list must be flagged, not returned as "ok" with
    # list-typed data.
    let list_root = (mktemp -d)
    mkdir ($list_root | path join ".claude-plugin")
    let list_path = ($list_root | path join ".claude-plugin" "plugin.json")
    "[1, 2, 3]" | save $list_path
    let list_res = (try {
        read-plugin-json $list_path
    } catch {
        {status: "threw", data: null, file: $list_path}
    })
    if $list_res.status != "invalid" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: JSON list manifest not flagged as invalid \(got status: ($list_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $list_root

    # Case 2 (must-flag, RED until implemented): a manifest that parses
    # clean to a JSON string.
    let string_root = (mktemp -d)
    mkdir ($string_root | path join ".claude-plugin")
    let string_path = ($string_root | path join ".claude-plugin" "plugin.json")
    '"juststring"' | save $string_path
    let string_res = (try {
        read-plugin-json $string_path
    } catch {
        {status: "threw", data: null, file: $string_path}
    })
    if $string_res.status != "invalid" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: JSON string manifest not flagged as invalid \(got status: ($string_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $string_root

    # Case 3 (must-flag, RED until implemented): a manifest that parses
    # clean to JSON null.
    let null_root = (mktemp -d)
    mkdir ($null_root | path join ".claude-plugin")
    let null_path = ($null_root | path join ".claude-plugin" "plugin.json")
    "null" | save $null_path
    let null_res = (try {
        read-plugin-json $null_path
    } catch {
        {status: "threw", data: null, file: $null_path}
    })
    if $null_res.status != "invalid" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: JSON null manifest not flagged as invalid \(got status: ($null_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $null_root

    # Case 4 (must-flag, RED until implemented): an empty file. `open` on
    # an empty .json file does not throw (empirically verified: it returns
    # status "ok" with data type "nothing"), so this needs the same
    # record-type guard as the other non-record cases.
    let empty_root = (mktemp -d)
    mkdir ($empty_root | path join ".claude-plugin")
    let empty_path = ($empty_root | path join ".claude-plugin" "plugin.json")
    "" | save $empty_path
    let empty_res = (try {
        read-plugin-json $empty_path
    } catch {
        {status: "threw", data: null, file: $empty_path}
    })
    if $empty_res.status != "invalid" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: empty-file manifest not flagged as invalid \(got status: ($empty_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $empty_root

    # Case 5 (must-flag, RED until implemented, the nasty one): a UTF-8 BOM
    # (0xEF 0xBB 0xBF) followed by otherwise-valid JSON. Written with
    # `save --raw` on each half — a plain `save` (no --raw) on a binary
    # literal serializes it as a pretty-printed list representation instead
    # of the raw bytes (confirmed: without --raw the "BOM" file came out as
    # 23 bytes of literal text "[\n  239,\n  187,\n  191\n]", not 3 raw
    # bytes) — so --raw is load-bearing for the fixture to be real BOM
    # bytes, not just a nicety.
    let bom_root = (mktemp -d)
    mkdir ($bom_root | path join ".claude-plugin")
    let bom_path = ($bom_root | path join ".claude-plugin" "plugin.json")
    (0x[EF BB BF]) | save -f --raw $bom_path
    '{"name": "bom-test"}' | save -a --raw $bom_path
    let bom_res = (try {
        read-plugin-json $bom_path
    } catch {
        {status: "threw", data: null, file: $bom_path}
    })
    if $bom_res.status != "invalid" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: BOM-prefixed manifest not flagged as invalid \(got status: ($bom_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $bom_root

    # Case 6 (regression guard, must already pass): a well-formed record
    # manifest from the real corpus still returns "ok" with usable,
    # record-typed data.
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let real_manifest = ($repo_root | path join "plugins" "core" ".claude-plugin" "plugin.json")
    let real_res = (try {
        read-plugin-json $real_manifest
    } catch {
        {status: "threw", data: null, file: $real_manifest}
    })
    if $real_res.status != "ok" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: real core plugin.json wrongly flagged \(got status: ($real_res.status)\)(ansi reset)"
        $failed = true
    }
    if not ($real_res.data | describe | str starts-with "record") {
        print $"(ansi red_bold)❌ non-record-manifest self-test: real core plugin.json data is not a record \(got: ($real_res.data | describe)\)(ansi reset)"
        $failed = true
    }
    if ($real_res.data | get -o name) != "core" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: real core plugin.json parsed content missing or wrong \(got name: ($real_res.data | get -o name)\)(ansi reset)"
        $failed = true
    }

    # Case 7 (regression guard, must already pass): a missing manifest is
    # still status "missing", never "invalid" — the non-record check must
    # not run ahead of, or interfere with, the existing `path exists` gate.
    let missing_root = (mktemp -d)
    let missing_path = ($missing_root | path join ".claude-plugin" "plugin.json")
    let missing_res = (try {
        read-plugin-json $missing_path
    } catch {
        {status: "threw", data: null, file: $missing_path}
    })
    if $missing_res.status != "missing" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: missing plugin.json wrongly reported as ($missing_res.status), expected missing(ansi reset)"
        $failed = true
    }
    rm -rf $missing_root

    # Case 8 (regression guard, must already pass — claude-skills-313's fix
    # must not regress): genuinely malformed (unparseable) JSON still
    # returns "invalid" via the existing try/catch.
    let malformed_root = (mktemp -d)
    mkdir ($malformed_root | path join ".claude-plugin")
    let malformed_path = ($malformed_root | path join ".claude-plugin" "plugin.json")
    "{ broken" | save $malformed_path
    let malformed_res = (try {
        read-plugin-json $malformed_path
    } catch {
        {status: "threw", data: null, file: null}
    })
    if $malformed_res.status != "invalid" {
        print $"(ansi red_bold)❌ non-record-manifest self-test: malformed plugin.json regressed \(got status: ($malformed_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $malformed_root

    if not $failed {
        print $"(ansi green_bold)✅ Non-record-manifest self-test passed \(8 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for read-plugin-json missing-required-field handling
# (claude-skills-316) — the third shape of this crash class. claude-skills-
# 313 caught unparseable JSON; claude-skills-314 caught a clean parse to a
# non-record. Both leave a manifest that PARSES CLEAN TO A RECORD but lacks
# `name` — the only field the Pass-1 registry loop dereferences unguarded
# ($plugin_json.name, three sites: the skill_dir_map append, the
# upstream_cmds `where ns ==` filter, and the $registry append itself, all
# inside the $registry-building loop in main).
# Every other plugin_json field access in this file already goes through
# `get -o` (safe). This self-test pins a fourth, distinct status —
# "missing_required_field" — rather than reusing "invalid": a parse failure
# and a schema gap are different states, matching the same distinction the
# helper already draws between "missing" (absent) and "invalid" (unparseable
# or non-record). Reusing "invalid" for a file that IS valid JSON would
# mislead a maintainer reading the finding.
#
# Case 3 (fields present, `name` absent) exists specifically to catch an
# implementation that only checks "is the record completely empty" rather
# than "is `name` present" — `{}` alone would pass a narrower, wrong check.
def run-missing-field-manifest-self-test [] {
    mut failed = false

    # Case 1 (must-flag, RED until implemented): a record with no fields at
    # all is missing `name`.
    let empty_record_root = (mktemp -d)
    mkdir ($empty_record_root | path join ".claude-plugin")
    let empty_record_path = ($empty_record_root | path join ".claude-plugin" "plugin.json")
    "{}" | save $empty_record_path
    let empty_record_res = (try {
        read-plugin-json $empty_record_path
    } catch {
        {status: "threw", data: null, file: null}
    })
    if $empty_record_res.status != "missing_required_field" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: empty-record manifest not flagged as missing_required_field \(got status: ($empty_record_res.status)\)(ansi reset)"
        $failed = true
    }

    # Case 2 (must-flag, RED until implemented): the result names the
    # offending file, so a finding built from it can say which manifest is
    # broken. Same fixture as Case 1, mirroring run-invalid-manifest-self-
    # test's Case 1/Case 2 split.
    if $empty_record_res.file != $empty_record_path {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: empty-record result does not name the offending file \(got: ($empty_record_res.file)\)(ansi reset)"
        $failed = true
    }
    rm -rf $empty_record_root

    # Case 3 (must-flag, RED until implemented): a record WITH fields, but
    # not `name`, must also be flagged — not just the degenerate {} case.
    let no_name_root = (mktemp -d)
    mkdir ($no_name_root | path join ".claude-plugin")
    let no_name_path = ($no_name_root | path join ".claude-plugin" "plugin.json")
    '{"foo": 1}' | save $no_name_path
    let no_name_res = (try {
        read-plugin-json $no_name_path
    } catch {
        {status: "threw", data: null, file: null}
    })
    if $no_name_res.status != "missing_required_field" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: manifest with fields but no name not flagged as missing_required_field \(got status: ($no_name_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $no_name_root

    # Case 4 (regression guard, must already pass): a well-formed manifest
    # from the real corpus, which DOES have `name`, still returns "ok" with
    # usable, record-typed data.
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let real_manifest = ($repo_root | path join "plugins" "core" ".claude-plugin" "plugin.json")
    let real_res = (try {
        read-plugin-json $real_manifest
    } catch {
        {status: "threw", data: null, file: $real_manifest}
    })
    if $real_res.status != "ok" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: real core plugin.json wrongly flagged \(got status: ($real_res.status)\)(ansi reset)"
        $failed = true
    }
    if ($real_res.data | get -o name) != "core" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: real core plugin.json parsed content missing or wrong \(got name: ($real_res.data | get -o name)\)(ansi reset)"
        $failed = true
    }

    # Case 5 (regression guard, must already pass): a missing manifest is
    # still status "missing", never "missing_required_field" — absent and
    # schema-incomplete are different states, and the required-field check
    # must not run ahead of, or interfere with, the existing `path exists`
    # gate.
    let missing_root = (mktemp -d)
    let missing_path = ($missing_root | path join ".claude-plugin" "plugin.json")
    let missing_res = (try {
        read-plugin-json $missing_path
    } catch {
        {status: "threw", data: null, file: $missing_path}
    })
    if $missing_res.status != "missing" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: missing plugin.json wrongly reported as ($missing_res.status), expected missing(ansi reset)"
        $failed = true
    }
    rm -rf $missing_root

    # Case 6 (regression guard, must already pass — claude-skills-313's fix
    # must not regress): genuinely malformed (unparseable) JSON still
    # returns "invalid", never "missing_required_field".
    let malformed_root = (mktemp -d)
    mkdir ($malformed_root | path join ".claude-plugin")
    let malformed_path = ($malformed_root | path join ".claude-plugin" "plugin.json")
    "{ broken" | save $malformed_path
    let malformed_res = (try {
        read-plugin-json $malformed_path
    } catch {
        {status: "threw", data: null, file: null}
    })
    if $malformed_res.status != "invalid" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: malformed plugin.json regressed \(got status: ($malformed_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $malformed_root

    # Case 7 (regression guard, must already pass — claude-skills-314's fix
    # must not regress): a manifest that parses clean to a non-record (a
    # JSON list) still returns "invalid", not "missing_required_field" — the
    # required-field check must not misclassify a non-record as a record
    # that's merely missing one field.
    let list_root = (mktemp -d)
    mkdir ($list_root | path join ".claude-plugin")
    let list_path = ($list_root | path join ".claude-plugin" "plugin.json")
    "[1, 2, 3]" | save $list_path
    let list_res = (try {
        read-plugin-json $list_path
    } catch {
        {status: "threw", data: null, file: $list_path}
    })
    if $list_res.status != "invalid" {
        print $"(ansi red_bold)❌ missing-field-manifest self-test: non-record manifest regressed \(got status: ($list_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $list_root

    if not $failed {
        print $"(ansi green_bold)✅ Missing-field-manifest self-test passed \(7 cases\)(ansi reset)"
    }
    $failed
}

# Embedded self-test for read-marketplace-json (claude-skills-315) — the
# guard around `open`-ing the corpus-root .claude-plugin/marketplace.json at
# what was line 4021 before this fix, the last unguarded manifest read in
# this file. Mirrors read-plugin-json's shape (claude-skills-313/314/316)
# but marketplace.json is not a plugin manifest — it is the corpus root:
# without it there is no plugin list to validate at all, so unlike a broken
# plugin.json (which is skipped and reported as a finding while the rest of
# the run continues), a broken marketplace.json must halt the whole run
# rather than continue with an empty, vacuously-passing corpus.
#
# Scope decision, deliberately narrower than the shapes this function could
# check: `plugins` present but of the WRONG type (a string, a record, a
# number) is NOT covered here. Verified empirically (nu 0.113.1): a string
# `plugins` value does not throw inside the guard itself — `for plugin in
# "notalist"` treats the whole string as one item — so unlike a missing or
# null `plugins`, this shape still crashes loudly downstream (at the first
# `$plugin.source`/`.name` field access, one loop iteration later) rather
# than silently validating an empty corpus. `plugins/tools/claude-code/
# skills/plugin-marketplace/scripts/validate-marketplace.nu` (run via `mise
# run test:marketplace`, part of `mise test`) already enforces `plugins` as
# an array as a schema rule; duplicating that type check here would be scope
# creep onto a sibling validator's job, not a fix for the raw-trace defect
# claude-skills-315 reports.
#
# `plugins: null` folds into the SAME "missing_required_field" status as an
# absent `plugins` key, not a distinct status — matching read-plugin-json's
# treatment of a missing `name`, and confirmed empirically that nushell's
# `get -o plugins` already returns null for both an absent key and an
# explicit `null` value, so no extra branching is needed to unify them. This
# distinction matters: a `plugins: null` marketplace.json does NOT throw
# today — the for-loop it drives silently iterates zero times, exit 0, no
# findings, no raw trace. That silent vacuous pass is a worse failure mode
# than any of the three shapes that throw, and is why it is pinned here
# rather than left uncovered.
def run-marketplace-json-self-test [] {
    mut failed = false

    # Case 1 (must-flag, RED until implemented): a missing marketplace.json
    # is status "missing" — the same missing/malformed distinction
    # read-plugin-json draws for plugin.json.
    let missing_root = (mktemp -d)
    let missing_path = ($missing_root | path join ".claude-plugin" "marketplace.json")
    let missing_res = (try {
        read-marketplace-json $missing_path
    } catch {
        {status: "threw", data: null, file: $missing_path}
    })
    if $missing_res.status != "missing" {
        print $"(ansi red_bold)❌ marketplace-json self-test: missing marketplace.json wrongly reported as ($missing_res.status), expected missing(ansi reset)"
        $failed = true
    }
    rm -rf $missing_root

    # Case 2 (must-flag, RED until implemented): unparseable JSON — the
    # actual claude-skills-315 defect — must report "invalid", never throw
    # the raw nushell parser trace seen today (the `nu::shell::error` /
    # `,-[...]` boxed-source markers on stderr, with stdout stopping mid-run
    # and no explanation of what broke or where).
    let bad_root = (mktemp -d)
    mkdir ($bad_root | path join ".claude-plugin")
    let bad_path = ($bad_root | path join ".claude-plugin" "marketplace.json")
    "{ broken" | save $bad_path
    let bad_res = (try {
        read-marketplace-json $bad_path
    } catch {
        {status: "threw", data: null, file: null}
    })
    if $bad_res.status != "invalid" {
        print $"(ansi red_bold)❌ marketplace-json self-test: malformed marketplace.json not flagged as invalid \(got status: ($bad_res.status)\)(ansi reset)"
        $failed = true
    }
    if $bad_res.file != $bad_path {
        print $"(ansi red_bold)❌ marketplace-json self-test: malformed-manifest result does not name the offending file \(got: ($bad_res.file)\)(ansi reset)"
        $failed = true
    }
    rm -rf $bad_root

    # Case 3 (must-flag, RED until implemented): valid JSON that parses to a
    # non-record top level (a JSON list) must also be "invalid" — mirrors
    # claude-skills-314's non-record-manifest fix for plugin.json.
    let list_root = (mktemp -d)
    mkdir ($list_root | path join ".claude-plugin")
    let list_path = ($list_root | path join ".claude-plugin" "marketplace.json")
    "[1, 2, 3]" | save $list_path
    let list_res = (try {
        read-marketplace-json $list_path
    } catch {
        {status: "threw", data: null, file: $list_path}
    })
    if $list_res.status != "invalid" {
        print $"(ansi red_bold)❌ marketplace-json self-test: non-record marketplace.json \(JSON list\) not flagged as invalid \(got status: ($list_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $list_root

    # Case 4 (must-flag, RED until implemented): a well-formed record with
    # no `plugins` key at all — mirrors claude-skills-316's missing-
    # required-field fix, but for `plugins` instead of `name`.
    let no_key_root = (mktemp -d)
    mkdir ($no_key_root | path join ".claude-plugin")
    let no_key_path = ($no_key_root | path join ".claude-plugin" "marketplace.json")
    {name: "test-marketplace"} | to json | save $no_key_path
    let no_key_res = (try {
        read-marketplace-json $no_key_path
    } catch {
        {status: "threw", data: null, file: $no_key_path}
    })
    if $no_key_res.status != "missing_required_field" {
        print $"(ansi red_bold)❌ marketplace-json self-test: marketplace.json with no plugins key not flagged \(got status: ($no_key_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $no_key_root

    # Case 5 (must-flag, RED until implemented): `plugins: null` — distinct
    # from Case 4 only in that the key IS present — must fold into the same
    # "missing_required_field" status. See the doc comment above this
    # function for why: without this, "Total skills: 0" prints silently,
    # exit 0, with no indication the corpus root was broken.
    let null_root = (mktemp -d)
    mkdir ($null_root | path join ".claude-plugin")
    let null_path = ($null_root | path join ".claude-plugin" "marketplace.json")
    {name: "test-marketplace", plugins: null} | to json | save $null_path
    let null_res = (try {
        read-marketplace-json $null_path
    } catch {
        {status: "threw", data: null, file: $null_path}
    })
    if $null_res.status != "missing_required_field" {
        print $"(ansi red_bold)❌ marketplace-json self-test: marketplace.json with plugins: null not flagged \(got status: ($null_res.status)\)(ansi reset)"
        $failed = true
    }
    rm -rf $null_root

    # Case 6 (must-flag, RED until implemented — read-marketplace-json does
    # not exist yet, so even the real corpus manifest reports "threw"): the
    # real shipped marketplace.json parses clean — status "ok", with an
    # actual non-empty plugins list, not "invalid" or
    # "missing_required_field". `get -o` throughout (never a bare
    # `.plugins` dot-path) so a still-null `data` on a failing
    # implementation reports a clean assertion failure instead of an
    # unrelated crash inside this self-test itself.
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let real_path = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let real_res = (try {
        read-marketplace-json $real_path
    } catch {
        {status: "threw", data: null, file: $real_path}
    })
    if $real_res.status != "ok" {
        print $"(ansi red_bold)❌ marketplace-json self-test: real marketplace.json wrongly flagged \(got status: ($real_res.status)\)(ansi reset)"
        $failed = true
    } else {
        let plugins_val = ($real_res.data | get -o plugins)
        # A JSON array of objects describes as "table", not "list<record<...
        # >>" (verified empirically, nu 0.113.1: [{a:1}] | describe => table,
        # [1,2,3] | describe => list<int>) — a table IS a list of records in
        # nushell, so both prefixes count as "a list".
        let plugins_type = ($plugins_val | describe)
        if not (($plugins_type | str starts-with "list") or ($plugins_type | str starts-with "table")) {
            print $"(ansi red_bold)❌ marketplace-json self-test: real marketplace.json parsed content has no plugins list \(got: ($plugins_type)\)(ansi reset)"
            $failed = true
        } else if ($plugins_val | length) == 0 {
            print $"(ansi red_bold)❌ marketplace-json self-test: real marketplace.json parsed to an empty plugins list(ansi reset)"
            $failed = true
        }
    }

    # Case 7 (must-flag, RED until implemented): `main` itself must act on
    # a bad status by halting with a readable message that names the file —
    # never main's current behaviour, an unguarded `open` whose raw nushell
    # parser trace reaches stderr with zero explanation on stdout. This is a
    # full subprocess run of the script, not a call against
    # read-marketplace-json directly: whether to halt-with-message vs.
    # report-and-continue is main's decision, and no unit call against the
    # helper alone can pin it — only running main can. main must also NOT
    # continue into Pass 1: "Total skills" must never print, since any
    # scoring emitted past a broken corpus root is meaningless, and the run
    # must exit non-zero so CI catches it.
    let harness_root = (mktemp -d)
    mkdir ($harness_root | path join ".claude-plugin")
    "{ broken" | save ($harness_root | path join ".claude-plugin" "marketplace.json")
    let script_path = ($repo_root | path join "test" "validate-skills-quality.nu")
    let run_res = (do { cd $harness_root; ^git init -q out+err> /dev/null; ^nu $script_path } | complete)
    if ($run_res.stderr | str contains "nu::shell::") {
        print $"(ansi red_bold)❌ marketplace-json self-test: main still leaks a raw nushell parser trace to stderr on malformed marketplace.json(ansi reset)"
        $failed = true
    }
    if not ($run_res.stdout | str contains "marketplace.json") {
        print $"(ansi red_bold)❌ marketplace-json self-test: main's halt message does not name marketplace.json \(stdout: ($run_res.stdout)\)(ansi reset)"
        $failed = true
    }
    if ($run_res.stdout | str contains "Total skills") {
        print $"(ansi red_bold)❌ marketplace-json self-test: main continued past a malformed marketplace.json and printed a skills total(ansi reset)"
        $failed = true
    }
    if $run_res.exit_code == 0 {
        print $"(ansi red_bold)❌ marketplace-json self-test: main exited 0 on a malformed marketplace.json — a broken corpus root must fail the run(ansi reset)"
        $failed = true
    }
    rm -rf $harness_root

    if not $failed {
        print $"(ansi green_bold)✅ Marketplace-json self-test passed \(7 cases\)(ansi reset)"
    }
    $failed
}

# claude-skills-315: guard around the corpus-root marketplace.json read.
# Mirrors read-plugin-json's status contract (ok | invalid | missing |
# missing_required_field), checking for `plugins` instead of `name` — the
# field main's Pass 1 loop (`for plugin in $marketplace.plugins`) depends on.
# A missing or null `plugins` key both fold into "missing_required_field"
# (get -o returns null for either), matching how read-plugin-json treats a
# missing `name`. Deliberately does not check `plugins`' type when present —
# see the doc comment on run-marketplace-json-self-test for why that's out
# of scope here.
def read-marketplace-json [path: string]: nothing -> record {
    if not ($path | path exists) {
        {status: "missing", data: null, file: $path}
    } else {
        try {
            let parsed = (open $path)
            if ($parsed | describe | str starts-with "record") {
                if ($parsed | get -o plugins) == null {
                    {status: "missing_required_field", data: null, file: $path}
                } else {
                    {status: "ok", data: $parsed, file: $path}
                }
            } else {
                {status: "invalid", data: null, file: $path}
            }
        } catch {
            {status: "invalid", data: null, file: $path}
        }
    }
}

def main [--update-baseline, --self-test] {
    if $self_test {
        # All suites always execute; aggregate before exiting so a failure in
        # an earlier one cannot mask fixtures in a later one.
        let skills_failed = (run-skills-self-test)
        let baseline_failed = (run-baseline-self-test)
        let checks_failed = (run-check-fixes-self-test)
        let duplicate_failed = (run-duplicate-self-test)
        let vocab_failed = (run-vocab-self-test)
        let pass2_links_failed = (run-pass2-links-self-test)
        let orphans_failed = (run-orphans-self-test)
        let safe_read_ref_failed = (run-safe-read-ref-self-test)
        let fm_schema_failed = (run-frontmatter-schema-self-test)
        let accumulator_failed = (run-accumulator-self-test)
        let pass2_eval_failed = (run-pass2-eval-self-test)
        let anti_fab_failed = (run-anti-fab-self-test)
        let braced_claude_failed = (run-braced-claude-self-test)
        let redundant_when_to_use_failed = (run-redundant-when-to-use-self-test)
        let output_style_failed = (run-output-style-self-test)
        let root_manifest_failed = (run-root-manifest-self-test)
        let invalid_manifest_failed = (run-invalid-manifest-self-test)
        let non_record_manifest_failed = (run-non-record-manifest-self-test)
        let missing_field_manifest_failed = (run-missing-field-manifest-self-test)
        let marketplace_json_failed = (run-marketplace-json-self-test)
        if $skills_failed or $baseline_failed or $checks_failed or $duplicate_failed or $vocab_failed or $pass2_links_failed or $orphans_failed or $safe_read_ref_failed or $fm_schema_failed or $accumulator_failed or $pass2_eval_failed or $anti_fab_failed or $braced_claude_failed or $redundant_when_to_use_failed or $output_style_failed or $root_manifest_failed or $invalid_manifest_failed or $non_record_manifest_failed or $missing_field_manifest_failed or $marketplace_json_failed { exit 1 }
        exit 0
    }

    print "Validating skill quality across all plugins..."
    print ""

    let repo_root = (git rev-parse --show-toplevel | str trim)
    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let marketplace_read = (read-marketplace-json $marketplace_path)
    if $marketplace_read.status != "ok" {
        print $"(ansi red_bold)❌ Cannot validate: ($marketplace_path) is unusable \(status: ($marketplace_read.status)\)(ansi reset)"
        exit 1
    }
    let marketplace = $marketplace_read.data

    let baseline_path = ($repo_root | path join "test" "quality-baseline.json")
    let baseline = if ($baseline_path | path exists) {
        open $baseline_path | get allowed_failures
    } else {
        []
    }
    let baseline_errors = (validate-baseline-entries $baseline)
    if ($baseline_errors | is-not-empty) {
        print $"(ansi red_bold)❌ ($baseline_errors | length) invalid baseline entries in ($baseline_path):(ansi reset)"
        for e in $baseline_errors { print $"  ($e)" }
        print "Every allowed_failures entry must be a record: {key, class (BUG|DEBT|CHECK_DEFECT|ACCEPTED), issue, first_seen, detail_count}."
        exit 1
    }
    let baseline_keys = ($baseline | each {|e| $e.key})

    # Pass 1: registry of local plugins -> skill dir names + command names,
    # used to resolve /plugin:skill invocations found in skill content.
    # skill_dir_map is a parallel flat list of {skill, dir, plugin} used to
    # existence-check cross-skill references/ pointers (see
    # cross-skill-qualified) — the plugin field lets that lookup be
    # namespace-aware when a skill name collides across two local plugins.
    mut registry = []
    mut skill_dir_map = []
    # failing_keys/failing_counts/surface_results are declared here, ahead of
    # Pass 1, rather than at their previous later declaration points
    # (claude-skills-313): a malformed plugin.json can now be caught and
    # reported as a finding from INSIDE Pass 1's registry-building loop
    # below, before either of those later points existed. Declaring the
    # accumulators once, up front, lets every pass — Pass 1's manifest read,
    # the skills-scoring loop, and the agents/commands/hooks/output-styles
    # loop further down — append into the same three lists rather than
    # threading a parallel accumulator that would need merging in later.
    mut failing_keys = []
    mut failing_counts = []
    mut surface_results = []
    for plugin in $marketplace.plugins {
        let source_type = ($plugin.source | describe)
        if ($source_type | str starts-with "record") { continue }
        if ($plugin.name == "all-skills") { continue }

        let plugin_dir = ($repo_root | path join ($plugin.source | str replace --regex '^\./' ''))
        let plugin_json_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")
        let plugin_read = (read-plugin-json $plugin_json_path)
        if $plugin_read.status == "missing" { continue }
        if $plugin_read.status == "invalid" {
            # A malformed manifest can't be registered — same shape as the
            # hooks.json bad_wrapper finding below, keyed off the manifest
            # itself. $plugin.name (from marketplace.json) rather than
            # $plugin_json.name, since the latter is unavailable when the
            # parse itself is what failed.
            let key_base = $"($plugin.name)/.claude-plugin/plugin.json"
            $failing_keys = ($failing_keys | append $"($key_base):invalid_json")
            $surface_results = ($surface_results | append {
                plugin: $plugin.name, kind: "plugin-json", file: "plugin.json", failed: "invalid_json"
                details: ""
            })
            continue
        }
        if $plugin_read.status == "missing_required_field" {
            # claude-skills-316: valid JSON, valid record, but missing the
            # one field this loop dereferences unguarded ($plugin_json.name,
            # three sites below). Same shape as "invalid" above — a distinct
            # `failed` value so the finding doesn't misreport a schema gap
            # as a parse failure.
            let key_base = $"($plugin.name)/.claude-plugin/plugin.json"
            $failing_keys = ($failing_keys | append $"($key_base):missing_required_field")
            $surface_results = ($surface_results | append {
                plugin: $plugin.name, kind: "plugin-json", file: "plugin.json", failed: "missing_required_field"
                details: ""
            })
            continue
        }

        let plugin_json = $plugin_read.data
        let skill_paths = ($plugin_json | get -o skills | default [])
        let skill_names = ($skill_paths | each {|p|
            $p | str replace --regex '^\./' '' | path basename
        })
        for p in $skill_paths {
            let full_dir = ($plugin_dir | path join ($p | str replace --regex '^\./' ''))
            $skill_dir_map = ($skill_dir_map | append {skill: ($full_dir | path basename), dir: $full_dir, plugin: $plugin_json.name})
        }
        let commands_dir = ($plugin_dir | path join "commands")
        let command_names = if ($commands_dir | path exists) {
            glob ($commands_dir | path join "*.md") | each {|f|
                $f | path basename | str replace ".md" ""
            }
        } else {
            []
        }
        # Upstream-shipped commands for skill-only local mirrors (see
        # UPSTREAM_COMMANDS) join invocables — but never `skills`, since an
        # agent's skills: frontmatter cannot preload a command.
        let upstream_cmds = ($UPSTREAM_COMMANDS
            | where ns == $plugin_json.name
            | each {|u| $u.commands} | flatten)
        $registry = ($registry | append {
            name: $plugin_json.name
            dir: $plugin_dir
            invocables: ($skill_names | append $command_names | append $upstream_cmds)
            skills: $skill_names
        })
    }

    mut results = []
    mut total_skills = 0
    mut total_pass = 0

    for plugin in $registry {
        let plugin_dir = $plugin.dir
        let plugin_name = $plugin.name
        # $registry only contains plugins that already parsed clean in Pass
        # 1 above (a malformed manifest is reported there and never makes it
        # into $registry), so this read-plugin-json call should always
        # return "ok" in practice. It is still guarded rather than a bare
        # `open`, matching claude-skills-313's four named call sites — a
        # defense-in-depth guard costs nothing and this function must never
        # throw regardless of what Pass 1 already checked.
        let plugin_read = (read-plugin-json ($plugin_dir | path join ".claude-plugin" "plugin.json"))
        if $plugin_read.status != "ok" { continue }
        let plugin_json = $plugin_read.data
        let skills = ($plugin_json | get -o skills | default [])

        # Check 17's sole acceptance path (claude-skills-184, C2): a prose
        # version pin must be recorded in the structured sources.toml. The
        # sources.md "X (current)" annotation path was retired once every
        # plugin had a conforming sources.toml (claude-skills-180) — toml is
        # now the single source of truth for pinned versions.
        let sources_toml_path = ($plugin_dir | path join "skills" "sources.toml")
        let toml_versions = if ($sources_toml_path | path exists) {
            try {
                open $sources_toml_path
                | get -o sources | default []
                | each {|s| $s.current_version? | default null }
                | compact
            } catch { [] }
        } else {
            []
        }

        for skill_path in $skills {
            let skill_dir = ($plugin_dir | path join ($skill_path | str replace --regex '^\./' ''))
            let skill_md_path = ($skill_dir | path join "SKILL.md")

            if not ($skill_md_path | path exists) {
                continue
            }

            $total_skills = $total_skills + 1

            let dir_name = ($skill_dir | path basename)
            let content = (open --raw $skill_md_path)
            let stripped = (strip-fences $content)
            let all_lines = ($content | lines)
            let line_count = ($all_lines | length)

            # Parse YAML frontmatter (between --- markers)
            let fm_lines = if ($all_lines | first | default "" | str trim) == "---" {
                let rest = ($all_lines | skip 1)
                let end_matches = ($rest | enumerate | where {|item| ($item.item | str trim) == "---"})
                if ($end_matches | is-not-empty) {
                    let end_idx = ($end_matches | first | get index)
                    $rest | first $end_idx
                } else {
                    []
                }
            } else {
                []
            }

            # Extract name field
            let name_lines = ($fm_lines | where {|line| $line | str starts-with "name:"})
            let name = if ($name_lines | is-not-empty) {
                $name_lines | first | str replace "name:" "" | str trim | str trim -c '"' | str trim -c "'"
            } else {
                ""
            }

            # Extract description field
            let desc_lines = ($fm_lines | where {|line| $line | str starts-with "description:"})
            let description = if ($desc_lines | is-not-empty) {
                $desc_lines | first | str replace "description:" "" | str trim | str trim -c '"' | str trim -c "'"
            } else {
                ""
            }

            mut failed = []

            # 1. Description length: non-empty, ≤1024 chars
            let desc_len = ($description | str length)
            if not ($desc_len > 0 and $desc_len <= 1024) { $failed = ($failed | append "desc") }

            # 2. Description has "Use when"
            let desc_lower = ($description | str downcase)
            if not ($desc_lower | str contains "use when") { $failed = ($failed | append "use_when") }

            # 3. Description third person (no "I can", "You can")
            let has_first = ($description | str contains "I can")
            let has_second = ($description | str contains "You can")
            let has_first_will = ($description | str contains "I will")
            let has_second_will = ($description | str contains "You will")
            if ($has_first or $has_second or $has_first_will or $has_second_will) {
                $failed = ($failed | append "third_person")
            }

            # 4. Name kebab-case
            let kebab_matches = ($name | parse --regex '^[a-z0-9]+(-[a-z0-9]+)*$')
            if ($kebab_matches | is-empty) { $failed = ($failed | append "kebab") }

            # 5. Name ≤64 chars
            let name_len = ($name | str length)
            if not ($name_len <= 64 and $name_len > 0) { $failed = ($failed | append "name_len") }

            # 6. No reserved words (exact-match only — see is-reserved-name)
            if (is-reserved-name $name) { $failed = ($failed | append "reserved") }

            # 7. SKILL.md ≤500 lines
            if $line_count > 500 { $failed = ($failed | append "lines") }

            # 18. Frontmatter keys are real (claude-skills-175). Answers "is
            # this key in the schema", not "does this marketplace permit it" —
            # `allowed-tools` is upstream-valid and separately rejected by
            # check 2. Commands share the skill schema (they merged upstream).
            let fm_unknown = (unknown-frontmatter-keys $fm_lines $SKILL_FM_KEYS)
            if ($fm_unknown | is-not-empty) { $failed = ($failed | append "fm_schema") }

            # Reference files, read once for checks 8, 9, and 16.
            let refs_dir = ($skill_dir | path join "references")
            let ref_files = if ($refs_dir | path exists) {
                glob ($refs_dir | path join "*.md")
            } else {
                []
            }
            # 19. Reference files are safe to read (claude-skills-222). See
            # safe-read-ref: a broken path or unreadable-permissions file is
            # reported as a finding instead of aborting the run, and a path
            # resolving outside the repo — whether via a symlinked leaf or a
            # symlinked ancestor directory — is quarantined (never read) and
            # reported rather than silently scanned into the corpus.
            let ref_reads = ($ref_files | each {|f| safe-read-ref $f $repo_root})
            let refs = ($ref_reads | each {|r| {name: $r.name, content: $r.content}})
            let unsafe_refs = ($ref_reads | where {|r| $r.unsafe})
            if ($unsafe_refs | length) > 0 { $failed = ($failed | append "ref_unsafe") }

            # 20. Redundant "When to Use" section (claude-skills-296): a body
            # "## When to Use"/"## When to Activate" H2 section that is only
            # a restated trigger-bullet list duplicates the description,
            # which is the sole text Claude sees at discovery time. Not a
            # DETAIL_CHECK — a ratchet on "how many redundant sections" buys
            # nothing per skill; this is a single boolean per file.
            if (has-redundant-when-to-use-section $content) {
                $failed = ($failed | append "redundant_when_to_use")
            }

            # 8. Has examples: code fence / example header in SKILL.md, or a
            # code fence in a reference file SKILL.md mentions (see has-examples)
            if not (has-examples $content $refs) { $failed = ($failed | append "examples") }

            # 9. Reference depth (no nested references; code examples don't count).
            # A references/ token qualified as pointing at another skill (see
            # cross-skill-qualified above) is not a same-skill nesting violation.
            let nested = ($refs | where {|r|
                let siblings = ($refs | where name != $r.name | get name)
                has-unqualified-references-token (strip-fences $r.content) $dir_name $skill_dir_map ($registry | get name) $siblings
            })
            if ($nested | length) > 0 { $failed = ($failed | append "ref_depth") }

            # 10. Anti-fabrication present — SKILL.md ONLY, deliberately
            # (claude-skills-202, option b of its AC). A prior version of
            # this check scanned SKILL.md's reference files too, reasoning
            # that widening an OR-across-content match could only make a
            # previously-failing skill pass, never fail a passing one — true
            # by construction, but it missed the check's actual job. A Gate
            # 3 fixture proved it: a SKILL.md with ZERO anti-fabrication
            # content, plus a mentioned reference file containing nothing
            # but the bare word "fabrication", scored full marks under the
            # wider scan. References became a way to SATISFY the check
            # rather than a surface it scrutinizes — the inverse of
            # claude-skills-202's actual concern (real, unverified claims
            # hiding in references). Reverted; reference-file anti-fab risk
            # stays out of scope until claude-skills-141 gives it real
            # per-file scrutiny instead of a corpus-wide keyword OR. See
            # has-anti-fab-evidence for what "present" means and its limits
            # even at SKILL.md scope.
            if not (has-anti-fab-evidence $content) {
                $failed = ($failed | append "anti_fab")
            }

            # 11. No braced CLAUDE_* env var in the SKILL.md body
            # (claude-skills-205). Frontmatter is exempt — the harness
            # expands the braced form there (e.g. a hooks: command field);
            # the body form is a bug that bakes one machine's absolute
            # cache path into prose. See has-braced-claude-var /
            # strip-frontmatter.
            if (has-braced-claude-var (strip-frontmatter $content)) {
                $failed = ($failed | append "braced_claude")
            }

            # 12. No 'allowed-tools' in frontmatter
            let has_allowed_tools = ($fm_lines | any {|line| ($line | str trim) | str starts-with "allowed-tools:"})
            if $has_allowed_tools { $failed = ($failed | append "allowed_tools") }

            # 13. Frontmatter name matches directory name (Agent Skills Specification)
            if $name != $dir_name { $failed = ($failed | append "name_dir") }

            # 14. Link integrity: asset paths mentioned in SKILL.md prose must exist.
            # references/ and agents/ are skill-spec dirs — their links must ALWAYS
            # resolve (a git checkout has no empty dirs, so a dir-exists guard would
            # make results environment-dependent). scripts/ templates/ hooks/ are
            # only validated when the dir exists inside the skill, so mentions of
            # other repos' scripts/ etc. are not false positives.
            # Leading boundary so a longer cross-plugin path like
            # plugins/core/skills/bees/agents/foo.md does not match on its
            # agents/foo.md substring. Extraction is shared with the Pass-2
            # agents/commands links check via extract-link-path-tokens.
            let link_paths = (extract-link-path-tokens $stripped)
            let broken_links = ($link_paths | where {|p|
                let top = ($p | split row "/" | first)
                let dir_gated = $top in ["scripts" "templates" "hooks"]
                let in_scope = (not $dir_gated) or (($skill_dir | path join $top) | path exists)
                let missing = (not (($skill_dir | path join $p) | path exists))
                # A references/ path qualified as pointing at another skill
                # (see cross-skill-qualified above) resolves against that
                # skill's own tree, not $skill_dir — not a broken link here.
                let cross_skill = ($top == "references") and (cross-skill-qualified (preceding-line $stripped $p) $dir_name $p $skill_dir_map ($registry | get name))
                $in_scope and $missing and (not $cross_skill)
            })
            if ($broken_links | is-not-empty) { $failed = ($failed | append "links") }

            # 15. No orphan files: every references/*.md and agents/*.md must be
            # mentioned at least once from SKILL.md, by a citation that RESOLVES
            # — i.e. `references/x.md`, not a bare `x.md`.
            #
            # A bare basename used to satisfy this check while pointing at
            # nothing: from the skill dir, `group-by-risk.md` does not exist.
            # That made the suite reward an unresolvable spelling — check 14
            # only parses dir-prefixed paths, so the bare form was invisible to
            # it while still clearing check 15 (claude-skills-164, PR 162).
            #
            # Scope note: this check covers references/ and agents/ only.
            # templates/ and scripts/ files are NOT policed here — expanding to
            # them was measured and rejected on two counts. Nine such files are
            # never mentioned in their SKILL.md at all and would become new
            # findings. And a per-file rule misreads collective citation: the
            # container skill has 11 `templates/<version>/commands.md` files but
            # documents them as a family, naming only two versions explicitly,
            # so expanding per file flags the other nine despite the set being
            # legitimately documented.
            let agents_dir = ($skill_dir | path join "agents")
            let agent_files = if ($agents_dir | path exists) {
                glob ($agents_dir | path join "*.md")
            } else {
                []
            }
            let orphans = (find-orphan-files $content ($ref_files | append $agent_files))
            if ($orphans | is-not-empty) { $failed = ($failed | append "orphans") }

            # 16. Cross-skill invocations resolve: every /plugin:skill token in
            # SKILL.md or references must name a real skill or command of a local
            # plugin. Unknown (external) plugin namespaces are skipped.
            let invocation_content = ($refs | each {|r| $r.content} | prepend $content | str join "\n")
            let bad_invocations = (find-bad-invocations $invocation_content $registry)
            if ($bad_invocations | is-not-empty) { $failed = ($failed | append "invocations") }

            # 17. Version pins agree with sources.toml: a "Current stable: X" /
            # "Currently at version X" claim must match a current_version
            # recorded in the plugin's sources.toml. Skills without a pin pass
            # (soft check).
            let stale_pins = (find-stale-version-pins $content $toml_versions)
            if ($stale_pins | is-not-empty) { $failed = ($failed | append "version_pin") }

            # Classify failures against the baseline
            let keys = ($failed | each {|c| $"($plugin_name)/($dir_name):($c)"})
            $failing_keys = ($failing_keys | append $keys)
            let new_failures = ($keys | where {|k| $k not-in $baseline_keys})

            # Per-finding counts for the detail_count ratchet: a waiver covers
            # the recorded count, not further growth of the same check.
            $failing_counts = (accumulate-detail-counts $failing_counts $"($plugin_name)/($dir_name)" $failed [
                {check: "lines", count: $line_count}
                {check: "links", count: ($broken_links | length)}
                {check: "orphans", count: ($orphans | length)}
                {check: "invocations", count: ($bad_invocations | length)}
                {check: "version_pin", count: ($stale_pins | length)}
                {check: "ref_depth", count: ($nested | length)}
                {check: "fm_schema", count: ($fm_unknown | length)}
                {check: "ref_unsafe", count: ($unsafe_refs | length)}
            ])

            let check_count = 20
            let score = $check_count - ($failed | length)

            $results = ($results | append {
                skill: $dir_name
                plugin: $plugin_name
                lines: $"($line_count)/500"
                score: $"($score)/($check_count)"
                failed: ($failed | str join " ")
                new: ($new_failures | each {|k| $k | split row ":" | last} | str join " ")
                details: ($broken_links | append $bad_invocations | append $stale_pins | append ($orphans | each {|f| $f | path basename}) | append ($fm_unknown | each {|k| $"frontmatter:($k)"}) | append ($nested | each {|r| $"nested:($r.name)"}) | append ($unsafe_refs | each {|r| $"($r.reason):($r.name)"}) | str join " ")
            })

            if ($failed | is-empty) {
                $total_pass = $total_pass + 1
            }
        }
    }

    # Pass 2: agents/*.md, commands/*.md, hooks/hooks.json — the surfaces a
    # `claude plugin validate` pass does not cover (bogus hook event names,
    # agents missing a name, unresolved /plugin:skill invocations, and — as
    # of the pointer-validation-gap plan (claude-skills-164) — broken
    # references/templates/scripts/agents/hooks path citations). Reuses the
    # Pass-1 registry, find-bad-invocations (check 16's logic), and
    # resolve-pass2-path (check 14's four-base resolver, generalized for
    # files with no single owning skill dir) rather than second resolvers.
    # Findings feed the same ratchet baseline as the per-skill checks above.
    # Failure-key scheme: `<plugin>/agents/<file>:<check>` and
    # `<plugin>/commands/<file>:<check>` — the SAME per-file key shape the
    # existing missing_name/missing_desc/bad_model/bad_invocations checks
    # already use below, extended to `links`. Plugin-level files (all
    # commands, and plugin-level agents) and skill-nested agents both name
    # the citing FILE, not a bare plugin-level bucket, so a failure is always
    # reportable down to one file even though most of these files have no
    # owning skill.
    # NOTE (claude-skills-175, fixed): Pass-2's two DETAIL_CHECKS-listed
    # checks — links and fm_schema — are now wired into the detail_count
    # ratchet via accumulate-detail-counts, same as the per-skill checks in
    # Pass 1. bad_invocations and the skills: frontmatter checks are boolean
    # (not in DETAIL_CHECKS) and correctly carry no count. Previously a
    # Pass-2 waiver on links/fm_schema would have absorbed unlimited later
    # growth of that finding on the same file — the corpus had zero such
    # waivers when the gap was found, so nothing was masked in practice, but
    # the hole was live the moment one was added.
    #
    # (claude-skills-151 Gate 3 finding) The per-file evaluation — every
    # check below, including the accumulate-detail-counts call — now lives
    # in evaluate-agent-file / evaluate-command-file, unit-tested directly
    # by run-pass2-eval-self-test: deleting that call now fails --self-test,
    # not only a live corpus scan. The loops below are a merge step only,
    # via apply-surface-finding. Known residual, corrected after a Gate 3
    # review found the first version of this comment overclaimed: main
    # still unpacks apply-surface-finding's result into three separate
    # `mut` assignments (nushell has no one-statement destructure-assign
    # for `mut`), and deleting only the `failing_counts` line among the
    # three is exactly as invisible as before — see apply-surface-finding's
    # own doc comment. What DID change: the per-file wiring is hermetically
    # tested, and a WHOLE deletion of the merge call is caught by the full
    # run via a baseline stale-key failure.
    let known_models = ["haiku" "sonnet" "opus" "fable" "inherit"]
    let known_hook_events = ["PreToolUse" "PostToolUse" "SessionStart" "SessionEnd" "UserPromptSubmit" "Stop" "SubagentStop" "PreCompact" "Notification"]
    # surface_results is declared once, ahead of Pass 1 (claude-skills-313)
    # — no re-declaration here.

    for plugin in $registry {
        let plugin_dir = $plugin.dir
        let plugin_name = $plugin.name

        # Agents: plugin-level agents/ dir plus any skill-level nested agents/
        # dirs (same file format — cheap to include, so both are in scope).
        # Each entry carries own_dir/dir_name for resolve-pass2-path: a
        # plugin-level agent's own_dir is the plugin dir (dir_name ""); a
        # skill-nested agent's own_dir is its enclosing skill dir (dir_name
        # the skill's directory name). The two globs are disjoint by
        # construction (one is rooted at <plugin>/agents/, the other at
        # <plugin>/skills/*/agents/), so no dedup is needed on append.
        let plugin_level_agents = ($plugin_dir | path join "agents")
        let plugin_agent_entries = if ($plugin_level_agents | path exists) {
            glob ($plugin_level_agents | path join "*.md")
                | each {|f| {file: $f, own_dir: $plugin_dir, dir_name: ""}}
        } else { [] }
        let nested_agent_entries = (glob ($plugin_dir | path join "skills" "*" "agents" "*.md")
            | each {|f|
                let skill_dir = ($f | path dirname | path dirname)
                {file: $f, own_dir: $skill_dir, dir_name: ($skill_dir | path basename)}
            })
        let agent_entries = ($plugin_agent_entries | append $nested_agent_entries)

        # claude-skills-151 Gate 3 finding: evaluation logic (all the checks,
        # including the links/fm_schema detail-count wiring) now lives in
        # evaluate-agent-file, unit-tested directly by run-pass2-eval-self-test
        # against a real fixture file. This loop is the merge step only —
        # apply-surface-finding folds one result into all three accumulators
        # in a single call.
        for entry in $agent_entries {
            let res = (evaluate-agent-file $entry.file $plugin_name $entry.own_dir $entry.dir_name $plugin_dir $registry $skill_dir_map $known_models)
            let acc = (apply-surface-finding $failing_keys $failing_counts $surface_results $res)
            $failing_keys = $acc.failing_keys
            $failing_counts = $acc.failing_counts
            $surface_results = $acc.surface_results
        }

        # Commands: plugin-level commands/ dir only (no nested-skill convention observed).
        let commands_dir = ($plugin_dir | path join "commands")
        let command_files = if ($commands_dir | path exists) {
            glob ($commands_dir | path join "*.md")
        } else { [] }

        # Same shape as the agent loop above — evaluate-command-file owns the
        # checks and the detail-count wiring, this is the merge step only.
        for f in $command_files {
            let res = (evaluate-command-file $f $plugin_name $plugin_dir $registry $skill_dir_map)
            let acc = (apply-surface-finding $failing_keys $failing_counts $surface_results $res)
            $failing_keys = $acc.failing_keys
            $failing_counts = $acc.failing_counts
            $surface_results = $acc.surface_results
        }

        # Output styles (claude-skills-310): plugin-level output-styles/ dir
        # only. Same merge-step shape as agents/commands above — evaluate-
        # output-style-file owns the checks and detail-count wiring.
        let output_styles_dir = ($plugin_dir | path join "output-styles")
        let output_style_files = if ($output_styles_dir | path exists) {
            glob ($output_styles_dir | path join "*.md")
        } else { [] }

        for f in $output_style_files {
            let res = (evaluate-output-style-file $f $plugin_name)
            let acc = (apply-surface-finding $failing_keys $failing_counts $surface_results $res)
            $failing_keys = $acc.failing_keys
            $failing_counts = $acc.failing_counts
            $surface_results = $acc.surface_results
        }

        # A plugin.json `outputStyles` field pointing at a nonexistent path
        # is a boolean finding (not in DETAIL_CHECKS) — one check per plugin,
        # keyed off the plugin.json file itself rather than a specific style.
        # Same defense-in-depth note as the skills-scoring loop above: a
        # malformed manifest is already caught and reported by Pass 1, so
        # $registry only ever holds plugins whose manifest parsed clean —
        # this guard exists so the contract holds regardless, not because
        # this branch is reachable in practice. On "invalid" it skips rather
        # than re-reporting, since Pass 1 already filed that finding once.
        let plugin_read = (read-plugin-json ($plugin_dir | path join ".claude-plugin" "plugin.json"))
        if $plugin_read.status == "ok" {
            let plugin_json = $plugin_read.data
            let bad_paths = (check-output-styles-path $plugin_json $plugin_dir)
            if ($bad_paths | is-not-empty) {
                let key_base = $"($plugin_name)/.claude-plugin/plugin.json"
                $failing_keys = ($failing_keys | append ($bad_paths | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "plugin-json", file: "plugin.json", failed: ($bad_paths | str join " ")
                    details: ""
                })
            }
        }

        # Hooks: plugin-level hooks/hooks.json only.
        let hooks_path = ($plugin_dir | path join "hooks" "hooks.json")
        if ($hooks_path | path exists) {
            mut failed = []
            let parsed = try {
                open $hooks_path
            } catch {
                null
            }
            if $parsed == null {
                $failed = ($failed | append "bad_wrapper")
            } else if (($parsed | get -o hooks) == null) {
                $failed = ($failed | append "bad_wrapper")
            } else {
                let bad_events = ($parsed.hooks | columns | where {|e| $e not-in $known_hook_events})
                if ($bad_events | is-not-empty) { $failed = ($failed | append "bad_event") }
            }

            if ($failed | is-not-empty) {
                let key_base = $"($plugin_name)/hooks/hooks.json"
                $failing_keys = ($failing_keys | append ($failed | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "hooks", file: "hooks.json", failed: ($failed | str join " ")
                    details: ""
                })
            }
        }
    }

    # Root manifest (claude-skills-312): the root .claude-plugin/plugin.json
    # ("all-skills") is excluded from $registry above to avoid double-
    # counting the corpus — that exclusion stays. But it is the only
    # manifest in this repo that sets `outputStyles`, so being outside
    # $registry meant it never ran through check-output-styles-path. This
    # is a one-shot check, not a per-plugin loop iteration — no plugin is
    # named "root-manifest", so that key prefix can't collide with a real
    # plugin's findings. Only the outputStyles-path check applies here;
    # everything else check-output-styles-path's siblings cover (agents/
    # commands/hooks/output-style-file frontmatter) has no root-level
    # equivalent, since the root manifest owns no agents/commands/hooks/
    # output-styles of its own — those live under each real plugin dir.
    let root_bad_paths = (check-root-manifest $repo_root)
    if ($root_bad_paths | is-not-empty) {
        let key_base = "root-manifest/.claude-plugin/plugin.json"
        $failing_keys = ($failing_keys | append ($root_bad_paths | each {|c| $"($key_base):($c)"}))
        $surface_results = ($surface_results | append {
            plugin: "root-manifest", kind: "plugin-json", file: "plugin.json", failed: ($root_bad_paths | str join " ")
            details: ""
        })
    }

    # Pass 3: corpus-wide duplicate-block check (claude-skills-124). Corpus is
    # every git-tracked .md/.sh file under plugins/ plus the root CLAUDE.md.
    # Findings are grouped per file SET and keyed dupe/<hash>:duplicate_block
    # (see dupe-key), feeding the same ratchet baseline as the per-skill
    # checks — detail_count is the group's shared-window count.
    let corpus_paths = (git -C $repo_root ls-files -- 'plugins/**/*.md' 'plugins/**/*.sh' 'CLAUDE.md' | lines | where {|p| $p | is-not-empty})
    # A tracked file deleted from the working tree but not yet committed is
    # skipped rather than opened — opening it aborted the whole run with a
    # raw "File not found" trace (claude-skills-155). The skip is announced:
    # a corpus that silently shrinks is how this check would go quiet.
    let corpus_split = (split-corpus-paths ($corpus_paths | each {|p|
        {path: $p, exists: ($repo_root | path join $p | path exists)}
    }))
    for w in $corpus_split.warnings { print $"(ansi yellow)($w)(ansi reset)" }
    let corpus = ($corpus_split.present | each {|p| {path: $p, content: (open --raw ($repo_root | path join $p))}})
    let satellites = (core-list-satellites ($repo_root | path join "test" "validate-core-list.nu"))
    let dupe_groups = (find-duplicate-groups $corpus
        | where {|g| not (dupe-exempt $g.files $satellites)}
        | each {|g| $g | insert key (dupe-key $g.files)}
        | sort-by key)
    # claude-skills-151: routed through accumulate-findings, whose value is
    # unit-tested directly (run-accumulator-self-test), rather than a
    # hand-rolled loop appending to both accumulators inline. Known residual
    # (Gate 3 finding on this PR): the two unpack lines right below are
    # STILL exactly as half-deletable as the original inline loop was —
    # deleting only the `$failing_counts = $dupe_acc.failing_counts` line
    # reproduces claude-skills-151 with both --self-test and the full run
    # green. The shape was relocated here from the loop body, not removed.
    # See accumulate-detail-counts's doc comment above for what a whole
    # call-site deletion DOES catch (a full-run stale-key failure) versus
    # what a half delete still doesn't (nothing).
    let dupe_acc = (accumulate-findings $failing_keys $failing_counts ($dupe_groups | each {|g| {key: $g.key, count: $g.windows}}))
    $failing_keys = $dupe_acc.failing_keys
    $failing_counts = $dupe_acc.failing_counts

    # Pass 4: syntax-vs-usage vocabulary cross-check (claude-skills-141).
    # For each format this repo both documents and contains, compare the
    # DOCUMENTED token vocabulary (the documenting skill's SKILL.md +
    # references/*.md, prose and tables included) against the REAL
    # vocabulary in this repo's instances. This is a tripwire, not a net:
    # real vocabularies are tiny (1 command token, 1 hook event, 5 agent
    # keys), so it effectively asks "does the doc mention ANY token reality
    # uses, and does it avoid foreign-family syntax" — exactly the observed
    # defect class (the pre-#134 claude-commands SKILL.md documented
    # fabricated Handlebars {{...}} and never mentioned $ARGUMENTS). Key
    # shape syntax/<format>:vocab_disjoint; detail_count is the size of the
    # disjoint documented set. An empty DOC vocabulary is a hard error
    # (extractor canary — see check-vocab-disjoint); an empty REAL
    # vocabulary stays silent. Real globs use ** deliberately:
    # plugins/*/commands/ matches only 9 of the 25 command files.
    let doc_skills_root = ($repo_root | path join "plugins" "tools" "claude-code" "skills")
    let command_files = (glob ($repo_root | path join "plugins" "**" "commands" "*.md"))
    let agent_vocab_files = (glob ($repo_root | path join "plugins" "**" "agents" "*.md"))
    let hook_files = (glob ($repo_root | path join "plugins" "**" "hooks" "hooks.json"))
    # Real-side glob canary BEFORE the vocabulary comparison: an
    # under-matching or mispointed glob must fail on its file count, not
    # slip through as "empty real → silent" (see VOCAB_REAL_FLOORS).
    let floor_errors = (vocab-real-floor-errors [
        {format: "commands", matched: ($command_files | length)}
        {format: "agents", matched: ($agent_vocab_files | length)}
        {format: "hooks", matched: ($hook_files | length)}
    ])
    if ($floor_errors | is-not-empty) {
        print $"(ansi red_bold)❌ syntax-vs-usage: real-instance file count below floor:(ansi reset)"
        for e in $floor_errors { print $"  ($e.format): matched ($e.matched) file\(s\), floor ($e.floor)" }
        print "The glob plumbing broke (wrong directory or an under-matching pattern), or instances were genuinely removed — in that case lower VOCAB_REAL_FLOORS to the new measured count. This is a hard error, not a baselineable finding."
        exit 1
    }
    let command_real = ($command_files
        | each {|f| extract-command-real-vocab (open --raw $f)} | flatten | uniq)
    let agent_real = ($agent_vocab_files
        | each {|f| extract-agent-real-keys (open --raw $f)} | flatten | uniq)
    let hook_real = ($hook_files
        | each {|f|
            let parsed = (try { open $f } catch { null })
            if $parsed == null { [] } else { extract-hook-real-events $parsed }
        } | flatten | uniq)
    let vocab_formats = [
        {format: "commands", doc: (extract-command-doc-vocab (vocab-doc-content ($doc_skills_root | path join "claude-commands"))), real: $command_real, foreign: ['{{}}']}
        {format: "agents", doc: (extract-agent-doc-keys (vocab-doc-content ($doc_skills_root | path join "claude-agents"))), real: $agent_real, foreign: []}
        {format: "hooks", doc: (extract-hook-doc-events (vocab-doc-content ($doc_skills_root | path join "claude-hooks"))), real: $hook_real, foreign: []}
    ]
    # claude-skills-151: collected functionally (no per-iteration mutation)
    # then folded into the ratchet with ONE accumulate-findings call after
    # the loop — the same shape as Pass 3's dupe_groups, and for the same
    # reason: a fixed-size call site regardless of how many formats fire,
    # instead of a hand-rolled append pair repeated once per firing format.
    # Same known residual as Pass 3 (see the comment at dupe_acc above):
    # this does not make the two unpack lines below any less half-deletable.
    let vocab_evals = ($vocab_formats | each {|vf| {vf: $vf, res: (check-vocab-disjoint $vf.doc $vf.real $vf.foreign)}})
    let vocab_doc_empty = ($vocab_evals | where {|e| $e.res.status == "doc_empty"} | each {|e| $e.vf.format})
    let vocab_fired = ($vocab_evals | where {|e| $e.res.status == "fires"} | each {|e| {
        format: $e.vf.format
        key: $"syntax/($e.vf.format):vocab_disjoint"
        doc: $e.vf.doc
        real: $e.vf.real
        count: ($e.res.disjoint | length)
    }})
    let vocab_findings = ($vocab_fired | each {|f| {format: $f.format, key: $f.key, doc: $f.doc, real: $f.real}})
    let vocab_acc = (accumulate-findings $failing_keys $failing_counts ($vocab_fired | each {|f| {key: $f.key, count: $f.count}}))
    $failing_keys = $vocab_acc.failing_keys
    $failing_counts = $vocab_acc.failing_counts
    if ($vocab_doc_empty | is-not-empty) {
        print $"(ansi red_bold)❌ syntax-vs-usage: EMPTY documented vocabulary for format\(s\): ($vocab_doc_empty | str join ', ')(ansi reset)"
        print "These skills are known to document tokens, so extracting none means the doc extractor broke (or the doc lost its syntax section). Fix the extractor or the doc — this is a hard error, not a baselineable finding."
        exit 1
    }

    # Accumulation loops are done — rebind as immutable so the closures below
    # can capture them (Nushell closures cannot capture mut variables).
    # vocab_findings is already immutable (claude-skills-151: collected
    # functionally, no longer built with a mut + for loop) so it needs no
    # rebind here.
    let failing_keys = $failing_keys
    let failing_counts = $failing_counts

    if ($results | is-empty) {
        print "No skills found to validate."
        exit 1
    }

    # Print scorecard
    print ($results | table --expand --width 220)
    print ""
    print $"Total skills: ($total_skills)"
    print $"Perfect score: ($total_pass)/($total_skills)"

    print ""
    if ($surface_results | is-empty) {
        print "agents/commands/hooks/output-styles surfaces: all clean"
    } else {
        print $"agents/commands/hooks/output-styles surfaces: ($surface_results | length) finding\(s\)"
        print ($surface_results | table --expand --width 220)
    }

    # Duplicate groups are keyed by an opaque hash, so always print the member
    # paths — a bare dupe/<hash> key in a failure list is not actionable.
    print ""
    if ($dupe_groups | is-empty) {
        print "duplicate blocks: none outside exemptions"
    } else {
        print $"duplicate blocks: ($dupe_groups | length) cross-file group\(s\), window = ($DUPE_WINDOW) normalised lines"
        for g in $dupe_groups {
            print $"  ($g.key) — ($g.windows) shared window\(s\):"
            for f in $g.files { print $"    ($f)" }
        }
    }

    # Vocab findings are keyed by format, so always print both vocabularies —
    # a bare syntax/<format> key in a failure list is not actionable.
    print ""
    if ($vocab_findings | is-empty) {
        print "syntax-vs-usage vocabularies: documented and real overlap for commands/agents/hooks"
    } else {
        print $"syntax-vs-usage: ($vocab_findings | length) format\(s\) documenting disjoint or foreign-family syntax:"
        for v in $vocab_findings {
            print $"  ($v.key) — format '($v.format)'"
            print $"    documented vocabulary: ($v.doc | str join ' ')"
            print $"    real-usage vocabulary: ($v.real | str join ' ')"
        }
    }

    if $update_baseline {
        # Shrink-only: the baseline is a ratchet, never a place to stash new
        # debt. Refuse to add any key that isn't already baselined — the only
        # thing --update-baseline is allowed to do is drop entries that now
        # pass (intersect currently-failing with the existing baseline).
        let new_keys = ($failing_keys | where {|k| $k not-in $baseline_keys} | uniq)
        if ($new_keys | is-not-empty) {
            print ""
            print $"(ansi red_bold)❌ --update-baseline is shrink-only: refusing to add ($new_keys | length) new key\(s\):(ansi reset)"
            for key in $new_keys { print $"  ($key)" }
            print "Fix the skill instead of baselining a new violation. A deliberate net-new debt acknowledgment requires editing test/quality-baseline.json by hand (record shape: key/class/issue/first_seen/detail_count) and stating why in the PR."
            exit 1
        }
        # Filter the record list (preserves class/issue/first_seen) and lower
        # any stale detail_count to the measured value — never raise one.
        let shrunk = ($baseline
            | where {|e| $e.key in $failing_keys}
            | each {|e|
                let current = ($failing_counts | where key == $e.key)
                if (($e | get -o detail_count | describe) == "int") and ($current | is-not-empty) and (($current | first | get count) < $e.detail_count) {
                    $e | update detail_count ($current | first | get count)
                } else {
                    $e
                }
            }
            | sort-by key)
        {
            "_comment": "Ratchet baseline for test/validate-skills-quality.nu. Each allowed_failures entry is a record: key (plugin/skill:check; corpus-wide duplicate groups use dupe/<md5-8 of the sorted member file set>:duplicate_block — the validator prints each group's member paths; syntax-vs-usage vocabulary findings use syntax/<format>:vocab_disjoint for the formats commands/agents/hooks — the validator prints both vocabularies), class (BUG | DEBT | CHECK_DEFECT | ACCEPTED — CHECK_DEFECT means the check itself is defective, entry's issue field names the tracker item for the check fix; ACCEPTED means a reviewed, closed verdict that the finding stays permanently by design rather than outstanding debt, entry's issue field names the tracker item the verdict was decided under — both are excluded from the burn-down total and reported separately so neither exclusion reads as progress), issue (tracker id the waiver is filed under), first_seen (ISO date, or the literal 'migrated' for entries predating the schema), detail_count (integer for detail-producing checks: lines/links/orphans/invocations/version_pin/ref_depth/duplicate_block/vocab_disjoint/fm_schema; null otherwise). Entries are pre-existing failures allowed to keep failing at their recorded count. Do not add entries for new code; fix the skill instead. When a fix lands or a count drops, the validator requires shrinking the baseline. Regenerate: nu test/validate-skills-quality.nu --update-baseline (shrink-only — removes fixed keys and lowers counts; errors instead of adding keys, never raises a count). Known residual: the ratchet bounds the NUMBER of findings per waived check, not their identity, so a same-commit swap of one finding for another of equal size passes."
            allowed_failures: $shrunk
        } | to json --indent 2 | save -f $baseline_path
        print ""
        print $"Baseline updated \(shrink-only\): ($baseline_path) — ($shrunk | length) allowed failures"
        exit 0
    }

    let ratchet = (ratchet-baseline $baseline $failing_keys $failing_counts)

    mut exit_code = 0

    if ($ratchet.hard_failures | is-not-empty) {
        print ""
        print $"FAIL: ($ratchet.hard_failures | length) quality violations not in the baseline:"
        for key in $ratchet.hard_failures { print $"  ($key)" }
        print "Fix the skill (preferred). See the 'details' column for broken links / bad invocations / stale pins / orphans."
        $exit_code = 1
    }

    if ($ratchet.stale_keys | is-not-empty) {
        print ""
        print $"FAIL: ($ratchet.stale_keys | length) baseline entries now pass — remove them to lock in the fix:"
        for key in $ratchet.stale_keys { print $"  ($key)" }
        print "Regenerate with: nu test/validate-skills-quality.nu --update-baseline"
        $exit_code = 1
    }

    if ($ratchet.count_regressions | is-not-empty) {
        print ""
        print $"FAIL: ($ratchet.count_regressions | length) baselined detail counts exceeded — a waived check absorbed new findings:"
        for r in $ratchet.count_regressions { print $"  ($r.key): current ($r.current) > baselined ($r.stored)" }
        print "Fix the regression; the waiver covers the recorded count, not further growth."
        $exit_code = 1
    }

    if ($ratchet.stale_counts | is-not-empty) {
        print ""
        print $"FAIL: ($ratchet.stale_counts | length) baselined detail counts are stale — current is lower, lock in the improvement:"
        for r in $ratchet.stale_counts { print $"  ($r.key): current ($r.current) < baselined ($r.stored)" }
        print "Regenerate with: nu test/validate-skills-quality.nu --update-baseline"
        $exit_code = 1
    }

    if $exit_code == 0 {
        print ""
        let bd = (burn-down-counts $baseline)
        mut suffix = ""
        if $bd.excluded > 0 {
            $suffix = $suffix + $" + ($bd.excluded) check-defects excluded \(see each entry's issue field\)"
        }
        if $bd.accepted > 0 {
            $suffix = $suffix + $" + ($bd.accepted) accepted-by-design \(see each entry's issue field\)"
        }
        print $"Skill quality validation complete! ($bd.burn) debt/bug entries to burn down($suffix)"
    }

    exit $exit_code
}
