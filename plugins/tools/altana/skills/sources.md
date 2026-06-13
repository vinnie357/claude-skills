# Sources

## altana

- **Repo:** https://github.com/vinnie357/altana (private)
- **Accessed:** 2026-06-13
- **Used for:** subcommand shapes (delegate, council, harness, models, list, doctor), JSON result contract, status codes, response protocol (## Answer / ## Evidence / ## Confidence + sentinel), config discovery order, harness TOML schema (agent, executor, model, write, timeout_s, env), prompt templates, op:// secret resolution, awman vs raw executor semantics, model picker (TTY vs non-TTY), VM networking pattern (host gateway IP)
- **Key topics:** altana CLI usage, harness presets, council synthesis, foreground vs background invocation, log file paths (`$TMPDIR/altana/<run_id>/<harness>.log`)

## altana docs/usage.md

- **Source:** `/Users/vinnie/github/altana/docs/usage.md`
- **Accessed:** 2026-06-13
- **Used for:** Local model walkthrough (VM networking, host gateway discovery), model picker interactive flow, response protocol wrapping detail, secrets section (op:// scrubbing), troubleshooting guidance
- **Key topics:** ANTHROPIC_BASE_URL in containers, ANTHROPIC_AUTH_TOKEN vs ANTHROPIC_API_KEY, picker selection flow, sentinel stripping

## altana harnesses.example.toml

- **Source:** `/Users/vinnie/github/altana/harnesses.example.toml`
- **Accessed:** 2026-06-13
- **Used for:** Canonical harness field names and TOML layout, prompt.critique template example, executor values (awman / raw)
- **Key topics:** Config schema, named harnesses, op:// references pattern
