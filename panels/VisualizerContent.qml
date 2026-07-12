import QtQuick
import Quickshell.Io
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    Component.onCompleted: { forceActiveFocus(); root.hasCavaData = false; cavaConfig.running = true }
    // Fixed: `cava.running` referenced a nonexistent ID (actual IDs are
    // cavaConfig / cavaProc / cavaReader), which threw a TypeError and
    // skipped the rest of the cleanup -- cavaProc and cavaReader (blocked
    // on a FIFO read) were never explicitly stopped, leaving cava and the
    // perl reader running after the panel closed. Now stops both
    // explicitly. Quickshell's Process sets running=false which sends
    // SIGTERM to the child.
    Component.onDestruction: { cavaProc.running = false; cavaReader.running = false; root.hasCavaData = false }

    Keys.onEscapePressed: { root.dismiss(); event.accepted = true }

    readonly property int barCount: 20

    property var bars:      Array(barCount).fill(0)
    property var frameBuf:  []
    property bool hasCavaData: false

    Process {
        id: cavaConfig
        command: ["bash", "-c",
            "printf '[general]\\nbars=" + root.barCount + "\\nframerate=60\\nsleep_timer=5\\n" +
            "[output]\\nmethod=raw\\nraw_target=/tmp/cava_qs.fifo\\n" +
            "data_format=binary\\nbits=16\\n' > /tmp/cava_qs.conf\n" +
            "rm -f /tmp/cava_qs.fifo && mkfifo /tmp/cava_qs.fifo && echo ok"
        ]
        stdout: SplitParser {
            onRead: d => { if (d.trim() === "ok") { cavaProc.running = true; cavaReader.running = true } }
        }
    }

    Process {
        id: cavaProc
        command: ["cava", "-p", "/tmp/cava_qs.conf"]
        running: false
    }

    Process {
        id: cavaReader
        command: ["perl", "-e",
            "open(my $f,'<:raw','/tmp/cava_qs.fifo') or die; $|=1; my $b; while(read($f,$b,2)==2){print unpack('v',$b),\"\\n\"}"
        ]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const v = parseInt(line.trim())
                if (isNaN(v)) return
                const scaled = Math.min(100, Math.round(v / 655))
                const buf = root.frameBuf.concat([scaled])
                if (buf.length >= root.barCount) {
                    root.bars = buf.slice(0, root.barCount)
                    root.frameBuf = []
                    root.hasCavaData = true
                } else {
                    root.frameBuf = buf
                }
            }
        }
    }

    Column {
        anchors { fill: parent; margins: 14 }
        spacing: 10

        Text {
            text: "VISUALIZER"; color: Colors.color8; font.pixelSize: 17; font.bold: true
            font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: 3
        }

        Item {
            width: parent.width
            height: parent.height - 40

            Row {
                anchors.fill: parent
                spacing: 3

                Repeater {
                    model: root.barCount
                    Rectangle {
                        required property int index
                        readonly property real barH: (root.bars[index] ?? 0) / 100

                        width: (parent.width - (root.barCount - 1) * 3) / root.barCount
                        height: parent.height
                        color: "transparent"

                        Rectangle {
                            width: parent.width
                            height: Math.max(3, parent.height * barH)
                            anchors.bottom: parent.bottom
                            radius: width / 2

                            readonly property real h: barH
                            // Was a hardcoded grayscale ramp (Qt.rgba with
                            // equal r/g/b) -- didn't track the wallust
                            // theme at all, so it looked the same
                            // regardless of wallpaper/accent color. Same
                            // dim -> bright -> critical threshold
                            // convention as SysInfoContent.qml's usage
                            // bars (color6 = dim, color4 = bright accent,
                            // Colors.critical = peak), just interpolated
                            // continuously by amplitude instead of
                            // stepped, so quiet bars sit at the theme's
                            // dim tone and loud bars ease toward the
                            // accent, then critical right at the peak.
                            // Qt.color() turns the "#rrggbb" strings from
                            // Colors.qml into proper color objects first --
                            // Qt.tint's second arg needs alpha-in-color,
                            // not a bare rgba() tuple, for the blend to
                            // read as "tint dim toward accent by h".
                            color: h > 0.85
                                ? Colors.critical
                                : Qt.tint(Qt.color(Colors.color6), Qt.rgba(Qt.color(Colors.color4).r, Qt.color(Colors.color4).g, Qt.color(Colors.color4).b, h))
                        }
                    }
                }
            }
        }

    }
}
