#!/usr/bin/env nu

# Public-repo disclosure lint (claude-skills-113).
#
# This repository is public. Real infrastructure identifiers must never land
# in tracked content — they enable reconnaissance and are not caught by
# gitleaks (which targets credentials, not references). This lint fails when
# any git-tracked file contains:
#
#   1. op:// secret references whose vault segment is not a placeholder
#      (placeholders: <vault>, {vault}, $VAR, your-vault, vault-name, ...)
#   2. RFC1918 IP literals (10/8, 172.16/12, 192.168/16) not on the reviewed
#      allowlist below — documentation examples belong in the RFC5737 ranges
#      (192.0.2.x, 198.51.100.x, 203.0.113.x) instead
#   3. Estate-hostname patterns used in host position (ssh/@/URL/.lan targets
#      such as pve2, pbs, *-mac-mini), plus any literal listed in the
#      OPTIONAL, git-ignored `.disclosure-blocklist.local` file
#
# The local blocklist lets an operator lint for their real hostnames without
# publishing them. It must NEVER be tracked — this script hard-fails if it is.
#
# Usage:
#   nu test/validate-disclosure.nu              # scan all tracked files
#   nu test/validate-disclosure.nu --self-test  # verify the rules themselves

# This script contains the very patterns it hunts, so it is excluded from
# its own scan. Everything else that is git-tracked is in scope.
const EXCLUDED_PATHS = [
  "test/validate-disclosure.nu"
]

# Reviewed-legitimate RFC1918 literals already used as documentation examples
# by upstream tools (Apple Container's default subnet is 192.168.64.0/24;
# the rest are generic samples in ansible/twelve-factor/container docs).
# Adding to this list requires confirming the value identifies no real host.
const ALLOWED_RFC1918 = [
  "10.0.0.0"
  "10.0.1.15"
  "10.0.1.100"
  "192.168.1.1"
  "192.168.1.10"
  "192.168.64.0"
  "192.168.64.1"
]

# A vault segment matching any of these is a placeholder, not a disclosure.
const PLACEHOLDER_VAULT = '^(<[^>]*>|\{[^}]*\}|\$[A-Za-z_{][A-Za-z0-9_}]*|(?i:your[-_]?vault|vault|vault-name|my[-_]?vault|example[-_]?vault|placeholder))$'

const RFC1918_RE = '\b10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b|\b172\.(1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}\b|\b192\.168\.[0-9]{1,3}\.[0-9]{1,3}\b'

const OP_REF_RE = 'op://[^/\s"''`)\]]+/'

# Host-position contexts for short estate-style hostnames. Case-sensitive on
# purpose: prose like "PVE hypervisor" or the keyword "pve" never matches;
# `ssh pve2`, `root@pbs`, `https://pdm:8443`, and `pve.lan` do. A trailing
# dot is excluded so public FQDNs like pve.proxmox.com stay legal.
const HOSTNAME_RES = [
  '[a-z0-9][a-z0-9-]*-mac-mini\b'
  'ssh\s+([a-z0-9_.-]+@)?(pve|pbs|pdm)[0-9]*(\s|$)'
  '@(pve|pbs|pdm)[0-9]*([^.a-z0-9-]|$)'
  '://(pve|pbs|pdm)[0-9]*[:/]'
  '\b(pve|pbs|pdm)[0-9]*\.(lan|local|internal|home\.arpa)\b'
]

const LOCAL_BLOCKLIST = ".disclosure-blocklist.local"

def main [--self-test] {
  let repo_root = (git rev-parse --show-toplevel | str trim)
  cd $repo_root

  if $self_test {
    run-self-test
    return
  }

  # The local blocklist must never be published.
  let tracked_blocklist = (do { git ls-files --error-unmatch $LOCAL_BLOCKLIST } | complete)
  if $tracked_blocklist.exit_code == 0 {
    print $"(ansi red_bold)❌ ($LOCAL_BLOCKLIST) is git-tracked — it may contain real hostnames and must stay local. Untrack it and add it to .gitignore.(ansi reset)"
    exit 1
  }

  let extra_hosts = (load-local-blocklist)
  if ($extra_hosts | length) > 0 {
    print $"🔍 Local blocklist active: ($extra_hosts | length) extra hostname literal\(s\)"
  }

  let files = (
    git ls-files
    | lines
    | where { |f| $f not-in $EXCLUDED_PATHS }
    | where { |f| ($f | path parse | get extension) not-in ["png" "jpg" "jpeg" "gif" "ico" "woff" "woff2"] }
  )

  mut findings = []
  for file in $files {
    let content = (try { open --raw $file | decode utf-8 } catch { "" })
    if ($content | is-empty) { continue }

    # Cheap whole-file pre-filter before per-line work
    let suspicious = (
      ($content =~ $RFC1918_RE)
      or ($content =~ 'op://')
      or ($HOSTNAME_RES | any { |re| $content =~ $re })
      or (($extra_hosts | length) > 0 and ($extra_hosts | any { |h| $content | str downcase | str contains $h }))
    )
    if not $suspicious { continue }

    for line in ($content | lines | enumerate) {
      let hits = (check-line $line.item $extra_hosts)
      for hit in $hits {
        $findings = ($findings | append {
          file: $file
          line: ($line.index + 1)
          rule: $hit.rule
          match: $hit.match
        })
      }
    }
  }

  if ($findings | length) > 0 {
    print $"\n(ansi red_bold)❌ Disclosure lint failed — ($findings | length) finding\(s\):(ansi reset)\n"
    print ($findings | table --expand)
    print ""
    print "Fix guidance:"
    print "  • op:// refs: use a placeholder vault (op://<vault>/item/field)"
    print "  • IP examples: use RFC5737 ranges (192.0.2.x, 198.51.100.x, 203.0.113.x),"
    print "    or add a reviewed entry to ALLOWED_RFC1918 in test/validate-disclosure.nu"
    print "  • Hostnames: use generic names (node1, host.example.com) — never estate names"
    exit 1
  }

  print $"(ansi green_bold)✅ Disclosure lint clean \(($files | length) tracked files scanned\)(ansi reset)"
  exit 0
}

