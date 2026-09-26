#!/usr/bin/env bash
# Tests for git-guard.sh. Run: plugins/git/hooks/tests/run.sh
# Needs bash, git and jq. Creates throwaway repos under a temp dir.

set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GUARD=$HERE/../git-guard.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

unset GIT_GUARD_PROTECTED_BRANCHES GIT_GUARD_ALLOWED_REMOTES GIT_GUARD_CC_TYPES GIT_GUARD_DISABLE
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

PASS=0
FAIL=0

REPO=$TMP/repo
git init -q -b main "$REPO"
(
  cd "$REPO" || exit 1
  git commit -q --allow-empty -m "chore: init"
  git remote add origin https://example.com/me/repo.git
  git remote add upstream https://example.com/them/repo.git
  git branch feat/1-thing
  git branch master
)

on_branch() { (cd "$REPO" && git checkout -q "$1"); }

# run_guard <mode> <tool_name> <tool_input json> [cwd]
run_guard() {
  jq -n --arg tool "$2" --argjson input "$3" --arg cwd "${4:-$REPO}" \
    '{hook_event_name: "x", tool_name: $tool, tool_input: $input, cwd: $cwd}' |
    "$GUARD" "$1" 2>"$TMP/stderr"
}

# expect <allow|block> <name> <mode> <tool> <input json> [stderr substring]
expect() {
  local want=$1 name=$2 rc got
  run_guard "$3" "$4" "$5"
  rc=$?
  case $rc in 0) got=allow ;; 2) got=block ;; *) got="error($rc)" ;; esac
  if [ "$got" = "$want" ] && { [ -z "${6:-}" ] || grep -qF -- "$6" "$TMP/stderr"; }; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $name (want $want, got $got)"
    sed 's/^/    /' "$TMP/stderr"
  fi
}

bash_in() { jq -n --arg c "$1" '{command: $c}'; }

pre() { # <allow|block> <name> <command> [substring]
  expect "$1" "$2" pre Bash "$(bash_in "$3")" "${4:-}"
}

# --- rule 22: git -C ---------------------------------------------------------
on_branch feat/1-thing
pre block "git -C"                 "git -C /tmp status"                      "rule 22"
pre block "git -C glued"           "git -C/tmp status"                       "rule 22"
pre block "git -c then -C"         "git -c color.ui=never -C /tmp log"       "rule 22"
pre block "git --git-dir"          "git --git-dir=/tmp/.git log"             "rule 22"
pre block "git --work-tree"        "git --work-tree /tmp status"             "rule 22"
pre block "-C after &&"            "cd /tmp && git -C . push"                "rule 22"
pre block "-C in \$( )"            "echo \$(git -C /tmp rev-parse HEAD)"     "rule 22"
pre block "-C in backticks"        "echo \`git -C /tmp rev-parse HEAD\`"     "rule 22"
pre block "env prefix"             "env FOO=1 git -C /tmp status"            "rule 22"
pre block "absolute git path"      "/usr/bin/git -C /tmp status"             "rule 22"
pre allow "git log -C (copy det.)" "git log -C --stat"
pre allow "git diff -C"            "git diff -C HEAD~1"
pre allow "-C in quoted message"   "git commit -m 'docs: never use git -C'"
pre allow "-C in grep pattern"     "grep -rn 'git -C' ."

# --- rule 36: protected branches --------------------------------------------
on_branch main
pre block "commit on main"          "git commit -m 'fix: x'"                  "rule 36"
pre block "push on main"            "git push"                                "rule 36"
pre block "push -u origin HEAD main" "git push -u origin HEAD"                "rule 36"
pre allow "switch -c then commit"   "git switch -c feat/2-x && git commit -m 'fix: x'"
pre allow "checkout -b then commit" "git checkout -b feat/2-x; git commit -m 'fix: x'"
pre allow "status on main"          "git status"
pre allow "log on main"             "git log --oneline -n 3"
on_branch master
pre block "commit on master"        "git commit -m 'fix: x'"                  "rule 36"
on_branch feat/1-thing
pre allow "commit on feature"       "git commit -m 'fix: x'"
pre allow "push feature"            "git push -u origin feat/1-thing"
pre allow "push HEAD from feature"  "git push -u origin HEAD"
pre allow "force-with-lease"        "git push --force-with-lease origin feat/1-thing"
pre block "push refspec to main"    "git push origin HEAD:main"               "rule 36"
pre block "push refs/heads/main"    "git push origin +feat/1-thing:refs/heads/main" "rule 36"
pre block "push local main"         "git push origin main"                    "rule 36"
pre block "delete main"             "git push origin :main"                   "rule 36"
pre block "push --all"              "git push --all origin"                   "rule 36"
pre allow "commit mentioning main"  "git commit -m 'fix: handle git push to main'"
GIT_GUARD_PROTECTED_BRANCHES=develop pre block "custom protected" "git push origin develop" "rule 36"
on_branch main
GIT_GUARD_PROTECTED_BRANCHES=develop pre allow "custom protected, main ok" "git commit -m 'fix: x'"
on_branch feat/1-thing
pre allow "commit in other repo via cd" "cd $TMP && git commit -m 'fix: x'"
mkdir -p "$TMP/other"
git init -q -b main "$TMP/other"
pre block "cd into repo on main"    "cd $TMP/other && git commit -m 'fix: x'" "rule 36"
pre block "relative cd into repo"   "cd ../other && git commit -m 'fix: x'"   "rule 36"

