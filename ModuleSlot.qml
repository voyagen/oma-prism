// Derived from the MIT-licensed Omarchy/lobo.islands bar engine; see LICENSE.
// Copyright (c) 2026 Daniel Lobo; Copyright (c) David Heinemeier Hansson.
// Prism changes: Copyright (c) 2026 Oma Prism contributors.
import QtQuick
import qs.Commons
import qs.Ui

Item {
  required property var controller
  id: slot
  property var rail: null
  Component { id: emptyModuleComponent; Item { implicitWidth: 0; implicitHeight: 0; visible: false } }
  Timer { id: injectTimer; interval: 0; onTriggered: slot.injectProps() }

  required property var entry
  property string region: ""
  readonly property string moduleName: controller.entryId(entry)
  readonly property var moduleSettings: controller.entrySettings(entry)
  readonly property string customType: controller.customModuleType(entry)
  readonly property var registryMetadata: controller.barWidgetRegistry.metadataFor(controller.canonicalWidgetId(moduleName))
  readonly property bool firstParty: registryMetadata && registryMetadata.firstParty === true
  readonly property string pluginApiId: registered ? controller.canonicalWidgetId(moduleName) : "bar-entry:" + moduleName
  // Re-evaluate when the registry mutates (Component reference changes,
  // plugin enabled/disabled, etc.). Reading the `widgets` property creates
  // the binding dependency; the wrapped function call alone wouldn't.
  readonly property var registryComponent: {
    var w = controller.barWidgetRegistry.widgets
    if (customType) return null
    var registryName = controller.canonicalWidgetId(moduleName)
    return w[registryName] ? w[registryName].component : null
  }
  readonly property bool qmlCustom: customType === "qml"
  readonly property bool commandCustom: customType === "command"
  readonly property bool registered: registryComponent !== null
  readonly property var activeItem: {
    if (registered) return registryLoader.item
    if (qmlCustom) return qmlLoader.item
    return componentLoader.item
  }
  property bool destroying:false
  property var observedItem: null
  readonly property bool hovered: moduleHover.hovered
  readonly property bool dragSource: controller.barDragSource === slot
  readonly property bool panelOpen: !!slot.activeItem && controller.activePopout === slot.activeItem
  readonly property bool motionVisible: {
    // Track committed content translation, not just the requested rail offset:
    // mapToItem itself does not register the Flickable's movement dependency.
    if (rail) {
      var start = controller.vertical ? y : x
      var extent = controller.vertical ? height : width
      var offset = controller.vertical ? -rail.contentItem.y : -rail.contentItem.x
      if (rail.viewportExtent <= 0 || start + extent <= offset || start >= offset + rail.viewportExtent) return false
    }
    return !!controller.drawnSlotRect(slot)
  }
  readonly property real minimumAxisExtent: activeItem && (activeItem instanceof WidgetButton || typeof activeItem.open === "function") ? controller.barSize : 0
  implicitWidth: activeItem && activeItem.visible ? Math.max(activeItem.implicitWidth, controller.vertical ? 0 : minimumAxisExtent) : 0
  implicitHeight: activeItem && activeItem.visible ? Math.max(activeItem.implicitHeight, controller.vertical ? minimumAxisExtent : 0) : 0
  width: implicitWidth
  height: implicitHeight
  z: modulePointer.dragging ? 100 : 0

  Component.onCompleted: controller.registerModuleSlot(slot)
  Component.onDestruction: {
    destroying=true
    injectTimer.stop()
    if (observedItem) controller.iconAdapter.release(observedItem)
    if (controller.barDragSource === slot) controller.clearBarDrag()
    controller.unregisterModuleSlot(slot)
  }

  HoverHandler { id: moduleHover }

  BorderSurface {
    visible: slot.dragSource
    anchors.fill: parent
    anchors.margins: Style.space(1)
    color: controller.transparent ? "transparent" : controller.background
    borderSpec: Border.flat(controller.barForeground, 1)
    radius: Math.min(Style.cornerRadius, height / 2)
    opacity: controller.transparent ? 0.22 : 0.32
  }

  Loader {
    id: componentLoader
    active: !slot.qmlCustom && !slot.registered
    sourceComponent: slot.commandCustom ? customCommandModuleComponent : emptyModuleComponent
    anchors.fill: parent
    opacity: slot.dragSource ? 0.22 : 1.0
    onLoaded: {
      slot.injectProps()
      injectTimer.restart()
    }
  }

  Loader {
    id: registryLoader
    active: slot.registered
    sourceComponent: slot.registered ? slot.registryComponent : null
    anchors.fill: parent
    opacity: slot.dragSource ? 0.22 : 1.0
    onLoaded: {
      slot.injectProps()
      injectTimer.restart()
    }
  }

  Loader {
    id: qmlLoader
    active: slot.qmlCustom
    source: slot.qmlCustom ? controller.customModuleSource(slot.entry) : ""
    anchors.fill: parent
    opacity: slot.dragSource ? 0.22 : 1.0
    onLoaded: {
      slot.injectProps()
      injectTimer.restart()
    }
  }

  StatePill {
    id: openPanelPill
    objectName: "open-panel-pill"
    readonly property var motionConfig: controller.iconAdapter.motionConfigFor(slot.activeItem)
    vertical: controller.vertical
    labelExtent: slot.activeItem && slot.activeItem.labelWidth !== undefined ? slot.activeItem.labelWidth : 0
    horizontalPadding: controller.pillHorizontalPadding
    z: -1
    highlighted: slot.panelOpen && !slot.dragSource && slot.motionVisible
    hovered: highlighted && slot.hovered
    pressed: highlighted && modulePointer.pressed && !modulePointer.dragging
    motionEnabled: controller.prismSettings.motionEnabled && motionConfig.interactionEnabled !== false && slot.motionVisible
    reducedMotion: motionConfig.reducedMotion ?? controller.prismSettings.reducedMotion
  }

  MouseArea {
    id: modulePointer

    property bool dragging: false
    property bool suppressClick: false
    property real pressedX: 0
    property real pressedY: 0
    readonly property bool canReorder: controller.shell && typeof controller.shell.mutateShellConfig === "function"
    readonly property real dragThreshold: Style.space(4)

    anchors.fill: parent
    acceptedButtons: Qt.LeftButton
    enabled: slot.visible && slot.width > 0 && slot.height > 0
    propagateComposedEvents: true
    cursorShape: controller.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor
    // Do not assign drag.target here: ModuleSlot is owned by Row/Column
    // positioners, and mutating slot.x/slot.y can leave stale offsets that
    // make neighboring modules overlap after a small aborted drag.

    onPressed: function(mouse) {
      dragging = false
      suppressClick = false
      pressedX = mouse.x
      pressedY = mouse.y
      controller.clearBarDrag()
    }

    onPositionChanged: function(mouse) {
      if (!canReorder || !(mouse.buttons & Qt.LeftButton)) return

      var distance = Math.abs(mouse.x - pressedX) + Math.abs(mouse.y - pressedY)
      if (distance >= dragThreshold) {
        if (!dragging) {
          controller.barDragWindow = controller.targetWindow(slot.activeItem) || controller.targetWindow(slot)
          controller.barDragScreen = controller.barDragWindow ? controller.barDragWindow.screen : null
          controller.barDragOffsetX = pressedX
          controller.barDragOffsetY = pressedY
          controller.captureBarDragGhost(slot)
          controller.barDragSource = slot
        }
        dragging = true
        controller.hideTooltip(slot.activeItem)
      }

      if (dragging) {
        var scenePoint = slot.mapToItem(null, mouse.x, mouse.y)
        var screenPoint = controller.barDragScreenPoint(scenePoint)
        controller.barDragSceneX = scenePoint.x
        controller.barDragSceneY = scenePoint.y
        controller.barDragScreenX = screenPoint.x
        controller.barDragScreenY = screenPoint.y

        var drop = controller.moduleDropAtScene(scenePoint, slot)
        controller.barDragTarget = drop ? drop.slot : null
        controller.barDragAfter = drop ? drop.after : false
        controller.barDragTargetGeometry = drop ? controller.dropMarkerRect(drop.slot, drop.after) : null
      }
    }

    onReleased: function(mouse) {
      var wasDragging = dragging
      var targetSlot = controller.barDragTarget
      var afterTarget = controller.barDragAfter

      if (wasDragging) suppressClick = true

      dragging = false
      controller.clearBarDrag()

      if (wasDragging && targetSlot) {
        controller.dropBarModuleAtTarget(slot, targetSlot, afterTarget)
        mouse.accepted = true
      } else if (!wasDragging) {
        mouse.accepted = false
      }
    }

    onCanceled: {
      dragging = false
      suppressClick = false
      controller.clearBarDrag()
    }

    onClicked: function(mouse) {
      if (suppressClick) {
        suppressClick = false
        mouse.accepted = true
        return
      }

      if (!controller.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
    }
  }

  onActiveItemChanged: {
    if (observedItem && observedItem !== activeItem) controller.iconAdapter.release(observedItem)
    observedItem = null
    injectTimer.restart()
  }
  onModuleSettingsChanged: injectProps()

  function injectProps() {
    var target = activeItem
    if (destroying || !target || !controller || !controller.barWidgetRegistry) return
    if (!commandCustom) {
      if ("bar" in target) target.bar = firstParty
        ? controller : controller.pluginBarApiFor(pluginApiId, moduleName, registered)
      if ("moduleName" in target) target.moduleName = moduleName
      if ("settings" in target) target.settings = moduleSettings
    }
    observedItem = target
    controller.iconAdapter.observe(target, moduleName, slot)
  }

  Component {
    id: customCommandModuleComponent
    CustomCommandModule { controller:slot.controller; entry:slot.entry }
  }
}
