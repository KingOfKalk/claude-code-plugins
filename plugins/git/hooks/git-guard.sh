#!/usr/bin/env bash
# git-guard: guardrail hooks for the git plugin.
#
#   git-guard.sh pre   PreToolUse  - block forbidden git / gh invocations
#   git-guard.sh post  PostToolUse - validate the message of a commit just made
#
# Reads the hook JSON on stdin. Exit 2 + stderr blocks (pre) or reports back
# to Claude (post). Exit 0 means nothing to report.
#
# Environment (set in Claude Code settings "env", not in the command):
#   GIT_GUARD_PROTECTED_BRANCHES  space/comma separated, default "main master"
#   GIT_GUARD_ALLOWED_REMOTES     space/comma separated, default "origin"
#   GIT_GUARD_CC_TYPES            space/comma separated Conventional Commit types
#   GIT_GUARD_DISABLE=1           turn all checks off
#
# Compatible with bash 3.2 (macOS /bin/bash).

# shellcheck disable=SC1003  # single-quoted backslash patterns are intended
set -u
export LC_ALL=C

MODE=${1:-pre}
[ "${GIT_GUARD_DISABLE:-}" = "1" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "git-guard: jq not found, git guardrail hooks are inactive" >&2
  exit 1
fi

INPUT=$(cat)
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
HOOK_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$HOOK_CWD" ] || HOOK_CWD=$PWD

PROTECTED=$(printf '%s' "${GIT_GUARD_PROTECTED_BRANCHES:-main master}" | tr ',' ' ')
ALLOWED_REMOTES=$(printf '%s' "${GIT_GUARD_ALLOWED_REMOTES:-origin}" | tr ',' ' ')
CC_TYPES=$(printf '%s' "${GIT_GUARD_CC_TYPES:-feat fix docs style refactor perf test build ci chore revert}" | tr ', ' '||')
CC_TYPES=$(printf '%s' "$CC_TYPES" | tr -s '|')
CC_TYPES=${CC_TYPES#|}
CC_TYPES=${CC_TYPES%|}

US=$'\x1f'
VIOLATIONS=()

violate() { VIOLATIONS+=("$1"); }

in_list() { # needle, space separated list
  local x
  for x in $2; do [ "$x" = "$1" ] && return 0; done
  return 1
}

# AI attribution patterns (rule 16). Only trailer / footer shaped text counts,
# so a plain mention of "Claude" in a message is fine.
AI_NAMES='claude|anthropic|copilot|chatgpt|openai|gpt-?[0-9]|gemini|codex|cursor|aider|devin|windsurf'
ATTRIBUTION_RE="co-authored-by:.*(${AI_NAMES})|signed-off-by:.*(${AI_NAMES})|(generated|created|written|authored|assisted) (with|by) \\[?(${AI_NAMES})|claude-session:|claude\\.ai/code/session_"

has_attribution() { printf '%s' "$1" | grep -Eiq -- "$ATTRIBUTION_RE"; }

# ---------------------------------------------------------------------------
# Shell tokenizer
#
# Splits S into simple commands (SEGS, tokens joined by US). Understands
# quotes, backslashes, comments, ; & | ( ) newlines, $(...) and backticks
# (recursively, so nested commands are checked too), redirections and
# heredocs (bodies are skipped, never treated as commands). No expansion is
# performed: "$VAR" stays literal.
# ---------------------------------------------------------------------------

S=""; N=0; I=0
SEGS=()
# runs of characters without special meaning (outside / inside double quotes)
RE_WORD_RUN='^[^][:space:]\\'"'"'"$`#;&|(){}<>[]+'
RE_DQ_RUN='^[^"\\$`]+'

tk_parse() { # $1 = "sub" when inside $( ... )
  local sub=${1:-} tok="" have=0 skip=0 c nc rest pre start
  local -a seg=() hd=()

  flush_tok() {
    if [ "$have" = 1 ]; then
      if [ "$skip" = 1 ]; then skip=0; else seg+=("$tok"); fi
    fi
    tok=""; have=0
  }
  flush_seg() {
    flush_tok
    if [ "${#seg[@]}" -gt 0 ]; then
      local j
      printf -v j "%s${US}" "${seg[@]}"
      SEGS+=("$j")
    fi
    seg=()
  }
  skip_heredocs() {
    local d line strip
    for d in "${hd[@]+"${hd[@]}"}"; do
      strip=0
      case $d in -*) strip=1 ;; esac
      d=${d#?}
      if [ "$strip" = 0 ]; then
        # fast path: jump straight to the delimiter line
        rest=${S:I}
        if [ "$rest" = "$d" ] || [ "${rest#"$d"$'\n'}" != "$rest" ]; then
          I=$((I + ${#d} + 1))
        else
          line=${rest%%$'\n'"$d"$'\n'*}
          if [ "$line" != "$rest" ]; then
            I=$((I + ${#line} + ${#d} + 2))
          else
            I=$N
          fi
        fi
        [ "$I" -gt "$N" ] && I=$N
        continue
      fi
      while [ "$I" -lt "$N" ]; do
        rest=${S:I}
        line=${rest%%$'\n'*}
        if [ "$line" = "$rest" ]; then I=$N; else I=$((I + ${#line} + 1)); fi
        if [ "$strip" = 1 ]; then
          while [ "${line:0:1}" = $'\t' ]; do line=${line:1}; done
        fi
        [ "$line" = "$d" ] && break
      done
    done
    hd=()
  }
  read_word() { # consume one shell word at I, unquoted value -> REPLY
    REPLY=""
    local ch
    while [ "$I" -lt "$N" ]; do
      ch=${S:I:1}
      case $ch in
        ' '|$'\t'|$'\n'|';'|'&'|'|'|'('|')'|'<'|'>') break ;;
        "'"|'"') I=$((I + 1)) ;;
        '\') REPLY+=${S:I+1:1}; I=$((I + 2)) ;;
        *) REPLY+=$ch; I=$((I + 1)) ;;
      esac
    done
  }
  parse_backtick() { # I at opening backtick
    local body="" ch saveS saveN saveI
    I=$((I + 1))
    while [ "$I" -lt "$N" ]; do
      ch=${S:I:1}
      if [ "$ch" = '\' ]; then body+=${S:I:2}; I=$((I + 2)); continue; fi
      [ "$ch" = '`' ] && { I=$((I + 1)); break; }
      body+=$ch; I=$((I + 1))
    done
    saveS=$S; saveN=$N; saveI=$I
    S=$body; N=${#S}; I=0
    tk_parse
    S=$saveS; N=$saveN; I=$saveI
    tok+="\`$body\`"
  }
  parse_dq() { # I just after opening "
    local ch nx
    while [ "$I" -lt "$N" ]; do
      ch=${S:I:1}
      case $ch in
        '"') I=$((I + 1)); return ;;
        '\')
          nx=${S:I+1:1}
          case $nx in
            '$'|'`'|'"'|'\') tok+=$nx ;;
            $'\n') ;;
            *) tok+="\\$nx" ;;
          esac
          I=$((I + 2)) ;;
        '$')
          if [ "${S:I+1:1}" = '(' ]; then
            start=$I; I=$((I + 2)); tk_parse sub; tok+=${S:start:I-start}
          else
            tok+=$ch; I=$((I + 1))
          fi ;;
        '`') parse_backtick ;;
        *)
          # consume the whole run of ordinary characters at once
          [[ ${S:I} =~ $RE_DQ_RUN ]]
          pre=${BASH_REMATCH[0]}
          [ -n "$pre" ] || pre=$ch
          tok+=$pre; I=$((I + ${#pre})) ;;
      esac
    done
  }

  while [ "$I" -lt "$N" ]; do
    c=${S:I:1}
    case $c in
      '\')
        nc=${S:I+1:1}
        if [ "$nc" != $'\n' ]; then tok+=$nc; have=1; fi
        I=$((I + 2)) ;;
      "'")
        rest=${S:I+1}
        pre=${rest%%\'*}
        tok+=$pre; have=1
        if [ "$pre" = "$rest" ]; then I=$N; else I=$((I + ${#pre} + 2)); fi ;;
      '"') I=$((I + 1)); have=1; parse_dq ;;
      '$')
        if [ "${S:I+1:1}" = '(' ]; then
          start=$I; I=$((I + 2)); tk_parse sub; tok+=${S:start:I-start}
        else
          tok+=$c; I=$((I + 1))
        fi
        have=1 ;;
      '`') have=1; parse_backtick ;;
      '#')
        if [ "$have" = 0 ]; then
          rest=${S:I}; pre=${rest%%$'\n'*}; I=$((I + ${#pre}))
        else
          tok+=$c; I=$((I + 1))
        fi ;;
      ')')
        I=$((I + 1))
        if [ "$sub" = sub ]; then flush_seg; return; fi
        flush_seg ;;
      ';'|'&'|'|'|'('|'{'|'}')
        if [ "$c" = '{' ] || [ "$c" = '}' ]; then
          # braces only group when they stand alone as a word
          nc=${S:I+1:1}
          if [ "$have" = 1 ] || { [ "$nc" != ' ' ] && [ "$nc" != $'\n' ] && [ "$nc" != ';' ] && [ -n "$nc" ]; }; then
            tok+=$c; have=1; I=$((I + 1)); continue
          fi
        fi
        flush_seg; I=$((I + 1)) ;;
      $'\n')
        flush_seg; I=$((I + 1)); skip_heredocs ;;
      ' '|$'\t') flush_tok; I=$((I + 1)) ;;
      '<'|'>')
        # fd number glued to the operator (2>, 1<) is not an argument
        case $tok in *[!0-9]*|'') ;; *) tok=""; have=0 ;; esac
        flush_tok
        if [ "${S:I:3}" = '<<<' ]; then
          I=$((I + 3)); skip=1
        elif [ "${S:I:2}" = '<<' ]; then
          I=$((I + 2))
          local dash=' '
          if [ "${S:I:1}" = '-' ]; then dash='-'; I=$((I + 1)); fi
          while [ "${S:I:1}" = ' ' ] || [ "${S:I:1}" = $'\t' ]; do I=$((I + 1)); done
          read_word
          hd+=("$dash$REPLY")
        else
          I=$((I + 1))
          case ${S:I:1} in '>'|'|') I=$((I + 1)) ;; esac
          if [ "${S:I:1}" = '&' ]; then
            I=$((I + 1))
            while [ "$I" -lt "$N" ]; do
              case ${S:I:1} in [0-9]|-) I=$((I + 1)) ;; *) break ;; esac
            done
          else
            skip=1
          fi
        fi ;;
      *)
        # consume the whole run of ordinary characters at once
        [[ ${S:I} =~ $RE_WORD_RUN ]]
        pre=${BASH_REMATCH[0]}
        [ -n "$pre" ] || pre=$c
        tok+=$pre; have=1; I=$((I + ${#pre})) ;;
    esac
  done
  flush_seg
}

tokenize() {
  S=$1; N=${#S}; I=0; SEGS=()
  tk_parse
}

# ---------------------------------------------------------------------------
# Git state helpers (run in the directory the command would run in)
# ---------------------------------------------------------------------------

EFF_DIR=""     # directory the current segment runs in
SIM_BRANCH=""  # branch switched to earlier in the same command, if any

git_in() { (cd "$EFF_DIR" 2>/dev/null && git "$@" 2>/dev/null); }

current_branch() {
  if [ -n "$SIM_BRANCH" ]; then printf '%s' "$SIM_BRANCH"; return; fi
  git_in branch --show-current
}

resolve_push_remote() { # $1 = branch
  local r=""
  if [ -n "$1" ]; then r=$(git_in config --get "branch.$1.pushRemote"); fi
  [ -n "$r" ] || r=$(git_in config --get remote.pushDefault)
  if [ -z "$r" ] && [ -n "$1" ]; then r=$(git_in config --get "branch.$1.remote"); fi
  [ -n "$r" ] || r=origin
  printf '%s' "$r"
}

do_cd() { # $1 = target (may be empty)
  local t=${1:-}
  # shellcheck disable=SC2088  # matching a literal ~/ prefix
  case $t in
    ''|'~') t=${HOME:-/} ;;
    '~/'*) t=${HOME:-}/${t#\~/} ;;
    '-'|*'$'*|*'`'*) return ;;  # unknown at hook time, keep current dir
  esac
  case $t in /*) ;; *) t=$EFF_DIR/$t ;; esac
  EFF_DIR=$t
  SIM_BRANCH=""
}

# ---------------------------------------------------------------------------
# Per-command checks
# ---------------------------------------------------------------------------

GIT_SUB=""       # subcommand of the last git segment analysed
GIT_ARGS=()      # its arguments
COMMIT_SEEN=0
COMMIT_DIR=""

analyse_git() { # tokens after the "git" word
  local t
  GIT_SUB=""; GIT_ARGS=()
  while [ $# -gt 0 ]; do
    t=$1
    case $t in
      -C|-C*)
        violate "rule 22: \`git -C\` is forbidden. It bypasses permission rules keyed on the git subcommand. Run \`cd <path>\` in its own step, then plain \`git ...\`."
        shift; [ "$t" = -C ] && shift; continue ;;
      --git-dir|--work-tree|--git-dir=*|--work-tree=*)
        violate "rule 22: \`git ${t%%=*}\` is a \`git -C\` variant and is forbidden. Run \`cd <path>\` in its own step, then plain \`git ...\`."
        shift; case $t in *=*) ;; *) shift ;; esac; continue ;;
      -c|--namespace|--exec-path|--config-env|--super-prefix|--list-cmds)
        shift; shift; continue ;;
      -*) shift; continue ;;
      *) GIT_SUB=$t; shift; break ;;
    esac
  done
  GIT_ARGS=("$@")

  case $GIT_SUB in
    commit) check_commit ;;
    push) check_push ;;
    switch|checkout) track_switch ;;
  esac
}

track_switch() {
  local a create=0 target=""
  set -- "${GIT_ARGS[@]+"${GIT_ARGS[@]}"}"
  while [ $# -gt 0 ]; do
    a=$1; shift
    case $a in
      -c|-C|-b|-B|--create|--force-create|--orphan) create=1; target=${1:-}; shift ;;
      --) break ;;
      -*) ;;
      *) [ -z "$target" ] && target=$a ;;
    esac
  done
  # plain "git checkout <x>" may be a path, only trust switch or -b/-c
  if [ "$create" = 1 ] || [ "$GIT_SUB" = switch ]; then
    [ -n "$target" ] && SIM_BRANCH=$target
  fi
}

check_commit() {
  local branch a f content
  COMMIT_SEEN=1
  COMMIT_DIR=$EFF_DIR
  branch=$(current_branch)
  if [ -n "$branch" ] && in_list "$branch" "$PROTECTED"; then
    violate "rule 36: committing on protected branch '$branch' is forbidden. Create a dedicated branch first (e.g. \`git switch -c <type>/<issue>-<slug>\`)."
  fi
  if has_attribution "$S_ALL"; then
    violate "rule 16: the commit message contains AI attribution (e.g. a Co-Authored-By AI trailer, 'Generated with Claude Code' or a Claude-Session trailer). Remove it; the human user is the only author."
  fi
  # message read from a file
  set -- "${GIT_ARGS[@]+"${GIT_ARGS[@]}"}"
  while [ $# -gt 0 ]; do
    a=$1; shift
    f=""
    case $a in
      -F|--file) f=${1:-}; shift ;;
      --file=*) f=${a#--file=} ;;
      -F?*) f=${a#-F} ;;
    esac
    if [ -n "$f" ] && [ "$f" != - ]; then
      case $f in /*) ;; *) f=$EFF_DIR/$f ;; esac
      if [ -r "$f" ]; then
        content=$(cat "$f")
        if has_attribution "$content"; then
          violate "rule 16: the commit message file '$f' contains AI attribution. Remove it; the human user is the only author."
        fi
      fi
    fi
  done
}

check_push() {
  local a remote="" all=0 branch dst spec
  local -a refspecs=()
  set -- "${GIT_ARGS[@]+"${GIT_ARGS[@]}"}"
  while [ $# -gt 0 ]; do
    a=$1; shift
    case $a in
      --repo=*) remote=${a#--repo=} ;;
      --repo) remote=${1:-}; shift ;;
      -o|--push-option|--receive-pack|--exec) shift ;;
      --all|--mirror|--branches) all=1 ;;
      --) refspecs+=("$@"); break ;;
      -*) ;;
      *) if [ -z "$remote" ] && [ "${#refspecs[@]}" -eq 0 ]; then remote=$a; else refspecs+=("$a"); fi ;;
    esac
  done

  branch=$(current_branch)
  [ -n "$remote" ] || remote=$(resolve_push_remote "$branch")
  if ! in_list "$remote" "$ALLOWED_REMOTES"; then
    violate "rule 43: pushing to '$remote' is forbidden. Only push to: $ALLOWED_REMOTES. Pushing elsewhere requires an explicit instruction from the user, who must run it themselves."
  fi

  if [ "$all" = 1 ]; then
    violate "rule 36: \`git push --all/--mirror/--branches\` would also push protected branches ($PROTECTED). Push the feature branch explicitly."
    return
  fi
  if [ "${#refspecs[@]}" -eq 0 ]; then
    if [ -n "$branch" ] && in_list "$branch" "$PROTECTED"; then
      violate "rule 36: pushing from protected branch '$branch' is forbidden. Work on a dedicated branch."
    fi
    return
  fi
  for spec in "${refspecs[@]}"; do
    spec=${spec#+}
    case $spec in
      *:*) dst=${spec#*:} ;;
      *) dst=$spec ;;
    esac
    [ "$dst" = HEAD ] && dst=$branch
    dst=${dst#refs/heads/}
    if [ -n "$dst" ] && in_list "$dst" "$PROTECTED"; then
      violate "rule 36: pushing to protected branch '$dst' is forbidden. Push the feature branch and open a pull request."
    fi
  done
}

check_forge() { # gh / glab tokens after the program word
  case "${1:-} ${2:-}" in
    'pr create'|'pr edit'|'mr create'|'mr update'|'pr comment'|'mr note')
      if has_attribution "$S_ALL"; then
        violate "rule 16: the pull request title/body contains AI attribution (e.g. 'Generated with Claude Code' or a claude.ai session link). Remove it."
      fi ;;
  esac
}

analyse_segment() { # tokens of one simple command
  local w
  # skip keywords, assignments and wrapper commands
  while [ $# -gt 0 ]; do
    w=$1
    case $w in
      if|then|else|elif|do|while|until|'!'|time|command|builtin|exec|nohup|sudo|xargs) shift ;;
      env) shift; while [ $# -gt 0 ]; do case $1 in -*|*=*) shift ;; *) break ;; esac; done ;;
      [A-Za-z_]*=*) shift ;;
      -*) shift ;;  # options of the wrapper commands above
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return
  w=${1##*/}
  case $w in
    cd|pushd) shift; do_cd "${1:-}" ;;
    git) shift; analyse_git "$@" ;;
    gh|glab) shift; check_forge "$@" ;;
  esac
}

