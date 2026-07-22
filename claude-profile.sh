#!/usr/bin/env bash
# claude-profile — switch between Claude Code accounts
# Usage: source this file in ~/.bashrc or ~/.zshrc

CLAUDE_PROFILES_DIR="$HOME/.claude-profiles"
CLAUDE_PROFILE_STATE="$CLAUDE_PROFILES_DIR/.active"

# Symlink shared resources from ~/.claude into a profile dir, unless already present.
# A real file/dir at the destination overrides the shared default.
_claude_profile_link_shared() {
  local dir="$1"
  local item
  for item in agents skills statusline.sh; do
    local src="$HOME/.claude/$item"
    local dst="$dir/$item"
    if [[ -e "$src" && ! -e "$dst" ]]; then
      ln -s "$src" "$dst"
    fi
  done
}

# Auto-restore last active profile on shell start
if [[ -f "$CLAUDE_PROFILE_STATE" ]]; then
  _last=$(cat "$CLAUDE_PROFILE_STATE")
  if [[ -d "$CLAUDE_PROFILES_DIR/$_last" ]]; then
    export CLAUDE_CONFIG_DIR="$CLAUDE_PROFILES_DIR/$_last"
  fi
  unset _last
fi

# Override claude command to always sync profile before launching.
# Profile is pinned at entry so post-save can't cross-contaminate if .active
# changes mid-session.
#
# A per-shell $CLAUDE_PROFILE (e.g. injected by a terminal that pins a profile to
# a workspace) wins over the global .active, so a profiled workspace launches its
# own account without disturbing the default other terminals use.
claude() {
  local _profile="${CLAUDE_PROFILE:-}"
  if [[ -z "$_profile" && -f "$CLAUDE_PROFILE_STATE" ]]; then
    _profile=$(cat "$CLAUDE_PROFILE_STATE")
  fi
  if [[ -n "$_profile" && -d "$CLAUDE_PROFILES_DIR/$_profile" ]]; then
    export CLAUDE_CONFIG_DIR="$CLAUDE_PROFILES_DIR/$_profile"
  else
    _profile=""
  fi
  (
    [[ -f "$CLAUDE_CONFIG_DIR/profile.env" ]] && . "$CLAUDE_CONFIG_DIR/profile.env"
    command claude "$@"
  )
  [[ -n "$_profile" ]] && claude-profile save "$_profile" > /dev/null 2>&1
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
      # Refuse cross-profile save: src must be the target dir or default ~/.claude.
      # Prevents copying credentials between profiles when CLAUDE_CONFIG_DIR is stale.
      if [[ "$src" != "$dir" && "$src" != "$HOME/.claude" ]]; then
        echo "✗ Refusing to save: CLAUDE_CONFIG_DIR ($src) is not the '$name' profile dir."
        echo "  Run 'claude-profile use $name' first."
        return 1
      fi
      [[ -f "$src/.credentials.json" && "$src" != "$dir" ]] && cp "$src/.credentials.json" "$dir/.credentials.json"
      [[ -f "$src/settings.json"     && "$src" != "$dir" ]] && cp "$src/settings.json"     "$dir/settings.json"
      echo "✓ Saved current session as '$name'"
      ;;
    use)
      local name="$2"
      if [[ -z "$name" ]]; then echo "Usage: claude-profile use <n>"; return 1; fi
      local dir="$CLAUDE_PROFILES_DIR/$name"
      if [[ ! -d "$dir" ]]; then echo "Profile '$name' not found."; return 1; fi
      _claude_profile_link_shared "$dir"
      export CLAUDE_CONFIG_DIR="$dir"
      echo "$name" > "$CLAUDE_PROFILE_STATE"
      echo "✓ Switched to '$name'"
      ;;
    run)
      local name="$2"
      if [[ -z "$name" ]]; then echo "Usage: claude-profile run <n> [claude args...]"; return 1; fi
      local dir="$CLAUDE_PROFILES_DIR/$name"
      if [[ ! -d "$dir" ]]; then echo "Profile '$name' not found."; return 1; fi
      shift 2
      _claude_profile_link_shared "$dir"
      (
        export CLAUDE_CONFIG_DIR="$dir"
        [[ -f "$dir/profile.env" ]] && . "$dir/profile.env"
        command claude "$@"
      )
      CLAUDE_CONFIG_DIR="$dir" claude-profile save "$name" > /dev/null 2>&1
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

  claude-profile add <n>            Create a new profile slot
  claude-profile save <n>           Snapshot current session into profile
  claude-profile use <n>            Switch to a profile (persists across terminals)
  claude-profile run <n> [args]     Launch claude with a profile for one session
                                    without changing the default
  claude-profile list               List all profiles
  claude-profile current            Show active profile
  claude-profile remove <n>         Delete a profile
  claude-profile unset              Go back to default ~/.claude

Last active profile is automatically restored in every new terminal.
Switching profiles syncs across all terminals on next 'claude' run.
EOF
      ;;
  esac
}