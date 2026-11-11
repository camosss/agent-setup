# agent-setup

A one-command setup for working with multiple Claude Code agents: launching them, coordinating them, and getting notified when they need you.

<br>

## Purpose

- Install the whole agent workspace on a new Mac with a single command
- Keep this repo in sync automatically whenever the local settings change
- Tuned to keep token usage low: earlier compaction, one session per task, unused connectors blocked

<br>

---

<br>

## Contents

| Looking for | Section |
|-------------|---------|
| Set up a new Mac | [Install](#install) |
| What is included | [Layout](#layout) |
| Token-saving settings | [Token savings](#token-savings) |
| How it behaves day to day | [Behavior](#behavior) |
| Push changes after editing settings | [Sync](#sync) |
| Keeping private info out of a public repo | [Public repo safeguards](#public-repo-safeguards) |

<br>

---

<br>

## Install

Requirements: macOS, [Homebrew](https://brew.sh), and a logged-in GitHub CLI.

```bash
gh auth login
gh repo clone camosss/agent-setup ~/agent-setup
~/agent-setup/install.sh
```

What `install.sh` does:

1. Installs everything in the `Brewfile`
2. Backs up existing settings as `<file>.bak.<timestamp>`
3. Copies the settings into place
4. Downloads the Herdr guides
5. Registers the daily sync job
6. Reloads Hammerspoon

When it finishes, it prints the remaining manual steps:

| Manual step | Why |
|-------------|-----|
| Run `claude` and log in | Accounts are not stored in the repo |
| Install work-specific plugins, skills, and the auto mode environment description | Left out because this repo is public |
| Create `~/.config/agent-setup/private.json` | `sync.sh` refuses to run without it ([format](./private.example.json)) |
| Allow Hammerspoon in Accessibility settings | Needed for the image paste shortcut in Ghostty |

<br>

---

<br>

## Layout

| Path | Installed to | What it holds |
|------|--------------|---------------|
| [`claude/settings.json`](./claude/settings.json) | `~/.claude/settings.json` | Model, auto-compact window, transcript retention, blocked connectors, hooks, auto mode rules |
| [`claude/CLAUDE.md`](./claude/CLAUDE.md) | `~/.claude/CLAUDE.md` | Instructions for every session: reply language, what to keep when compacting, subagent use, work session lifecycle |
| [`claude/hooks/`](./claude/hooks) | `~/.claude/hooks/` | Context cleanup reminders, completion notifications, Herdr tab markers |
| [`claude/skills/dispatch-work-sessions/`](./claude/skills/dispatch-work-sessions) | `~/.claude/skills/` | Skill that lets a coordinator session open work sessions, send them instructions, and close them when the task is done |
| [`hammerspoon/`](./hammerspoon) | `~/.hammerspoon/` | Silent notification banners that jump to the agent's pane on click, image paste shortcut |
| [`herdr/`](./herdr) | `~/.config/herdr/` | Agent pane sorting, labels, session restore, jump to the last notified pane (`prefix+j`) |
| [`ghostty/`](./ghostty) | `~/.config/ghostty/` | Terminal settings |
| [`Brewfile`](./Brewfile) | - | `claude-code@latest`, hammerspoon, herdr, gh, node |
| [`launchd/`](./launchd) | `~/Library/LaunchAgents/` | Daily sync at 21:00 |

<br>

---

<br>

## Token savings

Most usage comes from long-running sessions that re-read a large context on every turn. These settings keep the context small.

| Setting | Value | Effect |
|---------|-------|--------|
| `autoCompactWindow` | 400K | Compacts well before the 1M default (about 967K), so each turn reads less than half as much |
| `cleanupPeriodDays` | 14 | Deletes old session transcripts automatically |
| `deniedMcpServers` | Unused connectors | Keeps their tool definitions out of every session's context |
| [`context-hygiene.py`](./claude/hooks/context-hygiene.py) | 200K, 300K | Above 200K, suggests `/clear` when the topic changes. Above 300K, writes a handoff note right away and suggests a fresh session |
| Compaction rules in `CLAUDE.md` | - | Summaries always keep the goal, task card number, branch, PR, remaining work, and decisions |
| One session per task | - | Work sessions close once the PR and review fixes are done, and reopen for the next task |

<br>

---

<br>

## Behavior

**When you send a message**
The `context-hygiene` hook reads the context size of the last reply. Past a threshold, it tells Claude to suggest cleanup. The same suggestion is not repeated until the context grows another 100K.

**When an agent finishes or waits for input**
If you are not looking at that pane, Hammerspoon shows a banner and Herdr marks the tab.

**Coordinator sessions**
They open work sessions and send instructions. After verifying a completion report (PR link, remaining work), they close the session. Sessions with uncommitted or unpushed changes are never closed.

**Once a day**
The current local settings are synced to this repo.

<br>

---

<br>

## Sync

Settings are copied, not symlinked. Claude Code rewrites its settings file, which would break a symlink.

| Command | Purpose |
|---------|---------|
| `./sync.sh` | Copy local settings into the repo, then commit and push if anything changed |
| `./sync.sh --dry-run` | Show what changed without committing |
| `./install.sh` | Install the repo's settings on this Mac |

- The list of managed files lives in one place: [`paths.txt`](./paths.txt). Add a line there to track a new file.
- The home directory is stored as `__HOME__` and restored on install.
- Daily sync log: `/tmp/agent-setup-sync.log`

<br>

---

<br>

## Public repo safeguards

`sync.sh` reads `~/.config/agent-setup/private.json`, which lives outside the repo. Before committing, it:

1. Removes auto mode rules and plugin marketplaces that contain private words, telemetry values, and the listed `CLAUDE.md` blocks
2. Replaces the listed names with generic ones
3. Stops without committing if any private word or token-like string is still left

`install.sh` reverses the name replacements when `private.json` is present, and keeps the private values already in your local settings.

<br>

---

<br>

## Not included

- Memory (`~/.claude/projects/*/memory`) and session transcripts
- Work-specific skills and plugins, tokens, and credential files
- Herdr guides (`~/.claude/agent-guides`): the source, [2ykwang/dotfiles](https://github.com/2ykwang/dotfiles/tree/main/agent-guides), has no license, so they are not redistributed here. `install.sh` downloads them from a pinned commit instead.
