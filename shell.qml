import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "services"

ShellRoot {
    id: root

    property bool   osdVisible: false
    property string osdType:    ""

    Timer { id: osdTimer; interval: 2000; onTriggered: root.osdVisible = false }

    function showOsd(type: string): void {
        root.osdType    = type
        root.osdVisible = true
        osdTimer.restart()
    }

    property string panel: ""

    // First-login fix for the same wlr_seat_keyboard desync Pill.qml's
    // focuswindow dispatch targets (see Pill.qml's HyprlandFocusGrab /
    // preOpenWindowAddress comments) -- at login nothing has
    // requested/released a keyboard grab yet, so that per-close fix never
    // runs, and the first window opened can look focused without actually
    // receiving keystrokes until something re-drives Hyprland's focus path.
    //
    // Uses the same real fix as Pill.qml: an explicit
    // `hyprctl dispatch focuswindow address:...` targeting whatever window
    // Hyprland already considers active, once one exists -- NOT a
    // workspace bounce. A workspace round-trip at login is what used to
    // cause a visible flicker/jump the moment you logged in, on top of
    // being the wrong mechanism for the same reasons described in
    // Pill.qml.
    //
    // NOTE: the per-panel-close refocus lives ONLY in Pill.qml now (its
    // onPanelChanged fires for every path that sets panel back to "",
    // lockscreen included). This file previously ALSO dispatched its own
    // workspace kick whenever leaving the lockscreen, which raced Pill's
    // kick and was the actual cause of "focus, but still can't type until
    // switching workspace and back *again*". There must be exactly one
    // place doing this per transition; this timer only covers the
    // login-only case where there's no panel transition to hook.
    //
    // Instead of a blind fixed delay (which either fires before
    // Hyprland/QS are actually ready on a slow login, or wastes time
    // waiting on a fast one), this polls for Hyprland's IPC data actually
    // being populated (workspaces.length > 0 is a reliable "compositor is
    // up and QS's Hyprland connection is live" signal) and gives up after
    // a few seconds so it always fires exactly once either way.
    property int _loginPollAttempts: 0
    Timer {
        id: loginReadyPoll
        interval: 100; running: true; repeat: true
        onTriggered: {
            root._loginPollAttempts += 1
            let ready = false
            try { ready = Hyprland.workspaces.values.length > 0 } catch (e) { ready = false }
            if (ready || root._loginPollAttempts >= 50) {
                loginReadyPoll.stop()
                loginRefocus.start()
            }
        }
    }
    // Small extra delay after "workspaces populated" before reading
    // activeWindow: workspace data lands slightly before the client's own
    // window/activeWindow data does, on a fresh connection.
    Timer {
        id: loginRefocus
        interval: 150
        onTriggered: {
            const addr = Hyprland.activeWindow?.address ?? ""
            if (addr !== "") Hyprland.dispatch("focuswindow address:" + addr)
        }
    }

    function toggle(name: string): void {
        root.panel = (root.panel === name) ? "" : name
        if (root.panel !== "") root.osdVisible = false
    }

    IpcHandler {
        target: "island"
        function launcher():       void { root.toggle("launcher")       }
        function scriptlauncher(): void { root.toggle("scriptlauncher") }
        function controlcenter():  void { root.toggle("controlcenter")  }
        function mixer():          void { root.toggle("controlcenter")  }
        function sysinfo():        void { root.toggle("sysinfo")        }
        function power():          void { root.toggle("power")          }
        function wallpaper():      void { root.toggle("wallpaper")      }
        function media():          void { root.toggle("media")          }
        function powerprofile():   void { root.toggle("powerprofile")   }
        function visualizer():     void { root.toggle("visualizer")     }
        function lockscreen():     void { root.toggle("lockscreen")     }
        function close():          void { root.panel = ""               }

        function volUp():   void { Audio.setVolume(Audio.volume + 5);     root.showOsd("volume")     }
        function volDown(): void { Audio.setVolume(Audio.volume - 5);     root.showOsd("volume")     }
        function briUp():   void { Bright.setPercent(Bright.percent + 5); root.showOsd("brightness") }
        function briDown(): void { Bright.setPercent(Bright.percent - 5); root.showOsd("brightness") }

        function mediaToggle(): void { Media.toggle() }
        function mediaNext():   void { Media.next()   }
        function mediaPrev():   void { Media.prev()   }
    }

    // Single surface again -- see Pill.qml's header comment for why (exact
    // github animation match was the priority; the previous split-surface
    // Loader/displayPanel/panelClosing plumbing that lived here is gone).
    Pill {
        screen:     Quickshell.screens[0]
        panel:      root.panel
        osdVisible: root.osdVisible && root.panel === ""
        osdType:    root.osdType
        onDismiss:  root.panel = ""
    }
}