# Returns [{rule, match}] for one line of text.
def check-line [line: string, extra_hosts: list<string>] {
  mut hits = []

  # Rule 1: op:// with a non-placeholder vault segment
  if ($line =~ $OP_REF_RE) {
    let vaults = (
      $line
      | parse --regex 'op://(?<vault>[^/\s"''`)\]]+)/'
      | get vault
    )
    for vault in $vaults {
      if not ($vault =~ $PLACEHOLDER_VAULT) {
        $hits = ($hits | append { rule: "op-vault", match: $"op://($vault)/…" })
      }
    }
  }

  # Rule 2: RFC1918 literal not on the allowlist
  if ($line =~ $RFC1918_RE) {
    let ips = (
      $line
      | parse --regex '(?<ip>\b(?:10\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.[0-9]{1,3}\.[0-9]{1,3}|192\.168\.[0-9]{1,3}\.[0-9]{1,3})\b)'
      | get ip
    )
    for ip in $ips {
      if $ip not-in $ALLOWED_RFC1918 {
        $hits = ($hits | append { rule: "rfc1918-ip", match: $ip })
      }
    }
  }

  # Rule 3: estate hostname in host position
  for re in $HOSTNAME_RES {
    if ($line =~ $re) {
      $hits = ($hits | append { rule: "estate-hostname", match: ($line | str trim | str substring 0..79) })
    }
  }

  # Rule 3b: operator-supplied literal hostnames (local blocklist)
  for host in $extra_hosts {
    if ($line | str downcase | str contains $host) {
      $hits = ($hits | append { rule: "blocklisted-hostname", match: ($line | str trim | str substring 0..79) })
    }
  }

  $hits
}

# Reads .disclosure-blocklist.local if present: one lowercase hostname per
# line, '#' comments and blank lines ignored. The file is git-ignored.
def load-local-blocklist [] {
  if not ($LOCAL_BLOCKLIST | path exists) { return [] }
  open --raw $LOCAL_BLOCKLIST
  | lines
  | each { |l| $l | str trim | str downcase }
  | where { |l| ($l | is-not-empty) and not ($l | str starts-with "#") }
}

# Embedded rule verification: every bad sample must be caught, every good
# sample must pass. Samples use obviously fictional identifiers.
def run-self-test [] {
  let bad = [
    "  env = { DB_PASS = \"op://acme-secrets/db/password\" }"
    "host: 10.20.30.40"
    "curl http://172.17.5.9/health"
    "gateway 192.168.7.7"
    "ssh pve2"
    "scp file root@pbs"
    "curl https://pdm:8443/api"
    "rsync -a bobs-mac-mini:/srv ."
    "ping pve.lan"
  ]
  let good = [
    "op://<vault>/item/field"
    "op://your-vault/item/credential"
    "op://vault-name/item-name/field-name"
    "op://{{ vault }}/x/y"
    "use 192.0.2.10 or 203.0.113.5 in examples"
    "Apple Container default gateway is 192.168.64.1"
    "see https://pve.proxmox.com/wiki/Package_Repositories"
    "keywords: pve, pbs, pdm, hypervisor"
    "PVE hypervisor and PDM realm auth"
    "improve the docs"
    "public IP 8.8.8.8 and version 10.0.1 are fine"
  ]

  mut failed = false
  for sample in $bad {
    let hits = (check-line $sample [])
    if ($hits | length) == 0 {
      print $"(ansi red_bold)❌ self-test: NOT caught \(should fail\): ($sample)(ansi reset)"
      $failed = true
    }
  }
  for sample in $good {
    let hits = (check-line $sample [])
    if ($hits | length) > 0 {
      print $"(ansi red_bold)❌ self-test: false positive: ($sample) → ($hits | to nuon)(ansi reset)"
      $failed = true
    }
  }

  # Local blocklist literals are matched case-insensitively
  let bl_hits = (check-line "deploy to Fictional-Host-01 tonight" ["fictional-host-01"])
  if ($bl_hits | length) == 0 {
    print $"(ansi red_bold)❌ self-test: local blocklist literal not caught(ansi reset)"
    $failed = true
  }

  if $failed { exit 1 }
  print $"(ansi green_bold)✅ Disclosure lint self-test passed \(($bad | length) bad + ($good | length) good samples\)(ansi reset)"
  exit 0
}
