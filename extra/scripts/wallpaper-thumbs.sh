#!/usr/bin/env bash
# Pre-generates small cached thumbnails for the wallpaper panel.
#
# QML's Image sourceSize hint lets the decoder itself produce a small
# image instead of decoding at full resolution -- but that scaled-decode
# path is only implemented for JPEG (libjpeg-turbo DCT scaling). For PNG
# and WEBP, Qt's plugins must fully decode at native resolution and THEN
# scale, so a 4K PNG/WEBP wallpaper still pays the full decode cost on
# every panel open regardless of sourceSize. Precomputing a real small
# file on disk once removes that cost from every open after the first.
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$HOME/.local/state/nix-profiles/profile/bin:$HOME/.nix-profile/bin:$PATH"

WALL_DIR="${1:?Usage: wallpaper-thumbs.sh <dir>}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wallpaper-thumbs"
mkdir -p "$CACHE_DIR"

shopt -s nullglob
for f in "$WALL_DIR"/*.jpg "$WALL_DIR"/*.jpeg "$WALL_DIR"/*.png "$WALL_DIR"/*.webp; do
	[ -f "$f" ] || continue
	mtime=$(stat -c %Y "$f" 2>/dev/null || echo 0)
	base=$(basename "$f")
	# mtime in the thumb filename doubles as the cache-invalidation key --
	# no timestamp comparison needed at lookup time, a stale thumb from a
	# since-replaced wallpaper is just a differently-named orphan file.
	thumb="$CACHE_DIR/${base%.*}-${mtime}.jpg"
	[ -f "$thumb" ] && continue
	magick "$f" -auto-orient -resize '320x320^' -gravity center -extent 320x320 -quality 82 "$thumb" 2>/dev/null || true
done
