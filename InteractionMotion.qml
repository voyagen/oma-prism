import QtQuick
import QtQuick.Window
import qs.Commons

// Paint-only feedback: the native control remains the click/tooltip geometry.
Item {
  id: motion
  required property Item control
  property Item pointerScope: control
  readonly property bool prismOwned: true
  property bool motionEnabled: true
  property bool activityEnabled: true
  property bool reducedMotion: false
  property bool expressiveMotion: false
  property var enabledOverride: null
  property var reducedMotionOverride: null
  // Optional explicit direct painting children; null selects the native shape.
  property bool backgroundCovered: false
  property real pillHorizontalPadding: Style.space(6)
  readonly property bool highlighted: !!control && (control.effectiveActive !== undefined
    ? control.effectiveActive : control.active === true)
  readonly property alias statePill: pill
  property var visualItems: null
  property bool attached: true
  readonly property bool effectiveEnabled: !!attached && !!motionEnabled
    && (enabledOverride !== null ? !!enabledOverride
      : control && control.prismMotionEnabled !== undefined ? !!control.prismMotionEnabled : true)
  readonly property bool effectiveReduced: reducedMotionOverride !== null ? !!reducedMotionOverride
    : control && control.prismReducedMotion !== undefined ? !!control.prismReducedMotion : reducedMotion
  readonly property bool eligible: attached && activityEnabled && !!control && control.visible
    && control.opacity > 0 && control.enabled
    && (control.concealed === undefined || !control.concealed)
    && (control.interactive === undefined || control.interactive)
    && (!Window.window || Window.window.visible)
  readonly property point hoverPosition: pointerScope && control
    ? pointerScope.mapToItem(control, hover.point.position.x, hover.point.position.y) : Qt.point(-1, -1)
  readonly property point pressPosition: pointerScope && control
    ? pointerScope.mapToItem(control, point.point.position.x, point.point.position.y) : Qt.point(-1, -1)
  readonly property bool hovered: eligible && hover.hovered && contains(hoverPosition)
  readonly property bool inside: contains(pressPosition)
  property bool pressCanceled: false
  readonly property bool pressed: eligible && point.active && inside && !pressCanceled
    && (control.pressable === undefined || control.pressable)
  readonly property real visualScale: effectiveEnabled && !effectiveReduced ? scaleValue : 1
  readonly property bool running: scaleAnimation.running || releaseAnimation.running || opacityAnimation.running || pill.animating
  property real scaleValue: 1
  property real opacityValue: 1
  property var records: []
  property bool previousPressed: false
  property bool completed: false

  width: control ? control.width : 0
  height: control ? control.height : 0
  StatePill {
    id: pill
    parent: motion.control
    z: -1
    vertical: motion.control ? motion.control.vertical : false
    labelExtent: motion.control && motion.control.labelWidth !== undefined ? motion.control.labelWidth : 0
    horizontalPadding: motion.pillHorizontalPadding
    highlighted: motion.attached && motion.eligible && !motion.backgroundCovered && motion.highlighted
    hovered: motion.attached && !motion.backgroundCovered && motion.hovered
    pressed: motion.attached && !motion.backgroundCovered && motion.pressed
    motionEnabled: motion.effectiveEnabled && motion.activityEnabled
    reducedMotion: motion.effectiveReduced
  }

  // Receive a passive grab before native MouseAreas accept the same event.
  Item {
    id: pointerObserver
    readonly property bool prismOwned: true
    parent: motion.pointerScope
    z: 10000
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0
  }
  HoverHandler {
    id: hover
    enabled: motion.eligible
    parent: pointerObserver
    target: null
    blocking: false
  }
  PointHandler {
    id: point
    target: null
    enabled: motion.eligible && (motion.control.pressable === undefined || motion.control.pressable)
    parent: pointerObserver
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    grabPermissions: PointerHandler.TakeOverForbidden
    onActiveChanged: {
      if (active)
        motion.pressCanceled = !motion.inside
    }
  }

  function contains(position) {
    return control && position.x >= 0 && position.y >= 0
      && position.x < control.width && position.y < control.height
  }

  function nativeVisual(item) {
    if (!item || item === motion || item.prismOwned === true || item instanceof MouseArea)
      return false
    if (item instanceof Text)
      return control.opticalSize === undefined && item.text === control.text
        && item.horizontalAlignment === Text.AlignHCenter
        && item.verticalAlignment === Text.AlignVCenter
    if (control.opticalSize === undefined || item.width !== control.opticalSize
        || item.height !== control.opticalSize)
      return false
    // BarIconButton's centered square canvas contains its public OpticalGlyph
    // shape, even when its Loader paints a Prism SVG or custom component.
    for (var child of item.children) {
      if (child.text === control.text && child.paintedCenterX !== undefined
          && child.tightWidth !== undefined && child.baselineY !== undefined)
        return true
    }
    return false
  }

  function removeRecord(record) {
    record.feedback = false // Binding restores the native opacity binding/value.
    if (record.visual) {
      var remaining = []
      for (var transform of record.visual.transform) {
        if (transform !== record.paintScale)
          remaining.push(transform)
      }
      record.visual.transform = remaining
    }
    record.destroy()
  }

  function syncChildren() {
    if (!completed || !control)
      return
    var selected = []
    if (attached && effectiveEnabled) {
      for (var item of control.children) {
        if (visualItems !== null ? visualItems.indexOf(item) >= 0
            && item !== motion && item.prismOwned !== true && !(item instanceof MouseArea)
            : nativeVisual(item))
          selected.push(item)
      }
    }
    var next = []
    for (var record of records) {
      if (record.visual && selected.indexOf(record.visual) >= 0)
        next.push(record)
      else
        removeRecord(record)
    }
    for (var visual of selected) {
      var found = false
      for (var existing of next) {
        if (existing.visual === visual) {
          found = true
          break
        }
      }
      if (!found) {
        var created = visualRecord.createObject(motion, {visual: visual, nativeOpacity: visual.opacity})
        var transforms = []
        for (var current of visual.transform)
          transforms.push(current)
        transforms.push(created.paintScale)
        visual.transform = transforms
        next.push(created)
      }
    }
    records = next
    updateFeedback()
  }

  function updateFeedback() {
    for (var record of records) {
      var feedback = effectiveEnabled && effectiveReduced && eligible
        && (pressed || hovered || opacityAnimation.running)
      if (feedback && !record.feedback && record.visual)
        record.nativeOpacity = record.visual.opacity
      record.feedback = feedback
    }
  }

  function updateState() {
    if (!completed)
      return
    var releasedInside = previousPressed && !point.active && !pressCanceled && inside && hovered
    previousPressed = pressed
    scaleAnimation.stop()
    releaseAnimation.stop()
    opacityAnimation.stop()
    if (!eligible || !effectiveEnabled) {
      scaleValue = 1
      opacityValue = 1
      updateFeedback()
      return
    }
    if (effectiveReduced) {
      scaleValue = 1
      opacityAnimation.from = opacityValue
      opacityAnimation.to = pressed ? 0.82 : hovered ? 0.94 : 1
      opacityAnimation.duration = pressed ? 80 : hovered ? 120 : 160
      if (opacityAnimation.from !== opacityAnimation.to)
        opacityAnimation.start()
      updateFeedback()
      return
    }
    opacityValue = 1
    updateFeedback()
    if (releasedInside) {
      releaseRise.from = scaleValue
      releaseSettle.to = hovered ? (expressiveMotion ? 1.07 : 1.022) : 1
      releaseAnimation.start()
    } else {
      scaleAnimation.from = scaleValue
      scaleAnimation.to = pressed ? (expressiveMotion ? 0.90 : 0.975) : hovered ? (expressiveMotion ? 1.07 : 1.022) : 1
      scaleAnimation.duration = (pressed ? 80 : hovered ? 120 : 160) * (expressiveMotion ? 1.5 : 1)
      if (scaleAnimation.from !== scaleAnimation.to)
        scaleAnimation.start()
    }
  }

  function detach() {
    attached = false
    scaleAnimation.stop()
    releaseAnimation.stop()
    opacityAnimation.stop()
    scaleValue = 1
    opacityValue = 1
    for (var record of records)
      removeRecord(record)
    records = []
  }

  onHoveredChanged: updateState()
  onPressedChanged: updateState()
  onEligibleChanged: updateState()
  onEffectiveReducedChanged: updateState()
  onExpressiveMotionChanged: updateState()
  onInsideChanged: {
    if (point.active && !inside)
      pressCanceled = true
  }
  onEffectiveEnabledChanged: { syncChildren(); updateState() }
  onVisualItemsChanged: syncChildren()
  onControlChanged: { detach(); if (completed) { attached = true; syncChildren(); updateState() } }
  onAttachedChanged: { syncChildren(); updateState() }
  Connections {
    target: motion.control
    ignoreUnknownSignals: true
    function onChildrenChanged() { motion.syncChildren() }
    function onOpticalSizeChanged() { motion.syncChildren() }
    function onTextChanged() { motion.syncChildren() }
  }
  NumberAnimation {
    id: scaleAnimation
    target: motion; property: "scaleValue"
    easing.type: Easing.OutCubic
  }
  SequentialAnimation {
    id: releaseAnimation
    NumberAnimation {
      id: releaseRise
      target: motion; property: "scaleValue"; to: motion.expressiveMotion ? 1.09 : 1.025; duration: motion.expressiveMotion ? 150 : 100
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      id: releaseSettle
      target: motion; property: "scaleValue"; duration: motion.expressiveMotion ? 180 : 120
      easing.type: Easing.OutCubic
    }
  }
  NumberAnimation {
    id: opacityAnimation
    target: motion; property: "opacityValue"
    easing.type: Easing.OutCubic
    onRunningChanged: motion.updateFeedback()
  }
  Component {
    id: visualRecord
    QtObject {
      id: record
      required property Item visual
      property real nativeOpacity: 1
      property bool feedback: false
      property Scale paintScale: Scale {
        origin.x: record.visual ? record.visual.width / 2 : 0
        origin.y: record.visual ? record.visual.height / 2 : 0
        xScale: motion.visualScale
        yScale: motion.visualScale
      }
      property Binding opacityBinding: Binding {
        target: record.visual
        property: "opacity"
        value: record.nativeOpacity * motion.opacityValue
        when: record.feedback
        restoreMode: Binding.RestoreBindingOrValue
      }
    }
  }
  Component.onCompleted: { completed = true; attached = true; syncChildren(); updateState() }
  Component.onDestruction: {
    for (var record of records) removeRecord(record)
  }
}
