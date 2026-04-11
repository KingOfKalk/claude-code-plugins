# Obsidian CLI — Cheat Sheet

**Version:** 1.12+ | **Status:** Early access, syntax may change
**Prereq:** Obsidian must be running (CLI = IPC client, not standalone)
**Enable:** Settings → General → Command line interface
**Docs:** https://obsidian.md/help/cli

---

## Syntax

```
obsidian [vault=<name>] <command> [key=value …] [flags]
```

- `vault=` **must be first** param, always
- Values with spaces → quote: `content="Hello world"`
- `\n` and `\t` work in content values
- `--copy` → copies output to clipboard (any command)
- `total` flag → returns count instead of list
- `file=` → fuzzy wikilink match (no path, no extension)
- `path=` → exact vault-relative path with extension
- Output formats: `text` (default), `json`, `csv`, `tsv`, `yaml`, `md`, `paths`, `tree`

---

## Files & Folders

- `file file=<n>` → show metadata (size, dates)
- `files folder=<f> ext=<e> sort=modified limit=<n>` → list files
- `folder path=<p> info=files|folders|size` → folder info
- `folders folder=<f>` → list folders
- `open file=<n>` → open file (flag: `newtab`)
- `create name=<n> path=<p> content=<c> template=<t>` → create file
  - Auto-appends `.md` — don't include extension
  - Flags: `overwrite`, `open`, `newtab`, `silent`
  - ⚠ `overwrite` without `content=` → **truncates to 0 bytes, no warning**
  - ⚠ Without `silent` → opens GUI, breaks automation
  - Won't mkdir → do `mkdir -p` before
- `read file=<n>` → print contents to stdout
- `append file=<n> content=<c>` → append (flag: `inline`)
- `prepend file=<n> content=<c>` → prepend after frontmatter
- `move file=<n> to=<dest>` → move/rename, updates links
- `rename file=<n> name=<new>` → rename in place, updates links
- `delete file=<n>` → trash (flag: `permanent` → real delete)

---

## Daily Notes

- `daily` → open/create today's note
- `daily:path` → print expected path
- `daily:read` → print contents
- `daily:append content=<c>` → append (flags: `inline`, `open`)
- `daily:prepend content=<c>` → prepend after frontmatter

```
obsidian daily:append content="- [ ] Buy groceries"
```

---

## Search

- `search query=<q>` → full-text → file paths (flags: `total`, `case`)
- `search:context query=<q>` → grep-style with line context
- `search:open query=<q>` → open search panel in GUI
- Params: `path=`, `limit=`, `format=text|json`

```
obsidian search query="status::active" format=json
```

---

## Properties & Aliases

- `properties file=<n> name=<n> sort=count format=yaml|tsv` → list props
  - Flags: `total`, `counts`, `active`
- `property:read name=<n> file=<f>` → read value
- `property:set name=<n> value=<v> type=text|list|number|checkbox|date`
  - ⚠ Stores value as string literal, not native YAML type
  - ⚠ No-ops on externally written files (stale cache, 0–3s window)
  - Fix: add 3–5s delay or `obsidian open path=<file>` first
- `property:remove name=<n> file=<f>` → remove
- `aliases file=<n>` → list aliases (flags: `total`, `verbose`)

---

## Tags

- `tags file=<n> sort=count format=json|tsv` → list tags
  - Flags: `total`, `counts`, `active`
  - ⚠ Without `file=` → scopes to active file, returns nothing
  - Fix: always query vault-wide or specify file
- `tag name=<n>` → tag info, files with that tag (flags: `total`, `verbose`)

---

## Tasks

- `tasks file=<n> status=<char> format=json|tsv` → list tasks
  - Flags: `total`, `done`, `todo`, `verbose`, `active`, `daily`
  - ⚠ Without scope → scopes to active file, returns 0 tasks
  - Fix: use `tasks todo` with explicit `file=` or `daily` flag
- `task ref=<path:line>` → single task
  - Flags: `toggle`, `done`, `todo`
  - `status=<char>` → set custom status

```
obsidian tasks daily todo
obsidian task ref="Recipe.md:8" toggle
```

