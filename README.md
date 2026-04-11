# Skills

A collection of Claude Code skills, installable via the marketplace/plugin feature.

## Installation

```
/plugin marketplace add kingofkalk/skills
```

To pin a specific version:

```
/plugin marketplace add kingofkalk/skills@v1
```

## Available Skills

- [**commit**](plugins/commit/skills/commit/SKILL.md) — atomic git commits following the Conventional Commits spec, auto-splitting unrelated changes.
- [**docker**](plugins/docker/skills/docker/SKILL.md) — manage Docker containers with devcontainer detection and self-protection.
- [**docker-compose**](plugins/docker-compose/skills/docker-compose/SKILL.md) — manage Docker Compose services with devcontainer safety constraints.
- [**obsidian**](plugins/obsidian/skills/obsidian/SKILL.md) — PARA-aware Obsidian vault operations via the Obsidian CLI, with safety rules for known silent-failure modes.
- [**presentation-drafter**](plugins/presentation-drafter/skills/presentation-drafter/SKILL.md) — draft structured presentation outlines in Markdown using SCR and Winston's "How to Speak" principles.
