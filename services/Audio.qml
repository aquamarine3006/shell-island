pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property int  volume: 0
    property bool muted:  false
    // Same reasoning as Bright.live: setVolume()/toggleMute() already update
    // state optimistically, so polling only exists to catch external
    // changes. Two pamixer forks/tick (each opening a PulseAudio/PipeWire
    // client connection) forever was needless background load.
    property bool live: false

    // setVolume() used to assign volSet.command and set volSet.running=true
    // inline. Quickshell's Process drops the assignment when running is
    // already true (no queue), so rapid slider drags dropped every
    // intermediate value -- only the first call actually fired. Debouncing
    // via a Timer collapses a burst of N setVolume() calls into a single
    // pamixer invocation carrying the LATEST value, which is what the user
    // actually wants (no need for intermediate volumes to be applied).
    property int _pendingVol: -1
    function setVolume(v: int): void {
        const c = Math.max(0, Math.min(100, v))
        root.volume = c            // optimistic UI update
        root._pendingVol = c
        volSetTimer.restart()
    }
    Timer {
        id: volSetTimer
        interval: 50
        onTriggered: {
            if (root._pendingVol < 0) return
            volSet.command = ["pamixer", "--set-volume", String(root._pendingVol)]
            root._pendingVol = -1
            volSet.running = true
        }
    }
    function toggleMute(): void {
        root.muted = !root.muted
        muteProc.running = true
    }

    Timer {
        interval: 500; running: root.live; repeat: true; triggeredOnStart: true
        onTriggered: { volPoll.running = true; mutePoll.running = true }
    }
    Process {
        id: volPoll; command: ["pamixer", "--get-volume"]
        stdout: SplitParser { onRead: d => { const v = parseInt(d.trim()); if (!isNaN(v)) root.volume = v } }
    }
    Process {
        id: mutePoll; command: ["pamixer", "--get-mute"]
        stdout: SplitParser { onRead: d => { root.muted = d.trim() === "true" } }
    }
    Process { id: volSet }
    Process { id: muteProc; command: ["pamixer", "-t"] }
}
