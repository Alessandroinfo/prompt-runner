#!/usr/bin/env bash
#
# claude-parallel-runner — esegue prompt in parallelo su Claude Code via tmux
#
# UTILIZZO
#   bash run.sh --dir <prompts-dir> [opzioni]
#
# PARAMETRI OBBLIGATORI
#   --dir <path>              Directory contenente i file prompt (.md / .txt).
#                             La ricerca è ricorsiva: le sottocartelle diventano
#                             prefisso del nome task (es. piattaforma/crm).
#
# PARAMETRI OPZIONALI
#   --work-dir <path>         Directory di lavoro in cui Claude opera.
#                             Obbligatoria quando si usa --worktree: deve essere
#                             un repository git.
#                             Senza --worktree Claude usa la directory corrente.
#
#   --worktree                Per ogni task crea un git worktree isolato a partire
#                             da --work-dir. I worktree vengono rimossi al termine.
#                             Richiede --work-dir puntato a un repository git.
#
#   --print                   Esegue Claude in modalità non interattiva (claude -p).
#                             Obbligatorio per sessioni parallele: senza questo flag
#                             Claude apre una sessione interattiva e non termina.
#
#   --verbose                 Aggiunge --verbose al comando claude. In combinazione
#                             con --print: tool call, thinking e trace di esecuzione
#                             vengono scritti su stderr; stdout contiene solo la
#                             risposta finale.
#
#   --impl-prompt <file>      File di testo anteposto a ogni prompt prima
#                             dell'invio a Claude (istruzioni di sistema globali).
#
#   --session <nome>          Nome della sessione tmux (default: cpr-impl).
#
#   --marker-dir <path>       Directory dove vengono scritti i marker di stato
#                             (.running / .done / .fail). Default: /tmp/cpr-status.
#
#   --claude-bin <path>       Percorso dell'eseguibile claude.
#                             Default: ricerca in PATH, poi ~/.local/bin/claude.
#
# MODALITÀ OPERATIVE
#   --status                  Mostra il dashboard di stato dei task e termina.
#
#   --watch[=<secondi>]       Aggiorna il dashboard ogni N secondi (default: 5).
#                             Manda notifica macOS al completamento.
#                             Ctrl+C per uscire.
#
#   --dry-run                 Genera i runner senza avviare tmux. Utile per
#                             verificare la configurazione prima di eseguire.
#
#   --clean-markers           Rimuove tutti i marker di stato (.running / .done /
#                             .fail / .complete) prima di avviare i task.
#                             Di default i marker esistenti vengono lasciati intatti.
#
#   --clean-worktrees         Rimuove la directory /tmp/cpr-wt/ prima di avviare
#                             i task, eliminando eventuali worktree residui.
#                             Di default i worktree esistenti vengono lasciati intatti.
#
#   --kill                    Killa la sessione tmux attiva (SESSION_IMPL) e tutti
#                             i processi claude in esecuzione prima di avviare.
#                             Utile per ripartire da zero senza sessioni zombie.
#
#   --overview                Mostra tutti i task contemporaneamente in una griglia
#                             di pane tmux (layout tiled) invece di finestre separate.
#                             Ctrl+B Z  zoom su un singolo pane (toggle).
#                             Ctrl+B Q  mostra i numeri dei pane.
#                             Ctrl+B D  stacca (i task continuano in background).
#
# ESEMPI
#   # Esecuzione base con print mode
#   bash run.sh --dir ./prompts --print
#
#   # Esecuzione con worktree isolato su un progetto git
#   bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo
#
#   # Anteponi istruzioni di sistema a ogni prompt
#   bash run.sh --dir ./prompts --print --impl-prompt ./system.md
#
#   # Sessione con nome custom e marker in directory dedicata
#   bash run.sh --dir ./prompts --print --session myproject --marker-dir /tmp/myproject-status
#
#   # Controlla lo stato di una sessione in esecuzione
#   bash run.sh --dir ./prompts --status
#
#   # Watch automatico ogni 10 secondi
#   bash run.sh --dir ./prompts --watch=10
#
#   # Dry run: genera i runner e mostrali senza eseguire
#   bash run.sh --dir ./prompts --print --dry-run
#
#   # Avvia pulendo prima i marker di stato precedenti
#   bash run.sh --dir ./prompts --print --clean-markers
#
#   # Avvia pulendo sia marker che worktree residui
#   bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo --clean-markers --clean-worktrees
#
#   # Killa sessione e processi attivi prima di riavviare
#   bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo --kill
#
#   # Vista griglia: tutti i task visibili contemporaneamente
#   bash run.sh --dir ./prompts --print --overview
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Defaults ─────────────────────────────────────────────────────────────────
PROMPTS_DIR=""
IMPL_WORK_DIR=""
IMPL_PROMPT_FILE=""
STATUS_MARKER_DIR="/tmp/cpr-status"
SESSION_IMPL="cpr-impl"
CLAUDE_PRINT=false
CLAUDE_VERBOSE=false
USE_WORKTREE=false
DRY_RUN=false
STATUS_MODE=false
WATCH_MODE=false
WATCH_INTERVAL=5
CLEAN_MARKERS=false
CLEAN_WORKTREES=false
KILL_ACTIVE=false
OVERVIEW=false

