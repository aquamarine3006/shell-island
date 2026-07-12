import QtQuick
import "../services"

FocusScope {
    id: root
    signal dismiss()

    focus: true
    // See Media.qml: polling only runs while a panel that displays it is
    // actually open. Loader-instantiated panels get a real onDestruction,
    // so this can't leak the poll running after the panel closes.
    Component.onCompleted:   { forceActiveFocus(); Media.live = true }
    Component.onDestruction: Media.live = false

    Keys.onEscapePressed: { root.dismiss(); event.accepted = true }
    Keys.onSpacePressed:  { Media.toggle();  event.accepted = true }
    Keys.onRightPressed:  { Media.next();    event.accepted = true }
    Keys.onLeftPressed:   { Media.prev();    event.accepted = true }

    function fmt(s: int): string {
        const m = Math.floor(s / 60)
        const sec = s % 60
        return m + ":" + (sec < 10 ? "0" + sec : sec)
    }

    Column {
        anchors { fill: parent; margins: 20 }
        spacing: 14

        Row {
            width: parent.width; spacing: 14

            Rectangle {
                width: 64; height: 64; radius: 10; color: Colors.color0
                clip: true
                Image {
                    anchors.fill: parent
                    source: Media.artUrl.startsWith("file://") ? Media.artUrl
                            : (Media.artUrl.length > 0 ? Media.artUrl : "")
                    fillMode: Image.PreserveAspectCrop
                    visible: Media.artUrl.length > 0
                }
                Text {
                    anchors.centerIn: parent
                    text: "󰎆"; font.pixelSize: 28; color: Colors.color8
                    font.family: "JetBrainsMono Nerd Font"
                    visible: Media.artUrl.length === 0
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 78; spacing: 4

                Text {
                    width: parent.width
                    text: Media.title.length > 0 ? Media.title : "Nothing playing"
                    color: Colors.foreground; font.pixelSize: 17; font.bold: true
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Media.artist.length > 0 ? Media.artist : "—"
                    color: Colors.color8; font.pixelSize: 12
                    font.family: "JetBrainsMono Nerd Font"
                    elide: Text.ElideRight
                }
                Text {
                    text: Media.status
                    color: Media.playing ? Colors.foreground : Colors.color8
                    font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font"
                }
            }
        }

        Column { width: parent.width; spacing: 4
            Item {
                width: parent.width; height: 18

                Rectangle {
                    id: progTrack
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    height: 5; radius: 3; color: Colors.color0

                    Rectangle {
                        width: Media.length > 0
                            ? Math.max(0, Math.min(progTrack.width, progTrack.width * Media.position / Media.length))
                            : 0
                        height: parent.height; radius: 3; color: Colors.foreground
                    }
                    Rectangle {
                        property real frac: Media.length > 0 ? Math.max(0, Math.min(1, Media.position / Media.length)) : 0
                        x: Math.max(0, Math.min(progTrack.width - width, progTrack.width * frac - width / 2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 14; height: 14; radius: 7; color: Colors.foreground
                        visible: Media.length > 0
                    }
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -6
                        onClicked: mouse => {
                            if (Media.length > 0)
                                Media.seekTo(Math.round(mouse.x / progTrack.width * Media.length))
                        }
                    }
                }
            }

            Row {
                width: parent.width
                Text { id: posTime; text: root.fmt(Media.position); color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
                Item { width: parent.width - posTime.implicitWidth - endTime.implicitWidth; height: 1 }
                Text { id: endTime; text: root.fmt(Media.length); color: Colors.color8; font.pixelSize: 17; font.family: "JetBrainsMono Nerd Font" }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter; spacing: 20

            MediaBtn { id: prev2; icon: "󰒮"; onClicked: Media.prev() }
            MediaBtn { id: play2; icon: Media.playing ? "󰏤" : "󰐊"; onClicked: Media.toggle(); large: true }
            MediaBtn { id: next2; icon: "󰒭"; onClicked: Media.next() }
        }

    }

    component MediaBtn: Rectangle {
        id: mbtn
        signal clicked()
        property string icon: ""
        property bool   large: false

        width: large ? 58 : 46; height: width; radius: width / 2
        color: mba.containsMouse ? Colors.color0 : "transparent"
        Behavior on color { ColorAnimation { duration: 100 } }
        scale: mba.containsMouse ? 1.08 : 1.0
        Behavior on scale { SpringAnimation { spring: 7; damping: 0.7 } }

        Text {
            anchors.centerIn: parent; text: mbtn.icon
            color: Colors.foreground; font.pixelSize: mbtn.large ? 22 : 17
            font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea { id: mba; anchors.fill: parent; hoverEnabled: true; onClicked: mbtn.clicked() }
    }
}
