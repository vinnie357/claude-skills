# Bash to Nushell migration

Side-by-side translations of common bash idioms. Load when converting bash/zsh scripts to Nushell.

## Common Operations

```bash
# Bash
find . -name "*.txt" | wc -l

# Nushell
ls **/*.txt | length
```

```bash
# Bash
cat file.json | jq '.users[] | select(.age > 25) | .name'

# Nushell
open file.json | get users | where age > 25 | get name
```

```bash
# Bash
for file in *.txt; do
  mv "$file" "${file%.txt}.md"
done

# Nushell
ls *.txt | each { |f| mv $f.name ($f.name | str replace ".txt" ".md") }
```

## Redirection

Nushell does NOT support bash file-descriptor redirection (`2>&1`, `2>/dev/null`). Use Nu redirection operators instead — see the "Critical gotchas" section in SKILL.md and `shell-interop.md` for the full pitfall writeup.

```bash
# Bash
command > out.log 2>&1

# Nushell
command out+err> out.log   # or the o+e> short form
```
