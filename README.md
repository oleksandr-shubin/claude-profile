# claude-profile

Switch between multiple Claude Code accounts from the terminal.

## Install

Source the script in your shell config (`~/.bashrc` or `~/.zshrc`):

```bash
cp claude-profile.sh ~/.claude-profile.sh
echo 'source ~/.claude-profile.sh' >> ~/.bashrc
source ~/.claude-profile.sh
```

Profiles are stored in `~/.claude-profiles/`.

## Usage

### Add a new profile

```bash
claude-profile add work
```

This creates the profile directory. Then log in with that profile:

```bash
CLAUDE_CONFIG_DIR=~/.claude-profiles/work claude
```

After logging in, save the credentials:

```bash
claude-profile save work
```

### Switch profiles

```bash
claude-profile use work
```

The active profile persists across terminal sessions and is auto-restored on shell start.

### Other commands

```
claude-profile list        # List all profiles
claude-profile current     # Show active profile
claude-profile remove <n>  # Delete a profile
claude-profile unset       # Revert to default ~/.claude
```

## How it works

- The script wraps the `claude` command with a shell function that:
  1. **Before launch** — re-reads `~/.claude-profiles/.active` and sets `CLAUDE_CONFIG_DIR`, so profile switches in other terminals take effect immediately.
  2. **After exit** — auto-saves the active profile's credentials and settings, capturing any changes made during the session.
- The active profile name is stored in `~/.claude-profiles/.active` and auto-restored on every new shell.
- Each profile keeps its own copy of `.credentials.json`, `settings.json`, and `claude.json`.
