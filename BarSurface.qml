// Derived from the MIT-licensed Omarchy/lobo.islands bar engine; see LICENSE.
// Copyright (c) 2026 Daniel Lobo; Copyright (c) David Heinemeier Hansson.
// Prism changes: Copyright (c) 2026 Oma Prism contributors.
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel

PanelWindow {
  required property var controller
  id: barWindow

  // Hiding parks the bar just past its screen edge instead of unmapping it.
  // Unmapping frees the layer surface and the whole scene graph, so every
  // reveal has to rebuild them (new surface, re-shaped glyphs, re-uploaded
  // textures), which measures ~150ms against ~20ms to tear down. Parking
  // keeps the surface alive, so showing is only a margin change.
  visible: !remapGuard.remapping
  exclusionMode: controller.barHidden || !controller.prismSettings.reserveSpace ? ExclusionMode.Ignore : ExclusionMode.Auto

  ScreenMoveRemap {
    id: remapGuard
    window: barWindow
  }

  margins {
    top: controller.barHidden && controller.position === "top" ? -controller.barWindowSize : 0
    bottom: controller.barHidden && controller.position === "bottom" ? -controller.barWindowSize : 0
    left: controller.barHidden && controller.position === "left" ? -controller.barWindowSize : 0
    right: controller.barHidden && controller.position === "right" ? -controller.barWindowSize : 0
  }

  anchors {
    top: controller.position === "top" || controller.vertical
    bottom: controller.position === "bottom" || controller.vertical
    left: controller.position === "left" || !controller.vertical
    right: controller.position === "right" || !controller.vertical
  }

  implicitWidth: controller.vertical ? controller.barWindowSize : 0
  implicitHeight: controller.vertical ? 0 : controller.barWindowSize
  color: "transparent"
  surfaceFormat.opaque: false
  WlrLayershell.namespace: "omarchy-bar"
  WlrLayershell.layer: WlrLayer.Top

  readonly property alias surface: surface
  readonly property Item settingsButton: {
    for(var slot of controller.moduleSlots)
      if(slot.moduleName==="voyagen.prism.settings" && slot.activeItem && "settingsButton" in slot.activeItem && controller.slotWindow(slot)===barWindow)
        return slot.activeItem.settingsButton
    return null
  }
  property Item railFocusTarget:null
  property bool railFocusPrimed:false
  WlrLayershell.keyboardFocus:railFocusTarget ? (railFocusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
  Timer { id:railFocusPrime; interval:120; onTriggered:barWindow.railFocusPrimed=true }
  function focusRail(rail) {
    railFocusTarget=rail
    railFocusPrimed=false
    rail.forceActiveFocus()
    railFocusPrime.restart()
  }
  Connections {
    target:controller
    function onActivePopoutChanged() { if(controller.activePopout)barWindow.railFocusTarget=null }
  }
  Component.onCompleted: controller.registerBarPanel(barWindow)
  Component.onDestruction: controller.unregisterBarPanel(barWindow)
  Item {
    id: surface
    anchors.fill: parent
    anchors.topMargin: controller.position === "top" ? controller.islandEdgeGap : 0
    anchors.bottomMargin: controller.position === "bottom" ? controller.islandEdgeGap : 0
    anchors.leftMargin: controller.position === "left" ? controller.islandEdgeGap : 0
    anchors.rightMargin: controller.position === "right" ? controller.islandEdgeGap : 0
    readonly property real axisLength: controller.vertical ? height : width
    readonly property var geometry: BarModel.sectionGeometry(axisLength,{left:leftSlots.extents,center:centerSlots.extents,right:rightSlots.extents},controller.entryIndex(controller.layoutEntries("center"),controller.centerAnchor),controller.geometrySettings)
    readonly property bool anchored: geometry.groups.centerAnchor.extent > 0
    readonly property var rails: ({left:leftRail,right:rightRail,center:centerRail,centerBefore:beforeRail,centerAnchor:anchorRail,centerAfter:afterRail})
    CenterGestureArea { controller:barWindow.controller; anchors.fill:parent }
    Rectangle {
      anchors.fill:parent
      anchors.leftMargin: !controller.vertical && controller.prismSettings.mode === "floating-bar" ? controller.geometrySettings.outerMargin : 0
      anchors.rightMargin: anchors.leftMargin
      anchors.topMargin: controller.vertical && controller.prismSettings.mode === "floating-bar" ? controller.geometrySettings.outerMargin : 0
      anchors.bottomMargin: anchors.topMargin
      objectName:"continuous-bar-background"
      visible:controller.prismSettings.mode !== "islands"
      color:controller.islandColor
      border.color:controller.islandBorder
      border.width:controller.islandBorderWidth
      radius:controller.prismSettings.mode === "docked" ? 0 : controller.islandRadius
      antialiasing:true
      z:-1
    }
    Repeater {
      model:["left","center","right"]
      Island {
        controller:barWindow.controller
        required property string modelData
        interval:surface.geometry.islands[modelData]
        objectName:"island-background-"+modelData
        visible:controller.prismSettings.mode === "islands" && interval.extent > 0
        MouseArea {
          anchors.fill:parent
          acceptedButtons:Qt.NoButton
          onWheel:function(wheel) {
            var name=modelData==="center" && surface.anchored ? ((controller.vertical ? parent.y+wheel.y : parent.x+wheel.x)<surface.axisLength/2 ? "centerBefore" : "centerAfter") : modelData
            var rail=surface.rails[name]
            if(!rail.overflow){wheel.accepted=false;return}
            rail.scroll(-(wheel.angleDelta.y || wheel.angleDelta.x)/120*48)
            wheel.accepted=true
          }
        }
      }
    }
    AxisRail { controller:barWindow.controller; id:leftRail; geometry:surface.geometry.groups.left; layoutKey:controller.barConfigSerial+":"+controller.centerAnchor }
    AxisRail { controller:barWindow.controller; id:rightRail; geometry:surface.geometry.groups.right; layoutKey:controller.barConfigSerial+":"+controller.centerAnchor }
    AxisRail { controller:barWindow.controller; id:centerRail; geometry:surface.geometry.groups.center; centerSection:true; layoutKey:controller.barConfigSerial+":"+controller.centerAnchor }
    AxisRail { controller:barWindow.controller; id:beforeRail; geometry:surface.geometry.groups.centerBefore; centerSection:true; layoutKey:controller.barConfigSerial+":"+controller.centerAnchor }
    AxisRail { controller:barWindow.controller; id:anchorRail; geometry:surface.geometry.groups.centerAnchor; centerSection:true; layoutKey:controller.barConfigSerial+":"+controller.centerAnchor }
    AxisRail { controller:barWindow.controller; id:afterRail; geometry:surface.geometry.groups.centerAfter; centerSection:true; layoutKey:controller.barConfigSerial+":"+controller.centerAnchor }
    SectionSlots { controller:barWindow.controller; id:leftSlots; region:"left"; barSurface:surface }
    SectionSlots { controller:barWindow.controller; id:centerSlots; region:"center"; barSurface:surface }
    SectionSlots { controller:barWindow.controller; id:rightSlots; region:"right"; barSurface:surface }
    HoverHandler {
      onHoveredChanged: controller.setBarHovered(hovered)
      Component.onDestruction: if (hovered) controller.setBarHovered(false)
    }
  }

  PopupWindow {
    id: tooltipWindow

    visible: controller.tooltipShown && controller.tooltipTarget !== null && controller.tooltipText !== "" && controller.targetBelongsToWindow(controller.tooltipTarget, barWindow)
    color: "transparent"
    implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
    implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

    anchor {
      id: tooltipAnchor
      window: barWindow
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        var target = controller.tooltipTarget
        if (!controller.targetBelongsToWindow(target, barWindow)) return

        var popupWidth = tooltipWindow.implicitWidth
        var popupHeight = tooltipWindow.implicitHeight
        var localX = target.width / 2 - popupWidth / 2
        var localY = target.height + 6

        if (controller.position === "bottom") {
          localY = -popupHeight - 6
        } else if (controller.position === "left") {
          localX = target.width + 6
          localY = target.height / 2 - popupHeight / 2
        } else if (controller.position === "right") {
          localX = -popupWidth - 6
          localY = target.height / 2 - popupHeight / 2
        }

        var point = barWindow.contentItem.mapFromItem(target, localX, localY)
        tooltipAnchor.rect.x = Math.round(point.x)
        tooltipAnchor.rect.y = Math.round(point.y)
      }
    }

    BorderSurface {
      id: tooltipBubble
      implicitWidth: tooltipLabel.implicitWidth + 4 * controller.densityUnit
      implicitHeight: tooltipLabel.implicitHeight + 3 * controller.densityUnit
      color: Color.tooltip.background
      borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
      radius: 1.6 * controller.densityUnit

      Text {
        id: tooltipLabel
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: controller.tooltipText
        color: Color.tooltip.text
        font.family: controller.fontFamily
        font.pixelSize: Math.max(13, controller.prismSettings.fontSize)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
  }


  component Island: Rectangle {
    required property var controller
    property var interval: ({start:0,extent:0})
    x:controller.vertical ? 0 : interval.start
    y:controller.vertical ? interval.start : 0
    width:controller.vertical ? parent.width : interval.extent
    height:controller.vertical ? interval.extent : parent.height
    radius: controller.islandRadius
    color: controller.islandColor
    border.color: controller.islandBorder
    border.width: controller.islandBorderWidth
    antialiasing: true

    Behavior on color { ColorAnimation { duration:controller.prismDuration } }
  }


  component CenterGestureArea: MouseArea {
    required property var controller
    id: gestureArea

    property bool dragging: false
    property bool suppressClick: false
    property real pressedX: 0
    property real pressedY: 0
    readonly property real dragThreshold: Style.space(4)

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
    pressAndHoldInterval: 200

    function startDrag(x, y) {
      if (dragging) return
      dragging = true
      controller.beginBarMove(controller.targetWindow(gestureArea))
      var scenePoint = gestureArea.mapToItem(null, x, y)
      controller.updateBarMove(controller.windowScreenPoint(scenePoint, controller.barMoveWindow))
    }

    onPressed: function(mouse) {
      dragging = false
      suppressClick = false
      pressedX = mouse.x
      pressedY = mouse.y
    }

    onPressAndHold: function(mouse) {
      // A widget above us propagates its composed press-and-hold down here without
      // ever handing over the grab, so we'd get no release or cancel to end the move.
      if (!gestureArea.pressed) return
      startDrag(mouse.x, mouse.y)
    }

    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return

      if (!dragging) {
        var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
        if (distance < dragThreshold) return
        startDrag(mouse.x, mouse.y)
        return
      }

      var scenePoint = gestureArea.mapToItem(null, mouse.x, mouse.y)
      controller.updateBarMove(controller.windowScreenPoint(scenePoint, controller.barMoveWindow))
    }

    onReleased: function(mouse) {
      if (!dragging) return
      dragging = false
      suppressClick = true
      controller.finishBarMove()
      mouse.accepted = true
    }

    onCanceled: {
      dragging = false
      suppressClick = false
      controller.clearBarMove()
    }

    onClicked: function(mouse) {
      if(mouse.button===Qt.RightButton) {
        var panel=controller.targetWindow(gestureArea)
        controller.openPrismSettings(panel ? (panel.settingsButton || panel.surface) : null)
        mouse.accepted=true
        return
      }
      if (suppressClick) {
        suppressClick = false
        mouse.accepted = true
      }
    }

    onDoubleClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        return
      }
      if (mouse.button === Qt.LeftButton) {
        controller.toggleTransparency()
        mouse.accepted = true
      }
    }
  }


  component SectionSlots: Item {
    required property var controller
    id: section
    required property string region
    required property var barSurface
    readonly property var entries:controller.layoutEntries(region)
    readonly property var extents: {
      var sizes=[]
      for(var i=0;i<slots.count;i++) {
        var holder=slots.itemAt(i)
        var slot=holder ? holder.slot : null
        sizes.push(slot && slot.visible ? (controller.vertical ? slot.implicitHeight : slot.implicitWidth) : 0)
      }
      return sizes
    }
    readonly property var axis:BarModel.axisPositions(extents,controller.geometrySettings.widgetSpacing)
    readonly property int anchorIndex:controller.entryIndex(entries,controller.centerAnchor)
    readonly property var beforeAxis:BarModel.axisPositions(extents.slice(0,anchorIndex),controller.geometrySettings.widgetSpacing)
    readonly property var afterAxis:BarModel.axisPositions(extents.slice(anchorIndex+1),controller.geometrySettings.widgetSpacing)
    Repeater {
      id:slots
      model:section.entries
      Item {
        id:holder
        required property var modelData
        required property int index
        readonly property Item slot:delegateSlot
        // Repeater keeps this nonpainting holder as a sibling. Only the live
        // slot is reparented; moving the delegate itself breaks stackAfter.
        ModuleSlot {
          controller:section.controller
          id:delegateSlot
          entry:holder.modelData
          region:section.region
          readonly property int layoutIndex:holder.index
          readonly property string groupName:section.region!=="center" ? section.region : !section.barSurface.anchored ? "center" : layoutIndex<section.anchorIndex ? "centerBefore" : layoutIndex===section.anchorIndex ? "centerAnchor" : "centerAfter"
          rail:section.barSurface.rails[groupName]
          readonly property real axisOffset:groupName==="centerBefore" ? section.beforeAxis.positions[layoutIndex] || 0 : groupName==="centerAfter" ? section.afterAxis.positions[layoutIndex-section.anchorIndex-1] || 0 : groupName==="centerAnchor" ? 0 : section.axis.positions[layoutIndex] || 0
          parent:rail.contentItem
          x:controller.vertical ? (rail.width-width)/2 : axisOffset
          y:controller.vertical ? axisOffset : (rail.height-height)/2
        }
      }
    }
  }

}
