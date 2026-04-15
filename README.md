# Claude Code Plugins

A collection of Claude Code plugins, installable via the marketplace.

## Installation

```
/plugin marketplace add kingofkalk/claude-code-plugins
```

or in your terminal:

```bash
claude plugin marketplace add kingofkalk/claude-code-plugins
```


To pin a specific version:

```
/plugin marketplace add kingofkalk/claude-code-plugins@v1
```

## Installing a single plugin

Once the marketplace is added, install individual plugins by name. The
marketplace identifier is `kingofkalk-claude-code-plugins`:

```
/plugin install git@kingofkalk-claude-code-plugins
/reload-plugins
```

## Available Plugins

- [**git**](plugins/git/README.md) — atomic git commits following the Conventional Commits spec, auto-splitting unrelated changes.
- [**docker**](plugins/docker/README.md) — Docker CLI and Docker Compose skills with automatic devcontainer detection and safety constraints.
- [**obsidian**](plugins/obsidian/README.md) — PARA-aware Obsidian vault operations via the Obsidian CLI, plus a daily journal skill for morning planning and evening review.
- [**presentation-drafter**](plugins/presentation-drafter/skills/presentation-drafter/SKILL.md) — *skill* — draft structured presentation outlines in Markdown using SCR and Winston's "How to Speak" principles.
- [**statusline**](plugins/statusline/README.md) — *statusline* — colorful statusline showing model, cwd, git branch/dirty state, context-window usage bar, and output style.
