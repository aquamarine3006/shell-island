pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property int  percent: 100
    // setPercent() below updates `percent` optimistically the instant the
    // user changes it, so the poll below only exists to catch brightness
    // changes from *outside* this shell (firmware hotkeys, another app).
    // Running it unconditionally forked "brightnessctl get"+"max" (2
    // processes) 20x/sec forever -- the dominant contributor to constant
    // background CPU use. Gate it to when something is actually displaying
    // the value; Pill.qml drives this via a Binding on `live`.
    property bool live: false

    // Debounce setPercent() calls: Quickshell's Process drops command
    // reassignment while running, so a rapid slider drag would lose every
    // intermediate value except the first. 50ms timer collapses a burst
    // into one brightnessctl invocation carrying the latest value -- same
    // fix as Audio.qml's setVolume debounce.
    property int _pendingPct: -1
    function setPercent(v: int): void {
        const c = Math.max(5, Math.min(100, v))
        root.percent = c          // optimistic UI update
        root._pendingPct = c
        setProcTimer.restart()
    }
    Timer {
        id: setProcTimer
        interval: 50
        onTriggered: {
            if (root._pendingPct < 0) return
            setProc.command = ["brightnessctl", "set", String(root._pendingPct) + "%"]
            root._pendingPct = -1
            setProc.running = true
        }
    }

    Timer {
        interval: 300; running: root.live; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }
    Process {
        id: poll
        command: ["bash", "-c", "echo $(( $(brightnessctl get) * 100 / $(brightnessctl max) ))"]
        stdout: SplitParser { onRead: d => { const v = parseInt(d.trim()); if (!isNaN(v)) root.percent = v } }
    }
    Process { id: setProc }
}
