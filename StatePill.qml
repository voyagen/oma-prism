import QtQuick
import QtQuick.Window
import qs.Commons

// Paint-only state feedback. Opacity changes never alter layout or hit targets.
Rectangle {
  id: pill
  readonly property bool prismOwned: true
  property bool highlighted: false
  property bool hovered: false
  property bool pressed: false
  property bool motionEnabled: true
  property bool reducedMotion: false
  property bool vertical: false
  property real labelExtent: 0
  property real horizontalPadding: Style.space(6)
  readonly property real crossExtent: parent ? (vertical ? parent.width : parent.height) : 0
  readonly property real targetOpacity: highlighted ? (pressed ? 0.20 : hovered ? 0.16 : 0.12)
    : pressed ? 0.10 : hovered ? 0.055 : 0
  readonly property bool animating: fade.running
  readonly property bool canAnimate: motionEnabled && !!parent && parent.visible && parent.opacity > 0
    && width > 0 && height > 0 && (!Window.window || Window.window.visible)
  onCanAnimateChanged: if (!canAnimate) fade.complete()

  visible: opacity > 0
  // Paint may extend into existing spacing; layout and pointer bounds stay native.
  x: parent ? (parent.width - width) / 2 : 0
  y: parent ? (parent.height - height) / 2 : 0
  width: vertical ? crossExtent : Math.max(parent ? parent.width : 0, crossExtent, labelExtent > 0 ? labelExtent + 2 * horizontalPadding : 0)
  height: vertical ? Math.max(parent ? parent.height : 0, crossExtent) : crossExtent
  color: Color.accent
  radius: Math.min(width, height) / 2
  opacity: targetOpacity
  Behavior on opacity {
    enabled: pill.canAnimate
    NumberAnimation {
      id: fade
      duration: pill.reducedMotion ? 100 : pill.targetOpacity > 0 ? 120 : 160
      easing.type: Easing.OutCubic
    }
  }
}
