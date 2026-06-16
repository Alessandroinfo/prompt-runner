# claude-parallel-runner

Runs N Claude instances in parallel via tmux. Every `.md` or `.txt` file found recursively in the given directory becomes an independent tmux window inside a single session.

## Requirements

- [tmux](https://github.com/tmux/tmux)
- [Claude Code CLI](https://claude.ai/code)

## Usage

```bash
bash run.sh --dir <prompts-dir> [options]
```

### Options

```bash
bash run.sh --dir /path/to/prompts                        # one tmux window per prompt file
bash run.sh --dir /path/to/prompts --print                # non-interactive mode (claude -p) — required for parallel runs
bash run.sh --dir /path/to/prompts --worktree             # isolated git worktree per runner (requires --work-dir)
bash run.sh --dir /path/to/prompts --work-dir /repo       # git repo to use as base for worktrees
bash run.sh --dir /path/to/prompts --impl-prompt file.md  # prepend a shared system prompt to every task
bash run.sh --dir /path/to/prompts --verbose              # pass --verbose to Claude (tool calls + trace on stderr)
bash run.sh --dir /path/to/prompts --status               # show task status dashboard and exit
bash run.sh --dir /path/to/prompts --watch                # live dashboard, refresh every 5s (macOS notification on completion)
bash run.sh --dir /path/to/prompts --watch=10             # live dashboard, custom refresh interval
bash run.sh --dir /path/to/prompts --dry-run              # build runners without launching Claude
bash run.sh --dir /path/to/prompts --overview             # show all tasks in a tiled pane grid instead of separate windows
bash run.sh --dir /path/to/prompts --clean-markers        # clear previous status markers before starting
bash run.sh --dir /path/to/prompts --clean-worktrees      # remove residual worktrees from /tmp/cpr-wt/ before starting
bash run.sh --dir /path/to/prompts --kill                 # kill active tmux session and Claude processes before starting
bash run.sh --dir /path/to/prompts --session myproject    # custom tmux session name
bash run.sh --dir /path/to/prompts --marker-dir /tmp/foo  # custom directory for status markers
```

Already-completed tasks are skipped by default.

## Prompt structure

Every `.md` or `.txt` file in the directory (including subdirectories) becomes a task. The relative path is used as the task identifier: `platform/bookings.md` → task `platform/bookings`.

A shared file can be prepended to every prompt via `--impl-prompt`. Use this for global system instructions that apply to all tasks, keeping individual prompt files lean.

## Examples

```bash
# Basic parallel run
bash run.sh --dir ./prompts --print

# Isolated worktree per task on a git repo
bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo

# Prepend shared system instructions to every prompt
bash run.sh --dir ./prompts --print --impl-prompt ./prompt-master.md

# Watch dashboard with macOS notification on completion
bash run.sh --dir ./prompts --watch=10

# Start fresh: kill active session, clear markers and worktrees
bash run.sh --dir ./prompts --print --worktree --work-dir /path/to/repo \
  --kill --clean-markers --clean-worktrees
```

## tmux navigation

| Key | Action |
|---|---|
| `Ctrl+B W` | list windows |
| `Ctrl+B N / P` | next / previous window |
| `Ctrl+B Z` | zoom a pane (toggle, `--overview` mode) |
| `Ctrl+B Q` | show pane numbers (`--overview` mode) |
| `Ctrl+B D` | detach (tasks keep running in background) |

## CLI flags reference

| Flag | Description | Default |
|---|---|---|
| `--dir <path>` | Directory containing prompt files (required) | — |
| `--work-dir <path>` | Git repo used as worktree base | — |
| `--impl-prompt <file>` | File prepended to every prompt | — |
| `--session <name>` | tmux session name | `cpr-impl` |
| `--marker-dir <path>` | Directory for status markers | `/tmp/cpr-status` |
| `--claude-bin <path>` | Path to the Claude binary | auto-detected |
| `--print` | Non-interactive mode (`claude -p`) | `false` |
| `--verbose` | Pass `--verbose` to Claude | `false` |
| `--worktree` | Create an isolated git worktree per task | `false` |
| `--overview` | Tiled pane grid instead of separate windows | `false` |
| `--dry-run` | Build runners without launching Claude | `false` |
| `--status` | Print status dashboard and exit | `false` |
| `--watch[=N]` | Live dashboard, refresh every N seconds | 5s |
| `--clean-markers` | Remove existing status markers before start | `false` |
| `--clean-worktrees` | Remove residual worktrees before start | `false` |
| `--kill` | Kill active tmux session and Claude processes | `false` |

## prompt-master.md

`prompt-master.md` is a reusable template for site page generation prompts. It contains the full methodology (analysis phases, CMS assessment, output format, git rules, seed script instructions) with `{{placeholders}}` for project-specific values.

Use it as `--impl-prompt` to keep individual page prompt files minimal, or copy and fill in all placeholders to generate self-contained per-page prompts.

See the comment block at the top of `prompt-master.md` for the full list of placeholders and both usage modes.
