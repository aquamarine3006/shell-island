pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import "../services"
import Quickshell.Io

FocusScope {
    id: root
    signal dismiss()

    // Scripts live in the same folder as wallpaper.sh
    readonly property string scriptDir: Quickshell.env("HOME") + "/scripts"

    ListModel { id: allScripts }
    property var filteredScripts: []

    function applyFilter(q: string): void {
        const out = []
        for (let i = 0; i < allScripts.count; i++) {
            const s = allScripts.get(i)
            if (q === "" || s.name.toLowerCase().includes(q.toLowerCase()))
                out.push({ name: s.name, path: s.path })
        }
        root.filteredScripts = out
        list.currentIndex = 0
    }

    function runScript(idx: int): void {
        const s = root.filteredScripts[idx]
        if (!s) return
        Quickshell.execDetached(["bash", s.path])
        root.dismiss()
    }

    Process {
        id: lister
        command: ["bash", "-c",
            "for f in \"" + root.scriptDir + "\"/*.sh; do [ -f \"$f\" ] && echo \"$f\"; done"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.trim()
                if (p.length === 0) return
                const parts = p.split("/")
                const name  = parts[parts.length - 1].replace(/\.sh$/, "")
                allScripts.append({ name: name, path: p })
            }
        }
        onExited: root.applyFilter("")
    }

    focus: true
    Component.onCompleted: { allScripts.clear(); lister.running = true; search.forceActiveFocus() }

    Column {
        anchors { fill: parent; margins: 16 }
        spacing: 10

        Row {
            width: parent.width; spacing: 8
            Text {
                text: "󰆍"; color: Colors.color8; font.pixelSize: 16
                font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "SCRIPTS"; color: Colors.color8; font.pixelSize: 17; font.bold: true
                font.family: "JetBrainsMono Nerd Font"; font.letterSpacing: 3
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Rectangle {
            width: parent.width; height: 50; radius: 12; color: Colors.color0
            border.width: search.activeFocus ? 1 : 0; border.color: Colors.color8
            Behavior on border.width { NumberAnimation { duration: 80 } }

            TextInput {
                id: search
                anchors { fill: parent; leftMargin: 14; rightMargin: 14; topMargin: 4; bottomMargin: 4 }
                color: Colors.foreground; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                selectionColor: Colors.color8; clip: true

                onTextChanged: root.applyFilter(text.trim())
                Keys.onEscapePressed: { root.dismiss(); event.accepted = true }
                Keys.onReturnPressed: { root.runScript(list.currentIndex); event.accepted = true }
                Keys.onDownPressed:   { list.incrementCurrentIndex(); event.accepted = true }
                Keys.onUpPressed:     { list.decrementCurrentIndex(); event.accepted = true }

                Text {
                    visible: search.text.length === 0
                    text: "Filter scripts…"; color: Colors.color8; font: search.font
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        ListView {
            id: list
            width: parent.width
            height: Math.min(root.filteredScripts.length * 58, 290)
            model: root.filteredScripts; currentIndex: 0; clip: true
            boundsBehavior: Flickable.StopAtBounds; spacing: 4; interactive: false

            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                width: list.width; height: 58; radius: 12
                color: (rowHover.containsMouse || list.currentIndex === row.index) ? Colors.color0 : "transparent"
                Behavior on color { ColorAnimation { duration: 80 } }

                Rectangle {
                    width: 3; height: 24; radius: 2
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    color: list.currentIndex === row.index ? Colors.color8 : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }
                Text {
                    anchors { left: parent.left; leftMargin: 24; verticalCenter: parent.verticalCenter }
                    text: "󰆍"; color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                }
                Text {
                    anchors { left: parent.left; leftMargin: 46; verticalCenter: parent.verticalCenter }
                    text: row.modelData.name; color: Colors.foreground
                    font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                }
                Rectangle {
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    width: 28; height: 16; radius: 4; color: Colors.color0
                    Text { anchors.centerIn: parent; text: ".sh"; color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
                }
                MouseArea {
                    id: rowHover; anchors.fill: parent; hoverEnabled: true
                    onEntered: list.currentIndex = row.index
                    onClicked: root.runScript(row.index)
                }
            }
        }

        Text {
            visible: root.filteredScripts.length === 0
            width: parent.width; text: "No scripts found in\n" + root.scriptDir
            color: Colors.color8; font.pixelSize: 15; font.family: "JetBrainsMono Nerd Font"
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
        }

    }
}
