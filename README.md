# prompt-runner

Run N LLM CLI instances in parallel via tmux. Every `.md` or `.txt` file found recursively in a directory becomes an independent tmux window inside a single session.

Works with any CLI that reads a prompt from stdin — Claude Code, Aider, `llm`, or any custom binary.

## Requirements

- [tmux](https://github.com/tmux/tmux)
- An LLM CLI (e.g. [Claude Code](https://claude.ai/code))

## Quick start

```bash
# 1. Clone
git clone https://github.com/Alessandroinfo/prompt-runner.git
cd prompt-runner

# 2. Configure (optional — CLI flags work without a config file)
cp runner.conf.example runner.conf
# edit runner.conf with your binary path and args

# 3. Run
bash run.sh --dir ./prompts --print
```

`--print` enables non-interactive mode (required for parallel Claude Code runs).

## Configuration

Copy `runner.conf.example` to `runner.conf` and fill in the values. `runner.conf` is gitignored (it may contain API keys). CLI flags always override config file values.

| Key | Description | Default |
|---|---|---|
| `BIN` | Binary to run | auto-detect `claude` |
| `BIN_ARGS` | Extra arguments for the binary | — |
| `BIN_ENV` | Environment variable (repeatable) | — |
| `SESSION` | tmux session name | `pr-run` |
| `MARKER_DIR` | Directory for status markers | `/tmp/pr-status` |
| `PRINT` | Non-interactive mode | `false` |
| `VERBOSE` | Verbose output | `false` |
| `WORKTREE` | Create git worktrees | `false` |
| `OVERVIEW` | Tiled pane grid layout | `false` |

### Per-prompt frontmatter

Any prompt file can override the binary via a YAML frontmatter block:

```markdown
---
bin: /usr/local/bin/aider
bin-args: --no-auto-commits --model gpt-4o
bin-env: OPENAI_API_KEY=sk-...
---

Your prompt starts here.
```

The frontmatter is stripped before the prompt is sent. `bin-env` values merge with global ones.

## Usage

```bash
bash run.sh --dir <prompts-dir> [options]
```

### Common examples

```bash
# Claude Code with skip-permissions (via runner.conf)
# runner.conf: BIN=claude / BIN_ARGS=--dangerously-skip-permissions / PRINT=true
bash run.sh --dir ./prompts

# Explicit flags (no config file)
bash run.sh --dir ./prompts --print \
  --bin claude \
  --bin-args "--dangerously-skip-permissions" \
  --bin-env CLAUDE_CODE_USE_FOUNDRY=1

# Aider
bash run.sh --dir ./prompts \
  --bin aider \
  --bin-args "--no-auto-commits --model gpt-4o" \
  --bin-env OPENAI_API_KEY=sk-...

# Isolated git worktree per task
bash run.sh --dir ./prompts --worktree --work-dir /path/to/repo

# Prepend shared system instructions to every prompt
bash run.sh --dir ./prompts --impl-prompt ./prompt-master.md

# Live dashboard (refresh every 10s, macOS notification on completion)
bash run.sh --dir ./prompts --watch=10

# Start fresh: kill active session, clear markers and worktrees
bash run.sh --dir ./prompts --worktree --work-dir /path/to/repo \
  --kill --clean-markers --clean-worktrees
```

## All flags

| Flag | Description | Default |
|---|---|---|
| `--dir <path>` | Directory containing prompt files (required) | — |
| `--work-dir <path>` | Git repo used as worktree base | — |
| `--impl-prompt <file>` | File prepended to every prompt | — |
| `--bin <path>` | Binary to run | auto-detect `claude` |
| `--bin-args <args>` | Extra arguments for the binary | — |
| `--bin-env <KEY=VAL>` | Extra env var (repeatable) | — |
| `--config <file>` | Config file path | `runner.conf` |
| `--session <name>` | tmux session name | `pr-run` |
| `--marker-dir <path>` | Directory for status markers | `/tmp/pr-status` |
| `--print` | Non-interactive mode (`-p`) | `false` |
| `--verbose` | Pass `--verbose` to the binary | `false` |
| `--worktree` | Create an isolated git worktree per task | `false` |
| `--overview` | Tiled pane grid instead of separate windows | `false` |
| `--dry-run` | Build runners without launching | `false` |
| `--status` | Print status dashboard and exit | `false` |
| `--watch[=N]` | Live dashboard, refresh every N seconds | 5s |
| `--clean-markers` | Remove existing status markers before start | `false` |
| `--clean-worktrees` | Remove residual worktrees before start | `false` |
| `--kill` | Kill active tmux session and processes | `false` |

Already-completed tasks are skipped by default. Use `--clean-markers` to re-run them.

## tmux navigation

| Key | Action |
|---|---|
| `Ctrl+B W` | list windows |
| `Ctrl+B N / P` | next / previous window |
| `Ctrl+B Z` | zoom a pane (toggle, `--overview` mode) |
| `Ctrl+B Q` | show pane numbers (`--overview` mode) |
| `Ctrl+B D` | detach (tasks keep running in background) |

## Prompt structure

Every `.md` or `.txt` file in `--dir` (including subdirectories) becomes a task. The relative path is used as the task name: `platform/bookings.md` → task `platform/bookings`.

Use `--impl-prompt` to prepend a shared system file to every prompt, keeping individual task files lean.

## prompt-master.md

`prompt-master.md` is a reusable template for site-page generation prompts. It contains the full methodology with `{{placeholders}}` for project-specific values.

Use it with `--impl-prompt ./prompt-master.md`, or copy and fill all placeholders to generate self-contained per-page prompts. See the comment block at the top of the file for the full placeholder list.
