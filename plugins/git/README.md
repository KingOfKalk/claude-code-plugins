# git

Create atomic git commits following the [Conventional Commits](https://www.conventionalcommits.org/) specification. Automatically splits unrelated changes into separate commits.

## Installation

```
/plugin install git@kingofkalk-claude-code-plugins
```

## Skills

- [`commit`](skills/commit/SKILL.md) — analyze the working tree, group changes by logical concern, and create one or more atomic commits with Conventional Commit messages. Supports hunk-level splitting via `git apply --cached` when a single file contains changes for multiple commits.
