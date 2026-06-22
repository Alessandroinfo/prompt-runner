#!/usr/bin/env bash
#
# prompt-runner — run prompts in parallel via tmux
#
# USAGE
#   bash run.sh --dir <prompts-dir> [options]
#
# REQUIRED
#   --dir <path>              Directory containing prompt files (.md / .txt).
#                             Recursive: subdirectories become task name prefixes
#                             (e.g. platform/crm).
#
# OPTIONS
#   --work-dir <path>         Working directory for the binary.
#                             Required when using --worktree: must be a git repo.
#
#   --worktree                Create an isolated git worktree per task from
#                             --work-dir. Requires --work-dir pointing to a git repo.
#
#   --print                   Add -p to binary args and disable the completion
#                             instruction in the prompt.
#                             Required for parallel Claude runs.
#
#   --verbose                 Add --verbose to binary args.
#
#   --impl-prompt <file>      File prepended to every prompt before sending to
#                             the binary (global system instructions).
#
#   --bin <path>              Binary to run.
#                             Default: auto-detect claude in PATH, then ~/.local/bin/claude.
#                             Alias: --claude-bin (backwards compat).
#
#   --bin-args <args>         Extra arguments passed to the binary.
#                             E.g.: --bin-args "--dangerously-skip-permissions -p"
#
#   --bin-env <KEY=VALUE>     Environment variable for the binary (repeatable).
#                             E.g.: --bin-env CLAUDE_CODE_USE_FOUNDRY=1
#
#   --config <file>           Config file path (default: runner.conf in script dir).
#                             See runner.conf.example.
#
#   --session <name>          tmux session name (default: pr-run).
#
#   --marker-dir <path>       Directory for status markers (.running / .done / .fail).
#                             Default: /tmp/pr-status.
#
# PER-PROMPT OVERRIDE (frontmatter)
#   Any prompt file can start with a YAML frontmatter block:
#     ---
#     bin: /path/to/binary
#     bin-args: --flag1 --flag2
#     bin-env: KEY1=val1 KEY2=val2
#     ---
#   Per-prompt values override global ones. bin-env is merged (both apply).
#   The frontmatter is stripped before passing the prompt to the binary.
#
# MODES
#   --status                  Print task status dashboard and exit.
#
#   --watch[=<seconds>]       Refresh dashboard every N seconds (default: 5).
#                             Sends a macOS notification on completion.
#                             Ctrl+C to quit.
#
#   --dry-run                 Build runners without launching tmux. Useful to
#                             verify configuration before running.
#
#   --clean-markers           Remove all status markers (.running / .done /
#                             .fail / .complete) before starting.
#
#   --clean-worktrees         Remove /tmp/pr-wt/ before starting, deleting any
#                             residual worktrees.
#
#   --kill                    Kill the active tmux session and all running binary
#                             processes before starting.
#
#   --overview                Show all tasks simultaneously in a tiled tmux pane
#                             grid instead of separate windows.
#                             Ctrl+B Z  zoom a pane (toggle).
#                             Ctrl+B Q  show pane numbers.
#                             Ctrl+B D  detach (tasks keep running in background).
#
# EXAMPLES
#   # Basic run (config from runner.conf)
#   bash run.sh --dir ./prompts
#
#   # Explicit binary and args
#   bash run.sh --dir ./prompts --print \
#     --bin claude \
#     --bin-args "--dangerously-skip-permissions" \
#     --bin-env CLAUDE_CODE_USE_FOUNDRY=1
#
#   # Isolated worktree per task on a git repo
#   bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo
#
#   # Prepend global system instructions to every prompt
#   bash run.sh --dir ./prompts --print --impl-prompt ./system.md
#
#   # Check status of a running session
#   bash run.sh --dir ./prompts --status
#
#   # Live dashboard every 10 seconds
#   bash run.sh --dir ./prompts --watch=10
#
#   # Dry run: build runners and show them without executing
#   bash run.sh --dir ./prompts --dry-run
#
#   # Start clean: remove previous status markers
#   bash run.sh --dir ./prompts --print --clean-markers
#
#   # Kill active session and processes before restarting
#   bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo --kill
#
#   # Grid view: all tasks visible at once
#   bash run.sh --dir ./prompts --print --overview
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Defaults ─────────────────────────────────────────────────────────────────
PROMPTS_DIR=""
IMPL_WORK_DIR=""
IMPL_PROMPT_FILE=""
STATUS_MARKER_DIR="/tmp/pr-status"
WORKTREE_BASE="/tmp/pr-wt"
SESSION_IMPL="pr-run"
BIN=""
BIN_ARGS=""
BIN_ENV_LIST=()
PRINT_MODE=false
VERBOSE=false
USE_WORKTREE=false
DRY_RUN=false
STATUS_MODE=false
WATCH_MODE=false
WATCH_INTERVAL=5
CLEAN_MARKERS=false
CLEAN_WORKTREES=false
KILL_ACTIVE=false
OVERVIEW=false
CONFIG_FILE=""

