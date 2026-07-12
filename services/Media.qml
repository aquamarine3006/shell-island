pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property string title:    ""
    property string artist:   ""
    property string status:   "Stopped"
    property int    position: 0
    property int    length:   0
    property string artUrl:   ""

    readonly property bool playing: status === "Playing"

    // Only MediaContent and ControlCenterContent ever display this state;
    // every other consumer (shell.qml's IPC handlers) only calls the
    // control functions below. Before this flag existed, six separate
    // playerctl/bash subprocesses were forked every second forever,
    // regardless of whether any panel showing media info was even open --
    // each playerctl call opens its own MPRIS/D-Bus round trip, so this was
    // six fork+exec+D-Bus calls/sec 24/7 and was the single largest
    // contributor to idle CPU usage. Gated the same way Audio/Bright/
    // Network/PowerProfile/SysStats already are: false until a consuming
    // panel's Component.onCompleted/onDestruction flips it.
    property bool live: false
    onLiveChanged: if (root.live) pollAll.running = true

    function play():     void { _cmd(["playerctl", "play"])     }
    function pause():    void { _cmd(["playerctl", "pause"])    }
    function toggle():   void { _cmd(["playerctl", "play-pause"]) }
    function next():     void { _cmd(["playerctl", "next"])     }
    function prev():     void { _cmd(["playerctl", "previous"]) }
    // Clamp seek position to [0, length]. The MediaContent seek MouseArea
    // uses `anchors.margins: -6`, so mouse.x can range from -6 to
    // width+6, and the unguarded `Math.round(mouse.x/width*length)`
    // could produce negative or >length positions -- playerctl would
    // then error or seek to a nonsensical point.
    function seekTo(s: int): void {
        const clamped = Math.max(0, Math.min(root.length, s))
        _cmd(["playerctl", "position", String(clamped)])
    }

    // Debounce _cmd(): Quickshell Process drops command reassignment
    // while running, so rapid calls (e.g. holding the Next button) would
    // only fire the first one. Same pattern as Audio/Bright/PowerProfile.
    property var _pendingCmd: null
    function _cmd(c): void {
        root._pendingCmd = c
        cmdProcTimer.restart()
    }
    Timer {
        id: cmdProcTimer
        interval: 50
        onTriggered: {
            if (!root._pendingCmd) return
            cmdProc.command = root._pendingCmd
            root._pendingCmd = null
            cmdProc.running = true
        }
    }

    Timer {
        interval: 1000; running: root.live; repeat: true; triggeredOnStart: true
        onTriggered: pollAll.running = true
    }

    // Single subprocess instead of six: one playerctl "metadata" call plus
    // one "status" call, joined with a literal tab so a single SplitParser
    // can demux them -- five sequential playerctl invocations replaced by
    // one and a half. printf falls back to empty fields instead of
    // erroring when nothing is playing (playerctl metadata alone exits
    // non-zero with no player running), so the panel just shows blanks.
    //
    // Separator choice: previously `|` was used as IFS, which collides
    // with any title/artist containing a literal `|` and shifts every
    // later field -- including `ln`, which then makes
    // `$(( ${ln:-0} / 1000000 ))` evaluate against non-numeric garbage
    // and silently produce 0 (or, before bash 5.1, throw a syntax error
    // swallowed by 2>/dev/null). Tab is ASCII 9, which never appears in
    // ID3/Vorbis/MP4 metadata strings.
    Process {
        id: pollAll
        command: ["bash", "-c",
            "s=$(playerctl status 2>/dev/null); " +
            "IFS=$'\\t' read -r ti ar au ln <<<\"$(playerctl metadata --format '{{title}}\\t{{artist}}\\t{{mpris:artUrl}}\\t{{mpris:length}}' 2>/dev/null)\"; " +
            "po=$(playerctl position 2>/dev/null | cut -d. -f1); " +
            "printf '%s\\t%s\\t%s\\t%s\\t%s\\t%s\\n' \"$s\" \"$ti\" \"$ar\" \"$au\" \"${po:-0}\" \"$(( ${ln:-0} / 1000000 ))\""]
        stdout: SplitParser { onRead: d => {
            const p = d.split("\t")
            if (p.length < 6) return
            root.status   = p[0]
            root.title    = p[1]
            root.artist   = p[2]
            root.artUrl   = p[3]
            const pos = parseInt(p[4]); if (!isNaN(pos)) root.position = pos
            const len = parseInt(p[5]); if (!isNaN(len)) root.length   = len
        } }
    }

    Process { id: cmdProc }
}
