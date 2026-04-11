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

### commit

Create atomic git commits following the [Conventional Commits](https://www.conventionalcommits.org/) specification. Automatically splits unrelated changes into separate commits.

**Usage:** `/commit [scope or guidance, e.g. 'only auth changes']`

Features:
- Follows Conventional Commits 1.0.0 format
- Automatically splits unrelated changes into atomic commits
- Presents a commit plan for review before executing
- Supports path and semantic arguments for filtering changes

### docker

Manage Docker containers with automatic devcontainer detection and self-protection.

**Usage:** `/docker <action> [target]`

Features:
- List, inspect, start, stop, and remove containers
- Automatic devcontainer detection — refuses to stop/remove the container you're running in
- Supports logs, exec, build, pull, stats, and prune
- Safe defaults with user confirmation for destructive actions

### docker-compose

Manage Docker Compose services with automatic devcontainer detection and safety constraints.

**Usage:** `/docker-compose <action> [service]`

Features:
- Status, rebuild, restart, stop, up, down, logs, pull, config, and health checks
- Blocks `docker compose down` inside devcontainers to protect the dev stack
- Validates service names against the compose project
- Auto-shows logs on failure and unhealthy health check details

### presentation-drafter

Draft structured presentation outlines in Markdown using the SCR (Situation-Complication-Resolution) framework and Patrick Winston's "How to Speak" principles.

**Usage:** `/presentation-drafter`

Features:
- SCR storyline framework for persuasive/business talks
- Winston's engagement heuristics for teaching/training sessions
- Includes reference cheatsheets and reusable templates
- Outputs Markdown outlines — never slides directly

### obsidian

Interact with Obsidian vaults via the Obsidian CLI. Create, read, search, edit, and restructure notes in a PARA-organized vault with safety rules for the CLI's known silent-failure modes.

**Usage:** Triggered automatically when the user mentions Obsidian, vaults, notes, daily notes, journals, PARA, or knowledge management.

Features:
- PARA-aware classification (Projects / Areas / Resources / Archives) with a decision tree
- Daily note and journal workflows (create, append, read)
- Search, tag, task, and property queries via the Obsidian CLI
- Bundled references: CLI cheatsheet, known-bug workarounds (Obsidian CLI 1.12), and a PARA method guide
- Safety rules to avoid silent data loss (never trust exit codes, always `silent` on `create`, etc.)
