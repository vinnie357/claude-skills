#!/usr/bin/env nu

# Backstop for ordinary explicit git/gh/glab writes, not a shell security
# boundary. Reuse the merge gate's tokenizer; never execute payload commands.
# Aliases, wrapper scripts, indirect commands, editor/default/generated bodies,
# inherited commit messages and encoded API bodies remain manual-review inputs.
# Explicit body files must already exist. Dynamic values/stdin require a separate
# preparation call followed by a write using a literal, inspectable body file.
use scan-merge-writes.nu tokenize-command

def has-attribution [text: string]: nothing -> bool {
    $text =~ '(?i)🤖|\b(co-authored-by|signed-off-by|assisted-by)\s*:|\b(generated|written|created|authored|assisted|powered)[\s_-]+(with|by)[\s_-]+\[?(?:claude\b|anthropic\b|codex\b|openai\b|chatgpt\b|copilot\b|gemini\b|cursor\b|ai\b|an?\s+ai\b)'
}

def dynamic [value: string]: nothing -> bool {
    $value =~ '\$(\(|\{|[A-Za-z_])|`' or ($value | str starts-with '<(')
}

def read-body [value: string, cwd: string]: nothing -> string {
    if $value == '-' or (dynamic $value) or ($value | is-empty) {
        return 'uninspectable'
    }
    let path = ($cwd | path join $value)
    if ($path | path type) != 'file' { return 'uninspectable' }
    let body = (try { open --raw $path | into string } catch { null })
    if $body == null { return 'uninspectable' }
    if (has-attribution $body) { return 'attribution' }
    ''
}

# Find a command after environment assignments and supported global options.
def invocation [tokens: list<string>, cwd: string]: nothing -> record {
    mut i = 0
    mut base = $cwd
    while $i < ($tokens | length) and (($tokens | get $i) =~ '^[A-Za-z_][A-Za-z0-9_]*=') { $i += 1 }
    let executable = ($tokens | get -o $i | default '' | path basename)
    $i += 1
    if $executable not-in ['git' 'gh' 'glab'] { return {tool: '', args: [], cwd: $base} }
    while $i < ($tokens | length) {
        let t = ($tokens | get $i)
        if $t in ['-C' '-c' '--git-dir' '--work-tree' '-R' '--repo' '--hostname'] {
            let value = ($tokens | get -o ($i + 1) | default '')
            if $t == '-C' { $base = ($base | path join $value | path expand) }
            $i += 2
        } else if $t =~ '^--(git-dir|work-tree|repo|hostname)=' or $t =~ '^-R.+' {
            $i += 1
        } else { break }
    }
    {tool: $executable, args: ($tokens | skip $i), cwd: $base}
}

def api-write [args: list<string>]: nothing -> bool {
    # Ordinary GraphQL queries are reads even though HTTP uses POST. A query
    # supplied indirectly still needs inspection; encoded queries are out of scope.
    if 'graphql' in $args and not ($args | any {|t| $t =~ '\bmutation\b|query=[$@]|^--input(=|$)'}) { return false }
    mut method = ''
    for entry in ($args | enumerate) {
        if $entry.item in ['-X' '--method'] { $method = ($args | get -o ($entry.index + 1) | default '') }
        if $entry.item =~ '^--method=' { $method = ($entry.item | str replace '--method=' '') }
        if $entry.item =~ '^-X.+' { $method = ($entry.item | str substring 2..) }
    }
    if ($method | str upcase) in ['GET' 'HEAD' 'OPTIONS'] { return false }
    if ($method | is-not-empty) { return true }
    $args | any {|t| $t =~ '^(-[fF]|--(field|raw-field|input)(=|$))' }
}

