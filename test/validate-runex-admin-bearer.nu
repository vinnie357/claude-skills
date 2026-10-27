#!/usr/bin/env nu

# Regression tests for the runex skill's bundles.nu admin bearer
# (runex#388 caller side; closes runex-workflows-187).
#
# Runex now requires `Authorization: Bearer <RUNEX_ADMIN_TOKEN>` as the SOLE
# Authorization header on POST /api/bundles/{import,reload,sync,update}.
# These tests EXECUTE scripts/0.0.25/bundles.nu against a local header-capture
# stub (test/fixtures/runex-admin-bearer/capture_server.py) and assert on what
# actually went over the wire, so they hold whether the script uses nu
# `http post` or curl.
#
# Token values are synthetic, built at runtime, and never printed: failure
# messages name the check, not the value.
#
# Usage: nu test/validate-runex-admin-bearer.nu

const SCRIPT_REL = "plugins/tools/runex/skills/runex/scripts/0.0.25/bundles.nu"
const SERVER_REL = "test/fixtures/runex-admin-bearer/capture_server.py"

def admin-tok [] { ["adm" "fixture" "7f3e9a"] | str join "-" }
def api-tok [] { ["api" "fixture" "51c0d2"] | str join "-" }

# Start the stub; returns {job: id, port: int, log: path, dir: path}.
def start-server [repo: string] {
    let dir = (mktemp -d)
    let port_file = ($dir | path join "port")
    let log = ($dir | path join "requests.jsonl")
    "" | save --force $log
    let server = ($repo | path join $SERVER_REL)
    let id = (job spawn { ^python3 -I $server $port_file $log })
    mut tries = 0
    while (not ($port_file | path exists) or (open --raw $port_file | str trim | is-empty)) and $tries < 100 {
        sleep 50ms
        $tries += 1
    }
    let port = (open --raw $port_file | str trim | into int)
    {job: $id, port: $port, log: $log, dir: $dir}
}

def requests [srv: record] {
    open --raw $srv.log | lines | where {|l| $l | is-not-empty } | each {|l| $l | from json }
}

def reset-log [srv: record] { "" | save --force $srv.log }

# Run bundles.nu with a controlled token env. `admin`/`api` = null means UNSET.
def run-script [repo: string, srv: record, admin, api, args: list<string>] {
    let script = ($repo | path join $SCRIPT_REL)
    let host = $"http://127.0.0.1:($srv.port)"
    do {
        hide-env -i RUNEX_ADMIN_TOKEN
        hide-env -i RUNEX_API_TOKEN
        if $admin != null { $env.RUNEX_ADMIN_TOKEN = $admin }
        if $api != null { $env.RUNEX_API_TOKEN = $api }
        $env.RUNEX_HOST = $host
        ^nu $script ...$args | complete
    }
}

def check [name: string, ok: bool] {
    if $ok { print $"  PASS ($name)" } else { print $"  FAIL ($name)" }
    $ok
}

let repo = (git rev-parse --show-toplevel | str trim)
let script = ($repo | path join $SCRIPT_REL)
if not ($script | path exists) {
    print $"FAIL: ($SCRIPT_REL) missing"
    exit 1
}

let srv = (start-server $repo)
let archive = ($srv.dir | path join "fixture-bundle.tar.gz")
"not-really-a-tarball\n" | save --force $archive
let admin_bearer = $"Bearer (admin-tok)"
let api_bearer = $"Bearer (api-tok)"

# Cases: label, argv, whether the route is admin-gated, expected path
let cases = [
    {label: "import <archive>", args: ["import" $archive $"http://127.0.0.1:($srv.port)"], admin: true, path: "/api/bundles/import"}
    {label: "reload", args: ["reload"], admin: true, path: "/api/bundles/reload"}
    {label: "pull <name> <version>", args: ["pull" "fixture-bundle" "0.0.1"], admin: true, path: "/api/bundles/import"}
    {label: "bundles (non-admin GET)", args: ["bundles"], admin: false, path: "/api/bundles"}
]

mut results = []
mut leaked = false

for c in $cases {
    # 1. Both tokens set.
    reset-log $srv
    let r = (run-script $repo $srv (admin-tok) (api-tok) $c.args)
    let reqs = (requests $srv | where path == $c.path)
    let out = $"($r.stdout)($r.stderr)"
    if ($out | str contains (admin-tok)) or ($out | str contains (api-tok)) { $leaked = true }
    $results = ($results | append (check $"($c.label): request reached server" (($reqs | length) == 1)))
    let auth = if ($reqs | is-empty) { [] } else { $reqs | first | get auth }
    if $c.admin {
        $results = ($results | append (check $"($c.label): exactly one Authorization header with both tokens set" (($auth | length) == 1)))
        $results = ($results | append (check $"($c.label): Authorization is the admin bearer, not RUNEX_API_TOKEN" ($auth == [$admin_bearer])))
    } else {
        $results = ($results | append (check $"($c.label): still sends RUNEX_API_TOKEN bearer" ($auth == [$api_bearer])))
    }

    if $c.admin {
        # 2. Admin unset, API set: admin calls carry NO Authorization.
        reset-log $srv
        let r2 = (run-script $repo $srv null (api-tok) $c.args)
        let reqs2 = (requests $srv | where path == $c.path)
        let auth2 = if ($reqs2 | is-empty) { [nothing] } else { $reqs2 | first | get auth }
        $results = ($results | append (check $"($c.label): no Authorization when RUNEX_ADMIN_TOKEN unset" ($auth2 == [])))
        # 3. Admin empty string: same as unset.
        reset-log $srv
        let r3 = (run-script $repo $srv "" (api-tok) $c.args)
        let reqs3 = (requests $srv | where path == $c.path)
        let auth3 = if ($reqs3 | is-empty) { [nothing] } else { $reqs3 | first | get auth }
        $results = ($results | append (check $"($c.label): no Authorization when RUNEX_ADMIN_TOKEN empty" ($auth3 == [])))
        # 4. Admin set, API unset.
        reset-log $srv
        let r4 = (run-script $repo $srv (admin-tok) null $c.args)
        let out4 = $"($r4.stdout)($r4.stderr)"
        if ($out4 | str contains (admin-tok)) { $leaked = true }
        let reqs4 = (requests $srv | where path == $c.path)
        let auth4 = if ($reqs4 | is-empty) { [] } else { $reqs4 | first | get auth }
        $results = ($results | append (check $"($c.label): admin bearer sent when only RUNEX_ADMIN_TOKEN set" ($auth4 == [$admin_bearer])))
    }
}

# Multipart field name on archive upload (runex-workflows-187).
reset-log $srv
let _ = (run-script $repo $srv (admin-tok) null ["import" $archive $"http://127.0.0.1:($srv.port)"])
let up = (requests $srv | where path == "/api/bundles/import")
let fields = if ($up | is-empty) { [] } else { $up | first | get fields }
$results = ($results | append (check "import <archive>: multipart field is archive=" ($fields == ["archive"])))
$results = ($results | append (check "import <archive>: no legacy file= field" (not ("file" in $fields))))

$results = ($results | append (check "no token value appears in script output" (not $leaked)))

job kill $srv.job
rm -rf $srv.dir

let failed = ($results | where {|x| not $x } | length)
print $"\n($results | length) checks, ($failed) failed"
if $failed > 0 { exit 1 }
