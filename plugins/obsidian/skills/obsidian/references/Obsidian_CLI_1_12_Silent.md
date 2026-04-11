# Obsidian CLI 1.12 — Silent Failures

## Context
- CLI = IPC client to running Obsidian GUI, not standalone tool
- 13 silent failures found, exit code always 0, no error detection possible via `$?`
- "Early access feature" — syntax will change

---

## Critical Failures

### Exit codes broken
- Every command returns exit code 0, even on error
- **Fix:** parse stdout for `Error:` string

### Tasks/Tags default to "active file"
- `tasks todo` → returns 0 tasks (scoped to focused file)
- `tags counts` → returns nothing
- **Fix:** always use `tasks all todo` / `tags all counts`

### `properties format=json` silently ignored
- Returns YAML, no error
- **Fix:** use `format=yaml` or `format=tsv` only

### `create` opens GUI
- Disrupts automation pipelines
- **Fix:** always add `silent` flag

### `create overwrite` without `content=` → data loss
- Truncates file to 0 bytes, reports success
- Obsidian team says "intended behavior"
- **Fix:** validate content non-empty before call

### `property:set` no-ops on externally written files
- Stale in-memory state, 0–3s window after external write
- **Fix:** add 3–5s delay or `obsidian open path=<file>` first

---

## Platform Bugs

### Windows
- Console shim failed on colon subcommands + key=value → fixed in 1.12.2
- Admin terminal → silent failure, use normal user
- WSL2 interop → `property:*` returns exit 255, no fix

### Linux headless
- Use .deb not snap
- Run under xvfb with `DISPLAY=:5`
- systemd: set `PrivateTmp=false`

---

## Safe Command Patterns

```
obsidian tasks all todo                    # not: tasks todo
obsidian tags all counts sort=count        # not: tags counts
obsidian search query="x" format=json matches
obsidian create name="x" content="y" silent
obsidian properties path=<p> format=tsv    # not: format=json
```

- Always pass `vault="Name"` first
- `create` won't mkdir — do `mkdir -p` before
- `create` with `template=` may ignore `path=`

---

## Mitigations

- **General:** never trust exit codes, always parse stdout
