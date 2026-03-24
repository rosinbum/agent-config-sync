# agent-config-sync

Sync your Claude Code configuration across multiple machines and accounts — without sharing secrets.

Built for developers who maintain separate Claude Code environments (e.g., personal laptop + work laptop) and want to keep skills, commands, settings, and workflows in sync while keeping proprietary information where it belongs.

## The Problem

Claude Code stores configuration in `~/.claude/` — settings, commands, skills, agents, rules, and more. When you work across multiple machines or accounts, these configurations diverge. Existing sync tools assume one identity and one account. None handle:

- **Multi-profile overlays**: a shared base config with per-environment overrides
- **Content isolation**: work-only vs personal-only vs shared artifacts
- **Path normalization**: different usernames and home directories across machines

agent-config-sync fills that gap.

## Architecture

This repo is the **tool**. Your configuration data lives in a separate **private repo** that you create.

```
agent-config-sync/        ← this repo (public, the tool)
  acs                     ← single CLI script, install to PATH

your-claude-config/       ← your private repo (created by `acs init`)
  .acs                    ← marker file
  base/                   ← shared across all profiles
    settings.json           ({{ HOME }} placeholders)
    commands/*.md
    skills/*/SKILL.md
    agents/*.md
    rules/*.md
    statusline-command.sh
  profiles/
    personal/             ← personal-only overrides
      settings.json
      commands/
    work/                 ← work-only overrides
      settings.json
      commands/
```

Portable artifacts (commands, skills, etc.) are **symlinked** into `~/.claude/`, so edits in either location are the same file. Non-portable artifacts (settings with absolute paths) are **copied** with automatic path scrubbing (`/Users/you` ↔ `{{ HOME }}`).

Claude Code natively deep-merges `settings.json` on top of `settings.json`, so profile-specific settings just work.

## Install

```bash
# Clone the tool
git clone https://github.com/rosinbum/agent-config-sync.git

# Add to PATH (pick one)
ln -s "$PWD/agent-config-sync/acs" ~/.local/bin/acs
# or
cp agent-config-sync/acs /usr/local/bin/acs
```

## Quick Start

### First machine (e.g., personal laptop)

```bash
# Create your config repo
acs init ~/src/my-claude-config personal
cd ~/src/my-claude-config

# Import your existing ~/.claude/ config
acs bootstrap personal

# Review: settings.json should have {{ HOME }}, not /Users/you
cat base/settings.json

# Install (replaces files with symlinks, expands paths)
acs install personal

# Verify
acs status

# Push to a private repo
git add -A && git commit -m "initial config"
git remote add origin git@github.com:YOU/my-claude-config.git
git push -u origin main
```

### Second machine (e.g., work laptop)

```bash
# Install the tool (same as above)

# Clone your private config repo
git clone git@github.com:YOU/my-claude-config.git
cd my-claude-config

# Interactive merge: compare this machine's config against the repo,
# sort each difference into base (shared) or profile (work-only)
acs merge work

# Install with the work profile
acs install work

# Verify
acs status

# Commit the new profile
git add -A && git commit -m "add work profile"
git push
```

`acs merge` walks through each difference interactively:
- **Settings**: shows key-level diff, saves differences to profile
- **Commands/skills**: for each new artifact, asks base (shared) or profile (work-only)
- **Existing artifacts that differ**: asks whether to save this machine's version to profile

## Commands

### `acs init <directory> [profile]`

Create a new config repo with the directory structure.

```bash
acs init ~/src/my-claude-config personal
```

### `acs bootstrap [profile]`

One-time import of your existing `~/.claude/` config. Scrubs all absolute paths. Run from inside the config repo. Use this on your **first** machine.

```bash
cd ~/src/my-claude-config
acs bootstrap personal
```

### `acs merge <profile>`

Interactive merge for your **second** machine. Compares this machine's `~/.claude/` against the repo and helps sort differences into base (shared) or profile (machine-specific).

```bash
cd ~/src/my-claude-config
acs merge work
```