# ─── Default bin detection ────────────────────────────────────────────────────
_default_bin() {
  if command -v claude &>/dev/null; then
    command -v claude
  elif [[ -x "$HOME/.local/bin/claude" ]]; then
    echo "$HOME/.local/bin/claude"
  else
    echo "claude"
  fi
}

# ─── Pre-scan per --config ────────────────────────────────────────────────────
_prev_arg=""
for _arg in "$@"; do
  if [[ "$_prev_arg" == "--config" ]]; then
    CONFIG_FILE="$_arg"
    break
  fi
  case "$_arg" in
    --config=*) CONFIG_FILE="${_arg#--config=}"; break ;;
  esac
  _prev_arg="$_arg"
done
unset _arg _prev_arg

# ─── Caricamento config file ──────────────────────────────────────────────────
_load_config() {
  local cfg="$1"
  [[ ! -f "$cfg" ]] && return
  while IFS= read -r _cfg_line; do
    [[ "$_cfg_line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${_cfg_line//[[:space:]]/}" ]] && continue
    if [[ "$_cfg_line" =~ ^([A-Z_]+)[[:space:]]*=[[:space:]]*(.*) ]]; then
      local _cfg_key="${BASH_REMATCH[1]}"
      local _cfg_val
      read -r _cfg_val <<< "${BASH_REMATCH[2]}"
      case "$_cfg_key" in
        BIN)         BIN="$_cfg_val" ;;
        BIN_ARGS)    BIN_ARGS="$_cfg_val" ;;
        BIN_ENV)     BIN_ENV_LIST+=("$_cfg_val") ;;
        SESSION)     SESSION_IMPL="$_cfg_val" ;;
        MARKER_DIR)  STATUS_MARKER_DIR="$_cfg_val" ;;
        PRINT)       [[ "$_cfg_val" == "true" ]] && PRINT_MODE=true ;;
        VERBOSE)     [[ "$_cfg_val" == "true" ]] && VERBOSE=true ;;
        WORKTREE)    [[ "$_cfg_val" == "true" ]] && USE_WORKTREE=true ;;
        OVERVIEW)    [[ "$_cfg_val" == "true" ]] && OVERVIEW=true ;;
      esac
    fi
  done < "$cfg"
}

_load_config "${CONFIG_FILE:-$SCRIPT_DIR/runner.conf}"
[[ -z "$BIN" ]] && BIN="$(_default_bin)"

