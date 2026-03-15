import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string layout: "??"

    tooltipText: root.layout
    tooltipDirection: BarService.getTooltipDirection(screen?.name)
    baseSize: Style.getCapsuleHeightForScreen(screen?.name)
    applyUiScale: false
    customRadius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth
    colorFg: Color.mOnSurface

    MouseArea {
        id: hoverTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButton
        cursorShape: Qt.ArrowCursor
    }

    Text {
        anchors.centerIn: parent
        text: root.layout
        color: root.colorFg
        font.bold: true
        font.pixelSize: Math.round(root.baseSize * 0.45)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    /* === Process для Niri === */
    Process {
        id: niriProc
        stdout: StdioCollector {}
        onExited: (code) => {
            if (code !== 0 || !niriProc.stdout.text) return
            try {
                const data = JSON.parse(niriProc.stdout.text)
                root._niriNames = data.names || []
                const idx = data.current_idx ?? 0
                root.layout = shortName(root._niriNames[idx])
            } catch (e) { console.log("niri parse error:", e) }
        }
    }

    /* === Process для Hyprland === */
    Process {
        id: hyprProc
        stdout: StdioCollector {}
        onExited: (code) => {
            if (code !== 0 || !hyprProc.stdout.text) return
            try {
                const data = JSON.parse(hyprProc.stdout.text)
                const keyboards = data.keyboards || []
                let active = ""
                for (let kb of keyboards) {
                    if (kb.active_keymap) { active = kb.active_keymap; break }
                    if (kb.active && !active) active = kb.active
                }
                if (active) root.layout = shortName(active)
            } catch (e) { console.log("hyprctl parse error:", e) }
        }
    }

    Timer {
        id: pollTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateLayout()
    }

    property var _niriNames: null

    function shortName(full) {
        if (!full) return "??"
        const l = full.toLowerCase()
        if (l.includes("ru") || l.includes("russian")) return "ru"
        if (l.includes("us") || l.includes("english")) return "en"
        if (l.includes("fr") || l.includes("french")) return "fr"
        if (l.includes("de") || l.includes("german")) return "de"
        if (l.includes("es") || l.includes("spanish")) return "es"
        return full.slice(0, 2).toLowerCase()
    }

    function updateLayout() {
        // Niri
        if (Quickshell.env("NIRI_SOCKET") && !niriProc.running) {
            niriProc.command = ["niri", "msg", "-j", "keyboard-layouts"]
            niriProc.running = true
            return
        }
        // Hyprland
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") && !hyprProc.running) {
            hyprProc.command = ["hyprctl", "devices", "-j"]
            hyprProc.running = true
            return
        }
    }

    Component.onCompleted: updateLayout()
}