# Ricerca claude bin: PATH prima, poi posizione comune
_default_claude_bin() {
  if command -v claude &>/dev/null; then
    command -v claude
  elif [[ -x "$HOME/.local/bin/claude" ]]; then
    echo "$HOME/.local/bin/claude"
  else
    echo "claude"
  fi
}
CLAUDE_BIN="$(_default_claude_bin)"

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
    --claude-bin)    shift; CLAUDE_BIN="${1:-}" ;;
    --claude-bin=*)  CLAUDE_BIN="${1#--claude-bin=}" ;;
    --print)            CLAUDE_PRINT=true ;;
    --verbose)          CLAUDE_VERBOSE=true ;;
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
      printf '\033[1;31mERROR: parametro sconosciuto: %s\033[0m\n' "$1" >&2
      printf 'Usa --help per la documentazione.\n' >&2
      exit 1
      ;;
  esac
  shift
done

# ─── Validazione parametri ────────────────────────────────────────────────────
if [[ -z "$PROMPTS_DIR" ]]; then
  printf '\033[1;31mERROR: --dir è obbligatorio.\033[0m\n' >&2
  printf 'Usa --help per la documentazione.\n' >&2
  exit 1
fi

if [[ "$USE_WORKTREE" == "true" ]]; then
  if [[ -z "$IMPL_WORK_DIR" ]]; then
    printf '\033[1;31mERROR: --worktree richiede --work-dir <path-repo-git>.\033[0m\n' >&2
    exit 1
  fi
  if ! git -C "$IMPL_WORK_DIR" rev-parse --git-dir &>/dev/null; then
    printf '\033[1;31mERROR: --work-dir non è un repository git: %s\033[0m\n' "$IMPL_WORK_DIR" >&2
    exit 1
  fi
fi

if [[ -n "$IMPL_PROMPT_FILE" ]] && [[ ! -f "$IMPL_PROMPT_FILE" ]]; then
  printf '\033[1;31mERROR: --impl-prompt file non trovato: %s\033[0m\n' "$IMPL_PROMPT_FILE" >&2
  exit 1
fi

if [[ ! -x "$CLAUDE_BIN" ]] && ! command -v "$CLAUDE_BIN" &>/dev/null; then
  printf '\033[1;31mERROR: claude non trovato: %s\033[0m\n' "$CLAUDE_BIN" >&2
  printf 'Usa --claude-bin <path> per specificare il percorso.\n' >&2
  exit 1
fi

