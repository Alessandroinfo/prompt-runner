# claude-parallel-runner

Lancia N istanze Claude in parallelo via tmux. Ogni file `.md` o `.txt` trovato ricorsivamente nella directory indicata diventa una finestra tmux indipendente all'interno di un'unica sessione.

## Setup

```bash
cp config.sh.example config.sh
# edita config.sh
```

## Comandi

```bash
bash run.sh --dir /path/to/prompts              # avvia una finestra per ogni file trovato
bash run.sh --dir /path/to/prompts --print      # usa claude -p (consigliato per sessioni parallele)
bash run.sh --dir /path/to/prompts --worktree   # crea git worktree isolato per ogni runner
bash run.sh --dir /path/to/prompts --status     # dashboard stato
bash run.sh --dir /path/to/prompts --watch      # watch con refresh (default 5s)
bash run.sh --dir /path/to/prompts --dry-run    # costruisce runner senza lanciare Claude
bash run.sh --dir /path/to/prompts --force      # riesegue anche i task già completati
```

I task già completati vengono saltati di default.

## Struttura prompt

Ogni file `.md` o `.txt` nella directory (incluse sottocartelle) diventa un task.
Il path relativo viene usato come identificatore: `piattaforma/prenotazioni.md` → task `piattaforma/prenotazioni`.

Opzionalmente si può anteporre un file comune a ogni prompt tramite `IMPL_PROMPT_FILE` in `config.sh`.

## config.sh

| Variabile | Descrizione | Default |
|---|---|---|
| `IMPL_PROMPT_FILE` | File anteposto a ogni prompt (opzionale) | — |
| `IMPL_WORK_DIR` | Working directory durante l'esecuzione | `./` |
| `STATUS_MARKER_DIR` | Marcatori stato `.running/.done/.fail/.complete` | `/tmp/cpr-status` |
| `CLAUDE_BIN` | Percorso binario claude | `~/.local/bin/claude` |
| `SESSION_IMPL` | Nome sessione tmux | `cpr-impl` |
| `CLAUDE_PRINT` | Usa `-p` (print mode non interattivo) | `false` |
| `USE_WORKTREE` | Crea git worktree isolato per ogni runner | `false` |
