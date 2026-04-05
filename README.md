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
