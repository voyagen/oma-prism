import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects

Item {
  id: root
  property url source: ""
  property bool cache: true
  property bool asynchronous: false
  property color ink: "white"
  property real opticalSize: 18
  property string tintPolicy: "foreground"
  readonly property int status: image.status
  readonly property real paintedExtent: image.status === Image.Ready ? image.paintedWidth : 0
  implicitWidth: opticalSize
  implicitHeight: opticalSize
  Image {
    id: image
    anchors.fill: parent
    source: root.source
    cache: root.cache
    asynchronous: root.asynchronous
    sourceSize: Qt.size(Math.max(1, Math.round(root.opticalSize * Screen.devicePixelRatio)), Math.max(1, Math.round(root.opticalSize * Screen.devicePixelRatio)))
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: root.tintPolicy === "source"
  }
  ColorOverlay {
    anchors.fill: image
    source: image
    color: root.ink
    visible: root.tintPolicy === "foreground" && image.status === Image.Ready
  }
}
