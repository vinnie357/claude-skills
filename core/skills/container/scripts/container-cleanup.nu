#!/usr/bin/env nu

# Apple Container cleanup and resource management
# Supports: prune-all, prune-containers, prune-images, prune-volumes, prune-networks, df

def main [
    command: string  # Subcommand: prune-all, prune-containers, prune-images, prune-volumes, prune-networks, df
] {
    match $command {
        "prune-all" => { cmd-prune-all }
        "prune-containers" => { cmd-prune-containers }
        "prune-images" => { cmd-prune-images }
        "prune-volumes" => { cmd-prune-volumes }
        "prune-networks" => { cmd-prune-networks }
        "df" => { cmd-df }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: prune-all, prune-containers, prune-images, prune-volumes, prune-networks, df"
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

def cmd-prune-all [] {
    ensure-running
    print $"(ansi cyan)Pruning all unused resources...(ansi reset)"
    print ""

    print $"(ansi yellow)Pruning stopped containers...(ansi reset)"
    let c = (do { ^container prune } | complete)
    if $c.exit_code == 0 { print $c.stdout }

    print $"(ansi yellow)Pruning unused images...(ansi reset)"
    let i = (do { ^container image prune } | complete)
    if $i.exit_code == 0 { print $i.stdout }

    print $"(ansi yellow)Pruning unused volumes...(ansi reset)"
    let v = (do { ^container volume prune } | complete)
    if $v.exit_code == 0 { print $v.stdout }

    print $"(ansi yellow)Pruning unused networks...(ansi reset)"
    let n = (do { ^container network prune } | complete)
    if $n.exit_code == 0 { print $n.stdout }

    print ""
    print $"(ansi green)Cleanup complete(ansi reset)"

    # Show disk usage after cleanup
    print ""
    cmd-df
}

def cmd-prune-containers [] {
    ensure-running
    print $"(ansi yellow)Pruning stopped containers...(ansi reset)"
    let result = (do { ^container prune } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
        print $"(ansi green)Container prune complete(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-prune-images [] {
    ensure-running
    print $"(ansi yellow)Pruning unused images...(ansi reset)"
    let result = (do { ^container image prune } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
        print $"(ansi green)Image prune complete(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-prune-volumes [] {
    ensure-running
    print $"(ansi yellow)Pruning unused volumes...(ansi reset)"
    let result = (do { ^container volume prune } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
        print $"(ansi green)Volume prune complete(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-prune-networks [] {
    ensure-running
    print $"(ansi yellow)Pruning unused networks...(ansi reset)"
    let result = (do { ^container network prune } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
        print $"(ansi green)Network prune complete(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-df [] {
    ensure-running
    print $"(ansi cyan)Disk Usage:(ansi reset)"
    let result = (do { ^container system df } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}
