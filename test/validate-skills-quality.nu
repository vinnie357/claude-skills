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
#   nu test/validate-skills-quality.nu --self-test  # verify the skills: frontmatter, baseline schema/ratchet, check-fix fixtures, and Pass-2 agents/commands links

# Checks whose findings are countable at runtime; their baseline entries must
# carry an integer detail_count so a waiver covers the recorded count, not
# unbounded growth of the same check.
const DETAIL_CHECKS = ["lines" "links" "orphans" "invocations" "version_pin" "ref_depth" "duplicate_block" "vocab_disjoint" "fm_schema"]

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
def has-unqualified-references-token [content: string, dir_name: string, skill_dir_map: list, known_plugins: list]: nothing -> bool {
    ($content | lines | any {|line|
        if not ($line | str contains "references/") {
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

# Validate the baseline's allowed_failures entries. Records only — a bare
# string entry (the pre-claude-skills-132 shape) is a hard failure, because a
# hand-added string would bypass class/issue/detail_count permanently.
# Required: key, class (BUG|DEBT|CHECK_DEFECT), issue. first_seen is an ISO
# date for new entries or the literal "migrated" for pre-schema ones.
# detail_count must be an integer for detail-producing checks (DETAIL_CHECKS),
# null otherwise. Returns a list of error strings; empty means valid.
def validate-baseline-entries [entries: list] {
    let valid_classes = ["BUG" "DEBT" "CHECK_DEFECT"]
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
            $errors = ($errors | append $"($key): missing required 'class' \(BUG | DEBT | CHECK_DEFECT\)")
        } else if ($class not-in $valid_classes) {
            $errors = ($errors | append $"($key): invalid class '($class)' — must be BUG, DEBT, or CHECK_DEFECT")
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

# Burn-down split for the summary line: CHECK_DEFECT entries are defects in
# the checks themselves (each entry's issue field names the tracker item),
# not skill debt — they must be reported separately so their exclusion
# cannot read as progress.
def burn-down-counts [baseline: list] {
    let excluded = ($baseline | where {|e| ($e | get -o class) == "CHECK_DEFECT"} | length)
    {burn: (($baseline | length) - $excluded), excluded: $excluded}
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

    # Case 10: CHECK_DEFECT entries excluded from the burn-down total but
    # reported in the excluded figure
    let bd = (burn-down-counts [
        {key: "a/b:anti_fab", class: "DEBT", issue: "i"}
        {key: "c/d:reserved", class: "CHECK_DEFECT", issue: "claude-skills-130"}
    ])
    if not ($bd.burn == 1 and $bd.excluded == 1) {
        print $"(ansi red_bold)❌ baseline self-test: burn-down split wrong \(burn ($bd.burn), excluded ($bd.excluded)\)(ansi reset)"
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
    if (has-unqualified-references-token "### references/command-reference.md (if present)" "myskill" [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: heading line wrongly counted as nested reference(ansi reset)"
        $failed = true
    }
    if not (has-unqualified-references-token "See references/foo.md for detail." "myskill" [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: genuine sibling reference link not flagged(ansi reset)"
        $failed = true
    }
    if (has-unqualified-references-token $"- Move detailed reference material to ($tick1)references/($tick1)" "myskill" [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: bare references/ directory mention wrongly flagged(ansi reset)"
        $failed = true
    }
    # Composition with strip-fences: a sibling link INSIDE a 4-backtick outer
    # fence is example content (not flagged); outside any fence it is flagged.
    if (has-unqualified-references-token (strip-fences $nested) "myskill" [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: sibling link inside nested fence wrongly flagged(ansi reset)"
        $failed = true
    }
    if not (has-unqualified-references-token (strip-fences ([$tick3 "code" $tick3 "see references/foo.md"] | str join "\n")) "myskill" [] []) {
        print $"(ansi red_bold)❌ check-fix self-test: sibling link outside fences not flagged after stripping(ansi reset)"
        $failed = true
    }

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
        print $"(ansi green_bold)✅ Check-fix self-test passed \(19 cases\)(ansi reset)"
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
def core-list-satellites [script_path: string] {
    let raw = (open --raw $script_path)
    let sat = ($raw | parse --regex '(?m)path: "(?P<p>[^"]+)"' | get p)
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
    # satellite shapes; if the parse silently broke, exemption 3 would too
    let repo_root = (git rev-parse --show-toplevel | str trim)
    let derived = (core-list-satellites ($repo_root | path join "test" "validate-core-list.nu"))
    if ("plugins/core/skills/agent-loop/SKILL.md" not-in $derived) or ("plugins/core/hooks/session-start.sh" not-in $derived) or (($derived | length) < 5) {
        print $"(ansi red_bold)❌ duplicate self-test: satellite derivation from validate-core-list.nu broke \(got ($derived | length) entries\)(ansi reset)"
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
        print $"(ansi green_bold)✅ Duplicate-block self-test passed \(15 cases\)(ansi reset)"
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
        let fm_schema_failed = (run-frontmatter-schema-self-test)
        if $skills_failed or $baseline_failed or $checks_failed or $duplicate_failed or $vocab_failed or $pass2_links_failed or $orphans_failed or $fm_schema_failed { exit 1 }
        exit 0
    }

    print "Validating skill quality across all plugins..."
    print ""

    let repo_root = (git rev-parse --show-toplevel | str trim)
    let marketplace_path = ($repo_root | path join ".claude-plugin" "marketplace.json")
    let marketplace = (open $marketplace_path)

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
        print "Every allowed_failures entry must be a record: {key, class (BUG|DEBT|CHECK_DEFECT), issue, first_seen, detail_count}."
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
    for plugin in $marketplace.plugins {
        let source_type = ($plugin.source | describe)
        if ($source_type | str starts-with "record") { continue }
        if ($plugin.name == "all-skills") { continue }

        let plugin_dir = ($repo_root | path join ($plugin.source | str replace --regex '^\./' ''))
        let plugin_json_path = ($plugin_dir | path join ".claude-plugin" "plugin.json")
        if not ($plugin_json_path | path exists) { continue }

        let plugin_json = (open $plugin_json_path)
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
    mut failing_keys = []
    mut failing_counts = []

    for plugin in $registry {
        let plugin_dir = $plugin.dir
        let plugin_name = $plugin.name
        let plugin_json = (open ($plugin_dir | path join ".claude-plugin" "plugin.json"))
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
            let refs = ($ref_files | each {|f| {name: ($f | path basename), content: (open --raw $f)}})

            # 8. Has examples: code fence / example header in SKILL.md, or a
            # code fence in a reference file SKILL.md mentions (see has-examples)
            if not (has-examples $content $refs) { $failed = ($failed | append "examples") }

            # 9. Reference depth (no nested references; code examples don't count).
            # A references/ token qualified as pointing at another skill (see
            # cross-skill-qualified above) is not a same-skill nesting violation.
            let nested = ($refs | where {|r|
                has-unqualified-references-token (strip-fences $r.content) $dir_name $skill_dir_map ($registry | get name)
            })
            if ($nested | length) > 0 { $failed = ($failed | append "ref_depth") }

            # 10. Anti-fabrication present
            let content_lower = ($content | str downcase)
            let has_anti_fab_header = ($content_lower | str contains "anti-fabrication")
            let has_anti_fab_ref = ($content | str contains "core:anti-fabrication")
            let has_fabricat = ($content_lower | str contains "fabricat")
            if not ($has_anti_fab_header or $has_anti_fab_ref or $has_fabricat) {
                $failed = ($failed | append "anti_fab")
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
            for c in [
                {check: "lines", count: $line_count}
                {check: "links", count: ($broken_links | length)}
                {check: "orphans", count: ($orphans | length)}
                {check: "invocations", count: ($bad_invocations | length)}
                {check: "version_pin", count: ($stale_pins | length)}
                {check: "ref_depth", count: ($nested | length)}
                {check: "fm_schema", count: ($fm_unknown | length)}
            ] {
                if $c.check in $failed {
                    $failing_counts = ($failing_counts | append {key: $"($plugin_name)/($dir_name):($c.check)", count: $c.count})
                }
            }

            let check_count = 17
            let score = $check_count - ($failed | length)

            $results = ($results | append {
                skill: $dir_name
                plugin: $plugin_name
                lines: $"($line_count)/500"
                score: $"($score)/($check_count)"
                failed: ($failed | str join " ")
                new: ($new_failures | each {|k| $k | split row ":" | last} | str join " ")
                details: ($broken_links | append $bad_invocations | append $stale_pins | append ($orphans | each {|f| $f | path basename}) | append ($fm_unknown | each {|k| $"frontmatter:($k)"}) | str join " ")
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
    # NOTE: Pass-2 checks with countable findings (bad_invocations, the
    # skills: frontmatter checks, links) are NOT wired into the detail_count
    # ratchet. No Pass-2 waivers exist today, so the hard-failure path guards
    # them — if a Pass-2 waiver is ever added, give its check the same
    # DETAIL_CHECKS + failing_counts treatment the per-skill checks got, or
    # one waiver will absorb every later finding of that check on that file.
    let known_models = ["haiku" "sonnet" "opus"]
    let known_hook_events = ["PreToolUse" "PostToolUse" "SessionStart" "SessionEnd" "UserPromptSubmit" "Stop" "SubagentStop" "PreCompact" "Notification"]
    mut surface_results = []

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

        for entry in $agent_entries {
            let f = $entry.file
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

            # skills: frontmatter (claude-skills-119) — well-formed entries, no
            # duplicates, and each entry resolves against a local plugin's
            # `skills` list. Only runs when the agent has a `skills:` field.
            let skills_check = (check-agent-skills $fm_lines $registry)
            $failed = ($failed | append $skills_check.failed)

            let bad_invocations = (find-bad-invocations $content $registry)
            if ($bad_invocations | is-not-empty) { $failed = ($failed | append "bad_invocations") }

            # links (claude-skills-164): dir-gating uses pass2-dir-in-scope —
            # WIDER than check 14's own-level-only rule, since a Pass-2 file
            # has no single owning skill dir and resolve-pass2-path itself
            # checks own level, sibling skills, AND the plugin root; gating
            # on own-level alone excluded real pointers from evaluation
            # (Gate 3 finding, PR 160). references/agents are always in scope.
            let agent_stripped = (strip-fences $content)
            let agent_link_paths = (extract-link-path-tokens $agent_stripped)
            let agent_broken_links = ($agent_link_paths | where {|p|
                let top = ($p | split row "/" | first)
                let dir_gated = $top in ["scripts" "templates" "hooks"]
                let in_scope = (not $dir_gated) or (pass2-dir-in-scope $top $entry.own_dir $plugin_dir)
                $in_scope and not (resolve-pass2-path $p (preceding-line $agent_stripped $p) $entry.own_dir $entry.dir_name $plugin_dir $skill_dir_map ($registry | get name))
            })
            if ($agent_broken_links | is-not-empty) { $failed = ($failed | append "links") }

            # Frontmatter keys are real (claude-skills-175). Agents use their
            # OWN schema — `paths`/`shell` are skill-only, `tools`/`isolation`
            # are agent-only — so this deliberately does not reuse SKILL_FM_KEYS.
            let agent_fm_unknown = (unknown-frontmatter-keys $fm_lines $AGENT_FM_KEYS)
            if ($agent_fm_unknown | is-not-empty) { $failed = ($failed | append "fm_schema") }

            if ($failed | is-not-empty) {
                let key_base = $"($plugin_name)/agents/($f | path basename)"
                $failing_keys = ($failing_keys | append ($failed | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "agent", file: ($f | path basename), failed: ($failed | str join " ")
                    details: ($bad_invocations | append $skills_check.bad_tokens | append $agent_broken_links | append ($agent_fm_unknown | each {|k| $"frontmatter:($k)"}) | str join " ")
                })
            }
        }

        # Commands: plugin-level commands/ dir only (no nested-skill convention observed).
        let commands_dir = ($plugin_dir | path join "commands")
        let command_files = if ($commands_dir | path exists) {
            glob ($commands_dir | path join "*.md")
        } else { [] }

        for f in $command_files {
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

            # links (claude-skills-164): commands are always plugin-level, so
            # own_dir == plugin_dir — bases 1 and 4 of resolve-pass2-path
            # collapse to the same check for command files. Dir-gating uses
            # pass2-dir-in-scope so a command's citation of a SIBLING skill's
            # templates/ dir (e.g. linear's plan-epic.md -> a skill-owned
            # templates/0.1.0/epic.md) is still evaluated even though the
            # plugin itself has no plugin-level templates/ dir.
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

            if ($failed | is-not-empty) {
                let key_base = $"($plugin_name)/commands/($f | path basename)"
                $failing_keys = ($failing_keys | append ($failed | each {|c| $"($key_base):($c)"}))
                $surface_results = ($surface_results | append {
                    plugin: $plugin_name, kind: "command", file: ($f | path basename), failed: ($failed | str join " ")
                    details: ($bad_invocations | append $cmd_broken_links | append ($cmd_fm_unknown | each {|k| $"frontmatter:($k)"}) | str join " ")
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
    for g in $dupe_groups {
        $failing_keys = ($failing_keys | append $g.key)
        $failing_counts = ($failing_counts | append {key: $g.key, count: $g.windows})
    }

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
    mut vocab_findings = []
    mut vocab_doc_empty = []
    for vf in $vocab_formats {
        let res = (check-vocab-disjoint $vf.doc $vf.real $vf.foreign)
        if $res.status == "doc_empty" {
            $vocab_doc_empty = ($vocab_doc_empty | append $vf.format)
        } else if $res.status == "fires" {
            let key = $"syntax/($vf.format):vocab_disjoint"
            $failing_keys = ($failing_keys | append $key)
            $failing_counts = ($failing_counts | append {key: $key, count: ($res.disjoint | length)})
            $vocab_findings = ($vocab_findings | append {
                format: $vf.format, key: $key, doc: $vf.doc, real: $vf.real
            })
        }
    }
    if ($vocab_doc_empty | is-not-empty) {
        print $"(ansi red_bold)❌ syntax-vs-usage: EMPTY documented vocabulary for format\(s\): ($vocab_doc_empty | str join ', ')(ansi reset)"
        print "These skills are known to document tokens, so extracting none means the doc extractor broke (or the doc lost its syntax section). Fix the extractor or the doc — this is a hard error, not a baselineable finding."
        exit 1
    }

    # Accumulation loops are done — rebind as immutable so the closures below
    # can capture them (Nushell closures cannot capture mut variables).
    let failing_keys = $failing_keys
    let failing_counts = $failing_counts
    let vocab_findings = $vocab_findings

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
        print "agents/commands/hooks surfaces: all clean"
    } else {
        print $"agents/commands/hooks surfaces: ($surface_results | length) finding\(s\)"
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
            "_comment": "Ratchet baseline for test/validate-skills-quality.nu. Each allowed_failures entry is a record: key (plugin/skill:check; corpus-wide duplicate groups use dupe/<md5-8 of the sorted member file set>:duplicate_block — the validator prints each group's member paths; syntax-vs-usage vocabulary findings use syntax/<format>:vocab_disjoint for the formats commands/agents/hooks — the validator prints both vocabularies), class (BUG | DEBT | CHECK_DEFECT — CHECK_DEFECT means the check itself is defective; the entry's issue field names the tracker item for the check fix), issue (tracker id the waiver is filed under), first_seen (ISO date, or the literal 'migrated' for entries predating the schema), detail_count (integer for detail-producing checks: lines/links/orphans/invocations/version_pin/ref_depth/duplicate_block/vocab_disjoint/fm_schema; null otherwise). Entries are pre-existing failures allowed to keep failing at their recorded count. Do not add entries for new code; fix the skill instead. When a fix lands or a count drops, the validator requires shrinking the baseline. Regenerate: nu test/validate-skills-quality.nu --update-baseline (shrink-only — removes fixed keys and lowers counts; errors instead of adding keys, never raises a count). Known residual: the ratchet bounds the NUMBER of findings per waived check, not their identity, so a same-commit swap of one finding for another of equal size passes."
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
        if $bd.excluded > 0 {
            print $"Skill quality validation complete! ($bd.burn) debt/bug entries to burn down + ($bd.excluded) check-defects excluded \(see each entry's issue field\)"
        } else {
            print $"Skill quality validation complete! ($bd.burn) debt/bug entries to burn down"
        }
    }

    exit $exit_code
}
