#!/usr/bin/env nu

# Apple Container system service management
# Supports: start, stop, status, version, logs, df, health

def main [
    command: string  # Subcommand: start, stop, status, version, logs, df, health
] {
    match $command {
        "start" => { cmd-start }
        "stop" => { cmd-stop }
        "status" => { cmd-status }
        "version" => { cmd-version }
        "logs" => { cmd-logs }
        "df" => { cmd-df }
        "health" => { cmd-health }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: start, stop, status, version, logs, df, health"
            exit 1
        }
    }
}

def check-prerequisites [] {
    if (which container | is-empty) {
        print $"(ansi red)Error:(ansi reset) Apple Container CLI not found"
        print "Install from: https://github.com/apple/container/releases"
        exit 1
    }
}

def ensure-running [] {
    check-prerequisites
    let status = (do { ^container system status } | complete)
    if $status.exit_code != 0 {
        print $"(ansi yellow)Starting Apple Container...(ansi reset)"
        let start_result = (do { ^container system start } | complete)
        if $start_result.exit_code != 0 {
            print $"(ansi red)Error:(ansi reset) Failed to start Apple Container"
            print $start_result.stderr
            exit 1
        }
        print $"(ansi green)Apple Container started(ansi reset)"
    }
}

def cmd-start [] {
    check-prerequisites
    let status = (do { ^container system status } | complete)
    if $status.exit_code == 0 {
        print $"(ansi green)Apple Container is already running(ansi reset)"
        return
    }
    print $"(ansi yellow)Starting Apple Container...(ansi reset)"
    let result = (do { ^container system start } | complete)
    if $result.exit_code != 0 {
        print $"(ansi red)Error:(ansi reset) Failed to start"
        print $result.stderr
        exit 1
    }
    print $"(ansi green)Apple Container started(ansi reset)"
}

def cmd-stop [] {
    check-prerequisites
    let status = (do { ^container system status } | complete)
    if $status.exit_code != 0 {
        print $"(ansi green)Apple Container is not running(ansi reset)"
        return
    }
    print $"(ansi yellow)Stopping Apple Container...(ansi reset)"
    let result = (do { ^container system stop } | complete)
    if $result.exit_code != 0 {
        print $"(ansi red)Error:(ansi reset) Failed to stop"
        print $result.stderr
        exit 1
    }
    print $"(ansi green)Apple Container stopped(ansi reset)"
}

def cmd-status [] {
    check-prerequisites
    let result = (do { ^container system status } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Running(ansi reset)"
        print $result.stdout
    } else {
        print $"(ansi red)Not running(ansi reset)"
    }
}

def cmd-version [] {
    check-prerequisites
    let result = (do { ^container system version } | complete)
    print $result.stdout
}

def cmd-logs [] {
    check-prerequisites
    let result = (do { ^container system logs } | complete)
    print $result.stdout
}

def cmd-df [] {
    ensure-running
    let result = (do { ^container system df } | complete)
    print $result.stdout
}

def cmd-health [] {
    check-prerequisites
    print $"(ansi cyan)Apple Container Health Check(ansi reset)"
    print ""

    # System status
    let status = (do { ^container system status } | complete)
    if $status.exit_code == 0 {
        print $"  System:     (ansi green)Running(ansi reset)"
    } else {
        print $"  System:     (ansi red)Not running(ansi reset)"
        return
    }

    # Version
    let version = (do { ^container system version } | complete)
    print $"  Version:    ($version.stdout | str trim)"

    # Disk usage
    let df = (do { ^container system df } | complete)
    if $df.exit_code == 0 {
        print $"  Disk usage:"
        print $df.stdout
    }

    # Running containers
    let containers = (do { ^container list } | complete)
    if $containers.exit_code == 0 {
        let lines = ($containers.stdout | str trim | lines)
        let count = if ($lines | length) > 1 { ($lines | length) - 1 } else { 0 }
        print $"  Containers: ($count) running"
    }
}
