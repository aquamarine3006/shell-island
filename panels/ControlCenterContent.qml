pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    // This panel is the only place Audio/Bright/Network/PowerProfile's live
    // values are shown together, so it's the single place that turns their
    // polling on. Media has its own gate in MediaContent since it isn't
    // shown here.
    Component.onCompleted: {
        Audio.live        = true
        Bright.live       = true
        Network.live      = true
        PowerProfile.live = true
        forceActiveFocus()
    }
    Component.onDestruction: {
        Audio.live        = false
        Bright.live       = false
        Network.live      = false
        PowerProfile.live = false
    }
    Keys.onEscapePressed: function(ev) { root.dismiss(); ev.accepted = true }

    // ── Keyboard navigation ─────────────────────────────────────────────────
    // This panel previously had zero keyboard nav beyond Escape -- every
    // tile/slider/action was mouse-only. navIndex walks a flat list laid
    // out in the same visual grid as the two 4-wide tile rows, then the two
    // sliders as single-wide rows below them. Left/Right move within a row
    // (wrapping); Up/Down move between rows, landing on the same column
    // when the row below is narrower. Enter/Space activates the focused
    // tile; Left/Right on a focused slider adjust its value by 5% instead
    // of navigating (there is no "row" to leave sideways from a lone
    // slider row, so repurposing Left/Right there is unambiguous).
    property int navIndex: 0
    readonly property var navRows: [
        ["mute", "profile", "sunset", "nmtui"],
        ["play", "prev", "next"],
        ["volume"],
        ["brightness"]
    ]
    readonly property var navFlat: navRows.reduce((a, r) => a.concat(r), [])
    readonly property string navCurrent: navFlat[Math.max(0, Math.min(navFlat.length - 1, root.navIndex))]

    function navRowOf(key: string): int {
        for (let r = 0; r < navRows.length; r++) if (navRows[r].indexOf(key) !== -1) return r
        return 0
    }
    function navColOf(key: string): int {
        const r = navRowOf(key)
        return navRows[r].indexOf(key)
    }
    function navMove(rowDelta: int, colDelta: int): void {
        const key = root.navCurrent
        let row   = root.navRowOf(key)
        let col   = root.navColOf(key)
        if (colDelta !== 0) {
            const len = navRows[row].length
            col = (col + colDelta + len) % len
        }
        if (rowDelta !== 0) {
            row = Math.max(0, Math.min(navRows.length - 1, row + rowDelta))
            col = Math.min(col, navRows[row].length - 1)
        }
        root.navIndex = navFlat.indexOf(navRows[row][col])
    }
    function navActivate(): void {
        switch (root.navCurrent) {
        case "mute":    Audio.toggleMute(); break
        case "profile": { const p = PowerProfile.profiles; PowerProfile.setProfile(p[(p.indexOf(PowerProfile.current) + 1) % p.length]); break }
        case "sunset":  HyprSunset.toggle(); break
        // kitty is installed via home-manager (programs.kitty.enable), so it
        // lives at ~/.nix-profile/bin/kitty, NOT /run/current-system/sw/bin/.
        // Using an absolute system path that doesn't exist caused execDetached
        // to fail silently. Use bare "kitty" so PATH resolves correctly.
        // --app-id (not --class) sets the Wayland app_id that Hyprland's
        // windowrule matches against; --class only sets the X11 WM_CLASS.
        case "nmtui":   Quickshell.execDetached(["bash", "-c", "kitty --app-id nmtui --class nmtui -e nmtui"]); root.dismiss(); break
        case "play":    Media.toggle(); break
        case "prev":    Media.prev(); break
        case "next":    Media.next(); break
        }
    }
    function navAdjust(delta: int): void {
        if (root.navCurrent === "volume")     Audio.setVolume(Math.max(0, Math.min(100, Audio.volume + delta)))
        if (root.navCurrent === "brightness") Bright.setPercent(Math.max(0, Math.min(100, Bright.percent + delta)))
    }

    Keys.onUpPressed:    function(ev) { root.navMove(-1, 0); ev.accepted = true }
    Keys.onDownPressed:  function(ev) { root.navMove(1, 0);  ev.accepted = true }
    Keys.onLeftPressed:  function(ev) {
        if (root.navCurrent === "volume" || root.navCurrent === "brightness") root.navAdjust(-5)
        else root.navMove(0, -1)
        ev.accepted = true
    }
    Keys.onRightPressed: function(ev) {
        if (root.navCurrent === "volume" || root.navCurrent === "brightness") root.navAdjust(5)
        else root.navMove(0, 1)
        ev.accepted = true
    }
    Keys.onReturnPressed: function(ev) { root.navActivate(); ev.accepted = true }
    Keys.onSpacePressed:  function(ev) { root.navActivate(); ev.accepted = true }

    // ── Inline slider component ───────────────────────────────────────────────
    component SliderRow: Item {
        id: sldr; height: 44
        signal moved(real v)
        property real  value:  0
        property color accent: Colors.foreground

        Rectangle {
            id: track
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 7; radius: 4; color: Colors.color0
            Rectangle {
                width: Math.max(0, Math.min(track.width, track.width * sldr.value))
                height: parent.height; radius: 3; color: sldr.accent
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
        Rectangle {
            width: 20; height: 20; radius: 10; color: sldr.accent
            x: Math.max(0, Math.min(track.width - width, track.width * sldr.value - width / 2))
            anchors.verticalCenter: track.verticalCenter
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        MouseArea {
            anchors.fill: parent; preventStealing: true
            function val(mx) { return Math.max(0, Math.min(1, mx / track.width)) }
            onPressed:         function(mouse) { sldr.moved(val(mouse.x)) }
            onPositionChanged: function(mouse) { if (pressed) sldr.moved(val(mouse.x)) }
        }
    }

    // ── Stat row component ────────────────────────────────────────────────────
    component StatBar: Item {
        id: sb; height: 36
        property string label: ""
        property string value: ""
        property real   pct:   0

        Text {
            id: lbl; text: sb.label; color: Colors.color8
            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 52
        }
        Rectangle {
            id: sbTrack
            anchors { left: lbl.right; leftMargin: 8; right: valLbl.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            height: 4; radius: 2; color: Colors.color0
            Rectangle {
                width: Math.max(0, Math.min(sbTrack.width, sbTrack.width * sb.pct / 100))
                height: parent.height; radius: 2
                color: sb.pct > 85 ? Colors.foreground : (sb.pct > 60 ? Colors.color6 : Colors.color8)
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
        Text {
            id: valLbl; text: sb.value; color: Colors.color8
            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 100; horizontalAlignment: Text.AlignRight
        }
    }

    // ── Scrollable body ───────────────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; margins: 24 }
            spacing: 20

            // ── Giant clock ───────────────────────────────────────────────
            Item {
                width: parent.width; height: 96
                Text {
                    id: bigClock
                    anchors.centerIn: parent
                    color: Colors.foreground; font.pixelSize: 60; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    property string t: Qt.formatTime(new Date(), "hh:mm")
                    text: t
                    Timer { running: true; repeat: true; interval: 1000
                            onTriggered: parent.t = Qt.formatTime(new Date(), "hh:mm") }
                }
                Text {
                    anchors { top: bigClock.bottom; horizontalCenter: parent.horizontalCenter }
                    property string d: Qt.formatDate(new Date(), "ddd, MMM d")
                    text: d; color: Colors.color8; font.pixelSize: 15
                    font.family: "JetBrainsMono Nerd Font"
                    Timer { running: true; repeat: true; interval: 60000
                            onTriggered: parent.d = Qt.formatDate(new Date(), "ddd, MMM d") }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.color0 }

            // ── Quick tiles row 1: Mute | PowerProfile | HyprSunset | Impala ─
            Row {
                width: parent.width; spacing: 12

                // Mute
                Rectangle {
                    id: muteTileRect
                    width: (parent.width - 30) / 4; height: 84; radius: 18
                    color: Audio.muted ? Colors.foreground : Colors.color0
                    border.width: root.navCurrent === "mute" ? 2 : 0
                    border.color: Colors.foreground
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Audio.muted ? "󰖁" : "󰕾"
                            color: Audio.muted ? Colors.background : Colors.color8
                            font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Audio.muted ? "Muted" : "Sound"
                            color: Audio.muted ? Colors.background : Colors.color8
                            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                    scale: muteTileMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    MouseArea { id: muteTileMa; anchors.fill: parent; hoverEnabled: true; onClicked: Audio.toggleMute() }
                }

                // Power profile cycle
                Rectangle {
                    id: ppTile
                    width: (parent.width - 30) / 4; height: 84; radius: 18
                    color: PowerProfile.current === "performance" ? Colors.foreground : Colors.color0
                    border.width: root.navCurrent === "profile" ? 2 : 0
                    border.color: Colors.foreground
                    Behavior on color { ColorAnimation { duration: 150 } }
                    readonly property bool active: PowerProfile.current === "performance"
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: PowerProfile.icons[PowerProfile.current] ?? "󰈐"
                            color: ppTile.active ? Colors.background : Colors.color8
                            font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: ppTile.active ? "Perf" : (PowerProfile.current === "power-saver" ? "Saver" : "Bal")
                            color: ppTile.active ? Colors.background : Colors.color8
                            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                    scale: ppTileMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    MouseArea {
                        id: ppTileMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: {
                            const p = PowerProfile.profiles
                            PowerProfile.setProfile(p[(p.indexOf(PowerProfile.current) + 1) % p.length])
                        }
                    }
                }

                // HyprSunset toggle
                Rectangle {
                    id: sunsetTile
                    width: (parent.width - 30) / 4; height: 84; radius: 18
                    color: HyprSunset.active ? Colors.foreground : Colors.color0
                    border.width: root.navCurrent === "sunset" ? 2 : 0
                    border.color: Colors.foreground
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰖙"
                            color: HyprSunset.active ? Colors.background : Colors.color8
                            font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Sunset"
                            color: HyprSunset.active ? Colors.background : Colors.color8
                            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                    scale: sunsetTileMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    MouseArea { id: sunsetTileMa; anchors.fill: parent; hoverEnabled: true; onClicked: HyprSunset.toggle() }
                }

                // Launch nmtui
                Rectangle {
                    id: nmtuiTile
                    width: (parent.width - 30) / 4; height: 84; radius: 18; color: Colors.color0
                    border.width: root.navCurrent === "nmtui" ? 2 : 0
                    border.color: Colors.foreground
                    scale: nmtuiMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰖟"; color: Colors.color8
                            font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "nmtui"; color: Colors.color8
                            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                        }
                    }
                    MouseArea {
                        id: nmtuiMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Quickshell.execDetached(["bash", "-c", "kitty --app-id nmtui --class nmtui -e nmtui"]); root.dismiss() }
                    }
                }
            }

            // ── Quick tiles row 2: Play | Skip | Prev | (spacer) ─────────────
            Row {
                width: parent.width; spacing: 12

                Rectangle {
                    id: playTile2
                    width: (parent.width - 30) / 4; height: 84; radius: 18
                    color: Media.playing ? Colors.foreground : Colors.color0
                    border.width: root.navCurrent === "play" ? 2 : 0
                    border.color: Colors.foreground
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Media.playing ? "󰏤" : "󰐊"
                            color: Media.playing ? Colors.background : Colors.color8
                            font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Media.playing ? "Pause" : "Play"
                            color: Media.playing ? Colors.background : Colors.color8
                            font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                    scale: playTileMa2.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    MouseArea { id: playTileMa2; anchors.fill: parent; hoverEnabled: true; onClicked: Media.toggle() }
                }

                Rectangle {
                    width: (parent.width - 30) / 4; height: 84; radius: 18; color: Colors.color0
                    border.width: root.navCurrent === "prev" ? 2 : 0
                    border.color: Colors.foreground
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰒮"; color: Colors.color8; font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Prev"; color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
                    }
                    scale: prevTileMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    MouseArea { id: prevTileMa; anchors.fill: parent; hoverEnabled: true; onClicked: Media.prev() }
                }

                Rectangle {
                    width: (parent.width - 30) / 4; height: 84; radius: 18; color: Colors.color0
                    border.width: root.navCurrent === "next" ? 2 : 0
                    border.color: Colors.foreground
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰒭"; color: Colors.color8; font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Next"; color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
                    }
                    scale: skipTileMa2.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    MouseArea { id: skipTileMa2; anchors.fill: parent; hoverEnabled: true; onClicked: Media.next() }
                }

                // Placeholder 4th tile (spacer)
                Item { width: (parent.width - 30) / 4; height: 70 }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.color0 }

            // ── Volume slider ──────────────────────────────────────────────
            Column { width: parent.width; spacing: 6
                Item { width: parent.width; height: 18
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Text { text: Audio.muted ? "󰖁" : "󰕾"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Volume"; color: Colors.foreground; font.pixelSize: 17; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Audio.muted ? "MUTED" : Audio.volume + "%"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                }
                SliderRow {
                    width: parent.width
                    value: Audio.muted ? 0 : Audio.volume / 100
                    accent: Colors.foreground
                    onMoved: function(v) { Audio.setVolume(Math.round(v * 100)) }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -6; radius: 8
                        color: "transparent"
                        border.width: root.navCurrent === "volume" ? 2 : 0
                        border.color: Colors.foreground
                    }
                }
            }

            // ── Brightness slider ──────────────────────────────────────────
            Column { width: parent.width; spacing: 6
                Item { width: parent.width; height: 18
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Text { text: "󰃟"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Brightness"; color: Colors.foreground; font.pixelSize: 17; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Bright.percent + "%"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                }
                SliderRow {
                    width: parent.width
                    value: Bright.percent / 100
                    accent: Colors.foreground
                    onMoved: function(v) { Bright.setPercent(Math.round(v * 100)) }
                    Rectangle {
                        anchors.fill: parent; anchors.margins: -6; radius: 8
                        color: "transparent"
                        border.width: root.navCurrent === "brightness" ? 2 : 0
                        border.color: Colors.foreground
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.color0 }

            // ── WiFi info ──────────────────────────────────────────────────
            Rectangle {
                id: netCard
                width: parent.width; height: 64; radius: 14; color: Colors.color0

                Text {
                    id: netIcon
                    text: Network.icon; color: Network.connected ? Colors.foreground : Colors.color8
                    font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font"
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    width: 32
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Column {
                    anchors {
                        left: netIcon.right; leftMargin: 10
                        right: parent.right; rightMargin: 14
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Network.connected ? Network.ssid : "Not connected"
                        color: Network.connected ? Colors.foreground : Colors.color8
                        font.pixelSize: 17; font.bold: true; font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: {
                            if (!Network.connected) return "no network"
                            const ip = Network.ipAddr.length > 0 ? Network.ipAddr : "obtaining IP…"
                            return Network.strength.length > 0 ? ip + "  ·  " + Network.strength + "%" : ip
                        }
                        color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                    }
                }
            }

            // ── Battery bar (when present) ─────────────────────────────────
            Column {
                width: parent.width; spacing: 6; visible: Battery.present
                Item { width: parent.width; height: 18
                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Text { text: Battery.icon; color: Colors.foreground; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Battery"; color: Colors.foreground; font.pixelSize: 17; font.bold: true; font.family: "JetBrainsMono Nerd Font" }
                    }
                    Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: Battery.percent + "% · " + Battery.status; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font" }
                }
                Rectangle {
                    id: batBar2; width: parent.width; height: 7; radius: 4; color: Colors.color0
                    Rectangle {
                        width: Math.max(0, Math.min(batBar2.width, batBar2.width * Battery.percent / 100))
                        height: parent.height; radius: 3; color: Colors.foreground
                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Colors.color0 }

            // ── Media mini-card ────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 64; radius: 14; color: Colors.color0
                visible: Media.title.length > 0
                Row {
                    anchors { fill: parent; margins: 10 }
                    spacing: 10
                    Rectangle {
                        width: 44; height: 44; radius: 8; color: Colors.color0; anchors.verticalCenter: parent.verticalCenter
                        Image { anchors.fill: parent; source: Media.artUrl.length > 0 ? Media.artUrl : ""; fillMode: Image.PreserveAspectCrop; visible: Media.artUrl.length > 0 }
                        Text { anchors.centerIn: parent; visible: Media.artUrl.length === 0; text: "♪"; color: Colors.color8; font.pixelSize: 16 }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        width: parent.width - 34 - 10 - 80
                        Text { text: Media.title; color: Colors.foreground; font.pixelSize: 15; font.bold: true; font.family: "JetBrainsMono Nerd Font"; width: parent.width; elide: Text.ElideRight }
                        Text { text: Media.artist.length > 0 ? Media.artist : "Unknown"; color: Colors.color8; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; width: parent.width; elide: Text.ElideRight }
                    }
                    // Media controls — NO inline object array (avoids parser bug)
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Text {
                            text: "󰒮"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                            MouseArea { anchors.fill: parent; onClicked: Media.prev() }
                        }
                        Text {
                            text: Media.playing ? "󰏤" : "󰐊"; color: Colors.foreground; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                            MouseArea { anchors.fill: parent; onClicked: Media.toggle() }
                        }
                        Text {
                            text: "󰒭"; color: Colors.color8; font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                            MouseArea { anchors.fill: parent; onClicked: Media.next() }
                        }
                    }
                }
            }

            // ── Quick tiles row 3: Files | Sysinfo ────────────────────────────
            Row {
                width: parent.width; spacing: 12

                // Nemo files
                Rectangle {
                    width: (parent.width - 30) / 4; height: 84; radius: 18; color: Colors.color0
                    scale: filesMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰝰"; color: Colors.color8; font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Files"; color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
                    }
                    MouseArea { id: filesMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Quickshell.execDetached(["/run/current-system/sw/bin/nemo"]); root.dismiss() } }
                }

                // Sysinfo shortcut
                Rectangle {
                    width: (parent.width - 30) / 4; height: 84; radius: 18; color: Colors.color0
                    scale: sysMa.containsMouse ? 0.93 : 1.0
                    Behavior on scale { SpringAnimation { spring: 8; damping: 0.8 } }
                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰘚"; color: Colors.color8; font.pixelSize: 24; font.family: "JetBrainsMono Nerd Font" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Stats"; color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
                    }
                    MouseArea { id: sysMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Quickshell.execDetached(["quickshell", "ipc", "call", "island", "sysinfo"]); root.dismiss() } }
                }

                // Spacers (fill grid after Do Not Disturb removal)
                Item { width: (parent.width - 30) / 4; height: 84 }
                Item { width: (parent.width - 30) / 4; height: 84 }
            }


            Item { width: 1; height: 8 }
        }
    }
}
