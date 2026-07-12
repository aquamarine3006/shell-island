pragma ComponentBehavior: Bound
import QtQuick
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    Component.onCompleted: {
        PowerProfile.live = true
        forceActiveFocus()
        profileList.currentIndex = PowerProfile.profiles.indexOf(PowerProfile.current)
    }
    Component.onDestruction: PowerProfile.live = false

    Keys.onEscapePressed: function(ev) { root.dismiss(); ev.accepted = true }
    Keys.onReturnPressed: function(ev) {
        PowerProfile.setProfile(PowerProfile.profiles[profileList.currentIndex])
        ev.accepted = true
    }
    Keys.onUpPressed:   function(ev) { profileList.decrementCurrentIndex(); ev.accepted = true }
    Keys.onDownPressed: function(ev) { profileList.incrementCurrentIndex(); ev.accepted = true }

    Column {
        anchors { fill: parent; margins: 24 }
        spacing: 16

        Text {
            text: "POWER PROFILE"; color: Colors.color8; font.pixelSize: 17; font.bold: true
            font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: 3
        }

        ListView {
            id: profileList
            width: parent.width
            height: PowerProfile.profiles.length * 88
            model: PowerProfile.profiles
            currentIndex: PowerProfile.profiles.indexOf(PowerProfile.current)
            interactive: false; spacing: 10

            delegate: Rectangle {
                id: prow
                required property string modelData
                required property int    index
                width: profileList.width; height: 96; radius: 18

                readonly property bool isActive:   PowerProfile.current === prow.modelData
                readonly property bool isFocused:  profileList.currentIndex === prow.index
                readonly property string rowColor: PowerProfile.colors[prow.modelData] ?? Colors.foreground

                color: prow.isActive ? Colors.color1 : Colors.color0

                border.width: prow.isActive || prow.isFocused ? 1 : 0
                border.color: prow.isActive ? prow.rowColor : Colors.color0

                Behavior on color        { ColorAnimation  { duration: 120 } }
                Behavior on border.width { NumberAnimation { duration: 80  } }

                Text {
                    id: activeBadge
                    anchors { right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    text: prow.isActive ? "● active" : ""
                    color: prow.rowColor; font.pixelSize: 15; font.letterSpacing: 1
                    font.family: "JetBrainsMono Nerd Font"
                }

                Row {
                    anchors {
                        left: parent.left; leftMargin: 18
                        right: activeBadge.left; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 16

                    Text {
                        text: PowerProfile.icons[prow.modelData] ?? "?"
                        color: prow.isActive ? prow.rowColor : Colors.color8
                        font.pixelSize: 36; font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    Text {
                        width: parent.width - 36 - parent.spacing
                        elide: Text.ElideRight
                        text: PowerProfile.labels[prow.modelData] ?? prow.modelData
                        color: prow.isActive ? Colors.foreground : Colors.color6
                        font.pixelSize: 24; font.bold: prow.isActive
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onEntered: profileList.currentIndex = prow.index
                    onClicked: PowerProfile.setProfile(prow.modelData)
                }
            }
        }

    }
}