def is-write [tool: string, args: list<string>]: nothing -> bool {
    let verb = ($args | get -o 0 | default '')
    let action = ($args | get -o 1 | default '')
    if '--help' in $args or '-h' in $args { return false }
    if $tool == 'git' {
        if $verb in ['commit' 'merge' 'revert' 'cherry-pick' 'notes' 'push'] { return true }
        if $verb in ['branch' 'tag'] { return (not ($args | any {|t| $t in ['--list' '-l' '--contains' '--points-at']})) }
        if $verb in ['checkout' 'switch'] { return ($args | any {|t| $t in ['-b' '-B' '-c' '-C' '--orphan'] or $t =~ '^--orphan=|^-[bBcC].+'}) }
        if $verb == 'config' { return (($args | any {|t| $t =~ '^branch\..*\.description$'}) and (not ($args | any {|t| $t in ['--get' '--get-all' '--get-regexp' '--list' '-l']}))) }
        return false
    }
    if $verb == 'api' { return (api-write ($args | skip 1)) }
    $verb in ['pr' 'mr' 'issue' 'release' 'repo' 'label'] and $action in ['create' 'edit' 'update' 'comment' 'note' 'review' 'merge' 'close' 'reopen']
}

def inspect-write [call: record]: nothing -> string {
    let args = $call.args
    if not (is-write $call.tool $args) { return '' }
    if (has-attribution ($args | str join ' ')) { return 'attribution' }
    if $call.tool == 'git' and ($args | get -o 0) == 'commit' and ($args | any {|t| $t in ['-s' '--signoff']}) { return 'attribution' }
    let verb = ($args | get -o 0 | default '')
    let api = $verb == 'api'
    mut i = 0
    while $i < ($args | length) {
        let t = ($args | get $i)
        let parts = ($t | split row '=' | first)
        let flag = if $t =~ '^-[mFfbtd].+' and not ($t | str starts-with '--') { $t | str substring 0..1 } else { $parts }
        let file_flag = if $call.tool == 'git' {
            ($verb in ['commit' 'tag' 'notes' 'merge'] and $flag in ['-F' '--file']) or ($verb == 'commit' and $flag in ['--template' '-t'])
        } else {
            $flag in ['--body-file' '--description-file' '--notes-file' '--input'] or ($call.tool == 'gh' and $verb in ['pr' 'issue' 'release'] and $flag == '-F')
        }
        let text_flag = $flag in ['--body' '--title' '--description' '--message' '--notes' '--subject' '--field' '--raw-field' '-m' '-b' '-d'] or ($call.tool != 'git' and $flag in ['-t' '-f' '-F'])
        if $file_flag or $text_flag {
            let value = if ($t | str starts-with ($flag + '=')) {
                $t | str substring (($flag | str length) + 1)..
            } else if $t != $flag {
                $t | str substring ($flag | str length)..
            } else {
                $i += 1
                $args | get -o $i | default ''
            }
            if $file_flag {
                let result = (read-body $value $call.cwd)
                if $result != '' { return $result }
            } else if (dynamic $value) { return 'uninspectable'
            } else if $api and $flag in ['-F' '--field'] and ($value =~ '=@') {
                let file = ($value | split row '=@' | skip 1 | str join '=@')
                let result = (read-body $file $call.cwd)
                if $result != '' { return $result }
            } else if $call.tool == 'glab' and $flag in ['--description' '-d'] and ($value | str starts-with '@') {
                let result = (read-body ($value | str substring 1..) $call.cwd)
                if $result != '' { return $result }
            }
        }
        $i += 1
    }
    ''
}

def main [] {
    let payload = (try { ^cat | from json } catch { null })
    if ($payload | get -o tool_name) != 'Bash' { exit 0 }
    let command = ($payload | get -o tool_input.command)
    if ($command | describe) != 'string' { exit 0 }
    mut cwd = ($payload | get -o cwd | default $env.PWD)
    if ($cwd | describe) != 'string' { $cwd = $env.PWD }
    for tokens in (tokenize-command $command) {
        # Track ordinary `cd dir && ...`; other shell state is not evaluated.
        if ($tokens | get -o 0) == 'cd' and ($tokens | length) == 2 {
            let dir = ($tokens | get 1)
            if not (dynamic $dir) { $cwd = ($cwd | path join $dir | path expand) }
        }
        let reason = (inspect-write (invocation $tokens $cwd))
        if $reason != '' {
            if $reason == 'attribution' {
                print -e 'blocked: remove robot emoji and authorship/generation attribution from git and forge text before retrying (/core:git).'
            } else {
                print -e 'blocked: cannot inspect git/forge message input. Prepare a readable UTF-8 body file in a separate call, then retry with its literal path (/core:git).'
            }
            exit 2
        }
    }
    exit 0
}