# ─── CLI ──────────────────────────────────────────────────────────────────────
_usage() {
  awk 'NR>1 && /^set -/{exit} NR>1 && /^#/{sub(/^# ?/,""); print}' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)           shift; PROMPTS_DIR="${1:-}" ;;
    --dir=*)         PROMPTS_DIR="${1#--dir=}" ;;
    --work-dir)      shift; IMPL_WORK_DIR="${1:-}" ;;
    --work-dir=*)    IMPL_WORK_DIR="${1#--work-dir=}" ;;
    --impl-prompt)   shift; IMPL_PROMPT_FILE="${1:-}" ;;
    --impl-prompt=*) IMPL_PROMPT_FILE="${1#--impl-prompt=}" ;;
    --session)       shift; SESSION_IMPL="${1:-}" ;;
    --session=*)     SESSION_IMPL="${1#--session=}" ;;
    --marker-dir)    shift; STATUS_MARKER_DIR="${1:-}" ;;
    --marker-dir=*)  STATUS_MARKER_DIR="${1#--marker-dir=}" ;;
    --bin|--claude-bin)    shift; BIN="${1:-}" ;;
    --bin=*|--claude-bin=*) BIN="${1#*=}" ;;
    --bin-args)      shift; BIN_ARGS="${1:-}" ;;
    --bin-args=*)    BIN_ARGS="${1#--bin-args=}" ;;
    --bin-env)       shift; BIN_ENV_LIST+=("${1:-}") ;;
    --bin-env=*)     BIN_ENV_LIST+=("${1#--bin-env=}") ;;
    --config)        shift ;;   # già processato nel pre-scan
    --config=*)      ;;         # già processato nel pre-scan
    --print)            PRINT_MODE=true ;;
    --verbose)          VERBOSE=true ;;
    --worktree)         USE_WORKTREE=true ;;
    --dry-run)          DRY_RUN=true ;;
    --status)           STATUS_MODE=true ;;
    --watch)            WATCH_MODE=true; STATUS_MODE=true ;;
    --watch=*)          WATCH_MODE=true; STATUS_MODE=true; WATCH_INTERVAL="${1#--watch=}" ;;
    --clean-markers)    CLEAN_MARKERS=true ;;
    --clean-worktrees)  CLEAN_WORKTREES=true ;;
    --kill)             KILL_ACTIVE=true ;;
    --overview)         OVERVIEW=true ;;
    --help|-h)       _usage ;;
    *)
      printf '\033[1;31mERROR: unknown parameter: %s\033[0m\n' "$1" >&2
      printf 'Use --help for documentation.\n' >&2
      exit 1
      ;;
  esac
  shift
done

# ─── Validate parameters ──────────────────────────────────────────────────────
if [[ -z "$PROMPTS_DIR" ]]; then
  printf '\033[1;31mERROR: --dir is required.\033[0m\n' >&2
  printf 'Use --help for documentation.\n' >&2
  exit 1
fi

if [[ "$USE_WORKTREE" == "true" ]]; then
  if [[ -z "$IMPL_WORK_DIR" ]]; then
    printf '\033[1;31mERROR: --worktree requires --work-dir <git-repo-path>.\033[0m\n' >&2
    exit 1
  fi
  if ! git -C "$IMPL_WORK_DIR" rev-parse --git-dir &>/dev/null; then
    printf '\033[1;31mERROR: --work-dir is not a git repository: %s\033[0m\n' "$IMPL_WORK_DIR" >&2
    exit 1
  fi
fi

if [[ -n "$IMPL_PROMPT_FILE" ]] && [[ ! -f "$IMPL_PROMPT_FILE" ]]; then
  printf '\033[1;31mERROR: --impl-prompt file not found: %s\033[0m\n' "$IMPL_PROMPT_FILE" >&2
  exit 1
fi

if [[ ! -x "$BIN" ]] && ! command -v "$BIN" &>/dev/null; then
  printf '\033[1;31mERROR: binary not found: %s\033[0m\n' "$BIN" >&2
  printf 'Use --bin <path> or set BIN in runner.conf.\n' >&2
  exit 1
fi

# ─── Frontmatter parser ───────────────────────────────────────────────────────
# Sets global _PF_* variables (multiple return values from bash function)
_PF_BIN=""
_PF_BIN_ARGS=""
_PF_BIN_ENV_LIST=()
_PF_PROMPT_START=1