For each difference it finds:
- **Settings**: shows a key-level diff, offers to save differences as the profile's `settings.json`
- **New commands/skills/agents/rules**: asks whether each belongs in base or this profile
- **Files that differ from base**: asks whether to save this machine's version to the profile

### `acs install [OPTIONS] [profile]`

Install configuration from the repo into `~/.claude/`.

```bash
acs install personal         # install base + personal profile
acs install work             # install base + work profile
acs install --dry-run work   # preview without changes
acs install --force work     # overwrite local modifications
acs install --list           # list available profiles
```

What it does:
1. Symlinks `commands/`, `skills/`, `agents/`, `rules/` from base → `~/.claude/`
2. Symlinks `statusline-command.sh`, `keybindings.json`
3. Copies `settings.json` with path expansion (`{{ HOME }}` → `$HOME`)
4. Concatenates `base/CLAUDE.md` + `profiles/<name>/CLAUDE.md`
5. Overlays profile-specific artifacts (profile wins on conflicts)
6. Copies profile `settings.json`

### `acs capture [OPTIONS]`

Reverse sync: detects changes made in `~/.claude/` and captures them back.

```bash
acs capture                # capture to base/
acs capture --to-profile   # capture new artifacts to active profile
acs capture --dry-run      # preview
```

Detects:
- Modified `settings.json` via checksum, scrubs paths on capture
- New files in `~/.claude/commands/`, `skills/`, etc. (regular files, not symlinks)
- Modified `CLAUDE.md` — decomposes at `<!-- profile: NAME -->` marker

### `acs status`

Show sync status with colors.

```
=== Claude Config Sync ===
Config:  /Users/you/src/my-claude-config
Target:  /Users/you/.claude
Profile: personal

  synced    [base]     commands/address-pr-comments.md
  synced    [profile]  commands/personal-deploy.md
  new       [local]    commands/untitled.md
  modified             settings.json  (run acs capture)

  synced    [base]     statusline-command.sh
  synced    [base]     settings.json

  git: main [ahead 1]
```

### `acs push`

Capture + git commit + push (all-in-one).

### `acs pull`

Git pull + re-install.

### `acs diff`

Preview what capture would find (runs `capture --dry-run`).

## Daily Workflow

```bash
# After tweaking Claude Code config:
cd ~/src/my-claude-config
acs diff                     # see what changed
acs capture                  # capture to base/ (or --to-profile)
acs push                     # commit and push

# On another machine:
cd ~/src/my-claude-config
acs pull                     # git pull + re-install
```

## What Syncs (and What Doesn't)

### Synced

| Artifact | Method |
|---|---|
| `commands/*.md` | Symlink |
| `skills/*/SKILL.md` | Symlink |
| `agents/*.md` | Symlink |
| `rules/*.md` | Symlink |
| `statusline-command.sh` | Symlink |
| `keybindings.json` | Symlink |
| `settings.json` | Copy (base + profile deep-merged, path-scrubbed) |
| `CLAUDE.md` | Copy (base + profile concatenated) |

### Never Synced

Sessions, history, telemetry, debug logs, project memory, tasks, todos, plans, security warnings, caches, credentials, OAuth tokens, plugin caches.

## Profile Precedence

- **Commands, skills, agents, rules**: profile wins when same filename exists in base and profile
- **Settings**: `base/settings.json` + `profiles/<name>/settings.json` are deep-merged at install time (arrays concatenate + dedup, overlay scalars win)
- **CLAUDE.md**: both included (concatenated with `<!-- profile: NAME -->` marker)

## Requirements

- macOS or Linux
- bash, git
- `/usr/bin/python3` (standard on macOS — used only for JSON, no pip needed)

## Acknowledgments

Inspired by [Brian Lovin's agent-config](https://github.com/brianlovin/agent-config) — the pioneering approach of using a git repo with symlinks and sync scripts for Claude Code configuration management. agent-config-sync extends that pattern with multi-profile overlays, path normalization, and reverse sync for developers who work across multiple machines and accounts.

## License

MIT
