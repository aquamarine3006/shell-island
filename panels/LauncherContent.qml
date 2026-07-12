pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../services"

FocusScope {
    id: root
    signal dismiss()

    readonly property var allApps: [
        { name: "Firefox",  exec: "firefox"  },
        { name: "Kitty",    exec: "kitty"    },
        { name: "Nemo", exec: "nemo" }
    ]
    property var filteredApps: allApps

    function launch(idx: int): void {
        const app = filteredApps[idx]
        if (!app) return
        Quickshell.execDetached(["bash", "-c", app.exec + " &"])
        root.dismiss()
    }

    focus: true
    Component.onCompleted: search.forceActiveFocus()

    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 10

        Rectangle {
            width: parent.width; height: 50; radius: 12; color: Colors.color0
            border.width: search.activeFocus ? 1 : 0; border.color: Colors.color8
            Behavior on border.width { NumberAnimation { duration: 80 } }

            TextInput {
                id: search
                anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 4; bottomMargin: 4 }
                color: Colors.foreground; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                selectionColor: Colors.color8; clip: true

                onTextChanged: {
                    const q = text.trim().toLowerCase()
                    root.filteredApps = q === "" ? root.allApps : root.allApps.filter(a => a.name.toLowerCase().includes(q))
                    list.currentIndex = 0
                }

                Keys.onEscapePressed: { root.dismiss(); event.accepted = true }
                Keys.onReturnPressed: { root.launch(list.currentIndex); event.accepted = true }
                Keys.onDownPressed:   { list.incrementCurrentIndex(); event.accepted = true }
                Keys.onUpPressed:     { list.decrementCurrentIndex(); event.accepted = true }

                Text {
                    visible: search.text.length === 0
                    text: "Search apps…"; color: Colors.color8; font: search.font
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(root.filteredApps.length * 58, 230)
            model: root.filteredApps; currentIndex: 0; clip: true
            boundsBehavior: Flickable.StopAtBounds; spacing: 4; interactive: false

            delegate: Rectangle {
                id: row
                required property var  modelData
                required property int  index
                width: list.width; height: 58; radius: 12
                color: (rowHover.containsMouse || list.currentIndex === row.index) ? Colors.color0 : "transparent"
                Behavior on color { ColorAnimation { duration: 80 } }

                Rectangle {
                    width: 3; height: 24; radius: 2
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    color: list.currentIndex === row.index ? Colors.foreground : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Text {
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text: row.modelData.name; color: Colors.foreground; font.pixelSize: 15; font.family: "JetBrainsMono Nerd Font"
                }

                MouseArea {
                    id: rowHover; anchors.fill: parent; hoverEnabled: true
                    onEntered: list.currentIndex = row.index
                    onClicked: root.launch(row.index)
                }
            }
        }

    }
}