run_command_checks() { # $1 = full command
  local seg
  local -a toks
  S_ALL=$1
  EFF_DIR=$HOOK_CWD
  SIM_BRANCH=""
  tokenize "$1"
  for seg in "${SEGS[@]+"${SEGS[@]}"}"; do
    toks=()
    IFS=$US read -r -d '' -a toks < <(printf '%s' "$seg")
    analyse_segment "${toks[@]+"${toks[@]}"}"
  done
}

report() { # $1 = header
  [ "${#VIOLATIONS[@]}" -eq 0 ] && exit 0
  {
    echo "$1"
    local v
    for v in "${VIOLATIONS[@]}"; do echo "- $v"; done
  } >&2
  exit 2
}

# ---------------------------------------------------------------------------
# Post-commit validation of the real message
# ---------------------------------------------------------------------------

validate_message() { # $1 = full message
  local msg=$1 subject second body_has_bc subject_bang=0
  subject=${msg%%$'\n'*}

  if has_attribution "$msg"; then
    violate "rule 16: the commit message contains AI attribution. Remove it with \`git commit --amend\`."
  fi

  case $subject in
    'Merge '*|'Revert "'*|'fixup! '*|'squash! '*|'amend! '*) return ;;
  esac

  if ! printf '%s' "$subject" | grep -Eq "^(${CC_TYPES})(\\([^()[:space:]][^()]*\\))?!?: [^[:space:]]"; then
    violate "rule 17: subject '$subject' is not a Conventional Commit. Expected '<type>[(scope)][!]: <description>' with type one of: ${CC_TYPES//|/, }."
    return
  fi
  case $subject in *'!: '*) subject_bang=1 ;; esac

  if [ "$msg" != "$subject" ]; then
    second=${msg#*$'\n'}
    second=${second%%$'\n'*}
    if [ -n "$second" ]; then
      violate "Conventional Commits: the subject must be followed by a blank line before the body."
    fi
  fi

  body_has_bc=0
  if printf '%s\n' "$msg" | tail -n +2 | grep -Eq '^BREAKING[ -]CHANGE: '; then body_has_bc=1; fi
  if [ "$subject_bang" = 1 ] && [ "$body_has_bc" = 0 ]; then
    violate "rule 18: breaking change marked with '!' but no 'BREAKING CHANGE:' footer."
  elif [ "$subject_bang" = 0 ] && [ "$body_has_bc" = 1 ]; then
    violate "rule 18: 'BREAKING CHANGE:' footer present but no '!' after the type/scope."
  fi
}

