# git

Git and forge workflow for Claude Code:

- atomic commits following [Conventional Commits](https://www.conventionalcommits.org/)
- an issue-to-pull-request workflow
- hooks that enforce the hard guardrails

## Installation

```
/plugin install git@kingofkalk-claude-code-plugins
```

## Skills

- [`commit`](skills/commit/SKILL.md) - analyze the working tree, group changes by logical concern, and create one or more atomic commits with Conventional Commit messages.
  - Plans the commits and waits for confirmation.
  - Splits hunks with `git apply --cached` on stdin, so it never edits files.
  - Adds `Refs #<n>` when the branch is named `<type>/<n>-<slug>`.
  - Claude may invoke it on its own.
- [`ship`](skills/ship/SKILL.md) - issue, dedicated branch `<type>/<issue>-<slug>`, commit (via `commit`), push to `origin`, pull request (Conventional Commit title, `Closes #n`, Summary, Test plan), then CI and review monitoring until the pull request is ready to merge.
  - Uses existing labels only.
  - Never merges.
  - Falls back to GitHub MCP tools when `gh` is unavailable.
  - Runs **only when you invoke it** (`/git:ship`), because it creates issues and pull requests and pushes.

## Hooks

[`hooks/git-guard.sh`](hooks/git-guard.sh), registered in [`hooks/hooks.json`](hooks/hooks.json). Requires `bash` and `jq`.

### PreToolUse (blocks the tool call)

| Rule | Blocks | Tool |
|---|---|---|
| No `git -C` | `git -C <path>`, `git --git-dir`, `git --work-tree` used as global options. `git log -C` / `git diff -C` stay allowed | Bash |
| No work on protected branches | `git commit` / `git push` while on `main` or `master`. Pushes whose destination is a protected branch (`HEAD:main`, `:main`, `origin main`). `git push --all/--mirror/--branches` | Bash |
| Only `origin` | `git push` to any other remote or URL: explicit, via `--repo`, or resolved from `branch.<b>.pushRemote` / `remote.pushDefault` / `branch.<b>.remote` | Bash |
| No AI attribution | AI `Co-Authored-By` / `Signed-off-by` trailers, "Generated with/by <AI>", `Claude-Session:`, `claude.ai/code/session_` links in commit messages (`-m`, heredocs, `-F <file>`) and pull request titles/bodies (`gh pr create/edit/comment`, `glab mr create/update/note`) | Bash |
| No AI attribution | Same patterns in `title` / `body` | `mcp__*__create_pull_request`, `mcp__*__update_pull_request` |

The command is split with a quote-aware tokenizer:

- It handles `&&`, `||`, `;`, `|`, subshells, `$(...)`, backticks, heredocs and wrappers such as `env`, `command` and `sudo`.
- Text inside a commit message is never mistaken for a command.
- It follows `cd <dir>` and `git switch -c <branch>` / `git checkout -b <branch>` within the same command.

Only trailer-shaped attribution counts. Mentioning "Claude" in a message is fine.

### PostToolUse (reports back to Claude)

After a Bash call containing `git commit`, the hook reads the **real** message of the commit just created and asks Claude to `git commit --amend` when:

- the subject is not `<type>[(scope)][!]: <description>` with one of `feat fix docs style refactor perf test build ci chore revert`
- there is no blank line after the subject
- `!` and the `BREAKING CHANGE:` footer do not appear together
- the message contains AI attribution

`Merge ...`, `Revert "..."`, `fixup!`, `squash!` and `amend!` subjects are accepted.

#### Why validation happens after the commit

Parsing a commit message out of the command text is unreliable. The message may come from:

- `-m`
- `-F -` with a heredoc
- `$(cat <<EOF ...)`
- `--amend`, `--no-edit` or `-C <commit>`
- `--fixup`
- the editor

The PostToolUse check sees exactly what git stored. It cannot prevent the commit, but it can report it immediately while the commit is still local.

### Configuration

Set these in the `env` section of Claude Code settings (not in the command itself):

| Variable | Default |
|---|---|
| `GIT_GUARD_PROTECTED_BRANCHES` | `main master` |
| `GIT_GUARD_ALLOWED_REMOTES` | `origin` |
| `GIT_GUARD_CC_TYPES` | `feat fix docs style refactor perf test build ci chore revert` |
| `GIT_GUARD_DISABLE` | unset (`1` disables all checks) |

### Limits

These hooks are guardrails, not a sandbox. They do not see through:

- `bash -c "..."`, `eval`
- variables (`git push "$REMOTE"`)
- shell aliases or functions
- scripts that run git internally

Other global options before the subcommand (`git -c x=y push`, `git --no-pager push`) are not blocked. They also bypass prefix-based permission rules.

### Tests

```bash
plugins/git/hooks/tests/run.sh
```

- Creates throwaway repositories and feeds hook JSON to the script.
- Covers every rule, with allow cases for likely false positives.
- Prints `passed: N, failed: 0` on success.

To check a single command by hand:

```bash
jq -n --arg c 'git push upstream main' --arg cwd "$PWD" \
  '{tool_name: "Bash", tool_input: {command: $c}, cwd: $cwd}' \
  | plugins/git/hooks/git-guard.sh pre; echo "exit $?"
```

Exit `2` plus a message on stderr means blocked. Exit `0` means allowed.
