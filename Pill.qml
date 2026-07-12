pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "panels"
import "services"

// Single surface (per explicit request: exact animation match with
// github.com/aquamarine3006/nixos-dots takes priority). This WAS split into
// Pill.qml + FocusPanel.qml to work around Hyprland hyprwm/Hyprland#8293
// (mutating WlrKeyboardFocus on an already-mapped layer surface doesn't run
// Hyprland's refocus path, so focus/keyboard input can break on close). A
// single surface reintroduces that risk, so on close this explicitly hands
// focus back to whichever window was active before the panel opened via
// `hyprctl dispatch focuswindow address:...` (see the HyprlandFocusGrab /
// preOpenWindowAddress / onPanelChanged block below) -- that dispatch goes
// through Hyprland's real focus-and-seat-sync path, so it doesn't need a
// workspace round-trip as a side-effect trigger. The same first-login
// symptom (no window focused right after Hyprland starts) is handled
// separately in shell.qml.
PanelWindow {
    id: root
    required property var screen

    property string panel:      ""
    property bool   osdVisible: false
    property string osdType:    ""

    signal dismiss()

    anchors { top: true; left: true; right: true }
    implicitHeight: screen?.height ?? 1080
    color: "transparent"
    WlrLayershell.layer:         root.panel === "lockscreen" ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.namespace:     "quickshell:pill"
    // MUST stay static. hyprwm/Hyprland#8293 is specifically triggered by
    // mutating WlrKeyboardFocus on an already-mapped layer surface -- an
    // earlier revision of this fix made keyboardFocus flip
    // None<->OnDemand on every panel open/close, which does exactly that
    // on every single toggle instead of never. Keeping it permanently
    // OnDemand plus the HyprlandFocusGrab (which only requests/releases
    // the grab, and does NOT mutate this property) is the correct shape;
    // the explicit focuswindow dispatch below is what actually resyncs
    // focus once the grab clears.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: root.panel === "lockscreen" ? -1 : 56

    readonly property var dimMap: ({
        "":               { w: 260, h: 48,  r: 24 },
        "osd":            { w: 340, h: 48,  r: 24 },
        "launcher":       { w: 600, h: 420, r: 28 },
        "scriptlauncher": { w: 600, h: 420, r: 28 },
        "controlcenter":  { w: 600, h: 860, r: 28 },
        "sysinfo":        { w: 540, h: 460, r: 28 },
        "power":          { w: 360, h: 200, r: 28 },
        "wallpaper":      { w: 680, h: 590, r: 28 },
        "media":          { w: 480, h: 280, r: 28 },
        "powerprofile":   { w: 540, h: 460, r: 28 },
        "visualizer":     { w: 520, h: 220, r: 28 },
        "lockscreen":     { w: screen?.width ?? 1920, h: screen?.height ?? 1080, r: 0 }
    })

    readonly property string effectiveState:
        (panel === "" && osdVisible) ? "osd" : panel

    readonly property var dim: dimMap[effectiveState] ?? dimMap[""]

    // Fix for the Hyprland hyprwm/Hyprland#8293-shaped symptom ("panel
    // closes, no window ends up focused, typing needs a manual workspace
    // switch to start working again"). The PREVIOUS fix bounced
    // `workspace +1` then `workspace -1` to force Hyprland to recompute
    // focus as a side effect -- that's a hack riding an unrelated code
    // path, not a real fix, and it's why the desktop visibly flickers /
    // steals a workspace switch every time the panel closes.
    //
    // Real fix: capture the window that actually had focus right before
    // the panel grabbed it, and explicitly hand focus back to THAT window
    // with `hyprctl dispatch focuswindow address:<addr>` once the grab
    // clears. `focuswindow` drives Hyprland's real
    // activate-window-and-sync-seat-focus path (the same path Alt-Tab
    // uses), so it doesn't leave wlr_seat_keyboard out of sync the way
    // toggling WlrKeyboardFocus on a permanently-mapped layer surface does.
    // No workspace switch, no flicker, no side effects on unrelated
    // workspace state.
    property string preOpenWindowAddress: ""

    HyprlandFocusGrab {
        windows: [root]
        active:  root.panel !== ""
        onActiveChanged: {
            // Capture BEFORE the grab takes focus away: at the instant we
            // go active, Hyprland.activeWindow is still whatever the user
            // was actually working in.
            if (active) root.preOpenWindowAddress = Hyprland.activeWindow?.address ?? ""
        }
        onCleared: root.dismiss()
    }

    // `panel` is set to "" from three independent paths -- shell.qml's IPC
    // `close()` handler (keybind toggle), root.dismiss() (Escape / tile
    // select), and the grab clearing itself (click outside the surface).
    // All three need the refocus, so it's wired on `onPanelChanged` rather
    // than only `HyprlandFocusGrab.onCleared`.
    onPanelChanged: {
        if (root.panel === "" && root.preOpenWindowAddress !== "") {
            const addr = root.preOpenWindowAddress
            root.preOpenWindowAddress = ""
            Qt.callLater(() => Hyprland.dispatch("focuswindow address:" + addr))
        }
    }

    // Soft drop shadow: a dimmed duplicate of the pill's own shape, offset
    // slightly down and drawn UNDERNEATH it (declared before `pill`, so it
    // paints first). Cheaper and dependency-free compared to a real blur --
    // no Qt5Compat/GraphicalEffects import needed -- and at this shadow's
    // small size/opacity a soft blur would be indistinguishable from this
    // single offset layer anyway. Tracks `pill`'s animated
    // width/height/radius directly so it never lags a step behind during
    // the spring resize.
    Rectangle {
        id: pillShadow
        anchors.top:              parent.top
        anchors.topMargin:        (root.panel === "lockscreen" ? 0 : 12) + 4
        anchors.horizontalCenter: parent.horizontalCenter
        width:  pill.width
        height: pill.height
        radius: pill.radius
        color:  "#000000"
        opacity: root.panel === "lockscreen" ? 0.0 : pill.opacity * 0.32
    }

    Rectangle {
        id: pill
        anchors.top:              parent.top
        anchors.topMargin:        root.panel === "lockscreen" ? 0 : 12
        anchors.horizontalCenter: parent.horizontalCenter
        clip: true

        // Flat fill, no gradient -- matches the rest of the panel system.
        color: Colors.background
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.09)

        width:  root.dim.w
        height: root.dim.h
        radius: root.dim.r

        Behavior on width  { SpringAnimation { spring: 5.5; damping: 0.78; mass: 1.0 } }
        Behavior on height { SpringAnimation { spring: 5.5; damping: 0.78; mass: 1.0 } }
        Behavior on radius { SpringAnimation { spring: 5.5; damping: 0.78; mass: 1.0 } }

        readonly property bool isFullscreen:
            Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.hasFullscreen : false
        opacity: isFullscreen ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // ── Clock + Battery ───────────────────────────────────────────────
        Item {
            anchors.fill: parent
            opacity: (root.effectiveState === "") ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.InCubic } }

            Text {
                anchors.centerIn: parent
                color: Colors.foreground; font.pixelSize: 24; font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                property string t: Qt.formatTime(new Date(), "hh:mm")
                text: t
                Timer { running: true; repeat: true; interval: 1000
                        onTriggered: parent.t = Qt.formatTime(new Date(), "hh:mm") }
            }

            Text {
                visible: Battery.present
                anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.percent + "%"
                color: Battery.critical ? Colors.color1 : Colors.color8
                font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
                Behavior on color { ColorAnimation { duration: 400 } }
                SequentialAnimation on opacity {
                    running: Battery.critical; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }

        // ── OSD ───────────────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            opacity: (root.effectiveState === "osd") ? 1.0 : 0.0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Row {
                anchors.centerIn: parent; spacing: 12
                Text {
                    text: root.osdType === "volume" ? (Audio.muted ? "󰖁" : "󰕾") : "󰃟"
                    color: Colors.foreground; font.pixelSize: 24; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    id: osdTrack; width: 200; height: 5; radius: 3; color: Colors.color0
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle {
                        id: osdFill
                        width: Math.max(0, Math.min(osdTrack.width, osdTrack.width * (
                            root.osdType === "volume" ? (Audio.muted ? 0 : Audio.volume / 100) : (Bright.percent / 100)
                        )))
                        height: parent.height; radius: 2; color: Colors.color4
                    }
                    Rectangle {
                        x: Math.max(0, Math.min(osdTrack.width - width, osdFill.width - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10; height: 10; radius: 5; color: Colors.foreground
                    }
                }
                Text {
                    text: root.osdType === "volume" ? (Audio.muted ? "muted" : Audio.volume + "%") : (Bright.percent + "%")
                    color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // ── Launcher ──────────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "launcher"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: LauncherContent { onDismiss: root.dismiss() }
        }

        // ── Script Launcher ───────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "scriptlauncher"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: ScriptLauncherContent { onDismiss: root.dismiss() }
        }

        // ── Control Center ────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "controlcenter"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: ControlCenterContent { onDismiss: root.dismiss() }
        }

        // ── Sys Info ──────────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "sysinfo"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: SysInfoContent { onDismiss: root.dismiss() }
        }

        // ── Power ─────────────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "power"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: PowerContent { onDismiss: root.dismiss() }
        }

        // ── Wallpaper ─────────────────────────────────────────────────────
        // `active` stays permanently true here (unlike every other panel's
        // Loader) -- this is deliberate, not copy-paste drift. The
        // WallpaperIndex singleton already keeps the wallpaper LIST alive
        // across opens (see services/WallpaperIndex.qml), but this Loader
        // was still destroying and recreating the GridView + its Image
        // delegates on every open, because `active` flipped false->true
        // each time. Recreating dozens of `asynchronous: true` Image
        // delegates means at least one visible frame where each tile is
        // still its background-color placeholder before the (even
        // cache-hit) pixmap re-binds -- that's the flicker. Keeping the
        // Loader permanently active means the delegates are built ONCE and
        // just fade in/out afterwards, so there's nothing left to
        // re-decode or re-bind on open.
        Loader {
            anchors.fill: parent; active: true
            visible: root.panel === "wallpaper"
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: WallpaperContent {
                onDismiss: root.dismiss()
                panelVisible: root.panel === "wallpaper"
            }
        }

        // ── Media ─────────────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "media"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: MediaContent { onDismiss: root.dismiss() }
        }

        // ── Power Profile ─────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "powerprofile"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: PowerProfileContent { onDismiss: root.dismiss() }
        }

        // ── Visualizer ────────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "visualizer"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: VisualizerContent { onDismiss: root.dismiss() }
        }

        // ── Lockscreen ────────────────────────────────────────────────────
        Loader {
            anchors.fill: parent; active: root.panel === "lockscreen"
            opacity: active ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            sourceComponent: LockscreenContent { onDismiss: root.dismiss() }
        }
    }

    Region { id: pillMask; item: pill }
    mask: pillMask

    // Each service's background poll only runs while something on screen
    // actually reads it -- see the `live` property comment in each
    // services/*.qml singleton for why. User-initiated changes (slider
    // drag, key-driven volume/brightness) already update state optimistically
    // so nothing goes stale while polling is off; this only affects catching
    // *external* changes, which is only worth doing while visible anyway.
    Binding { target: Bright;       property: "live"; value: root.panel === "controlcenter" || (root.effectiveState === "osd" && root.osdType === "brightness") }
    Binding { target: Audio;        property: "live"; value: root.panel === "controlcenter" || (root.effectiveState === "osd" && root.osdType === "volume") }
    Binding { target: SysStats;     property: "live"; value: root.panel === "sysinfo" }
    Binding { target: PowerProfile; property: "live"; value: root.panel === "controlcenter" || root.panel === "powerprofile" }
    Binding { target: Network;      property: "live"; value: root.panel === "controlcenter" }
}
