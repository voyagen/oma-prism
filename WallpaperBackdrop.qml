import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons

// Wallpaper the host paints behind the bar, as one reduced-resolution texture of the whole screen.
// Resolves ~/.local/state/omarchy/current/background (a symlink the host retargets on theme change),
// skips videos, and keeps the previous frame until a new image has decoded.
Item {
  id: root

  property bool active: false
  property size screenSize: Qt.size(0, 0)
  // Where this window's top-left sits on the screen, in px.
  property point windowOrigin: Qt.point(0, 0)
  property real devicePixelRatio: 1

  readonly property string link: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"
  property string path: ""
  readonly property bool video: Util.isVideoPath(path)
  readonly property bool ready: active && !video && hasImage && screenSize.width > 0 && screenSize.height > 0
  property bool hasImage: false
  readonly property Item texture: shot

  width: 0
  height: 0

  Process {
    id: readlink
    command: ["readlink", "-f", root.link]
    stdout: StdioCollector {
      onStreamFinished: {
        var resolved = text.trim()
        if (resolved !== root.path) root.path = resolved
      }
    }
  }

  // The host retargets the symlink (and its file) on theme changes; poll modestly, only while glass is on.
  Timer {
    interval: 2500
    repeat: true
    running: root.active
    triggeredOnStart: true
    onTriggered: if (!readlink.running) readlink.running = true
  }

  Image {
    id: image
    width: root.screenSize.width
    height: root.screenSize.height
    asynchronous: true
    cache: false
    fillMode: Image.PreserveAspectCrop
    // Same mapping as the host's wallpaper window, so screen px map 1:1 onto this item.
    sourceSize: Qt.size(root.screenSize.width * root.devicePixelRatio, root.screenSize.height * root.devicePixelRatio)
    source: root.active && !root.video && root.path !== "" && root.screenSize.width > 0 ? Util.fileUrl(root.path) : ""
    onStatusChanged: {
      if (status === Image.Ready) {
        root.hasImage = true
        shot.scheduleUpdate()
      } else if (status === Image.Error && source !== "") {
        root.hasImage = false
      }
    }
  }

  ShaderEffectSource {
    id: shot
    sourceItem: image
    live: false
    hideSource: true
    smooth: true
    visible: false
    width: 1
    height: 1
    textureSize: Qt.size(Math.max(1, Math.round(root.screenSize.width / 2)), Math.max(1, Math.round(root.screenSize.height / 2)))
  }
}
