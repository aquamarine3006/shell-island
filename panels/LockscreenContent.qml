import QtQuick
import Quickshell
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    Component.onCompleted: { forceActiveFocus(); pwInput.forceActiveFocus() }

    property string password:  ""
    property string authState: "idle"   // idle | checking | wrong | ok

    Timer {
        id: authProc
        interval: 400; running: false; repeat: false
        onTriggered: {
            if (root.password === "3004") {
                root.authState = "ok"
                root.dismiss()
            } else {
                root.authState = "wrong"
                wrongTimer.restart()
                shakeAnim.restart()
                root.password = ""
                pwInput.text  = ""
            }
        }
    }

    Timer { id: wrongTimer; interval: 1200; onTriggered: root.authState = "idle" }

    function tryAuth(): void {
        if (root.password.length === 0) return
        root.authState = "checking"
        authProc.start()
    }

    // ── Fade-in ───────────────────────────────────────────────────────────────
    opacity: 0
    NumberAnimation on opacity { to: 1; duration: 400; easing.type: Easing.OutCubic; running: true }

    // ── Background ───────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Colors.background }

    // ══════════════════════════════════════════════════════════════════════════
    // BOUNCING BALL PHYSICS
    // ══════════════════════════════════════════════════════════════════════════
    Item {
        id: physics
        anchors.fill: parent

        readonly property real gravity:    0.4
        readonly property real restitution: 0.72   // bounciness (0-1)
        readonly property real friction:    0.991  // horizontal drag per frame

        // ball state
        property real bx: parent.width  * 0.3
        property real by: parent.height * 0.5
        property real vx: 3.8
        property real vy: -5.0
        property real radius: 18

        // trail: last N positions
        property var trail: []
        readonly property int trailLen: 18

        // second smaller ball
        property real b2x: parent.width  * 0.65
        property real b2y: parent.height * 0.3
        property real v2x: -2.6
        property real v2y: 3.1
        property real r2: 11

        property var trail2: []
        readonly property int trail2Len: 12

        Timer {
            interval: 16; running: true; repeat: true
            onTriggered: {
                // ── ball 1 ────────────────────────────────────────────────
                physics.vy += physics.gravity
                physics.vx *= physics.friction
                physics.bx += physics.vx
                physics.by += physics.vy

                // floor
                if (physics.by + physics.radius >= physics.height) {
                    physics.by = physics.height - physics.radius
                    physics.vy = -Math.abs(physics.vy) * physics.restitution
                    physics.vx *= 0.92
                }
                // ceiling
                if (physics.by - physics.radius <= 0) {
                    physics.by = physics.radius
                    physics.vy = Math.abs(physics.vy) * physics.restitution
                }
                // walls
                if (physics.bx + physics.radius >= physics.width) {
                    physics.bx = physics.width - physics.radius
                    physics.vx = -Math.abs(physics.vx) * physics.restitution
                }
                if (physics.bx - physics.radius <= 0) {
                    physics.bx = physics.radius
                    physics.vx = Math.abs(physics.vx) * physics.restitution
                }

                // energy injection — kick ball if it gets too slow
                var speed1 = Math.sqrt(physics.vx * physics.vx + physics.vy * physics.vy)
                if (speed1 < 4.0) {
                    physics.vx += (Math.random() - 0.5) * 6
                    physics.vy  = -(3.5 + Math.random() * 4)
                }

                // trail
                var t = physics.trail.concat([{ x: physics.bx, y: physics.by }])
                if (t.length > physics.trailLen) t = t.slice(t.length - physics.trailLen)
                physics.trail = t

                // ── ball 2 ────────────────────────────────────────────────
                physics.v2y += physics.gravity * 0.85
                physics.v2x *= physics.friction
                physics.b2x += physics.v2x
                physics.b2y += physics.v2y

                if (physics.b2y + physics.r2 >= physics.height) {
                    physics.b2y = physics.height - physics.r2
                    physics.v2y = -Math.abs(physics.v2y) * (physics.restitution - 0.05)
                    physics.v2x *= 0.9
                }
                if (physics.b2y - physics.r2 <= 0) {
                    physics.b2y = physics.r2
                    physics.v2y = Math.abs(physics.v2y) * physics.restitution
                }
                if (physics.b2x + physics.r2 >= physics.width) {
                    physics.b2x = physics.width - physics.r2
                    physics.v2x = -Math.abs(physics.v2x) * physics.restitution
                }
                if (physics.b2x - physics.r2 <= 0) {
                    physics.b2x = physics.r2
                    physics.v2x = Math.abs(physics.v2x) * physics.restitution
                }

                // energy injection for ball 2
                var speed2 = Math.sqrt(physics.v2x * physics.v2x + physics.v2y * physics.v2y)
                if (speed2 < 3.0) {
                    physics.v2x += (Math.random() - 0.5) * 5
                    physics.v2y  = -(2.5 + Math.random() * 3)
                }

                var t2 = physics.trail2.concat([{ x: physics.b2x, y: physics.b2y }])
                if (t2.length > physics.trail2Len) t2 = t2.slice(t2.length - physics.trail2Len)
                physics.trail2 = t2
            }
        }

        // ── Trail 1 ───────────────────────────────────────────────────────────
        Repeater {
            model: physics.trailLen
            Rectangle {
                required property int index
                readonly property real frac: (index + 1) / physics.trailLen
                readonly property var  pos:  physics.trail[index] ?? ({ x: -99, y: -99 })
                x: pos.x - width / 2
                y: pos.y - height / 2
                width:  physics.radius * 2 * frac * 0.9
                height: width; radius: width / 2
                opacity: frac * 0.35
                color: Colors.foreground
            }
        }

        // ── Ball 1 ────────────────────────────────────────────────────────────
        Rectangle {
            x: physics.bx - physics.radius
            y: physics.by - physics.radius
            width: physics.radius * 2; height: physics.radius * 2
            radius: physics.radius
            color: Colors.foreground
            // squish on floor impact
            readonly property real squish: (physics.by + physics.radius >= physics.height - 2) ? 0.7 : 1.0
            transform: Scale {
                xScale: 1 + (1 - ball1.squish) * 0.5
                yScale: ball1.squish
                origin.x: physics.radius; origin.y: physics.radius * 2
            }
            id: ball1
        }

        // ── Trail 2 ───────────────────────────────────────────────────────────
        Repeater {
            model: physics.trail2Len
            Rectangle {
                required property int index
                readonly property real frac: (index + 1) / physics.trail2Len
                readonly property var  pos:  physics.trail2[index] ?? ({ x: -99, y: -99 })
                x: pos.x - width / 2
                y: pos.y - height / 2
                width:  physics.r2 * 2 * frac * 0.9
                height: width; radius: width / 2
                opacity: frac * 0.25
                color: Colors.color6
            }
        }

        // ── Ball 2 ────────────────────────────────────────────────────────────
        Rectangle {
            x: physics.b2x - physics.r2
            y: physics.b2y - physics.r2
            width: physics.r2 * 2; height: physics.r2 * 2
            radius: physics.r2
            color: Colors.color8
        }

        // ── Floor shadow (shows ball is near ground) ──────────────────────────
        Rectangle {
            readonly property real dist: (physics.height - physics.by - physics.radius) / physics.height
            x: physics.bx - shadowW / 2
            y: physics.height - 6
            readonly property real shadowW: physics.radius * 3 * (1 - dist * 0.8)
            width: shadowW; height: 4; radius: 2
            color: Colors.foreground
            opacity: (1 - dist) * 0.18
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // CENTER UI
    // ══════════════════════════════════════════════════════════════════════════
    Column {
        anchors.centerIn: parent
        spacing: 32

        // ── Clock ─────────────────────────────────────────────────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                property string t: Qt.formatTime(new Date(), "hh:mm")
                text: t; color: Colors.foreground
                font.pixelSize: 130; font.bold: true
                font.family: "JetBrainsMono Nerd Font"
                Timer { running: true; repeat: true; interval: 1000
                        onTriggered: parent.t = Qt.formatTime(new Date(), "hh:mm") }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                property string d: Qt.formatDate(new Date(), "dddd, MMMM d")
                text: d; color: Colors.color8; font.pixelSize: 20
                font.family: "JetBrainsMono Nerd Font"
                Timer { running: true; repeat: true; interval: 60000
                        onTriggered: parent.d = Qt.formatDate(new Date(), "dddd, MMMM d") }
            }
        }

        // ── Password field ────────────────────────────────────────────────────
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 280; height: 52

            // shake animation on wrong password
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: pwBox; property: "x"; to: pwBox.baseX + 10; duration: 50 }
                NumberAnimation { target: pwBox; property: "x"; to: pwBox.baseX - 10; duration: 50 }
                NumberAnimation { target: pwBox; property: "x"; to: pwBox.baseX + 6;  duration: 40 }
                NumberAnimation { target: pwBox; property: "x"; to: pwBox.baseX - 6;  duration: 40 }
                NumberAnimation { target: pwBox; property: "x"; to: pwBox.baseX;      duration: 30 }
            }

            Rectangle {
                id: pwBox
                readonly property real baseX: 0
                x: baseX; y: 0
                width: parent.width; height: parent.height
                radius: 14
                color: root.authState === "wrong"    ? Colors.color1
                     : root.authState === "checking"  ? Colors.color0
                     : Colors.color0
                border.width: 1
                border.color: root.authState === "wrong"    ? Colors.color1
                            : root.authState === "checking"  ? Colors.color8
                            : pwInput.activeFocus             ? Colors.color8
                            : Colors.color0
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on color        { ColorAnimation { duration: 150 } }

                // dots showing typed chars
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: root.password.length > 0 && root.authState !== "checking"
                    Repeater {
                        model: Math.min(root.password.length, 20)
                        Rectangle {
                            width: 7; height: 7; radius: 4
                            color: root.authState === "wrong" ? Colors.color1 : Colors.foreground
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                    }
                }

                // placeholder
                Text {
                    anchors.centerIn: parent
                    visible: root.password.length === 0 && root.authState === "idle"
                    text: "enter password"
                    color: Colors.color8; font.pixelSize: 15
                    font.family: "JetBrainsMono Nerd Font"
                }

                // checking spinner dots
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: root.authState === "checking"
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 6; height: 6; radius: 3; color: Colors.color8
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite; running: root.authState === "checking"
                                PauseAnimation   { duration: index * 180 }
                                NumberAnimation  { to: 1.0; duration: 220 }
                                NumberAnimation  { to: 0.2; duration: 220 }
                                PauseAnimation   { duration: (2 - index) * 180 }
                            }
                        }
                    }
                }

                MouseArea { anchors.fill: parent; onClicked: pwInput.forceActiveFocus() }
            }

            // invisible input
            TextInput {
                id: pwInput
                width: 0; height: 0; echoMode: TextInput.Password
                onTextChanged: { root.password = text }
                Keys.onReturnPressed: function(ev) { root.tryAuth(); ev.accepted = true }
                Keys.onEscapePressed: function(ev) {
                    root.password = ""; text = ""; root.dismiss(); ev.accepted = true
                }
            }
        }

        // ── wrong password label ──────────────────────────────────────────────
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.authState === "wrong" ? "incorrect password" : ""
            color: Colors.color1; font.pixelSize: 13
            font.family: "JetBrainsMono Nerd Font"
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        // ── Battery ───────────────────────────────────────────────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10; visible: Battery.present

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Text {
                    visible: Battery.charging
                    text: "󱐋"; color: Colors.color2; font.pixelSize: 22
                    font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: Battery.charging; loops: Animation.Infinite
                        NumberAnimation { to: 0.2; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: Battery.percent + "%"
                    color: Battery.critical ? Colors.color1 : Battery.charging ? Colors.color2 : Colors.color8
                    font.pixelSize: 18; font.family: "JetBrainsMono Nerd Font"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 400 } }
                    SequentialAnimation on opacity {
                        running: Battery.critical; loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
            }

            Rectangle {
                id: batTrack
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160; height: 3; radius: 2; color: Colors.color0
                Rectangle {
                    id: batFill
                    width: Math.max(0, Math.min(batTrack.width, batTrack.width * Battery.percent / 100))
                    height: parent.height; radius: 2
                    color: Battery.critical ? Colors.color1 : Battery.charging ? Colors.color2 : Colors.color8
                    Behavior on width { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 400 } }
                }
                Rectangle {
                    visible: Battery.charging
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0; width: batFill.width; height: 8; radius: 4; color: "transparent"
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width; height: 6; radius: 3; color: Colors.color2
                        SequentialAnimation on opacity {
                            running: Battery.charging; loops: Animation.Infinite
                            NumberAnimation { to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
        }
    }
}
