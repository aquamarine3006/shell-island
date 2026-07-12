pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../services"
import Quickshell.Io

Item {
    id: root
    signal dismiss()

    // Set by Pill.qml's Loader, which now stays permanently `active` for
    // this panel (see the comment on that Loader) so the GridView and its
    // Image delegates are built once and never torn down -- this Item just
    // fades in/out via `visible` instead of being destroyed/recreated on
    // every open. `panelVisible` is how it knows when it's actually the
    // one being shown, since Component.onCompleted now only fires once
    // ever, not on every open.
    property bool panelVisible: false

    readonly property string wallScript: Quickshell.env("HOME") + "/scripts/wallpaper.sh"
    readonly property int cols: 4
    readonly property int gap:  8

    // Chosen once per panel-open, applies to whichever wallpaper gets
    // confirmed. wallpaper.sh remembers it per-wallpaper on disk (see
    // wallpaper.sh's MODES_FILE) so re-selecting the same wallpaper later
    // without pressing Space again reuses whatever it was last set to --
    // this toggle is only for actively choosing/changing it right now.
    property string mode: "dark"

    // Listing/thumbnailing lives in the WallpaperIndex singleton (see
    // ../services/WallpaperIndex.qml) so it survives independently of this
    // panel's own lifecycle too.
    Component.onCompleted: {
        WallpaperIndex.ensureLoaded()
    }

    onPanelVisibleChanged: {
        if (panelVisible) {
            // Only a cheap `stat` on the directory, not a rescan -- catches
            // wallpapers added/removed since last open without redoing any
            // decode work for files that haven't changed.
            WallpaperIndex.checkStale()
            grid.forceActiveFocus()
        }
    }

    // Apple-style segmented control (iOS "Light | Dark" toggle): one
    // capsule track, one sliding highlight underneath plain text labels.
    // No icons/emoji -- the sliding highlight is the only affordance
    // needed to read current state at a glance.
    Rectangle {
        id: modeToggle
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
        width: 200; height: 32; radius: 16
        color: Colors.color0

        Rectangle {
            id: modeHighlight
            width: parent.width / 2; height: parent.height
            radius: parent.radius
            color: Colors.background
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)
            x: root.mode === "light" ? 0 : parent.width / 2
            Behavior on x { SpringAnimation { spring: 6.0; damping: 0.8 } }
        }

        Row {
            anchors.fill: parent
            Repeater {
                model: ["light", "dark"]
                delegate: Item {
                    required property string modelData
                    width: modeToggle.width / 2; height: modeToggle.height
                    Text {
                        anchors.centerIn: parent
                        text: modelData === "light" ? "Light" : "Dark"
                        font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                        font.bold: root.mode === modelData
                        color: root.mode === modelData ? Colors.foreground : Colors.color8
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.mode = modelData
                    }
                }
            }
        }
    }

    // Vibrancy slider: drag to change wallust's saturation live. Manual
    // hex->HSV parsing here instead of Qt.color(...).hsvSaturation --
    // that method isn't guaranteed present in every Quickshell QML engine
    // build, and a throwing binding was the likely reason this never
    // rendered right in the first place. Parsing three hex pairs and
    // taking (max-min)/max is the standard HSV saturation formula, no Qt
    // color API needed at all.
    Item {
        id: vibrancySlider
        anchors { top: modeToggle.bottom; horizontalCenter: parent.horizontalCenter; topMargin: 14 }
        width: 220; height: 20

        function hexSaturation(hex) {
            const h = hex.replace("#", "")
            const r = parseInt(h.substring(0, 2), 16)
            const g = parseInt(h.substring(2, 4), 16)
            const b = parseInt(h.substring(4, 6), 16)
            const max = Math.max(r, g, b)
            const min = Math.min(r, g, b)
            return max === 0 ? 0 : (max - min) / max
        }

        // Seed value: average saturation of the six accent colors in the
        // CURRENTLY active palette, read once when the panel first shows
        // this wallpaper's colors. After that the slider is fully
        // user-driven (sliderPct), not recomputed from Colors, so
        // dragging doesn't fight with the palette updating underneath it.
        function seedFromPalette() {
            const cols = [Colors.color1, Colors.color2, Colors.color3,
                          Colors.color4, Colors.color5, Colors.color6]
            let sum = 0
            for (let i = 0; i < cols.length; i++) sum += vibrancySlider.hexSaturation(cols[i])
            return Math.round((sum / cols.length) * 100)
        }

        property int sliderPct: 70
        property bool seeded: false

        Component.onCompleted: {
            // wallpaper-vibrancy.sh persists the last user-set value to
            // this file; if it exists, that wins over a palette guess
            // since it reflects an explicit choice rather than a
            // derived reading.
            satFileProc.running = true
        }

        Process {
            id: satFileProc
            command: ["cat", Quickshell.env("HOME") + "/.cache/wallust/saturation"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const n = parseInt(text.trim(), 10)
                    vibrancySlider.sliderPct = Number.isNaN(n)
                        ? vibrancySlider.seedFromPalette()
                        : Math.max(0, Math.min(100, n))
                    vibrancySlider.seeded = true
                }
            }
        }

        // Debounced so dragging doesn't spawn a wallust process per
        // pixel of mouse movement -- 120ms of no further movement before
        // the actual re-theme runs, same debounce shape as a live search
        // box.
        Timer {
            id: applyTimer
            interval: 120
            onTriggered: Quickshell.execDetached([
                "bash", Quickshell.env("HOME") + "/scripts/wallpaper-vibrancy.sh",
                String(vibrancySlider.sliderPct)
            ])
        }

        Text {
            id: vibrancyLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Vibrancy"
            font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
            color: Colors.color8
        }

        Text {
            id: vibrancyPct
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: vibrancySlider.sliderPct + "%"
            font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
            color: Colors.color8
        }

        Rectangle {
            id: track
            anchors.left: vibrancyLabel.right
            anchors.leftMargin: 8
            anchors.right: vibrancyPct.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 4; radius: 2
            color: Colors.color0

            Rectangle {
                height: parent.height; radius: parent.radius
                width: parent.width * (vibrancySlider.sliderPct / 100)
                color: Colors.color4
            }

            Rectangle {
                id: handle
                width: 12; height: 12; radius: 6
                color: Colors.foreground
                border.width: 1; border.color: Colors.color0
                anchors.verticalCenter: parent.verticalCenter
                x: parent.width * (vibrancySlider.sliderPct / 100) - width / 2
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -8  // generous hit target, track itself is only 4px tall
                onPositionChanged: (mouse) => {
                    if (pressed) updateFromX(mouse.x)
                }
                onPressed: (mouse) => updateFromX(mouse.x)

                function updateFromX(x) {
                    const pct = Math.round(Math.max(0, Math.min(1, x / track.width)) * 100)
                    if (pct !== vibrancySlider.sliderPct) {
                        vibrancySlider.sliderPct = pct
                        applyTimer.restart()
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        anchors { top: vibrancySlider.bottom; left: parent.left; right: parent.right; bottom: parent.bottom; margins: 14; topMargin: 14 }
        clip: true; model: WallpaperIndex.model; currentIndex: 0
        boundsBehavior: Flickable.StopAtBounds
        cellWidth:  width / root.cols; cellHeight: cellWidth
        // Bound to panelVisible, NOT a bare `true`. This Loader stays
        // permanently active (see Pill.qml) so this GridView is never
        // destroyed -- if focus were unconditionally true, this item
        // would keep claiming focus-scope ownership even while hidden,
        // and silently steal keyboard focus from other panels once
        // whatever THEY were focusing gets torn down (their Loaders,
        // unlike this one, really do destroy/recreate their content).
        focus: root.panelVisible
        // Recycles delegates instead of destroying/recreating them while
        // scrolling -- with dozens+ wallpapers this is the difference
        // between one-time delegate creation and constant alloc/GC churn.
        reuseItems: true

        Keys.onEscapePressed: { root.dismiss(); event.accepted = true }
        Keys.onSpacePressed: { root.mode = (root.mode === "dark" ? "light" : "dark"); event.accepted = true }
        Keys.onReturnPressed: {
            if (grid.currentIndex >= 0 && grid.currentIndex < WallpaperIndex.model.count) {
                Quickshell.execDetached(["bash", root.wallScript, WallpaperIndex.model.get(grid.currentIndex).path, root.mode])
                root.dismiss()
            }
            event.accepted = true
        }
        Keys.onLeftPressed:  { grid.moveCurrentIndexLeft();  event.accepted = true }
        Keys.onRightPressed: { grid.moveCurrentIndexRight(); event.accepted = true }
        Keys.onUpPressed:    { grid.moveCurrentIndexUp();    event.accepted = true }
        Keys.onDownPressed:  { grid.moveCurrentIndexDown();  event.accepted = true }

        delegate: Item {
            id: wrap
            required property string path
            required property string displayPath
            required property int    index
            width:  GridView.view.cellWidth; height: GridView.view.cellHeight

            readonly property bool active: grid.currentIndex === wrap.index

            Rectangle {
                id: thumb
                anchors.centerIn: parent
                width:  wrap.width  - root.gap; height: wrap.height - root.gap
                radius: 8; clip: true; color: Colors.color0

                border.width: wrap.active ? 2 : 0; border.color: Colors.foreground
                Behavior on border.width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                scale: wrap.active ? 1.05 : 1.0; transformOrigin: Item.Center
                Behavior on scale { SpringAnimation { spring: 6.5; damping: 0.78 } }

                Image {
                    anchors.fill: parent
                    // displayPath is the cached thumbnail when one exists
                    // (see wallpaper-thumbs.sh) and the original otherwise.
                    // sourceSize alone doesn't help for PNG/WEBP sources --
                    // Qt only supports scaled decode-time sizing for JPEG,
                    // so a large PNG/WEBP still pays a full-resolution
                    // decode every time without an actual small file to
                    // point at.
                    //
                    // sourceSize is a FIXED target, not `width`/`height`.
                    // This Item's size tracks the pill's spring-animated
                    // expand/collapse (260px -> 680px), so binding
                    // sourceSize to it meant every single animation frame
                    // requested a full redecode at that frame's
                    // intermediate size -- that's what caused the
                    // stutter/flicker while the panel was expanding. The
                    // GridView is 4 columns inside a 680px-wide panel
                    // (see Pill.qml's dimMap), so ~170px cells; 220 gives
                    // headroom for HiDPI without redecoding on resize.
                    // The Image is still decoded once at this fixed size
                    // and simply GPU-scaled during the spring, same as any
                    // other animated Item.
                    source: "file://" + wrap.displayPath
                    fillMode: Image.PreserveAspectCrop; asynchronous: true
                    sourceSize.width:  220
                    sourceSize.height: 220
                    cache: true
                }

                Rectangle {
                    anchors.fill: parent; color: Colors.background
                    opacity: wrap.active ? 0.0 : 0.25
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: grid.currentIndex = wrap.index
                    onClicked: {
                        grid.currentIndex = wrap.index
                        Quickshell.execDetached(["bash", root.wallScript, wrap.path, root.mode])
                        root.dismiss()
                    }
                }
            }
        }
    }
}
