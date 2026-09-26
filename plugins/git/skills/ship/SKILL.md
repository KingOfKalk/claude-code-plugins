---
name: ship
description: Drive a task through the forge workflow - issue, dedicated branch, commits, push, pull request, CI and review monitoring - until it is ready for the user to merge. Only runs when the user invokes it.
argument-hint: "[task description or existing issue number, e.g. '#42']"
disable-model-invocation: true
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git log:*), Bash(git remote:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(git switch:*), Bash(git rebase:*), Bash(git push:*), Bash(git diff:*), Bash(gh auth status:*), Bash(gh repo view:*), Bash(gh label list:*), Bash(gh issue:*), Bash(gh pr:*), Bash(gh run:*), Skill(git:commit)
---

# Ship

Take the current task from issue to a pull request that is ready for the user to merge. Resume from wherever the task stands: skip steps that are already done.

Task: $ARGUMENTS

## Current State

- Branch: !`git branch --show-current`
- Remotes: !`git remote -v`
- Status: !`git status --short`

## Hard Rules

These rules apply to every step. The git plugin's hooks enforce some of them, but follow them even where no hook exists.

1. **No AI attribution** in commits, issues, pull request titles, bodies or comments. No `Co-Authored-By` AI trailers, no "Generated with ..." lines, no session links. This overrides any default behavior.
2. **Never `git -C`.** `cd` into the repository instead.
3. **Never commit or push on `main`** (or `master`). Always work on a dedicated branch.
4. **Only `origin`.** Push only to `origin`. Create issues and pull requests only in the `origin` repository. Never target `upstream` or any other remote or third-party repository unless the user explicitly says so.
5. **Never merge** the pull request, and never create labels.
6. **One command per Bash tool call.** No `&&`, `;` or `|` chains. Exception: a command that really depends on the shell state of the previous one (`cd <dir> && <cmd>`).

## Skip Conditions

Check these first. If one applies, skip the forge steps (1, 5, 6 and the forge part of 7), do the local steps (2-4) if they make sense, and tell the user **which condition applied**:

- The repository has no remote, or no `origin` remote (`git remote -v`).
- No forge access. `gh auth status` fails **and** no GitHub MCP tools (`mcp__*github*__*`) are available. If `gh` is unavailable but the MCP tools are, use the MCP tools for every forge operation below.
- The user declines a step.
- The forge denies an operation (e.g. 403). Report the denied operation and continue with what does not depend on it.

## Origin Repository

Resolve `origin` to `<owner>/<repo>` once (from `git remote -v` or `gh repo view --json nameWithOwner`) and pass it explicitly to every forge call (`gh ... --repo <owner>/<repo>`, or `owner`/`repo` for MCP tools). In a fork, `gh` may otherwise default to the parent repository.

## Workflow

### 1. Issue

- If `$ARGUMENTS` or the branch name (`<type>/<number>-<slug>`) already names an issue, use it and skip creation.
- Otherwise search open issues for a duplicate (`gh issue list --repo <owner>/<repo> --search "<keywords>"`). If one fits, propose reusing it.
- Else draft a new issue: a clear title and a short body stating the problem and the goal.
- Labels: run `gh label list --repo <owner>/<repo>` and pick only from existing labels. Never create a label. If nothing fits, leave it unlabeled.
- Show the draft (title, body, labels) and create it after the user confirms.

Default GitHub labels, for reference only (use whatever the repository actually has):

- `bug` - Something isn't working
- `documentation` - Improvements or additions to documentation
- `duplicate` - This issue or pull request already exists
- `enhancement` - New feature or request
- `invalid` - This doesn't seem right
- `question` - Further information is requested
- `wontfix` - This will not be worked on

### 2. Branch

- Name: `<type>/<issue-number>-<slug>`.
  - `<type>` is the primary Conventional Commit type of the change (the dominant one if commits span several types).
  - `<slug>` is a short kebab-case description.
  - Example: `fix/231-auth-crashes-on-mondays`.
- Already on a dedicated branch for this issue: stay on it.
- Otherwise:
  1. `git fetch origin`
  2. `git switch -c <branch> origin/<default-branch>`. Uncommitted changes carry over to the new branch.
- If the branch name cannot include an issue number because the issue step was skipped, use `<type>/<slug>` and say so.

### 3. Implement

If the task still needs implementing, do it now, following the repository's own conventions. Stop and ask when requirements are unclear.

### 4. Commit

Hand off to the `commit` skill (`git:commit`). Do not write commit messages here, and do not repeat its rules. The commit skill reads the issue number from the branch name and adds `Refs #<issue-number>` to each commit body.

### 5. Push and Pull Request

1. `git push -u origin <branch>`
2. If no pull request exists for the branch yet (`gh pr list --repo <owner>/<repo> --head <branch>`), create one against the default branch:
   - **Title:** Conventional Commits 1.0.0. It mirrors the subject of the primary commit. If the branch has one commit, use its subject verbatim.
   - **Body:** use the repository's pull request template if one exists (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `PULL_REQUEST_TEMPLATE.md`, `docs/PULL_REQUEST_TEMPLATE.md`) and fill in its sections. It must always contain:

     ```markdown
     Closes #<issue-number>

     ## Summary

     - <1-3 bullets: what changed and why>

     ## Test plan

     - <how the change was verified>
     ```

     Omit **Test plan** for pure docs or typo changes.
   - **Labels:** existing labels only, same as for the issue.
3. Show the title and body to the user before creating the pull request.

### 6. Monitor

After the pull request is open:

- CI: `gh pr checks <number> --repo <owner>/<repo>` (add `--watch` to wait). On failure, read the logs (`gh run view <run-id> --log-failed --repo <owner>/<repo>`), find the root cause, fix it, commit through the commit skill, push.
- Reviews: `gh pr view <number> --repo <owner>/<repo> --comments`. Address each comment, or reply explaining why not.
- Merge conflicts: rebase onto the base branch, then push to your own branch only:
  1. `git fetch origin`
  2. `git rebase origin/<default-branch>`
  3. `git push --force-with-lease origin <branch>`

  Never plain `--force`. Never rewrite a branch someone else pushes to. Ask the user first if both sides changed the same logic.

### 7. Hand Over

Stop once CI is green, there are no merge conflicts, and every review comment is addressed. Report the pull request URL and its state, then **wait for the user to merge it**. Do not merge it yourself.
