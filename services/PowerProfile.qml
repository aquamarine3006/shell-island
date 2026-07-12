pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property string current: "balanced"
    // Only read from ControlCenter/PowerProfile panels; no reason to poll
    // powerprofilesctl (a dbus round-trip) every 2s regardless of visibility.
    property bool  live: false

    readonly property var profiles: ["power-saver", "balanced", "performance"]

    readonly property var icons: ({
        "power-saver":  "󰌪",
        "balanced":     "󰈐",
        "performance":  "󰓅"
    })
    readonly property var labels: ({
        "power-saver":  "Power Saver",
        "balanced":     "Balanced",
        "performance":  "Performance"
    })
    readonly property var colors: ({
        "power-saver":  Colors.color5,
        "balanced":     Colors.color7,
        "performance":  Colors.foreground
    })

    // Debounce setProfile() -- Quickshell Process drops command
    // reassignment while running. PowerProfile is rarely called rapidly
    // (cycling through 3 profiles), but the debounce is cheap insurance
    // against double-clicks landing on the wrong target. Same pattern as
    // Audio.qml's setVolume / Bright.qml's setPercent.
    property string _pendingProfile: ""
    function setProfile(p: string): void {
        root.current = p             // optimistic UI update
        root._pendingProfile = p
        setProcTimer.restart()
    }
    Timer {
        id: setProcTimer
        interval: 50
        onTriggered: {
            if (root._pendingProfile.length === 0) return
            setProc.command = ["powerprofilesctl", "set", root._pendingProfile]
            root._pendingProfile = ""
            setProc.running = true
        }
    }

    Timer {
        interval: 2000; running: root.live; repeat: true; triggeredOnStart: true
        onTriggered: poll.running = true
    }
    Process {
        id: poll; command: ["powerprofilesctl", "get"]
        stdout: SplitParser { onRead: d => { const v = d.trim(); if (v.length > 0) root.current = v } }
    }
    Process { id: setProc }
}
