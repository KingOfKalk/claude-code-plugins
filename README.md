# Skills

A collection of Claude Code skills, installable via the marketplace/plugin feature.

## Installation

```
/plugin marketplace add KingOfKalk/skills
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
