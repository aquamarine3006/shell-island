pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property int     percent: 100
    property string  status:  "Unknown"   // "Charging", "Discharging", "Full", "Unknown"
    property bool    present: false

    readonly property bool charging:  status === "Charging" || status === "Full"
    readonly property bool critical:  percent <= 15 && !charging

    readonly property string icon: {
        if (status === "Full")     return "󰁹"
        if (status === "Charging") {
            if (percent >= 90) return "󰂅"
            if (percent >= 70) return "󰂄"
            if (percent >= 50) return "󰂃"
            if (percent >= 30) return "󰂂"
            return "󰢜"
        }
        if (percent >= 90) return "󰁹"
        if (percent >= 70) return "󰁾"
        if (percent >= 50) return "󰁽"
        if (percent >= 30) return "󰁻"
        if (percent >= 15) return "󰁺"
        return "󰂃"
    }

    readonly property color iconColor: {
        if (charging)      return Colors.color2
        if (percent <= 15) return Colors.color1
        if (percent <= 30) return Colors.color3
        return Colors.foreground
    }

    Timer {
        interval: 15000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { presentPoll.running = true; percentPoll.running = true; statusPoll.running = true }
    }
    Process {
        id: presentPoll
        command: ["bash", "-c", "ls /sys/class/power_supply/BAT* 2>/dev/null | head -1"]
        stdout: SplitParser { onRead: d => { root.present = d.trim().length > 0 } }
    }
    Process {
        id: percentPoll
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1"]
        stdout: SplitParser { onRead: d => { const v = parseInt(d.trim()); if (!isNaN(v)) root.percent = v } }
    }
    Process {
        id: statusPoll
        command: ["bash", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1"]
        stdout: SplitParser { onRead: d => { const v = d.trim(); if (v.length > 0) root.status = v } }
    }
}
