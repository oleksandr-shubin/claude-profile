#!/usr/bin/env bash
# claude-profile — switch between Claude Code accounts
# Usage: source this file in ~/.bashrc or ~/.zshrc

CLAUDE_PROFILES_DIR="$HOME/.claude-profiles"
CLAUDE_PROFILE_STATE="$CLAUDE_PROFILES_DIR/.active"

# Auto-restore last active profile on shell start
if [[ -f "$CLAUDE_PROFILE_STATE" ]]; then
  _last=$(cat "$CLAUDE_PROFILE_STATE")
  if [[ -d "$CLAUDE_PROFILES_DIR/$_last" ]]; then
    export CLAUDE_CONFIG_DIR="$CLAUDE_PROFILES_DIR/$_last"
  fi
  unset _last
fi

# Override claude command to always sync profile before launching
claude() {
  if [[ -f "$CLAUDE_PROFILE_STATE" ]]; then
    _last=$(cat "$CLAUDE_PROFILE_STATE")
    if [[ -d "$CLAUDE_PROFILES_DIR/$_last" ]]; then
      export CLAUDE_CONFIG_DIR="$CLAUDE_PROFILES_DIR/$_last"
    fi
    unset _last
  fi
  command claude "$@"
  # auto-save profile after claude exits
  if [[ -f "$CLAUDE_PROFILE_STATE" ]]; then
    _last=$(cat "$CLAUDE_PROFILE_STATE")
    [[ -n "$_last" ]] && claude-profile save "$_last" > /dev/null 2>&1
    unset _last
  fi
}

claude-profile() {
  local cmd="${1:-help}"
  case "$cmd" in
    add)
      local name="$2"
      if [[ -z "$name" ]]; then echo "Usage: claude-profile add <n>"; return 1; fi
      if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then echo "Invalid name."; return 1; fi
      local dir="$CLAUDE_PROFILES_DIR/$name"
      if [[ -d "$dir" ]]; then echo "Profile '$name' already exists."; return 1; fi
      mkdir -p "$dir"
      echo "Profile '$name' created."
      echo "Run:  CLAUDE_CONFIG_DIR=$dir claude"
      echo "Log in, then:  claude-profile save $name"
      ;;
    save)
      local name="$2"
      if [[ -z "$name" ]]; then echo "Usage: claude-profile save <n>"; return 1; fi
      local dir="$CLAUDE_PROFILES_DIR/$name"
      mkdir -p "$dir"
      local src="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
      [[ -f "$src/.credentials.json" ]] && cp "$src/.credentials.json" "$dir/.credentials.json"
      [[ -f "$src/settings.json" ]]     && cp "$src/settings.json"     "$dir/settings.json"
      [[ -f "$HOME/.claude.json" ]]     && cp "$HOME/.claude.json"     "$dir/claude.json"
      echo "✓ Saved current session as '$name'"
      ;;
    use)
      local name="$2"
      if [[ -z "$name" ]]; then echo "Usage: claude-profile use <n>"; return 1; fi
      local dir="$CLAUDE_PROFILES_DIR/$name"
      if [[ ! -d "$dir" ]]; then echo "Profile '$name' not found."; return 1; fi
      export CLAUDE_CONFIG_DIR="$dir"
      echo "$name" > "$CLAUDE_PROFILE_STATE"
      echo "✓ Switched to '$name'"
      ;;
    unset|default)
      unset CLAUDE_CONFIG_DIR
      rm -f "$CLAUDE_PROFILE_STATE"
      echo "✓ Cleared — using default ~/.claude"
      ;;
    current)
      if [[ -f "$CLAUDE_PROFILE_STATE" ]]; then
        echo "Active profile: $(cat "$CLAUDE_PROFILE_STATE")"
      else
        echo "No profile active — using default ~/.claude"
      fi
      ;;
    list|ls)
      if [[ ! -d "$CLAUDE_PROFILES_DIR" ]]; then echo "No profiles yet."; return 0; fi
      local active_name=""
      [[ -f "$CLAUDE_PROFILE_STATE" ]] && active_name=$(cat "$CLAUDE_PROFILE_STATE")
      echo "Profiles:"
      for dir in "$CLAUDE_PROFILES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        local name; name=$(basename "$dir")
        local active=""
        [[ "$name" == "$active_name" ]] && active=" ◀ active"
        echo "  $name$active"
      done
      ;;
    remove|rm)
      local name="$2"
      if [[ -z "$name" ]]; then echo "Usage: claude-profile remove <n>"; return 1; fi
      local dir="$CLAUDE_PROFILES_DIR/$name"
      if [[ ! -d "$dir" ]]; then echo "Profile '$name' not found."; return 1; fi
      read -r -p "Delete profile '$name'? [y/N] " confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        rm -rf "$dir"
        if [[ "$(cat "$CLAUDE_PROFILE_STATE" 2>/dev/null)" == "$name" ]]; then
          unset CLAUDE_CONFIG_DIR
          rm -f "$CLAUDE_PROFILE_STATE"
        fi
        echo "✓ Removed '$name'"
      else
        echo "Cancelled."
      fi
      ;;
    help|*)
      cat <<'EOF'
claude-profile — manage Claude Code account profiles

  claude-profile add <n>     Create a new profile slot
  claude-profile save <n>    Snapshot current session into profile
  claude-profile use <n>     Switch to a profile
  claude-profile list           List all profiles
  claude-profile current        Show active profile
  claude-profile remove <n>  Delete a profile
  claude-profile unset          Go back to default ~/.claude

Last active profile is automatically restored in every new terminal.
Switching profiles syncs across all terminals on next 'claude' run.
EOF
      ;;
  esac
}