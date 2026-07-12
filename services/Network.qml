pragma Singleton
import QtQuick
import Quickshell.Io

Item {
    id: root
    property string ssid:      ""
    property string ipAddr:    ""
    property string strength:  ""
    property bool   connected: false
    // Only ControlCenter reads this. nmcli scans are the heaviest command
    // in this codebase (dbus + wifi rescan) -- worth gating hardest.
    property bool   live: false

    readonly property string icon: {
        if (!connected) return "󰤭"
        const s = parseInt(strength)
        if (isNaN(s))  return "󰤫"
        if (s >= 75)   return "󰤨"
        if (s >= 50)   return "󰤥"
        if (s >= 25)   return "󰤢"
        return "󰤟"
    }

    Timer {
        interval: 10000; running: root.live; repeat: true; triggeredOnStart: true
        onTriggered: { statusPoll.running = true; ipPoll.running = true }
    }
    Process { id: statusPoll
        // nmcli -t escapes `:` in SSIDs as `\:` and `\` itself as `\\`.
        // Splitting raw on `:` mangles SSIDs that contain a colon, and the
        // signal field gets misaligned. awk handles the unescape via
        // gsub() before re-joining the (possibly-colon-containing) SSID
        // with a tab separator that we control and split on in QML. Field
        // 1 is "yes"/"no" (active flag); field 2 is SSID; field 3 is
        // signal strength.
        command: ["bash", "-c", "nmcli -t -f active,ssid,signal dev wifi | awk -F: -v OFS='\\t' '$1==\"yes\"{found=1; ssid=\"\"; for(i=2;i<NF;i++){ if(ssid!=\"\") ssid=ssid\":\"; ssid=ssid $i }; gsub(/\\\\\\\\/,\"\\\\\",ssid); gsub(/\\\\:/,\":\",ssid); print ssid,$NF} END{if(!found) print \"\",0}'"]
        stdout: SplitParser { onRead: d => {
            const parts = d.split("\t")
            root.ssid = (parts[0] || "").trim()
            root.strength = (parts[1] || "").trim()
            root.connected = root.ssid.length > 0
        } } }
    Process { id: ipPoll
        command: ["bash", "-c", "ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | head -1"]
        stdout: SplitParser { onRead: d => { root.ipAddr = d.trim() } } }
}