# --- rule 43: remotes -------------------------------------------------------
pre block "push upstream"           "git push upstream feat/1-thing"          "rule 43"
pre block "push --repo"             "git push --repo=upstream"                "rule 43"
pre block "push to URL"             "git push https://example.com/x.git feat/1-thing" "rule 43"
pre block "push in subshell"        "(git push upstream feat/1-thing)"        "rule 43"
pre block "push after if"           "if true; then git push upstream; fi"     "rule 43"
pre allow "push origin"             "git push origin feat/1-thing"
pre allow "fetch upstream"          "git fetch upstream"
(cd "$REPO" && git config branch.feat/1-thing.pushRemote upstream)
pre block "implicit pushRemote"     "git push"                                "rule 43"
(cd "$REPO" && git config --unset branch.feat/1-thing.pushRemote)
pre allow "implicit origin"         "git push"
GIT_GUARD_ALLOWED_REMOTES="origin fork" pre allow "allowed remote override" "git push fork feat/1-thing"

# --- rule 16: AI attribution ------------------------------------------------
HEREDOC_BAD=$(cat <<'X'
git commit -m "$(cat <<'EOF'
feat(api): add thing

Details with "quotes" and 1) a paren.

Co-Authored-By: Claude Opus <noreply@anthropic.com>
EOF
)"
X
)
HEREDOC_OK=$(cat <<'X'
git commit -m "$(cat <<'EOF'
feat(api): add thing

Mention Claude Code and "git push upstream" and git -C in prose.
1) unbalanced paren
EOF
)"
X
)
STDIN_BAD=$(cat <<'X'
git commit -F - <<'EOF'
fix: y

Claude-Session: https://claude.ai/code/session_123
EOF
X
)
pre block "co-author trailer -m"    "git commit -m 'feat: x' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'" "rule 16"
pre block "copilot co-author"       "git commit -m 'feat: x' -m 'Co-authored-by: Copilot <x@github.com>'" "rule 16"
pre block "generated with"          "git commit -m 'feat: x' -m 'Generated with [Claude Code](https://claude.com/claude-code)'" "rule 16"
pre block "heredoc co-author"       "$HEREDOC_BAD"                            "rule 16"
pre block "stdin heredoc session"   "$STDIN_BAD"                              "rule 16"
pre allow "heredoc prose mentions"  "$HEREDOC_OK"
pre allow "human co-author"         "git commit -m 'feat: x' -m 'Co-authored-by: Jane Doe <jane@example.com>'"
printf 'feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n' >"$REPO/msg.txt"
pre block "-F file with trailer"    "git commit -F msg.txt"                   "rule 16"
printf 'feat: x\n' >"$REPO/msg.txt"
pre allow "-F clean file"           "git commit -F msg.txt"
pre block "gh pr create body"       "gh pr create --title 'feat: x' --body 'Summary

🤖 Generated with [Claude Code](https://claude.com/claude-code)'" "rule 16"
pre allow "gh pr create clean"      "gh pr create --title 'feat: x' --body 'Closes #1'"
pre allow "echo attribution (not a commit)" "echo 'Co-Authored-By: Claude'"
expect block "mcp create PR body" pre mcp__github__create_pull_request \
  '{"title":"feat: x","body":"Summary\n\nhttps://claude.ai/code/session_01abc"}' "rule 16"
expect allow "mcp create PR clean" pre mcp__github__create_pull_request \
  '{"title":"feat: x","body":"Closes #1"}'

# --- misc -------------------------------------------------------------------
pre allow "non-git command"         "ls -la"
pre allow "empty command"           ""
GIT_GUARD_DISABLE=1 pre allow "disabled" "git -C /tmp status"

# --- post: Conventional Commits on the real message --------------------------
post_commit() { # <allow|block> <name> <message> [substring]
  (cd "$REPO" && git commit -q --allow-empty -F - <<<"$3")
  expect "$1" "$2" post Bash "$(bash_in 'git commit -F -')" "${4:-}"
}
on_branch feat/1-thing
post_commit allow "post: valid"                   "feat(git/hooks): add guard"
post_commit allow "post: valid with body"         $'fix: handle x\n\nBody.\n\nRefs #12'
post_commit allow "post: breaking ok"             $'feat(api)!: drop v1\n\nBREAKING CHANGE: v1 removed'
post_commit allow "post: merge"                   "Merge branch 'main' into feat/1-thing"
post_commit allow "post: fixup"                   "fixup! feat: add guard"
post_commit block "post: no type"                 "add guard"                                "rule 17"
post_commit block "post: unknown type"            "feature: add guard"                       "rule 17"
post_commit block "post: missing space"           "feat:add guard"                           "rule 17"
post_commit block "post: no blank line"           $'feat: x\nbody'                           "blank line"
post_commit block "post: bang without footer"     "feat!: drop v1"                           "rule 18"
post_commit block "post: footer without bang"     $'feat: drop v1\n\nBREAKING CHANGE: gone'  "rule 18"
post_commit block "post: attribution"             $'feat: x\n\nCo-Authored-By: Claude <noreply@anthropic.com>' "rule 16"
expect allow "post: non-commit command" post Bash "$(bash_in 'git status')"
(cd "$REPO" && git checkout -q main)
expect allow "post: failed commit (last reflog is checkout)" post Bash "$(bash_in 'git commit -m bad')"

echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
