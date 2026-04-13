# Claude Code Plugins

A collection of Claude Code plugins, installable via the marketplace.

## Installation

```
/plugin marketplace add KingOfKalk/claude_code_plugins
```

To pin a specific version:

```
/plugin marketplace add KingOfKalk/claude_code_plugins@v1
```

## Available Plugins

- [**commit**](plugins/commit/skills/commit/SKILL.md) — *skill* — atomic git commits following the Conventional Commits spec, auto-splitting unrelated changes.
- [**docker**](plugins/docker/skills/docker/SKILL.md) — *skill* — manage Docker containers with devcontainer detection and self-protection.
- [**docker-compose**](plugins/docker-compose/skills/docker-compose/SKILL.md) — *skill* — manage Docker Compose services with devcontainer safety constraints.
- [**obsidian**](plugins/obsidian/skills/obsidian/SKILL.md) — *skill* — PARA-aware Obsidian vault operations via the Obsidian CLI, with safety rules for known silent-failure modes.
- [**presentation-drafter**](plugins/presentation-drafter/skills/presentation-drafter/SKILL.md) — *skill* — draft structured presentation outlines in Markdown using SCR and Winston's "How to Speak" principles.
- [**statusline**](plugins/statusline/README.md) — *statusline* — colorful statusline showing model, cwd, git branch/dirty state, context-window usage bar, and output style.
