#!/usr/bin/env nu
# Allium-db CLI wrapper for Claude agents
# Version 0.1.0
#
# This script provides Nushell wrappers around the allium-db Zig CLI binary.
# The binary is installed via mise from vinnie357/allium-db (private repo).
#
# Subcommands: register, resolve, weed, elicit
#
# Each subcommand is stubbed with "not yet implemented" until the underlying
# CLI is available.

def main [...args] {
    if ($args | length) == 0 {
        print "Allium-db CLI Wrapper v0.1.0"
        print ""
        print "Usage: allium-db <command> [args]"
        print ""
        print "Commands:"
        print "  register <spec-path>     Ingest .allium file into database"
        print "  resolve <epic-slug>      Fetch spec for epic"
        print "  weed <code-path>         Compare code against spec"
        print "  elicit                   Interactive spec capture"
        print ""
        print "Subcommands not yet implemented — install allium-db from vinnie357/allium-db first"
        exit 1
    }

    let cmd = $args.0
    let rest = ($args | skip 1)

    match $cmd {
        "register" => {
            print "not yet implemented — install allium-db from vinnie357/allium-db first"
            print ""
            print "Usage: allium-db register <spec-path>"
            print "Example: allium-db register ./docs/adr/ADR-035.allium"
            exit 1
        }
        "resolve" => {
            print "not yet implemented — install allium-db from vinnie357/allium-db first"
            print ""
            print "Usage: allium-db resolve <epic-slug>"
            print "Example: allium-db resolve VIN-72"
            exit 1
        }
        "weed" => {
            print "not yet implemented — install allium-db from vinnie357/allium-db first"
            print ""
            print "Usage: allium-db weed <code-path>"
            print "Example: allium-db weed ./lib/allium_db/register.ex"
            exit 1
        }
        "elicit" => {
            print "not yet implemented — install allium-db from vinnie357/allium-db first"
            print ""
            print "Usage: allium-db elicit"
            print "Launches interactive spec capture (no args)"
            exit 1
        }
        _ => {
            print $"Unknown command: ($cmd)"
            print ""
            print "Available commands: register, resolve, weed, elicit"
            exit 1
        }
    }
}
