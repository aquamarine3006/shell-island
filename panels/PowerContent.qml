import QtQuick
import Quickshell
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    Component.onCompleted: shutdownBtn.forceActiveFocus()

    Keys.onEscapePressed: function(event) { root.dismiss(); event.accepted = true }

    Column {
        anchors.centerIn: parent; spacing: 16

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "POWER"; color: Colors.color8; font.pixelSize: 17; font.bold: true
            font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: 3
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 12

            PowerBtn {
                id: shutdownBtn; label: "Shutdown"
                KeyNavigation.right: rebootBtn; KeyNavigation.left:  rebootBtn
                onActivated: { Quickshell.execDetached(["systemctl", "poweroff"]); root.dismiss() }
            }

            PowerBtn {
                id: rebootBtn; label: "Reboot"
                KeyNavigation.left:  shutdownBtn; KeyNavigation.right: shutdownBtn
                onActivated: { Quickshell.execDetached(["systemctl", "reboot"]); root.dismiss() }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "←→ select   Enter confirm   Esc cancel"
            color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
        }
    }

    component PowerBtn: Rectangle {
        id: pbtn
        signal activated()
        property string label: ""

        width: 140; height: 72; radius: 14
        color: (ma.containsMouse || pbtn.activeFocus) ? Colors.color0 : Colors.color0
        border.width: pbtn.activeFocus ? 1 : 0; border.color: Colors.foreground
        activeFocusOnTab: true

        Behavior on color        { ColorAnimation  { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on border.width { NumberAnimation { duration: 100 } }
        scale: (ma.containsMouse || pbtn.activeFocus) ? 1.04 : 1.0
        transformOrigin: Item.Center
        Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.75 } }

        Text {
            anchors.centerIn: parent; text: pbtn.label; color: Colors.foreground
            font.pixelSize: 17; font.bold: true; font.family: "JetBrainsMono Nerd Font"
        }

        Keys.onReturnPressed: function(event) { pbtn.activated(); event.accepted = true }
        Keys.onSpacePressed:  function(event) { pbtn.activated(); event.accepted = true }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            onEntered: pbtn.forceActiveFocus()
            onClicked: pbtn.activated()
        }
    }
}
