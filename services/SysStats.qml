pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property real   cpuPercent:  0
    property real   ramPercent:  0
    property int    ramUsedMB:   0
    property int    ramTotalMB:  0
    property real   swapPercent: 0
    property int    swapUsedMB:  0
    property int    swapTotalMB: 0
    property string diskUsed:    "?"
    property string diskTotal:   "?"
    property real   diskPercent: 0
    property string uptime:      ""
    property string hostname:    ""
    property string kernel:      ""

    property string _prevStat: ""
    // Only SysInfoContent (the sysinfo panel) reads any of this. Polling 5
    // subprocesses every 4s unconditionally, for a value nothing on screen
    // ever shows unless that panel is open, is wasted work.
    property bool live: false
    // First reading after an idle gap would otherwise diff against a
    // _prevStat from minutes ago, producing one bogus CPU% before
    // self-correcting on the next tick. We reset _prevStat BEFORE
    // triggering the first poll so the diff-against-empty guard inside
    // cpuPoll's onRead skips the bogus computation. Previously
    // `onLiveChanged` reset _prevStat AND the Timer's triggeredOnStart
    // fired cpuPoll simultaneously -- order undefined, and if the Timer
    // won, cpuPoll read the OLD _prevStat and produced exactly the bogus
    // reading the comment claimed to fix. The Timer is now gated to NOT
    // fire on its first start when live just flipped; the explicit
    // cpuPoll trigger below provides the first read after the reset.
    onLiveChanged: {
        if (root.live) {
            root._prevStat = ""
            // Defer the first poll to the next event-loop tick so the
            // _prevStat="" assignment above is committed before cpuPoll's
            // onRead handler runs. Qt.callLater guarantees that.
            Qt.callLater(() => { cpuPoll.running = true; ramPoll.running = true; swapPoll.running = true; diskPoll.running = true; uptimePoll.running = true })
        }
    }

    Timer {
        interval: 4000; running: root.live; repeat: true  // NOT triggeredOnStart -- see onLiveChanged
        onTriggered: { cpuPoll.running = true; ramPoll.running = true; swapPoll.running = true; diskPoll.running = true; uptimePoll.running = true }
    }

    Process { id: cpuPoll
        command: ["bash", "-c", "cat /proc/stat | head -1"]
        stdout: SplitParser { onRead: d => {
            const parts = d.trim().split(/\s+/)
            const user   = parseInt(parts[1])
            const nice   = parseInt(parts[2])
            const system = parseInt(parts[3])
            const idle   = parseInt(parts[4])
            const iowait = parseInt(parts[5])
            const irq    = parseInt(parts[6])
            const sirq   = parseInt(parts[7])
            const totalIdle   = idle + iowait
            const totalActive = user + nice + system + irq + sirq
            const total = totalIdle + totalActive
            if (root._prevStat.length > 0) {
                const prev  = root._prevStat.split(",").map(Number)
                const dIdle  = totalIdle  - prev[0]
                const dTotal = total      - prev[1]
                if (dTotal > 0) root.cpuPercent = Math.round((1 - dIdle / dTotal) * 100)
            }
            root._prevStat = totalIdle + "," + total
        } } }

    Process { id: ramPoll
        command: ["bash", "-c", "free -m | awk 'NR==2{print $2,$3}'"]
        stdout: SplitParser { onRead: d => {
            const r = d.trim().split(/\s+/)
            if (r.length >= 2) {
                root.ramTotalMB = parseInt(r[0]) || 0
                root.ramUsedMB  = parseInt(r[1]) || 0
                root.ramPercent = root.ramTotalMB > 0 ? Math.round(root.ramUsedMB / root.ramTotalMB * 100) : 0
            }
        } } }

    Process { id: swapPoll
        command: ["bash", "-c", "free -m | awk 'NR==3{print $2,$3}'"]
        stdout: SplitParser { onRead: d => {
            const s = d.trim().split(/\s+/)
            if (s.length >= 2) {
                root.swapTotalMB = parseInt(s[0]) || 0
                root.swapUsedMB  = parseInt(s[1]) || 0
                root.swapPercent = root.swapTotalMB > 0 ? Math.round(root.swapUsedMB / root.swapTotalMB * 100) : 0
            }
        } } }

    Process { id: diskPoll
        command: ["bash", "-c", "df -h / | awk 'NR==2{print $3,$2,$5}'"]
        stdout: SplitParser { onRead: d => {
            const p = d.trim().split(/\s+/)
            if (p.length >= 3) {
                root.diskUsed    = p[0]
                root.diskTotal   = p[1]
                root.diskPercent = parseInt(p[2]) || 0
            }
        } } }

    Process { id: uptimePoll
        command: ["bash", "-c", "uptime -p | sed 's/up //'"]
        stdout: SplitParser { onRead: d => { root.uptime = d.trim() } } }

    Component.onCompleted: { hostPoll.running = true; kernelPoll.running = true }
    Process { id: hostPoll; command: ["hostname"]
        stdout: SplitParser { onRead: d => { root.hostname = d.trim() } } }
    Process { id: kernelPoll; command: ["bash", "-c", "uname -r"]
        stdout: SplitParser { onRead: d => { root.kernel = d.trim() } } }
}