_parse_frontmatter() {
  local file="$1"
  _PF_BIN=""
  _PF_BIN_ARGS=""
  _PF_BIN_ENV_LIST=()
  _PF_PROMPT_START=1

  local first_line
  first_line=$(head -1 "$file" 2>/dev/null) || return
  [[ "$first_line" != "---" ]] && return

  local end_line
  end_line=$(awk 'NR>1 && /^---$/{print NR; exit}' "$file")
  [[ -z "$end_line" ]] && return

  _PF_PROMPT_START=$((end_line + 1))

  while IFS= read -r _fm_line; do
    if [[ "$_fm_line" =~ ^([a-z-]+)[[:space:]]*:[[:space:]]*(.*) ]]; then
      local _fm_key="${BASH_REMATCH[1]}"
      local _fm_val
      read -r _fm_val <<< "${BASH_REMATCH[2]}"
      case "$_fm_key" in
        bin)      _PF_BIN="$_fm_val" ;;
        bin-args) _PF_BIN_ARGS="$_fm_val" ;;
        bin-env)  _PF_BIN_ENV_LIST+=("$_fm_val") ;;
      esac
    fi
  done < <(sed -n "2,$((end_line - 1))p" "$file")
}

# ─── Discover tasks ───────────────────────────────────────────────────────────
_discover_tasks() {
  if [[ ! -d "$PROMPTS_DIR" ]]; then
    printf '\033[1;31mERROR: --dir not found: %s\033[0m\n' "$PROMPTS_DIR" >&2
    exit 1
  fi
  while IFS= read -r f; do
    rel="${f#$PROMPTS_DIR/}"
    echo "${rel%.*}"
  done < <(find "$PROMPTS_DIR" \( -name "*.md" -o -name "*.txt" \) | sort)
}

