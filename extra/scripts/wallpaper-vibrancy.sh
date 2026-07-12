#!/usr/bin/env bash
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/state/nix-profiles/profile/bin:$HOME/.nix-profile/bin:$PATH"

# Called by the wallpaper panel's vibrancy slider (WallpaperContent.qml),
# debounced client-side so this only actually runs ~every 120ms while
# dragging, not on every pixel of mouse movement.
SAT="${1:?Usage: wallpaper-vibrancy.sh <0-100>}"
LOGFILE="/tmp/wallpaper-vibrancy-sh.log"
exec > "$LOGFILE" 2>&1

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
WALL_FILE="$CACHE/current-wallpaper"
[ -f "$WALL_FILE" ] || { echo "no current wallpaper recorded yet"; exit 0; }
WALL="$(cat "$WALL_FILE")"

# Reuse wallpaper.sh's own per-wallpaper mode memory rather than
# duplicating/forking it -- same MODES_FILE, read-only here.
#
# Use awk with EXACT first-field match instead of `grep -F "$WALL"$'\t'`.
# grep -F is substring match, so /foo/bar.jpg would also match a stored
# line for /some/prefix/foo/bar.jpg and return the wrong mode. See
# wallpaper.sh for the same fix on the write path.
MODES_FILE="$CACHE/wallust/wallpaper-modes"
MODE="dark"
if [ -f "$MODES_FILE" ]; then
  M="$(awk -F$'\t' -v p="$WALL" '$1==p {print $2}' "$MODES_FILE" | tail -1)"
  [ -n "$M" ] && MODE="$M"
fi

# Persisted independently of wallust.toml's own static default (70) so
# the slider's chosen value survives across wallpaper switches until the
# user drags it again -- wallpaper.sh's own `wallust run` calls don't
# pass --saturation, so without this the next plain wallpaper switch
# would silently revert to the config-file default.
SAT_FILE="$CACHE/wallust/saturation"
mkdir -p "$(dirname "$SAT_FILE")"
echo "$SAT" > "$SAT_FILE"

# --saturation is a real wallust CLI flag (wallust >=2.8.0) that overrides
# wallust.toml's `saturation = 70` for just this run, same override
# relationship wallpaper.sh already relies on for -p/palette. Re-running
# wallust rewrites every configured template target (quickshell.json,
# hyprland colors.lua, gtk.css, kitty, nvim, btop) in one shot.
# NOTE: zellij config.kdl is NOT wallust-templated (see wallpaper.sh:89-94)
# -- the previous comment here claiming otherwise was wrong.
wallust run -s -p "${MODE}16" --saturation "$SAT" "$WALL"

# Hyprland's colors.lua needs the same hash-stripping atomic swap
# wallpaper.sh does -- wallust writes hex WITH a leading '#', which isn't
# valid inside hyprland.lua's "rgb(" .. colors.x .. ")" concatenation.
REPO_COLORS="${NIXOS_DOTS_REPO:-$HOME/nixos-dots}/home/dotfiles/hyprland/colors.lua"
if [ -f /tmp/wallust-hyprland-colors.lua ]; then
  sed 's/#//g' /tmp/wallust-hyprland-colors.lua > "${REPO_COLORS}.new"
  mv "${REPO_COLORS}.new" "$REPO_COLORS"
fi

# Push the new palette to every live consumer. wallpaper.sh does this same
# set of pushes; the previous version of this file only pushed kitty's
# SIGUSR1 and silently left btop and every running nvim instance showing
# the OLD saturation (until manually restarted), even though wallust had
# already rewritten their theme files on disk.
pkill -SIGUSR1 kitty 2>/dev/null || true
pkill -SIGUSR2 btop 2>/dev/null || true

# nvim: push directly over each instance's RPC socket (see nvim/init.lua).
sock_dir="/tmp/nvim-sockets"
for sock in "$sock_dir"/*.sock; do
  [ -e "$sock" ] || continue
  nvim --server "$sock" --remote-send "<Cmd>lua require('theme').apply()<CR>" 2>/dev/null || true
done

echo "done: sat=$SAT mode=$MODE wall=$WALL"