---

## Links

- `backlinks file=<n>` → incoming links (flags: `counts`, `total`)
- `links file=<n>` → outgoing links (flag: `total`)
- `unresolved` → broken wikilinks (flags: `total`, `counts`, `verbose`)
- `orphans` → files with 0 incoming links
- `deadends` → files with 0 outgoing links

---

## Bookmarks

- `bookmarks format=json|tsv` → list (flags: `total`, `verbose`)
- `bookmark file=<n> subpath="#Heading"` → bookmark a file/heading
- `bookmark search=<q> title=<t>` → bookmark a search
- `bookmark url=<u> title=<t>` → bookmark a URL

---

## Templates

- `templates` → list (flag: `total`)
- `template:read name=<n>` → read content (flag: `resolve` → processes variables)
- `template:insert name=<n>` → insert into active file
  - ⚠ No `path=` param — always targets active file
  - Use `create path=<p> template=<t>` for new file from template

---

## File History & Diff

- `diff file=<n> from=<v> to=<v> filter=local|sync` → compare versions
- `history file=<n>` → local File Recovery versions
- `history:list` → all files with local history
- `history:read file=<n> version=<v>` → read version (default: 1)
- `history:restore file=<n> version=<v>` → restore
- `history:open file=<n>` → open File Recovery UI

---

## Bases

- `bases` → list `.base` files
- `base:views` → views in active base
- `base:create file=<f> view=<v> name=<n> content=<c>` → create item (flags: `open`, `newtab`)
- `base:query file=<f> view=<v> format=json|csv|tsv|md|paths` → query

---

## Workspace & Tabs

- `workspace` → show layout tree (flag: `ids`)
- `workspaces` → list saved (flag: `total`)
- `workspace:save name=<n>` / `workspace:load name=<n>` / `workspace:delete name=<n>`
- `tabs` → list open tabs (flag: `ids`)
- `tab:open group=<id> file=<f> view=<type>` → open tab
- `recents` → recently opened files

---

## Commands & Utility

- `commands filter=<prefix>` → list command IDs
- `command id=<id>` → execute command
- `hotkeys format=json` → list hotkeys (flags: `total`, `verbose`)
- `hotkey id=<id>` → hotkey for command
- `outline file=<n> format=tree|md|json` → heading structure
- `wordcount file=<n>` → word/char count (flags: `words`, `characters`)
- `random folder=<f>` → open random note (flag: `newtab`)
- `random:read folder=<f>` → print random note
- `unique name=<n> content=<c>` → create Zettelkasten note
- `web url=<u>` → open URL in viewer (flag: `newtab`)

---

## General

- `help` / `help <command>` → show help
- `version` → print version
- `reload` → reload app window
- `restart` → restart app
- `vault info=name|path|files|folders|size` → vault info
- `vaults` → list known vaults (flags: `total`, `verbose`)


---

## Silent Failures (v1.12)

**All exit codes are 0, even on error. Never trust `$?`. Parse stdout for `Error:` string.**

- `tasks` / `tags` without file scope → scopes to active file → returns nothing
- `properties format=json` → silently ignored, returns YAML → use `format=yaml|tsv`
- `create` without `silent` → opens GUI
- `create overwrite` without `content=` → truncates file to 0 bytes, "intended behavior"
- `property:set` after external write → no-op (stale cache, 0–3s)
- **Windows:** admin terminal → silent failure, use normal user
- **Windows/WSL2:** `property:*` → exit 255, no fix
- **Linux headless:** use .deb not snap, run under xvfb (`DISPLAY=:5`)

---

## Safe Patterns

```
obsidian vault="MyVault" tasks daily todo
obsidian vault="MyVault" tags sort=count format=tsv
obsidian vault="MyVault" search query="x" format=json
obsidian vault="MyVault" create name="x" content="y" silent
obsidian vault="MyVault" properties path=<p> format=tsv
```

- Always pass `vault=` first
- Always pass `content=` with `create overwrite`
- Always use `silent` with `create` in scripts
- Never trust exit codes — parse stdout
