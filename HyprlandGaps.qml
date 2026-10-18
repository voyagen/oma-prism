// Live Hyprland general:gaps_out as {top,right,bottom,left}, or null when unavailable.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import "BarModel.js" as BarModel

Item {
  id: root
  property bool active: false
  property var gaps: null
  width: 0
  height: 0

  function refresh() { if (active && !query.running) query.running = true }
  onActiveChanged: if (active) refresh()
  Component.onCompleted: refresh()

  Process {
    id: query
    command: ["hyprctl", "getoption", "general:gaps_out", "-j"]
    stdout: StdioCollector {
      onStreamFinished: {
        var parsed = null
        try {
          var data = JSON.parse(text)
          parsed = BarModel.parseHyprlandGaps(typeof data.custom === "string" ? data.custom : data.css)
        } catch (error) { parsed = null }
        if (JSON.stringify(parsed) !== JSON.stringify(root.gaps)) root.gaps = parsed
      }
    }
    onExited: function(code) { if (code !== 0 && root.gaps !== null) root.gaps = null }
  }

  // Config reloads and Omarchy's gaps toggle both reload the Hyprland config.
  Connections {
    target: Hyprland
    function onRawEvent(event) { if (event.name === "configreloaded") root.refresh() }
  }
  // Safety net if an event is missed.
  Timer {
    interval: 5000
    repeat: true
    running: root.active
    onTriggered: root.refresh()
  }
}
