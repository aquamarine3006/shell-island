#!/usr/bin/env bash
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/state/nix-profiles/profile/bin:$HOME/.nix-profile/bin:$PATH"
WALL="${1:?Usage: wallpaper.sh <path> [light|dark]}"
sock_dir="/tmp/nvim-sockets"
LOGFILE="/tmp/wallpaper-sh.log"
: > "$LOGFILE"
exec >> "$LOGFILE" 2>&1
t() { echo "[$(date +%s.%N)] $*"; }

MODES_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/wallpaper-modes"
mkdir -p "$(dirname "$MODES_FILE")"
touch "$MODES_FILE"
if [ -n "${2:-}" ]; then
  MODE="$2"
else
  MODE=$(awk -F$'\t' -v p="$WALL" '$1==p {print $2}' "$MODES_FILE" | tail -1)
  MODE="${MODE:-dark}"
fi
awk -F$'\t' -v p="$WALL" '$1!=p' "$MODES_FILE" > "${MODES_FILE}.new" || true
printf '%s\t%s\n' "$WALL" "$MODE" >> "${MODES_FILE}.new"
mv "${MODES_FILE}.new" "$MODES_FILE"
t "start: $WALL mode=$MODE"

SAT_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/saturation"
SAT=$(cat "$SAT_FILE" 2>/dev/null || echo 70)
wallust run -s -p "${MODE}16" --saturation "$SAT" "$WALL"
pkill -SIGUSR1 kitty 2>/dev/null || true
pkill -SIGUSR2 btop 2>/dev/null || true
t "wallust done"

for sock in "$sock_dir"/*.sock; do
  [ -e "$sock" ] || continue
  nvim --server "$sock" --remote-send "<Cmd>lua require('theme').apply()<CR>" 2>/dev/null || true
done
t "nvim reload pushed"

REPO_COLORS="${NIXOS_DOTS_REPO:-$HOME/nixos-dots}/home/dotfiles/hyprland/colors.lua"
sed 's/#//g' /tmp/wallust-hyprland-colors.lua > "${REPO_COLORS}.new"
mv "${REPO_COLORS}.new" "$REPO_COLORS"
t "atomically replaced colors.lua"

# =============================================================================
# NEMO: write CSS only — no kill/relaunch
# =============================================================================
# GTK3 apps read ~/.config/gtk-3.0/gtk.css fresh on every launch. Writing the
# new CSS here is enough: whenever Nemo is next closed and reopened (by the
# user, naturally), it'll pick up the new theme on its own. No need to force
# a reload by killing running windows.

WALLUST_CSS="${XDG_CACHE_HOME:-$HOME/.cache}/wallust/gtk.css"
USER_CSS_DIR="$HOME/.config/gtk-3.0"
USER_CSS="$USER_CSS_DIR/gtk.css"
mkdir -p "$USER_CSS_DIR"
cp "$WALLUST_CSS" "$USER_CSS"
t "user CSS written ($(wc -c < "$USER_CSS" 2>/dev/null || echo '?') bytes)"

# =============================================================================
# Wallpaper record + awww
# =============================================================================
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE"
echo "$WALL" > "$CACHE/current-wallpaper"
t "current-wallpaper recorded"

awww img "$WALL" \
  --transition-type grow \
  --transition-pos 0.5,0.5 \
  --transition-duration 1.5 \
  --transition-fps 60
t "awww done"
t "done"
