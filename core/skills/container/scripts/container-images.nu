#!/usr/bin/env nu

# Apple Container image management
# Supports: list, pull, push, build, save, load, tag, prune, inspect

def main [
    command: string   # Subcommand: list, pull, push, build, save, load, tag, prune, inspect
    ...args: string   # Additional arguments passed to the command
] {
    match $command {
        "list" => { cmd-list }
        "pull" => { cmd-pull $args }
        "push" => { cmd-push $args }
        "build" => { cmd-build $args }
        "save" => { cmd-save $args }
        "load" => { cmd-load $args }
        "tag" => { cmd-tag $args }
        "prune" => { cmd-prune }
        "inspect" => { cmd-inspect $args }
        _ => {
            print $"(ansi red)Error:(ansi reset) Unknown command '($command)'"
            print "Available: list, pull, push, build, save, load, tag, prune, inspect"
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

def cmd-list [] {
    ensure-running
    print $"(ansi cyan)Images:(ansi reset)"
    let result = (do { ^container image list } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-pull [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Image name required"
        print "Usage: container-images.nu pull <image>"
        exit 1
    }
    let image = ($args | first)
    print $"(ansi cyan)Pulling:(ansi reset) ($image)"
    let result = (do { ^container image pull $image } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Pulled:(ansi reset) ($image)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-push [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Image name required"
        exit 1
    }
    let image = ($args | first)
    print $"(ansi cyan)Pushing:(ansi reset) ($image)"
    let result = (do { ^container image push $image } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Pushed:(ansi reset) ($image)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-build [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Build context required"
        print "Usage: container-images.nu build [-t tag] [-f file] [path]"
        exit 1
    }
    print $"(ansi cyan)Building image...(ansi reset)"
    let result = (do { ^container build ...$args } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
        print $"(ansi green)Build complete(ansi reset)"
    } else {
        print $"(ansi red)Build failed:(ansi reset)"
        print $result.stderr
        exit 1
    }
}

def cmd-save [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Image name and output required"
        print "Usage: container-images.nu save <image> -o <file>"
        exit 1
    }
    let result = (do { ^container image save ...$args } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Image saved(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-load [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Input file required"
        print "Usage: container-images.nu load -i <file>"
        exit 1
    }
    let result = (do { ^container image load ...$args } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Image loaded(ansi reset)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-tag [args: list<string>] {
    ensure-running
    if ($args | length) < 2 {
        print $"(ansi red)Error:(ansi reset) Source and target required"
        print "Usage: container-images.nu tag <source> <target>"
        exit 1
    }
    let source = ($args | first)
    let target = ($args | get 1)
    let result = (do { ^container image tag $source $target } | complete)
    if $result.exit_code == 0 {
        print $"(ansi green)Tagged:(ansi reset) ($source) -> ($target)"
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}

def cmd-prune [] {
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

def cmd-inspect [args: list<string>] {
    ensure-running
    if ($args | is-empty) {
        print $"(ansi red)Error:(ansi reset) Image name required"
        exit 1
    }
    let image = ($args | first)
    let result = (do { ^container image inspect $image } | complete)
    if $result.exit_code == 0 {
        print $result.stdout
    } else {
        print $"(ansi red)Error:(ansi reset) ($result.stderr)"
        exit 1
    }
}
