# docker

Manage Docker containers and Docker Compose services with automatic devcontainer detection and safety constraints. Each skill detects when it is running inside a devcontainer and refuses destructive actions that would tear down the environment it is running in.

## Installation

```
/plugin install docker@kingofkalk-claude-code-plugins
```

## Skills

- [`container`](skills/container/SKILL.md) — manage Docker containers through the `docker` CLI: `ps`, `logs`, `exec`, `stop`, `start`, `rm`, `images`, `pull`, `build`, `inspect`, `stats`, `prune`. Guards `exec`, `stop`, and `rm` so the skill cannot destroy its own devcontainer.
- [`compose`](skills/compose/SKILL.md) — manage Docker Compose services: `status`, `up`, `rebuild`, `restart`, `stop`, `logs`, `pull`, `config`, `health`. Blocks `down` inside a devcontainer, forces `--no-deps` on `up`, requires explicit service names for `restart`/`stop`, and forbids `--follow` on logs.
