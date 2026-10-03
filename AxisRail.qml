import QtQuick
import qs.Commons

Item {
  required property var controller
  id: rail
  property bool centerSection:false
  HoverHandler {
    onHoveredChanged:if(rail.centerSection)controller.setCenterSectionHovered(hovered)
    Component.onDestruction:if(hovered && rail.centerSection)controller.setCenterSectionHovered(false)
  }
  property var geometry: ({start:0,extent:0,contentExtent:0,initialOffset:0})
  readonly property bool overflow: geometry.contentExtent > geometry.extent
  readonly property real buttonExtent: overflow ? Math.min(12,geometry.extent/2) : 0
  readonly property real viewportExtent: Math.max(0,geometry.extent-2*buttonExtent)
  readonly property real maximumOffset: Math.max(0,geometry.contentExtent-viewportExtent)
  property real offset: 0
  property string layoutKey: ""
  property bool aligned: false
  function updateOffset() {
    if (!aligned && geometry.contentExtent > 0) {
      offset = Math.min(maximumOffset, Math.max(0, geometry.initialOffset))
      aligned = true
    } else offset = Math.min(maximumOffset, Math.max(0, offset))
  }
  Timer { id: alignTimer; interval: 0; onTriggered: rail.updateOffset() }
  onLayoutKeyChanged: { aligned = false; alignTimer.restart() }
  readonly property alias contentItem: viewport.contentItem
  onGeometryChanged: updateOffset()
  onMaximumOffsetChanged: offset = Math.min(maximumOffset,Math.max(0,offset))
  x:controller.vertical ? 0 : geometry.start
  y:controller.vertical ? geometry.start : 0
  width:controller.vertical ? parent.width : geometry.extent
  height:controller.vertical ? geometry.extent : parent.height
  activeFocusOnTab:overflow
  Keys.onEscapePressed: {
    var window=controller.targetWindow(rail)
    if(window)window.railFocusTarget=null
  }
  function scroll(delta) { offset=Math.min(maximumOffset,Math.max(0,offset+delta)) }
  Keys.onPressed:function(event) {
    if([Qt.Key_Left,Qt.Key_Up,Qt.Key_Right,Qt.Key_Down].indexOf(event.key)<0)return
    scroll(event.key===Qt.Key_Left || event.key===Qt.Key_Up ? -48 : 48)
    event.accepted=true
  }
  Flickable {
    id:viewport
    x:controller.vertical ? 0 : rail.buttonExtent
    y:controller.vertical ? rail.buttonExtent : 0
    width:controller.vertical ? rail.width : rail.viewportExtent
    height:controller.vertical ? rail.viewportExtent : rail.height
    contentWidth:controller.vertical ? width : rail.geometry.contentExtent
    contentHeight:controller.vertical ? rail.geometry.contentExtent : height
    contentX:controller.vertical ? 0 : rail.offset
    contentY:controller.vertical ? rail.offset : 0
    interactive:false
    clip:true
    boundsBehavior:Flickable.StopAtBounds
    MouseArea {
      x:controller.vertical ? 0 : rail.offset
      y:controller.vertical ? rail.offset : 0
      width:viewport.width
      height:viewport.height
      z:-1
      acceptedButtons:Qt.NoButton
      onWheel:function(wheel) {
        if(!rail.overflow){wheel.accepted=false;return}
        rail.scroll(-(wheel.angleDelta.y || wheel.angleDelta.x)/120*48)
        wheel.accepted=true
      }
    }
  }
  Repeater {
    model:2
    MouseArea {
      required property int index
      visible:rail.overflow && rail.buttonExtent>0
      x:controller.vertical ? 0 : (index ? rail.width-rail.buttonExtent : 0)
      y:controller.vertical ? (index ? rail.height-rail.buttonExtent : 0) : 0
      width:controller.vertical ? rail.width : rail.buttonExtent
      height:controller.vertical ? rail.buttonExtent : rail.height
      acceptedButtons:Qt.LeftButton
      onClicked: {
        var window=controller.targetWindow(rail)
        if(window)window.focusRail(rail)
        rail.scroll(index ? 48 : -48)
      }
      onWheel:function(wheel){rail.scroll(-(wheel.angleDelta.y || wheel.angleDelta.x)/120*48);wheel.accepted=true}
      Text {
        anchors.centerIn:parent
        text:controller.vertical ? (index ? "⌄" : "⌃") : (index ? "›" : "‹")
        font.pixelSize:12
        color:controller.barForeground
      }
    }
  }
}
