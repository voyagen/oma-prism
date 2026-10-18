import QtQuick

// Client-side Liquid Glass material. With a WallpaperBackdrop the shader blurs, saturates and
// lens-refracts the wallpaper under the surface, then layers tint, specular rim, hairline and dither.
// Without one (video/missing wallpaper) it is a tinted pane; windows under the bar are never visible
// to a layer-shell client. Shader: shaders/liquidglass.frag, rebuild with
//   qsb --qt6 -o shaders/liquidglass.frag.qsb shaders/liquidglass.frag
Item {
  id: root

  property real radius: 12
  property color tint: "#000000"
  property real tintOpacity: 0.25
  property bool darkAppearance: true
  property real lensStrength: 1.0
  // WallpaperBackdrop (or null): supplies the screen texture and this window's screen origin.
  property Item backdrop: null

  readonly property bool shaderActive: effect.status === ShaderEffect.Compiled
  readonly property bool backdropActive: backdrop !== null && backdrop.ready

  // Surface top-left in screen px. Reads every ancestor x/y so the binding re-evaluates on layout moves.
  function screenOrigin() {
    var x = 0, y = 0, p = root
    while (p && p.parent) { x += p.x; y += p.y; p = p.parent }
    return backdrop ? Qt.point(x + backdrop.windowOrigin.x, y + backdrop.windowOrigin.y) : Qt.point(x, y)
  }

  ShaderEffect {
    id: effect
    anchors.fill: parent
    blending: true
    property vector2d size: Qt.vector2d(root.width, root.height)
    property real radius: Math.min(root.radius, Math.min(root.width, root.height) / 2)
    property color tint: root.tint
    property real tintOpacity: Math.max(0, Math.min(1, root.tintOpacity))
    property real darkAppearance: root.darkAppearance ? 1.0 : 0.0
    property real lensStrength: Math.max(0, Math.min(1, root.lensStrength))
    property vector2d screenSize: root.backdrop ? Qt.vector2d(root.backdrop.screenSize.width, root.backdrop.screenSize.height) : Qt.vector2d(1, 1)
    property vector2d origin: Qt.vector2d(root.screenOrigin().x, root.screenOrigin().y)
    property real backdropOn: root.backdropActive ? 1.0 : 0.0
    property var backdrop: root.backdropActive ? root.backdrop.texture : null
    fragmentShader: Qt.resolvedUrl("shaders/liquidglass.frag.qsb")
    visible: status !== ShaderEffect.Error
  }

  Rectangle {
    anchors.fill: parent
    visible: effect.status === ShaderEffect.Error
    radius: Math.min(root.radius, Math.min(root.width, root.height) / 2)
    color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintOpacity)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, root.darkAppearance ? 0.14 : 0.3)
  }
}
