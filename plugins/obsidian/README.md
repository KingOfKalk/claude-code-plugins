# obsidian

Interact with Obsidian vaults via the [Obsidian CLI](https://github.com/Yakitrak/obsidian-cli): create, read, search, edit, and restructure notes following the [PARA method](https://fortelabs.com/blog/para/). Includes a daily journal skill for morning planning and evening review workflows.

## Installation

```
/plugin install obsidian@kingofkalk-claude-code-plugins
```

## Skills

- [`vault`](skills/vault/SKILL.md) — create, read, search, edit, move, and restructure notes through the Obsidian CLI. Enforces PARA classification rules and documents the CLI's known silent-failure modes so data is not lost. Bundles reference material under [`skills/vault/references/`](skills/vault/references/): a CLI cheatsheet, a silent-failure guide, and a PARA method guide.
- [`daily`](skills/daily/SKILL.md) — structured morning-planning and evening-review workflows for the user's daily journal (5–15 minutes each). Depends on the `vault` skill for vault access and CLI operations.
