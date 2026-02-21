#!/usr/bin/env nu

# Apple Container lifecycle management
# Supports: run, ps, start, stop, kill, rm, exec, logs, inspect, stats

def main [
    command: string   # Subcommand: run, ps, start, stop, kill, rm, exec, logs, inspect, stats
    ...args: string   # Additional arguments passed to the command
] {
    match $command {
        "run" => { cmd-run $args }
        "ps" => { cmd-ps $args }
        "start" => { cmd-start $args }
        "stop" => { cmd-stop $args }
        "kill" => { cmd-kill $args }
        "rm" => { cmd-rm $args }
        "exec" => { cmd-exec $args }
        "logs" => { cmd-logs $args }
        "inspect" => { cmd-inspect $args }
        "stats" => { cmd-stats }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: run, ps, start, stop, kill, rm, exec, logs, inspect, stats"
            exit 1
        }
    }
}

def ensure-running [] {
    if (which container | is-empty) {
        print $"(ansi red)Error:(ansi reset) Apple Container CLI not found"
        exit 1
    }
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

def cmd-run [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Image name required"
        print "Usage: container-lifecycle.nu run [flags] <image> [command]"
        exit 1
    }
    let result = (do { ^container run ...$args } | complete)
    print $result.stdout
    if $result.exit_code != 0 {
        print $result.stderr
        exit $result.exit_code
    }
}

def cmd-ps [args: list<string>] {
    ensure-running
    print $"(ansi cyan)Containers:(ansi reset)"
    let result = if ($args | is-empty) {
        (do { ^container list } | complete)
    } else {
        (do { ^container list ...$args } | complete)
    }
    if $result.exit_code == 0 {
        print $result.stdout
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-start [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Container name or ID required"
        exit 1
    }
    let name = ($args | first)
    let result = (do { ^container start $name } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Started:(ansi reset) ($name)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-stop [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Container name or ID required"
        exit 1
    }
    let name = ($args | first)
    let result = (do { ^container stop $name } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Stopped:(ansi reset) ($name)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-kill [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Container name or ID required"
        exit 1
    }
    let name = ($args | first)
    let result = (do { ^container kill $name } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Killed:(ansi reset) ($name)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-rm [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Container name or ID required"
        exit 1
    }
    let result = (do { ^container rm ...$args } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Removed(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-exec [args: list<string>] {
    ensure-running
    if ($args | length) < 2 {
        print $"(ansi red)Error:(ansi reset) Container name and command required"
        print "Usage: container-lifecycle.nu exec <container> <command>"
        exit 1
    }
    let result = (do { ^container exec ...$args } | complete)
    print $result.stdout
    if $result.exit_code != 0 {
        print $result.stderr
        exit $result.exit_code
    }
}

def cmd-logs [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Container name or ID required"
        exit 1
    }
    let result = (do { ^container logs ...$args } | complete)
    print $result.stdout
    if $result.exit_code != 0 {
        print $result.stderr
        exit $result.exit_code
    }
}

def cmd-inspect [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Container name or ID required"
        exit 1
    }
    let name = ($args | first)
    let result = (do { ^container inspect $name } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-stats [] {
    ensure-running
    let result = (do { ^container stats } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}