TASKS=()
while IFS= read -r _t; do TASKS+=("$_t"); done < <(_discover_tasks)
TOTAL=${#TASKS[@]}

if [[ $TOTAL -eq 0 ]] && ! $STATUS_MODE; then
  printf '\033[1;31mERROR: no .md or .txt files found in %s\033[0m\n' "$PROMPTS_DIR" >&2
  exit 1
fi

# ─── Helpers ──────────────────────────────────────────────────────────────────
_safe_id()     { echo "${1//\//__}" | tr ' ' '_'; }
_marker_base() { echo "$STATUS_MARKER_DIR/impl-$(_safe_id "$1")"; }
_impl_runner() { echo "$STATUS_MARKER_DIR/run-impl-$(_safe_id "$1").sh"; }
_prompt_file() {
  local f
  for ext in md txt; do
    f="$PROMPTS_DIR/${1}.${ext}"
    [[ -f "$f" ]] && echo "$f" && return
  done
}

# ─── Status dashboard ─────────────────────────────────────────────────────────
print_status() {
  local IMPL_DONE=0 IMPL_RUNNING=0 IMPL_FAIL=0

  printf '\n  %-38s  %s\n' "TASK" "STATUS"
  printf '  %.0s─' {1..62}; printf '\n'

  for task in "${TASKS[@]}"; do
    local marker impl_status
    marker=$(_marker_base "$task")

    if [[ -f "${marker}.done" ]] && [[ -f "${marker}.complete" ]]; then
      impl_status="✔  done (confirmed)"
      ((IMPL_DONE++)) || true
    elif [[ -f "${marker}.done" ]]; then
      impl_status="✔  done"
      ((IMPL_DONE++)) || true
    elif [[ -f "${marker}.running" ]]; then
      impl_status="⟳  running"
      ((IMPL_RUNNING++)) || true
    elif [[ -f "${marker}.fail" ]]; then
      [[ -f "${marker}.complete" ]] \
        && impl_status="⚠  incomplete (.complete present)" \
        || impl_status="✖  failed"
      ((IMPL_FAIL++)) || true
    else
      impl_status="—  not started"
    fi

    printf '  %-38s  %s\n' "$task" "$impl_status"
  done

  printf '  %.0s─' {1..62}; printf '\n'
  printf '  %d / %d done  (running: %d  failed: %d)\n\n' \
    "$IMPL_DONE" "$TOTAL" "$IMPL_RUNNING" "$IMPL_FAIL"

  _IMPL_DONE=$IMPL_DONE
  _IMPL_RUNNING=$IMPL_RUNNING
}

# ─── Status / watch ───────────────────────────────────────────────────────────
if $STATUS_MODE; then
  if $WATCH_MODE; then
    _PREV_DONE=-1
    while true; do
      clear
      printf '  \033[1;36mprompt-runner — watch (every %ds, Ctrl+C to quit)\033[0m\n' "$WATCH_INTERVAL"
      printf '  \033[2m%s\033[0m\n' "$(date '+%H:%M:%S')"
      print_status
      if [[ "$_IMPL_RUNNING" -eq 0 ]] && [[ "$_IMPL_DONE" -gt 0 ]] && [[ "$_IMPL_DONE" -ne "$_PREV_DONE" ]]; then
        _PREV_DONE=$_IMPL_DONE
        if [[ "$_IMPL_DONE" -eq "$TOTAL" ]]; then
          osascript -e 'display notification "All tasks completed!" with title "prompt-runner" sound name "Glass"' 2>/dev/null || true
        else
          osascript -e "display notification \"$_IMPL_DONE / $TOTAL done\" with title \"prompt-runner\" sound name \"Bottle\"" 2>/dev/null || true
        fi
      fi
      sleep "$WATCH_INTERVAL"
    done
  else
    print_status
    exit 0
  fi
fi

# ─── Build runners ────────────────────────────────────────────────────────────
build_impl_runners() {
  mkdir -p "$STATUS_MARKER_DIR"

  for task in "${TASKS[@]}"; do
    local safe_id runner marker src work_dir
    safe_id=$(_safe_id "$task")
    runner=$(_impl_runner "$task")
    marker=$(_marker_base "$task")
    src=$(_prompt_file "$task")
    work_dir="${IMPL_WORK_DIR:-$SCRIPT_DIR}"

    [[ -z "$src" ]] && { printf 'WARN: prompt not found for "%s", skipping\n' "$task" >&2; continue; }

    # Per-task frontmatter
    _parse_frontmatter "$src"
    local task_bin="${_PF_BIN:-$BIN}"
    local task_bin_args="${_PF_BIN_ARGS:-$BIN_ARGS}"
    local task_prompt_start="$_PF_PROMPT_START"

    # Env vars: global + frontmatter merge; safe form for set -u
    local task_env_list=(
      ${BIN_ENV_LIST[@]+"${BIN_ENV_LIST[@]}"}
      ${_PF_BIN_ENV_LIST[@]+"${_PF_BIN_ENV_LIST[@]}"}
    )

    local print_flag="" verbose_flag=""
    [[ "$PRINT_MODE" == "true" ]] && print_flag="-p"
    [[ "$VERBOSE" == "true" ]] && verbose_flag="--verbose"

    # Build "env KEY=VAL ..." prefix for the command
    local env_prefix=""
    if [[ ${#task_env_list[@]} -gt 0 ]]; then
      env_prefix="env"
      local e
      for e in "${task_env_list[@]}"; do
        env_prefix+=" ${e}"
      done
    fi

    # Read prompt command (skip frontmatter if present)
    local cat_prompt
    if [[ "$task_prompt_start" -gt 1 ]]; then
      cat_prompt="tail -n +${task_prompt_start} '${src}'"
    else
      cat_prompt="cat '${src}'"
    fi

    cat > "$runner" << IMPL_EOF
#!/usr/bin/env bash
clear
printf '\033[1;33m╔══════════════════════════════════════════════════════════╗\n'
printf '║  %-56s║\n' "  ${task}"
printf '╚══════════════════════════════════════════════════════════╝\033[0m\n\n'

MARKER='${marker}'
touch "\${MARKER}.running"
rm -f "\${MARKER}.done" "\${MARKER}.fail"

ACTUAL_WORK_DIR='${work_dir}'
if [[ '${USE_WORKTREE}' == "true" ]]; then
  WORKTREE_PATH='${WORKTREE_BASE}/${safe_id}'
  rm -rf "\${WORKTREE_PATH}"
  git -C '${work_dir}' worktree add "\${WORKTREE_PATH}" HEAD
  ACTUAL_WORK_DIR="\${WORKTREE_PATH}"
  printf '\033[2m  worktree: %s\033[0m\n\n' "\${WORKTREE_PATH}"
fi
cd "\${ACTUAL_WORK_DIR}"

DELAYS=(10 30 60)
attempt=0
STATUS=1

# Auto-answer the "trust this folder" prompt on first launch
{ sleep 2; tmux send-keys -t "\$TMUX_PANE" "" Enter; } &
_TRUST_PID=\$!

while [[ \$attempt -le \${#DELAYS[@]} ]]; do
  if [[ \$attempt -gt 0 ]]; then
    delay="\${DELAYS[\$attempt-1]}"
    printf '\n\033[1;33m↻  Attempt %d / %d — waiting %ds...\033[0m\n\n' \
      "\$((attempt+1))" "\$((\${#DELAYS[@]}+1))" "\$delay"
    sleep "\$delay"
  fi

  {
    [[ -n '${IMPL_PROMPT_FILE}' ]] && [[ -f '${IMPL_PROMPT_FILE}' ]] && cat '${IMPL_PROMPT_FILE}' && printf '\n\n---\n\n'
    ${cat_prompt}
    [[ '${PRINT_MODE}' != "true" ]] && printf '\n\n---\n\nWhen done, write the file ${marker}.complete with a brief summary of what you did.\n'
  } | ${env_prefix:+${env_prefix} }${task_bin}${task_bin_args:+ ${task_bin_args}}${print_flag:+ ${print_flag}}${verbose_flag:+ ${verbose_flag}} -
  STATUS=\$?
  kill "\$_TRUST_PID" 2>/dev/null || true

  [[ \$STATUS -eq 0 ]] && break
  ((attempt++)) || true
done

rm -f "\${MARKER}.running"

if [[ \$STATUS -eq 0 ]] && [[ -f "\${MARKER}.complete" ]]; then
  touch "\${MARKER}.done"
  printf '\n\033[1;32m✔  DONE: ${task}\033[0m\n'
  printf '\n--- summary ---\n'; cat "\${MARKER}.complete"; printf '\n'
  tmux rename-window "✔-${safe_id}" 2>/dev/null || true
elif [[ \$STATUS -eq 0 ]]; then
  touch "\${MARKER}.done"
  printf '\n\033[1;32m✔  DONE: ${task}\033[0m\n'
  tmux rename-window "✔-${safe_id}" 2>/dev/null || true
else
  touch "\${MARKER}.fail"
  printf '\n\033[1;31m✖  FAILED after %d attempts: ${task}\033[0m\n' "\$((attempt+1))"
  tmux rename-window "✖-${safe_id}" 2>/dev/null || true
fi
IMPL_EOF
    chmod +x "$runner"
  done
}

# ─── Launch tmux (separate windows) ──────────────────────────────────────────
launch_tmux() {
  local session="$1"
  local launched=0

  tmux kill-session -t "$session" 2>/dev/null || true

  local FIRST=true
  for task in "${TASKS[@]}"; do
    local safe_id runner
    safe_id=$(_safe_id "$task")
    runner=$(_impl_runner "$task")

    [[ ! -f "$runner" ]] && continue

    if $FIRST; then
      tmux new-session -d -s "$session" -n "$safe_id" -x 220 -y 50
      FIRST=false
    else
      tmux new-window -t "${session}:" -n "$safe_id"
    fi

    sleep 0.3
    tmux send-keys -t "${session}:${safe_id}" "bash '${runner}'" Enter
    ((launched++)) || true
  done

  printf '→ Started %d tmux windows in session "%s"\n' "$launched" "$session"
}

# ─── Launch tmux (pane grid, --overview) ─────────────────────────────────────
launch_tmux_overview() {
  local session="$1"
  local launched=0

  tmux kill-session -t "$session" 2>/dev/null || true

  local FIRST=true
  for task in "${TASKS[@]}"; do
    local runner
    runner=$(_impl_runner "$task")

    [[ ! -f "$runner" ]] && continue

    if $FIRST; then
      tmux new-session -d -s "$session" -n "overview" -x 220 -y 50
      tmux send-keys -t "${session}:overview" "bash '${runner}'" Enter
      FIRST=false
    else
      tmux split-window -t "${session}:overview" -h "bash '${runner}'"
      tmux select-layout -t "${session}:overview" tiled
    fi

    sleep 0.1
    ((launched++)) || true
  done

  tmux select-layout -t "${session}:overview" tiled 2>/dev/null || true
  tmux set-option -t "$session" -g mouse on 2>/dev/null || true

  printf '→ Started %d tmux panes in grid in session "%s"\n' "$launched" "$session"
}

print_summary() {
  local session="$1"
  printf '\n'
  printf '═%.0s' {1..62}; printf '\n'
  printf '  Session started → tmux "%s"\n' "$session"
  printf '═%.0s' {1..62}; printf '\n\n'
  if $OVERVIEW; then
    printf '  Ctrl+B Z       zoom a pane (toggle fullscreen)\n'
    printf '  Ctrl+B Q       show pane numbers\n'
    printf '  Ctrl+B arrows  navigate between panes\n'
  else
    printf '  Ctrl+B W       list windows\n'
    printf '  Ctrl+B N / P   next / previous window\n'
  fi
  printf '  Ctrl+B D       detach (tasks keep running in background)\n\n'
  printf '  Status:  bash run.sh --dir "%s" --status\n\n' "$PROMPTS_DIR"
}

# ─── Dry run ──────────────────────────────────────────────────────────────────
if $DRY_RUN; then
  build_impl_runners
  printf '\nDry run: runners written to %s\n' "$STATUS_MARKER_DIR"
  ls -lh "$STATUS_MARKER_DIR"/run-impl-*.sh 2>/dev/null | awk '{print $5, $9}' || true
  exit 0
fi

# ─── Execute ──────────────────────────────────────────────────────────────────
if $KILL_ACTIVE; then
  tmux kill-session -t "$SESSION_IMPL" 2>/dev/null && printf '→ tmux session "%s" killed\n' "$SESSION_IMPL" || true
  _kill_pat="${BIN}"
  [[ -n "$BIN_ARGS" ]] && _kill_pat+=" ${BIN_ARGS}"
  pkill -f "$_kill_pat" 2>/dev/null && printf '→ "%s" processes killed\n' "$(basename "$BIN")" || true
fi

if $CLEAN_MARKERS; then
  rm -f "$STATUS_MARKER_DIR"/impl-*.done \
        "$STATUS_MARKER_DIR"/impl-*.fail \
        "$STATUS_MARKER_DIR"/impl-*.running \
        "$STATUS_MARKER_DIR"/impl-*.complete
  printf '→ Markers removed from %s\n' "$STATUS_MARKER_DIR"
fi

if $CLEAN_WORKTREES; then
  rm -rf "${WORKTREE_BASE:?}/"
  printf '→ Residual worktrees removed from %s\n' "$WORKTREE_BASE"
  if [[ -n "$IMPL_WORK_DIR" ]] && git -C "$IMPL_WORK_DIR" rev-parse --git-dir &>/dev/null; then
    git -C "$IMPL_WORK_DIR" worktree prune
    printf '→ Worktrees removed from git registry in %s\n' "$IMPL_WORK_DIR"
  fi
fi

build_impl_runners

if $OVERVIEW; then
  launch_tmux_overview "$SESSION_IMPL"
else
  launch_tmux "$SESSION_IMPL"
fi

print_summary "$SESSION_IMPL"
tmux attach-session -t "$SESSION_IMPL"
