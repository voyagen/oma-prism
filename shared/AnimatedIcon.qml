import QtQuick
import QtQuick.Window

Item {
  id: root

  property url source: ""
  property bool cache: true
  property bool asynchronous: false
  property color ink: "white"
  property real opticalSize: 18
  property string tintPolicy: "foreground"
  readonly property int status: currentIcon.status
  readonly property real paintedExtent: currentIcon.paintedExtent

  property bool motionEnabled: true
  property bool reducedMotion: false
  property bool expressiveMotion: false
  property var enabledOverride: null
  property var reducedMotionOverride: null
  property string effect: "none"
  property bool replaceEnabled: false
  property bool activityEnabled: true

  readonly property bool effectiveMotionEnabled: motionEnabled && (enabledOverride === null || enabledOverride === undefined ? true : !!enabledOverride)
  readonly property bool effectiveReducedMotion: reducedMotionOverride === null || reducedMotionOverride === undefined ? reducedMotion : !!reducedMotionOverride
  readonly property bool renderable: activityEnabled && visible && (!Window.window || Window.window.visible) && opacity > 0 && width > 0 && height > 0
  readonly property bool animating: oneShot.running || breathing.running || spinning.running || replacement.running
  readonly property bool running: animating
  readonly property bool replacing: replacement.running
  readonly property bool disappeared: hiddenByEffect
  readonly property string activeEffect: oneShot.running ? shotName : (spinning.running ? "rotate" : (breathing.running ? effect : (replacement.running ? "replace" : "none")))

  implicitWidth: opticalSize
  implicitHeight: opticalSize

  property bool ready: false
  property bool stopped: false
  property bool hiddenByEffect: false
  property string shotName: "none"
  property url currentSource: ""
  property url outgoingSource: ""
  property real semanticOpacity: 1
  property real semanticScale: 1
  property real semanticY: 0
  property real semanticRotation: 0
  property real incomingOpacity: 1
  property real outgoingOpacity: 0
  property real incomingX: 0
  property real outgoingX: 0
  property real incomingScale: 1
  property real outgoingScale: 1
  property int firstDuration: 0
  property int secondDuration: 0
  property int thirdDuration: 0
  property real firstOpacity: 1
  property real secondOpacity: 1
  property real finalOpacity: 1
  property real firstScale: 1
  property real firstY: 0
  property real firstRotation: 0
  property real secondRotation: 0


  function haltSemantic() {
    oneShot.stop();
    breathing.stop();
    var wasSpinning = spinning.running;
    spinning.stop();
    if (wasSpinning)
      semanticRotation = semantic.rotation % 360;
    semantic.rotation = 0;
  }

  function resetSemantic() {
    semanticOpacity = hiddenByEffect ? 0 : 1;
    semanticScale = 1;
    semanticY = 0;
    semanticRotation = 0;
  }

  function finishReplacement() {
    replacement.stop();
    incomingOpacity = 1;
    outgoingOpacity = 0;
    incomingX = 0;
    outgoingX = 0;
    incomingScale = 1;
    outgoingScale = 1;
    outgoingSource = "";
  }

  function resumeContinuous() {
    if (!ready || stopped || hiddenByEffect || !effectiveMotionEnabled || !renderable || oneShot.running)
      return;
    if (effect === "rotate" && !effectiveReducedMotion)
      spinning.start();
    else if (effect === "pulse" || effect === "breathe" || effect === "rotate")
      breathing.start();
  }

  function reconcileMotion() {
    if (!ready)
      return;
    if (oneShot.running && shotName === "disappear")
      hiddenByEffect = true;
    haltSemantic();
    finishReplacement();
    if (!effectiveMotionEnabled)
      hiddenByEffect = false;
    resetSemantic();
    resumeContinuous();
  }

  function stopEffect() {
    stopped = true;
    haltSemantic();
    finishReplacement();
    hiddenByEffect = false;
    resetSemantic();
  }

  function startReplacement(previousSource) {
    var interrupted = replacement.running;
    replacement.stop();
    outgoingSource = previousSource;
    if (!interrupted) {
      incomingOpacity = 0;
      outgoingOpacity = 1;
      incomingX = effectiveReducedMotion ? 0 : expressiveMotion ? 2.5 : 1;
      outgoingX = 0;
      incomingScale = effectiveReducedMotion ? 1 : expressiveMotion ? 0.90 : 0.96;
      outgoingScale = 1;
    }
    replacement.start();
  }

  function replaceSource(nextSource) {
    source = nextSource;
  }

  function triggerEffect(name) {
    var interrupted = oneShot.running;
    stopped = false;
    haltSemantic();
    if (!effectiveMotionEnabled || !renderable) {
      if (!effectiveMotionEnabled)
        hiddenByEffect = false;
      resetSemantic();
      return;
    }
    if (name === "none") {
      stopEffect();
      return;
    }
    if (name === "replace") {
      if (!hiddenByEffect)
        startReplacement(currentSource);
      resumeContinuous();
      return;
    }
    if (name === "pulse" || name === "breathe" || name === "rotate") {
      resetSemantic();
      // Continuous effects are state, not queued imperative requests.
      if (effect !== name) effect = name;
      resumeContinuous();
      return;
    }
    if (name !== "bounce" && name !== "wiggle" && name !== "appear" && name !== "disappear") {
      resetSemantic();
      resumeContinuous();
      return;
    }
    if (hiddenByEffect && name !== "appear")
      return;
    shotName = name;
    firstOpacity = 1;
    secondOpacity = 1;
    finalOpacity = name === "disappear" ? 0 : 1;
    firstScale = 1;
    firstY = 0;
    firstRotation = 0;
    secondRotation = 0;
    thirdDuration = 0;
    if (name === "appear" || name === "disappear") {
      if (name === "appear" && !interrupted && !hiddenByEffect && semanticOpacity === 1)
        semanticOpacity = 0;
      hiddenByEffect = false;
      firstDuration = 160;
      secondDuration = 0;
      firstOpacity = finalOpacity;
      secondOpacity = finalOpacity;
      firstScale = effectiveReducedMotion ? 1 : (name === "disappear" ? 0.96 : 1);
      if (name === "appear" && !effectiveReducedMotion && semanticScale === 1)
        semanticScale = 0.96;
    } else {
      firstDuration = name === "bounce" ? 120 : 80;
      secondDuration = name === "bounce" ? 180 : 160;
      thirdDuration = name === "wiggle" ? 80 : 0;
      if (effectiveReducedMotion)
        firstOpacity = 0.72;
      else if (name === "bounce")
        firstY = -Math.min(2, opticalSize * 0.1) * (expressiveMotion ? 2.5 : 1);
      else {
        firstRotation = expressiveMotion ? -12 : -5;
        secondRotation = expressiveMotion ? 12 : 5;
      }
    }
    oneShot.start();
  }

  onSourceChanged: {
    if (!ready)
      return;
    var previousSource = currentSource;
    if (hiddenByEffect || (oneShot.running && shotName === "disappear")) {
      haltSemantic();
      hiddenByEffect = false;
      resetSemantic();
    }
    stopped = false;
    currentSource = source;
    if (replaceEnabled && effectiveMotionEnabled && renderable && previousSource.toString() !== "")
      startReplacement(previousSource);
    else
      finishReplacement();
    resumeContinuous();
  }
  onEffectChanged: { if (ready) triggerEffect(effect); }
  onEffectiveMotionEnabledChanged: reconcileMotion()
  onEffectiveReducedMotionChanged: reconcileMotion()
  onExpressiveMotionChanged: reconcileMotion()
  onRenderableChanged: reconcileMotion()
  onReplaceEnabledChanged: { if (!replaceEnabled) finishReplacement(); }
  Component.onCompleted: {
    currentSource = source;
    ready = true;
    triggerEffect(effect);
  }

  Item {
    id: semantic
    anchors.fill: parent
    opacity: root.semanticOpacity
    scale: root.semanticScale
    transform: [
      Translate { y: root.semanticY },
      Rotation { angle: root.semanticRotation; origin.x: semantic.width / 2; origin.y: semantic.height / 2 }
    ]

    Item {
      anchors.fill: parent
      opacity: root.outgoingOpacity
      scale: root.outgoingScale
      transform: Translate { x: root.outgoingX }
      visible: root.outgoingOpacity > 0
      SvgIcon {
        anchors.fill: parent
        source: root.outgoingSource
        cache: root.cache
        asynchronous: root.asynchronous
        ink: root.ink
        opticalSize: root.opticalSize
        tintPolicy: root.tintPolicy
      }
    }
    Item {
      anchors.fill: parent
      opacity: root.incomingOpacity
      scale: root.incomingScale
      transform: Translate { x: root.incomingX }
      SvgIcon {
        id: currentIcon
        anchors.fill: parent
        source: root.currentSource
        cache: root.cache
        asynchronous: root.asynchronous
        ink: root.ink
        opticalSize: root.opticalSize
        tintPolicy: root.tintPolicy
      }
    }
  }

  SequentialAnimation {
    id: oneShot
    ParallelAnimation {
      NumberAnimation { target: root; property: "semanticOpacity"; to: root.firstOpacity; duration: root.firstDuration; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "semanticScale"; to: root.firstScale; duration: root.firstDuration; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "semanticY"; to: root.firstY; duration: root.firstDuration; easing.type: Easing.OutQuad }
      NumberAnimation { target: root; property: "semanticRotation"; to: root.firstRotation; duration: root.firstDuration; easing.type: Easing.OutQuad }
    }
    ParallelAnimation {
      NumberAnimation { target: root; property: "semanticOpacity"; to: root.secondOpacity; duration: root.secondDuration; easing.type: Easing.InOutQuad }
      NumberAnimation { target: root; property: "semanticScale"; to: 1; duration: root.secondDuration; easing.type: Easing.InOutQuad }
      NumberAnimation { target: root; property: "semanticY"; to: 0; duration: root.secondDuration; easing.type: Easing.InOutQuad }
      NumberAnimation { target: root; property: "semanticRotation"; to: root.secondRotation; duration: root.secondDuration; easing.type: Easing.InOutQuad }
    }
    NumberAnimation { target: root; property: "semanticRotation"; to: 0; duration: root.thirdDuration; easing.type: Easing.OutQuad }
    onFinished: {
      root.hiddenByEffect = root.shotName === "disappear";
      root.resetSemantic();
      root.resumeContinuous();
    }
  }

  SequentialAnimation {
    id: breathing
    loops: Animation.Infinite
    ParallelAnimation {
      NumberAnimation { target: root; property: "semanticOpacity"; to: root.effect === "pulse" ? 0.82 : 0.86; duration: root.effect === "breathe" ? 800 : (root.effect === "rotate" ? 550 : 500); easing.type: Easing.InOutSine }
      NumberAnimation { target: root; property: "semanticScale"; to: !root.effectiveReducedMotion && root.effect === "breathe" ? (root.expressiveMotion ? 1.07 : 1.025) : 1; duration: root.effect === "breathe" ? 800 : (root.effect === "rotate" ? 550 : 500); easing.type: Easing.InOutSine }
    }
    ParallelAnimation {
      NumberAnimation { target: root; property: "semanticOpacity"; to: 1; duration: root.effect === "breathe" ? 800 : (root.effect === "rotate" ? 550 : 500); easing.type: Easing.InOutSine }
      NumberAnimation { target: root; property: "semanticScale"; to: 1; duration: root.effect === "breathe" ? 800 : (root.effect === "rotate" ? 550 : 500); easing.type: Easing.InOutSine }
    }
  }

  RotationAnimator {
    id: spinning
    target: semantic
    from: 0
    to: 360
    duration: 1100
    loops: Animation.Infinite
  }

  ParallelAnimation {
    id: replacement
    NumberAnimation { target: root; property: "incomingOpacity"; to: 1; duration: 190; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "outgoingOpacity"; to: 0; duration: 190; easing.type: Easing.InOutQuad }
    NumberAnimation { target: root; property: "incomingX"; to: 0; duration: 190; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "outgoingX"; to: root.effectiveReducedMotion ? 0 : root.expressiveMotion ? -2.5 : -1; duration: 190; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "incomingScale"; to: 1; duration: 190; easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "outgoingScale"; to: root.effectiveReducedMotion ? 1 : root.expressiveMotion ? 0.90 : 0.96; duration: 190; easing.type: Easing.OutQuad }
    onFinished: root.finishReplacement()
  }
}