# ─── Discover tasks ───────────────────────────────────────────────────────────
_discover_tasks() {
  if [[ ! -d "$PROMPTS_DIR" ]]; then
    printf '\033[1;31mERROR: --dir non trovata: %s\033[0m\n' "$PROMPTS_DIR" >&2
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
  printf '\033[1;31mERROR: nessun file .md o .txt trovato in %s\033[0m\n' "$PROMPTS_DIR" >&2
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

  printf '\n  %-38s  %s\n' "TASK" "STATO"
  printf '  %.0s─' {1..62}; printf '\n'

  for task in "${TASKS[@]}"; do
    local marker impl_status
    marker=$(_marker_base "$task")

    if [[ -f "${marker}.done" ]] && [[ -f "${marker}.complete" ]]; then
      impl_status="✔  completato (confermato)"
      ((IMPL_DONE++)) || true
    elif [[ -f "${marker}.done" ]]; then
      impl_status="✔  completato"
      ((IMPL_DONE++)) || true
    elif [[ -f "${marker}.running" ]]; then
      impl_status="⟳  in corso"
      ((IMPL_RUNNING++)) || true
    elif [[ -f "${marker}.fail" ]]; then
      [[ -f "${marker}.complete" ]] \
        && impl_status="⚠  incompleto (.complete presente)" \
        || impl_status="✖  fallito"
      ((IMPL_FAIL++)) || true
    else
      impl_status="—  non avviato"
    fi

    printf '  %-38s  %s\n' "$task" "$impl_status"
  done

  printf '  %.0s─' {1..62}; printf '\n'
  printf '  %d / %d completati  (in corso: %d  falliti: %d)\n\n' \
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
      printf '  \033[1;36mclaude-parallel-runner — watch (ogni %ds, Ctrl+C per uscire)\033[0m\n' "$WATCH_INTERVAL"
      printf '  \033[2m%s\033[0m\n' "$(date '+%H:%M:%S')"
      print_status
      if [[ "$_IMPL_RUNNING" -eq 0 ]] && [[ "$_IMPL_DONE" -gt 0 ]] && [[ "$_IMPL_DONE" -ne "$_PREV_DONE" ]]; then
        _PREV_DONE=$_IMPL_DONE
        if [[ "$_IMPL_DONE" -eq "$TOTAL" ]]; then
          osascript -e 'display notification "Tutti i task completati!" with title "claude-parallel-runner" sound name "Glass"' 2>/dev/null || true
        else
          osascript -e "display notification \"$_IMPL_DONE / $TOTAL completati\" with title \"claude-parallel-runner\" sound name \"Bottle\"" 2>/dev/null || true
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
    local safe_id runner marker src work_dir print_flag verbose_flag use_worktree
    safe_id=$(_safe_id "$task")
    runner=$(_impl_runner "$task")
    marker=$(_marker_base "$task")
    src=$(_prompt_file "$task")
    work_dir="${IMPL_WORK_DIR:-$SCRIPT_DIR}"
    use_worktree="$USE_WORKTREE"
    [[ "$CLAUDE_PRINT" == "true" ]] && print_flag="-p" || print_flag=""
    [[ "$CLAUDE_VERBOSE" == "true" ]] && verbose_flag="--verbose" || verbose_flag=""

    [[ -z "$src" ]] && { printf 'WARN: prompt non trovato per "%s", skip\n' "$task" >&2; continue; }

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
if [[ '${use_worktree}' == "true" ]]; then
  WORKTREE_PATH="/tmp/cpr-wt/${safe_id}"
  rm -rf "\${WORKTREE_PATH}"
  git -C '${work_dir}' worktree add "\${WORKTREE_PATH}" HEAD
  ACTUAL_WORK_DIR="\${WORKTREE_PATH}"
  printf '\033[2m  worktree: %s\033[0m\n\n' "\${WORKTREE_PATH}"
fi
cd "\${ACTUAL_WORK_DIR}"

DELAYS=(10 30 60)
attempt=0
STATUS=1

# Risponde automaticamente al prompt "trust this folder" al primo avvio
{ sleep 2; tmux send-keys -t "\$TMUX_PANE" "" Enter; } &
_TRUST_PID=\$!

while [[ \$attempt -le \${#DELAYS[@]} ]]; do
  if [[ \$attempt -gt 0 ]]; then
    delay="\${DELAYS[\$attempt-1]}"
    printf '\n\033[1;33m↻  Tentativo %d / %d — attendo %ds...\033[0m\n\n' \
      "\$((attempt+1))" "\$((\${#DELAYS[@]}+1))" "\$delay"
    sleep "\$delay"
  fi

  {
    [[ -n '${IMPL_PROMPT_FILE}' ]] && [[ -f '${IMPL_PROMPT_FILE}' ]] && cat '${IMPL_PROMPT_FILE}' && printf '\n\n---\n\n'
    cat '${src}'
    [[ '${CLAUDE_PRINT}' != "true" ]] && printf '\n\n---\n\nAl termine del lavoro scrivi il file ${marker}.complete con un breve riepilogo di cosa hai fatto.\n'
  } | CLAUDE_CODE_USE_FOUNDRY=1 ${CLAUDE_BIN} --dangerously-skip-permissions ${print_flag} ${verbose_flag} -
  STATUS=\$?
  kill "\$_TRUST_PID" 2>/dev/null || true

  [[ \$STATUS -eq 0 ]] && break
  ((attempt++)) || true
done

rm -f "\${MARKER}.running"

if [[ \$STATUS -eq 0 ]] && [[ -f "\${MARKER}.complete" ]]; then
  touch "\${MARKER}.done"
  printf '\n\033[1;32m✔  DONE: ${task}\033[0m\n'
  printf '\n--- riepilogo ---\n'; cat "\${MARKER}.complete"; printf '\n'
  tmux rename-window "✔-${safe_id}" 2>/dev/null || true
elif [[ \$STATUS -eq 0 ]]; then
  touch "\${MARKER}.done"
  printf '\n\033[1;32m✔  DONE: ${task}\033[0m\n'
  tmux rename-window "✔-${safe_id}" 2>/dev/null || true
else
  touch "\${MARKER}.fail"
  printf '\n\033[1;31m✖  FAILED dopo %d tentativi: ${task}\033[0m\n' "\$((attempt+1))"
  tmux rename-window "✖-${safe_id}" 2>/dev/null || true
fi
IMPL_EOF
    chmod +x "$runner"
  done
}

# ─── Launch tmux (finestre separate) ──────────────────────────────────────────
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

  printf '→ Avviate %d finestre tmux nella sessione "%s"\n' "$launched" "$session"
}

# ─── Launch tmux (griglia pane, --overview) ───────────────────────────────────
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

  # Applica layout tiled finale per distribuzione uniforme
  tmux select-layout -t "${session}:overview" tiled 2>/dev/null || true

  # Mouse mode: clic per cambiare pane, scroll con rotella
  tmux set-option -t "$session" -g mouse on 2>/dev/null || true

  printf '→ Avviati %d pane tmux in griglia nella sessione "%s"\n' "$launched" "$session"
}

print_summary() {
  local session="$1"
  printf '\n'
  printf '═%.0s' {1..62}; printf '\n'
  printf '  Sessioni avviate → tmux "%s"\n' "$session"
  printf '═%.0s' {1..62}; printf '\n\n'
  if $OVERVIEW; then
    printf '  Ctrl+B Z       zoom su un pane (toggle fullscreen)\n'
    printf '  Ctrl+B Q       mostra i numeri dei pane\n'
    printf '  Ctrl+B frecce  naviga tra i pane\n'
  else
    printf '  Ctrl+B W       elenco finestre\n'
    printf '  Ctrl+B N / P   finestra successiva / precedente\n'
  fi
  printf '  Ctrl+B D       stacca (sessioni continuano in background)\n\n'
  printf '  Stato:  bash run.sh --dir "%s" --status\n\n' "$PROMPTS_DIR"
}

# ─── Dry run ──────────────────────────────────────────────────────────────────
if $DRY_RUN; then
  build_impl_runners
  printf '\nDry run: runner scritti in %s\n' "$STATUS_MARKER_DIR"
  ls -lh "$STATUS_MARKER_DIR"/run-impl-*.sh 2>/dev/null | awk '{print $5, $9}' || true
  exit 0
fi

# ─── Execute ──────────────────────────────────────────────────────────────────
if $KILL_ACTIVE; then
  tmux kill-session -t "$SESSION_IMPL" 2>/dev/null && printf '→ Sessione tmux "%s" terminata\n' "$SESSION_IMPL" || true
  _print_flag=""
  _verbose_flag=""
  [[ "$CLAUDE_PRINT" == "true" ]] && _print_flag=" -p"
  [[ "$CLAUDE_VERBOSE" == "true" ]] && _verbose_flag=" --verbose"
  _kill_pattern="${CLAUDE_BIN} --dangerously-skip-permissions${_print_flag}${_verbose_flag} -"
  pkill -f "$_kill_pattern" 2>/dev/null && printf '→ Processi claude terminati\n' || true
fi

if $CLEAN_MARKERS; then
  rm -f "$STATUS_MARKER_DIR"/impl-*.done \
        "$STATUS_MARKER_DIR"/impl-*.fail \
        "$STATUS_MARKER_DIR"/impl-*.running \
        "$STATUS_MARKER_DIR"/impl-*.complete
  printf '→ Marker rimossi da %s\n' "$STATUS_MARKER_DIR"
fi

if $CLEAN_WORKTREES; then
  rm -rf /tmp/cpr-wt/
  printf '→ Worktree residui rimossi da /tmp/cpr-wt/\n'
  if [[ -n "$IMPL_WORK_DIR" ]] && git -C "$IMPL_WORK_DIR" rev-parse --git-dir &>/dev/null; then
    git -C "$IMPL_WORK_DIR" worktree prune
    printf '→ Worktree rimossi dal registro git in %s\n' "$IMPL_WORK_DIR"
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
