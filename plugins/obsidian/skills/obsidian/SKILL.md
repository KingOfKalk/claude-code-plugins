---
name: obsidian
description: >
  Interact with Obsidian vaults via the Obsidian CLI. Use this skill whenever the user wants to
  create, read, search, edit, move, restructure, or query notes in Obsidian. Also use when the user
  mentions daily notes, journals, PARA method, knowledge management, note-taking, vault organization,
  backlinks, tags, tasks, templates, or anything related to their Obsidian workflow. Trigger on
  mentions of "obsidian", "vault", "note", "daily note", "journal", "PARA", "projects folder",
  "areas folder", "resources folder", "archives folder", "zettelkasten", or any request to find,
  summarize, or restructure knowledge. Even casual requests like "add this to my notes",
  "what did I write about X", or "clean up my vault" should trigger this skill.
---

# Obsidian Skill

Interact with an Obsidian vault through the Obsidian CLI. The user's vault follows the PARA method.

## Step 0 — Always Do First

Before ANY action, get the current date and time:

```bash
date '+%Y-%m-%d %H:%M:%S %A'
```

Store the result mentally — you need it for daily notes, timestamps, frontmatter, file naming, and contextual awareness (e.g. "today", "this week", "yesterday").

## Step 1 — Read References As Needed

Three reference files are bundled. Read them before acting:

| When                                            | Read                                                                  |
| ----------------------------------------------- | --------------------------------------------------------------------- |
| Any CLI command                                 | `references/Obsidian_CLI_Cheatsheet.md` — full command reference      |
| Debugging or unexpected behavior                | `references/Obsidian_CLI_1_12_Silent.md` — known bugs and workarounds |
| Organizing, classifying, or restructuring notes | `references/PARA_Method_Guide.md` — classification rules              |

Read the CLI cheatsheet on first use in every conversation. You don't need to re-read it if you've already read it in this conversation.

## Step 2 — Vault Discovery

If you don't know the vault name yet, discover it:

```bash
obsidian vaults
```

Then always pass `vault="<Name>"` as the first parameter in every command.

## Step 3 — CLI Safety Rules

These are non-negotiable. The CLI has silent failures that destroy data:

1. **Never trust exit codes.** Always parse stdout for `Error:` strings.
2. **Always use `silent` flag with `create`.** Without it, Obsidian GUI steals focus.
3. **Never use `create overwrite` without `content=`.** It truncates the file to 0 bytes silently.
4. **Always scope `tasks` and `tags` commands.** Without scope they return nothing (scoped to active file). Use `tasks daily todo`, `tasks all todo`, or explicit `file=`.
5. **Don't use `format=json` for `properties`.** It's silently ignored. Use `format=yaml` or `format=tsv`.
6. **After writing a file externally, wait 3-5 seconds** before using `property:set` — stale cache causes silent no-ops.
7. **`mkdir -p` before `create`** — the CLI won't create directories.

## Step 4 — PARA-Aware Vault Structure

The user's vault follows this structure:

```
0-Inbox/          ← capture buffer, unprocessed items
1-Projects/       ← active, time-bound work with deadlines
2-Areas/          ← ongoing responsibilities (no end date)
3-Resources/      ← reference material, interests
4-Archives/       ← inactive items from 1–3
```

### Classification Decision Tree

When creating or moving notes, classify by asking in order — stop at first "yes":

1. Does it belong to an active project with a deadline? → `1-Projects/`
2. Does it relate to an ongoing area of responsibility? → `2-Areas/`
3. Is it a topic of interest or reference? → `3-Resources/`
4. None of the above / no longer active? → `4-Archives/`

### Project vs. Area — The Verb Test

- **Project verbs:** finalize, ship, deliver, publish, launch → has a deadline, has a finish line
- **Area verbs:** manage, maintain, ensure, oversee → ongoing, never "done"

If unsure, ask the user. Don't guess.

## Common Workflows

### Create a Note

```bash
mkdir -p "<vault_path>/<para_folder>/<subfolder>"
obsidian vault="V" create name="Note Title" path="<para_folder>/<subfolder>" content="---\ncreated: 2025-01-15\ntags:\n  - tag1\n---\n\n# Note Title\n\nContent here" silent
```

- Always add YAML frontmatter with at least `created` date (from Step 0).
- Place in the correct PARA folder. Ask the user if classification is ambiguous.
- Use `silent` flag. Always.

### Daily Journal

```bash
obsidian vault="V" daily
obsidian vault="V" daily:append content="## <TIME>\n\n- Entry text here" inline
```

- Use `daily:append` to add entries with a timestamp heading.
- If the daily note doesn't exist yet, `daily` creates it from the user's template.
- Use `daily:read` to check what's already there before appending.

### Search / Find Information

```bash
obsidian vault="V" search query="search terms" format=json
obsidian vault="V" search:context query="search terms"
```

- Use `search:context` when the user wants to see matching lines, not just file names.
- Combine with `read file="..."` to fetch full note content.
- For tag-based searches: `obsidian vault="V" tag name="tagname"`.

### Restructure / Move Notes

```bash
obsidian vault="V" move file="Note" to="4-Archives/old-project"
```

- `move` updates all internal links automatically.
- When archiving a completed project, move the entire project folder to `4-Archives/`.
- When restructuring, explain what you're doing and why (PARA classification reasoning).

### Read a Note

```bash
obsidian vault="V" read file="Note Title"
```

- `file=` uses fuzzy wikilink matching — no path, no extension needed.
- For exact path: use `path=` with vault-relative path including `.md`.

### List & Explore

```bash
obsidian vault="V" files folder="1-Projects" sort=modified
obsidian vault="V" folders folder="1-Projects"
obsidian vault="V" tags sort=count format=tsv
obsidian vault="V" tasks all todo
```

### Properties / Metadata

```bash
obsidian vault="V" properties path="1-Projects/my-note.md" format=tsv
obsidian vault="V" property:set name="status" value="done" file="Note" type=text
```

- Remember: `format=json` is broken for properties. Use `tsv` or `yaml`.

## Response Style

- When showing note contents to the user, format them cleanly.
- When creating or modifying notes, confirm what you did with the file path.
- When classifying into PARA, briefly state your reasoning.
- If a CLI command produces unexpected output, check `references/Obsidian_CLI_1_12_Silent.md` for known bugs before retrying.
- Keep responses concise — the user is busy.