post_commit() {
  local cmd entry ts gs now sha msg
  cmd=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
  [ -n "$cmd" ] || exit 0
  run_command_checks "$cmd"
  VIOLATIONS=()   # pre-checks are not re-reported here
  [ "$COMMIT_SEEN" = 1 ] || exit 0
  EFF_DIR=$COMMIT_DIR

  entry=$(git_in reflog -1 --date=unix --format="%gd${US}%gs")
  [ -n "$entry" ] || exit 0
  ts=${entry%%"$US"*}
  ts=${ts##*\{}
  ts=${ts%\}}
  gs=${entry#*"$US"}
  case $gs in commit*) ;; *) exit 0 ;; esac
  case $gs in 'commit (merge)'*) exit 0 ;; esac
  now=$(date +%s)
  case $ts in ''|*[!0-9]*) exit 0 ;; esac
  [ $((now - ts)) -le 120 ] || exit 0

  sha=$(git_in rev-parse --short HEAD)
  msg=$(git_in log -1 --format=%B)
  validate_message "$msg"
  report "git-guard: commit $sha violates the commit rules. Fix it with \`git commit --amend\` (it is not pushed yet):"
}

# ---------------------------------------------------------------------------

S_ALL=""

case $MODE in
  pre)
    case $TOOL_NAME in
      Bash)
        run_command_checks "$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')"
        report "git-guard blocked this command:" ;;
      *)
        # MCP pull request tools (rule 16)
        text=$(printf '%s' "$INPUT" | jq -r '[.tool_input.title, .tool_input.body] | map(select(type == "string")) | join("\n")')
        if has_attribution "$text"; then
          violate "rule 16: the pull request title/body contains AI attribution (e.g. 'Generated with Claude Code' or a claude.ai session link). Remove it."
        fi
        report "git-guard blocked this tool call:" ;;
    esac ;;
  post)
    [ "$TOOL_NAME" = Bash ] || exit 0
    post_commit ;;
  *)
    echo "git-guard: unknown mode '$MODE'" >&2
    exit 1 ;;
esac
