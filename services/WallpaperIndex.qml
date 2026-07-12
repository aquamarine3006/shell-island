pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persistent wallpaper listing, independent of the panel's Loader lifecycle.
//
// WallpaperContent.qml lives inside `Loader { active: root.panel === "wallpaper" }`
// in Pill.qml, which DESTROYS the panel (and any local ListModel/Process) every
// time it closes. Previously the listing + thumbnail scan re-ran from scratch on
// every open, which is why the panel felt slow every single time rather than
// just the first time. This singleton is created once for the whole shell
// process and never torn down, so the scan only happens:
//   1. once, the first time the wallpaper panel is ever opened, and
//   2. again only if the wallpaper directory's mtime changes (see dirWatcher),
//      so adding/removing wallpapers is still picked up without a full
//      unconditional rescan on every open.
Item {
    id: root

    readonly property string wallDir:     Quickshell.env("WALLPAPER_DIR")
    readonly property string thumbScript: Quickshell.env("HOME") + "/scripts/wallpaper-thumbs.sh"
    readonly property string thumbCache:  Quickshell.env("HOME") + "/.cache/wallpaper-thumbs"

    property ListModel model: ListModel {}
    property bool loaded: false
    property string lastDirMtime: ""

    function ensureLoaded() {
        if (!root.loaded) rescan()
    }

    function rescan() {
        root.loaded = true
        root.model.clear()
        lister.running = true
        thumbGen.running = true
    }

    // Cheap staleness check: if the directory's own mtime changed (a file was
    // added/removed/renamed), rescan. Editing a wallpaper in place still
    // busts its own thumbnail cache key (see wallpaper-thumbs.sh's mtime
    // suffix) even without a full rescan, so this only needs to catch
    // additions/removals, not in-place edits.
    Process {
        id: dirStat
        command: ["stat", "-c", "%Y", root.wallDir]
        stdout: SplitParser { onRead: line => {
            const m = line.trim()
            if (root.lastDirMtime !== "" && root.lastDirMtime !== m) root.rescan()
            root.lastDirMtime = m
        } }
    }

    function checkStale() { dirStat.running = true }

    Process {
        id: lister
        command: ["bash", "-c",
            "CACHE=\"" + root.thumbCache + "\"; shopt -s nullglob; " +
            "for f in \"" + root.wallDir + "\"/*.jpg \"" + root.wallDir + "\"/*.jpeg \"" + root.wallDir + "\"/*.png \"" + root.wallDir + "\"/*.webp; do " +
            "m=$(stat -c %Y \"$f\" 2>/dev/null || echo 0); b=$(basename \"$f\"); t=\"$CACHE/${b%.*}-$m.jpg\"; " +
            "if [ -f \"$t\" ]; then printf '%s\\t%s\\n' \"$f\" \"$t\"; else printf '%s\\t%s\\n' \"$f\" \"$f\"; fi; " +
            "done"]
        stdout: SplitParser { onRead: line => {
            const parts = line.trim().split("\t")
            if (parts.length === 2 && parts[0].length > 0) root.model.append({ path: parts[0], displayPath: parts[1] })
        } }
    }

    // Detached, low-priority: fills in any missing thumbnails so future
    // opens (and future rescans) hit the fast cached path.
    Process {
        id: thumbGen
        command: ["nice", "-n", "19", "bash", root.thumbScript, root.wallDir]
    }
}
