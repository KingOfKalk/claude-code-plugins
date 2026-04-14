---
name: daily
description: Manage the user's daily journal in Obsidian using a structured morning/evening workflow. Use this skill whenever the user mentions their daily journal, daily note, morning planning, evening review, daily agenda, daily log, or any variation of "plan my day", "review my day", "update my journal", "what's on today", "wrap up my day", "end of day", "start of day", or "daily". Also trigger when the user asks to check, create, or update today's (or any specific date's) journal entry. This skill depends on the `vault` skill for vault access and CLI operations — always read the `vault` SKILL.md first.
---

# Obsidian Daily Journal

A skill for preparing, updating, and maintaining daily journal entries in the user's Obsidian vault. Supports two distinct workflows — **morning planning** and **evening review** — designed to take 5–15 minutes each.

## Dependencies

- **`vault` skill**: Read it first for vault path, CLI commands, file conventions, and `claude.md` rules.
- **User's `claude.md`**: Always check for vault-specific conventions before writing.

## Journal Template

Do NOT hardcode or assume the template structure. Instead:

1. Use the `vault` skill to locate the journal template in the vault (check Obsidian's template folder / daily notes settings).
2. Read the actual template file to understand the current structure — it may have changed since this skill was written.
3. Use that template as-is when creating new journal entries.

### Rules when working with the template

- Never modify or regenerate `dataviewjs` or `dataview` code blocks — treat them as read-only.
- Tasks use standard Obsidian checkbox syntax: `- [ ]` (open) / `- [x]` (done).
- Keep frontmatter fields intact. Only update fields like `location` if the user explicitly says so.
- Dates follow `YYYY-MM-DD` format.
- If the template can't be found, ask the user — don't guess.

## Workflow

### Step 0: Determine mode

Ask the user (or infer from context/time cues):

| Signal                                                           | Mode                                       |
| ---------------------------------------------------------------- | ------------------------------------------ |
| "plan my day", "morning", "start of day", "what's on today"      | Morning                                    |
| "review", "wrap up", "end of day", "evening", "how did today go" | Evening                                    |
| Ambiguous or just "daily" / "journal"                            | Ask: "Morning planning or evening review?" |

### Step 1: Locate or create the journal entry

1. Use the `vault` skill to check if today's journal file already exists.
2. If it exists → read it.
3. If it doesn't exist → look up the journal template (see "Journal Template" above), then create the entry from it, filling in today's date.
4. If the user specifies a different date → use that date instead.

### Step 2a: Morning Planning (5–15 min)

Goal: Help the user walk into their day with clarity.

1. **Read yesterday's journal** (if it exists) — check for:
   - Unfinished tasks (carry forward if still relevant)
   - Any "tomorrow" notes in the Log
2. **Check external context** if available (calendar, email via connected tools). Summarize what's coming up today.
3. **Populate the Agenda section** with:
   - Carried-over tasks from yesterday
   - Calendar events / meetings
   - Anything the user mentions
4. **Populate the Tasks section** with actionable items derived from the agenda. Keep them concrete and completable.
5. **Present a summary** to the user and ask if anything is missing or should change.
6. **Write the file** once confirmed.

Keep the tone concise and practical — no motivational fluff. The user wants to think clearly, not be coached.

### Step 2b: Evening Review (5–15 min)

Goal: Help the user close the day cleanly and capture what matters.

1. **Read today's journal** — review Agenda and Tasks.
2. **Ask the user** (briefly, not an interrogation):
   - "What got done? Anything to note?"
   - "Anything to carry to tomorrow?"
3. **Update the Tasks section**: Mark completed items `- [x]`, leave open items as-is or move to tomorrow's note if the user says so.
4. **Update the Log section** with:
   - Key outcomes, decisions, observations the user shares
   - Keep it bullet-point style, concise
5. **Optionally preview tomorrow**: If the user wants, create tomorrow's journal and seed its Agenda with carried-over items.
6. **Write the file** once confirmed.

### PARA Integration

The journal itself lives outside the PARA hierarchy (it's a daily artifact, not a project or area). But when the user mentions work related to a specific Project or Area:

- Link to the relevant note using `[[Note Name]]` wikilink syntax.
- If a task belongs to a PARA project, tag it or link it: `- [ ] Finish proposal draft → [[Q3 Proposal]]`
- Don't reorganize the user's vault — just create the connections.

## Important Reminders

- **Don't over-ask.** Morning and evening should feel lightweight. 2–3 focused questions max, then write.
- **Don't invent content.** Only add what the user tells you, what's carried from yesterday, or what comes from connected tools (calendar/email). Never fabricate agenda items or tasks.
- **Preserve existing content.** When updating a journal that already has entries, append — don't overwrite.
- **Respect the user's style.** Read past journal entries to match their tone, level of detail, and conventions. If they write terse bullets, you write terse bullets.
