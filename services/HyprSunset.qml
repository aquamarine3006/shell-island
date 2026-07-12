pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property bool active: false

    function toggle(): void {
        if (root.active) {
            killProc.running = true
            root.active = false
        } else {
            Quickshell.execDetached(["hyprsunset", "-t", "4500"])
            root.active = true
        }
    }

    Component.onCompleted: checkProc.running = true
    Process { id: checkProc
        command: ["bash", "-c", "pgrep -x hyprsunset && echo yes || echo no"]
        stdout: SplitParser { onRead: d => { root.active = d.trim() === "yes" } } }
    Process { id: killProc; command: ["pkill", "-x", "hyprsunset"] }
}
