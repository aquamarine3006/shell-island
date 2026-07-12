pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    // SysStats polls 5 subprocesses every 4s -- only worth paying for while
    // this panel is actually visible (see SysStats.qml).
    Component.onCompleted:   { forceActiveFocus(); SysStats.live = true }
    Component.onDestruction: SysStats.live = false
    Keys.onEscapePressed: function(ev) { root.dismiss(); ev.accepted = true }

    // ── Arc gauge component ───────────────────────────────────────────────────
    // Uses Canvas with a single onPaint handler driven by a smooth animPct property.
    // Only ONE onAnimPctChanged handler — calling requestPaint() — no duplicate.
    component ArcGauge: Item {
        id: ag
        width: 110; height: 110
        property real   pct:   0
        property string label: ""
        property string value: ""
        property string dim:    Colors.color6
        property string bright: Colors.color14

        // Smoothly animated internal value
        property real animPct: 0
        Behavior on animPct { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
        onPctChanged:     animPct = ag.pct
        Component.onCompleted: animPct = ag.pct

        Canvas {
            anchors.fill: parent
            // repaint whenever animPct moves
            property real trigger: ag.animPct
            onTriggerChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const cx = width / 2, cy = height / 2, r = width / 2 - 10
                const start = Math.PI * 0.75
                const full  = Math.PI * 1.5

                // background track
                ctx.beginPath()
                ctx.arc(cx, cy, r, start, start + full)
                ctx.strokeStyle = Colors.color0
                ctx.lineWidth   = 9
                ctx.lineCap     = "round"
                ctx.stroke()

                // foreground fill
                const sweep = full * Math.min(1, Math.max(0, ag.animPct) / 100)
                if (sweep > 0) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, start + sweep)
                    ctx.strokeStyle = ag.animPct > 85 ? Colors.critical
                                    : ag.animPct > 60 ? ag.bright
                                    : ag.dim
                    ctx.lineWidth   = 9
                    ctx.lineCap     = "round"
                    ctx.stroke()
                }
            }
        }

        Column {
            anchors.centerIn: parent; spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ag.value; color: Colors.foreground
                font.pixelSize: 19; font.bold: true
                font.family: "JetBrainsMono Nerd Font"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: ag.label; color: Colors.color8
                font.pixelSize: 13
                font.family: "JetBrainsMono Nerd Font"
            }
        }
    }

    // ── Bar stat for Disk ─────────────────────────────────────────────────────
    component StatBar: Item {
        id: sb; height: 46
        property string icon:  ""
        property string label: ""
        property string value: ""
        property real   pct:   0
        property string dim:    Colors.color6
        property string bright: Colors.color14

        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 8
            Text { text: sb.icon; color: Colors.color8; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: sb.label; color: Colors.color8; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
        }
        Text {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text: sb.value; color: sb.bright
            font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"
        }
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 5; radius: 3; color: Colors.color0
            Rectangle {
                width: Math.max(0, Math.min(parent.width, parent.width * sb.pct / 100))
                height: parent.height; radius: 3
                color: sb.pct > 85 ? Colors.critical : (sb.pct > 60 ? sb.bright : sb.dim)
                Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    Column {
        anchors { fill: parent; margins: 22 }
        spacing: 14

        // ── Header row ────────────────────────────────────────────────────────
        Item {
            width: parent.width; height: 32
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 8
                Text { text: "󰻟"; color: Colors.color8; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "SYSTEM"; color: Colors.color8; font.pixelSize: 15; font.bold: true; font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: 3; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: SysStats.hostname; color: Colors.color8
                font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.color0 }

        // ── Arc gauges row: CPU | RAM | Swap ─────────────────────────────────
        Row {
            width: parent.width
            spacing: (parent.width - 330) / 2

            // Each gauge gets its own hue family (blue/green/magenta) instead
            // of all three sharing the same foreground/color6/color8 cycle --
            // that was the actual reason CPU/RAM/Swap only read as distinct
            // via their text labels before.
            ArcGauge {
                pct:   SysStats.cpuPercent
                label: "CPU"
                value: SysStats.cpuPercent + "%"
                dim:    Colors.color4
                bright: Colors.color12
            }
            ArcGauge {
                pct:   SysStats.ramPercent
                label: "RAM"
                value: {
                    const used  = SysStats.ramUsedMB
                    const total = SysStats.ramTotalMB
                    if (total <= 0) return "—"
                    return used >= 1024
                        ? (used / 1024).toFixed(1) + "G"
                        : used + "M"
                }
                dim:    Colors.color2
                bright: Colors.color10
            }
            ArcGauge {
                pct:   SysStats.swapPercent
                label: "Swap"
                value: {
                    const used  = SysStats.swapUsedMB
                    const total = SysStats.swapTotalMB
                    if (total <= 0) return "—"
                    return used >= 1024
                        ? (used / 1024).toFixed(1) + "G"
                        : used + "M"
                }
                dim:    Colors.color5
                bright: Colors.color13
            }
        }

        // RAM / Swap detail line
        Row {
            width: parent.width; spacing: 20
            // RAM detail
            Text {
                width: (parent.width - 20) / 2
                text: {
                    const u = SysStats.ramUsedMB, t = SysStats.ramTotalMB
                    if (t <= 0) return "RAM: —"
                    const ug = u >= 1024 ? (u/1024).toFixed(1)+"G" : u+"M"
                    const tg = t >= 1024 ? (t/1024).toFixed(1)+"G" : t+"M"
                    return "RAM  " + ug + " / " + tg + "  (" + SysStats.ramPercent + "%)"
                }
                color: Colors.color8; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                horizontalAlignment: Text.AlignHCenter
            }
            // Swap detail
            Text {
                width: (parent.width - 20) / 2
                text: {
                    const u = SysStats.swapUsedMB, t = SysStats.swapTotalMB
                    if (t <= 0) return "Swap: none"
                    const ug = u >= 1024 ? (u/1024).toFixed(1)+"G" : u+"M"
                    const tg = t >= 1024 ? (t/1024).toFixed(1)+"G" : t+"M"
                    return "Swap  " + ug + " / " + tg + "  (" + SysStats.swapPercent + "%)"
                }
                color: Colors.color8; font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle { width: parent.width; height: 1; color: Colors.color0 }

        // ── Disk bar ──────────────────────────────────────────────────────────
        StatBar {
            width: parent.width
            icon: "󰋊"; label: "Disk"
            value: SysStats.diskUsed + " / " + SysStats.diskTotal + "  (" + SysStats.diskPercent + "%)"
            pct:   SysStats.diskPercent
            dim:    Colors.color6
            bright: Colors.color14
        }

        Rectangle { width: parent.width; height: 1; color: Colors.color0 }

        // ── Kernel + uptime ───────────────────────────────────────────────────
        Row {
            width: parent.width; spacing: 10
            Column {
                spacing: 6; width: parent.width
                Row {
                    spacing: 8
                    Text { text: "󰌢"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: SysStats.kernel; color: Colors.color8; font.pixelSize: 15; font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight; width: parent.parent.width - 28 }
                }
                Row {
                    spacing: 8
                    Text { text: "󰅐"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "up " + SysStats.uptime; color: Colors.color8; font.pixelSize: 15; font.family: "JetBrainsMono Nerd Font" }
                }
            }
        }

    }
}
