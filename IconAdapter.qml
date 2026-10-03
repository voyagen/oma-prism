import "shared" as Shared
import QtQuick
import Quickshell
import qs.Ui
import qs.Commons
import "IconResolver.js" as Resolver

Item {
  id: adapter
  visible: false
  property var settings: ({})
  // Keep resolution inputs stable during unrelated appearance previews.
  property var resolutionSettings: ({})
  property string resolutionSnapshot: ""
  onSettingsChanged: {
    var config = settings || {}
    var mapping = {iconPack: config.iconPack, semanticOverrides: config.semanticOverrides, widgetOverrides: config.widgetOverrides}
    var snapshot = JSON.stringify(mapping)
    if (snapshot !== resolutionSnapshot) {
      resolutionSnapshot = snapshot
      resolutionSettings = JSON.parse(snapshot)
    }
  }
  property var observations: []
  property var watches: []
  property var targets: []
  property var dirty: []
  property bool destroying: false
  property int revision: 0
  Timer { id: notificationTimer; interval: 0; onTriggered: adapter.revision++ }
  Timer { id: reconcileTimer; interval: 0; onTriggered: adapter.reconcile() }
  function notifyChanged() {
    if (!destroying && !notificationTimer.running) notificationTimer.start()
  }
  readonly property var records: {
    var serial = revision
    return targets.map(function(record) {
      return { target: record.target, widgetId: record.context, slot: record.slot,
        glyph: record.target ? record.target.text : "",
        semantic: record.resolved.semantic, source: String(record.asset), origin: record.resolved.origin,
        status: record.probeStatus, adapted: record.bindingApplied, conflict: record.conflict,
        renderedStatus: record.paintItem ? record.paintItem.status : Image.Null,
        prefix: record.resolved.prefix,
        effectiveFontSize: record.paintItem ? record.paintItem.effectiveFontSize : 0,
        paintedExtent: record.paintedExtent }
    })
  }
  readonly property var diagnostics: {
    var serial = revision
    var issues = []
    targets.forEach(function(record) {
      var reason = record.conflict ? "Another owner supplied iconComponent; Prism relinquished this target" : record.resolved.reason
      if (record.probeStatus === Image.Error) reason = "Cannot read/render SVG: " + record.asset
      if (record.custom) reason = "Existing custom iconComponent retained"
      if (record.resolved.prefix && !record.geometryReady) reason = "Power percentage cannot fit native slot at 8px text plus a 12px SVG"
      else if (record.paintItem && record.resolved.prefix && record.paintItem.effectiveFontSize < adapter.settings.fontSize)
        reason = "Power percentage fitted to " + record.paintItem.effectiveFontSize + "px (requested " + adapter.settings.fontSize + "px)"
      if (reason) issues.push({target:record.target, widgetId:record.context, glyph:record.target ? record.target.text : "",
        semantic: record.resolved.semantic, source: String(record.asset), slot: record.slot, reason: reason})
    })
    observations.forEach(function(observation) {
      if (["crmne.mpris", "akshar.radio-atlas", "tornikegomareli.spaces"].indexOf(observation.widgetId) >= 0)
        issues.push({target:observation.root, widgetId:observation.widgetId, glyph:"", slot:observation.slot, source:"original", reason:"Partial: private text/transport/artwork/application image surfaces remain widget-owned; no universal icon or label-size override"})
    })
    watches.forEach(function(watch) {
      if(watch.fontConflict) {
        var observation=watch.target ? owner(watch.target) : null
        issues.push({target:watch.target,widgetId:watch.context,glyph:"",slot:observation ? observation.slot : null,source:"original",reason:"Another owner supplied fontSize; Prism relinquished the public label."})
      }
    })
    return issues
  }

  // Policies consume public widget semantics, never private service state.
  property var semanticPolicies: ({
    "omarchy.bluetooth": "bluetooth",
    "omarchy.audio": "mute",
    "omarchy.microphone": "microphone"
  })
  function motionConfigFor(control) {
    if (!control) return {}
    var observation = owner(control)
    var context = observation ? contextFor(control, observation) : ("moduleName" in control ? control.moduleName : "")
    var overrides = settings.motionOverrides || {}
    return Object.prototype.hasOwnProperty.call(overrides, context) ? overrides[context] : {}
  }
  function pointerScopeFor(control) {
    var observation = owner(control)
    return observation && observation.slot ? observation.slot : control
  }
  function panelPillFor(control) {
    var observation = owner(control)
    return !!observation && !!observation.slot && observation.slot.panelOpen
  }
  function motionVisibleFor(control) {
    var observation = owner(control)
    return !observation || !observation.slot || observation.slot.motionVisible !== false
  }
  function policyFor(context) {
    return Object.prototype.hasOwnProperty.call(semanticPolicies, context) ? semanticPolicies[context] : ""
  }
  function replacementFor(context, previous, current) {
    var policy = policyFor(context)
    if (policy === "bluetooth") return true
    if (policy === "microphone" || policy === "mute")
      return (previous.indexOf("muted") >= 0) !== (current.indexOf("muted") >= 0)
    return false
  }
  function observe(widgetRoot, widgetId, slot) {
    if (!widgetRoot) return
    for (var i = 0; i < observations.length; ++i) {
      if (observations[i].root === widgetRoot && observations[i].slot === slot) {
        schedule(widgetRoot)
        return
      }
    }
    observations = observations.concat([{root:widgetRoot, widgetId:widgetId, slot:slot}])
    schedule(widgetRoot)
  }
  function release(widgetRoot) {
    observations = observations.filter(function(o) { return o.root !== widgetRoot })
    sweep()
  }
  function refresh() {
    targets.forEach(function(record) { record.refreshProbe() })
    observations.forEach(function(o) { schedule(o.root) })
  }
  function schedule(item) {
    if (destroying) return
    if (item && dirty.indexOf(item) < 0) dirty.push(item)
    if (!reconcileTimer.running) reconcileTimer.start()
  }
  function owner(item) {
    for (var p = item; p; p = p.parent) {
      for (var i = 0; i < observations.length; ++i) if (observations[i].root === p) return observations[i]
    }
    return null
  }
  function contextFor(item, observation) {
    for (var p = item; p; p = p.parent) {
      if ("moduleName" in p && typeof p.moduleName === "string" && p.moduleName) return p.moduleName
      if (p === observation.root) break
    }
    return observation.widgetId
  }
  function publicLabelText(text) {
    if(typeof text!=="string" || text==="")return false
    for(var i=0;i<text.length;i++) {
      var point=text.codePointAt(i)
      if(point>0xffff)i++
      if(point>=0xe000 && point<=0xf8ff || point>=0xf0000 && point<=0xffffd || point>=0x100000 && point<=0x10fffd)return false
    }
    return true
  }
  function scan(item, observation) {
    if (!item || item === adapter || item.prismOwned === true) return
    var watch = watches.find(function(watch) { return watch.target === item })
    if (!watch) {
      watch = watchComponent.createObject(adapter,{target:item,context:contextFor(item,observation)})
      watches.push(watch)
    }
    if (item instanceof BarIconButton) {
      var record = targets.find(function(record) { return record.target === item })
      if (!record) {
        record = recordComponent.createObject(adapter, {target:item, context:contextFor(item,observation), slot:observation.slot, custom:item.iconComponent !== null})
        targets.push(record)
      } else {
        record.context = contextFor(item,observation)
        record.slot = observation.slot
      }
      return
    }
    // Inactive loaders have no surface. Window/popup items are nonvisual and
    // never occur in visual children; hidden bar indicator loaders must still
    // be discovered so later visibility/text changes retain the same records.
    if (item instanceof Loader && (!item.active || item.item && !(item.item instanceof Item))) return
    for (var i = 0; i < item.children.length; ++i) scan(item.children[i],observation)
  }
  function reconcile() {
    var pending = dirty
    dirty = []
    pending.forEach(function(item) {
      var observation = owner(item)
      if (observation) scan(item,observation)
    })
    sweep()
    notifyChanged()
  }
  function sweep() {
    var kept = []
    targets.forEach(function(record) {
      var observation = record.target ? owner(record.target) : null
      if (observation) {
        record.context = contextFor(record.target,observation)
        record.slot = observation.slot
        kept.push(record)
      } else {
        record.detach()
        record.destroy()
      }
    })
    targets = kept
    kept = []
    watches.forEach(function(watch) {
      var observation=watch.target ? owner(watch.target) : null
      if (observation) {
        watch.context=contextFor(watch.target,observation)
        kept.push(watch)
      } else { watch.attached=false; watch.destroy() }
    })
    watches = kept
    notifyChanged()
  }
  Component.onDestruction: {
    destroying = true
    reconcileTimer.stop()
    notificationTimer.stop()
    targets.forEach(function(record) { record.detach() })
    watches.forEach(function(watch) { watch.attached=false })
  }

  Component {
    id: watchComponent
    QtObject {
      id: watch
      required property Item target
      onTargetChanged: if (!target) adapter.schedule(null)
      property bool attached:true
      property bool fontConflict:false
      property int fontRestoreMode:Binding.RestoreBindingOrValue
      property Timer fontCheck: Timer { interval: 0; onTriggered: watch.checkFontOwnership() }
      function checkFontOwnership() {
        if(!target || !labelFontApplied || target.fontSize===adapter.settings.fontSize)return
        // Do not tear down a Binding from inside its target's synchronous
        // change notification; its value/restore operation is still on-stack.
        fontRestoreMode=Binding.RestoreNone
        fontConflict=true
        adapter.notifyChanged()
      }
      property string context:""
      readonly property bool publicLabel:target && target instanceof WidgetButton && !(target instanceof BarIconButton)
        && ["crmne.mpris","akshar.radio-atlas","tornikegomareli.spaces"].indexOf(context)<0 && adapter.publicLabelText(target.text)
      readonly property bool labelFontApplied:attached && publicLabel && !fontConflict
      readonly property var observation: target ? adapter.owner(target) : null
      readonly property bool controlGroup: (target instanceof Row || target instanceof Column || target instanceof Grid)
        && target.children.filter(function(child) { return child instanceof WidgetButton }).length > 1
      property Binding groupSpacingBinding: Binding {
        target: watch.controlGroup ? watch.target : null
        property: "spacing"
        value: watch.observation && watch.observation.slot ? watch.observation.slot.controller.prismSettings.widgetSpacing : 0
        when: watch.attached && watch.controlGroup && !!watch.observation && !!watch.observation.slot
        restoreMode: Binding.RestoreBindingOrValue
      }
      readonly property bool layoutApplied: attached && !!observation && !!observation.slot
        && target instanceof WidgetButton
        && (target instanceof BarIconButton || target.labelVisible)
        && ["crmne.mpris","akshar.radio-atlas","tornikegomareli.spaces"].indexOf(context)<0
      readonly property var controller: layoutApplied ? observation.slot.controller : null
      readonly property string prefix: target instanceof BarIconButton ? Resolver.resolve(context,target.text,adapter.resolutionSettings).prefix.trim() : ""
      property TextMetrics prefixMetrics: TextMetrics {
        text: watch.prefix
        font.family: watch.target instanceof WidgetButton ? watch.target.fontFamily : ""
        font.pixelSize: adapter.settings.fontSize || Style.font.body
      }
      readonly property real axisExtent: !controller ? 0 : Math.ceil(Math.max(controller.barSize,
        target instanceof BarIconButton
          ? (prefix ? prefixMetrics.advanceWidth + adapter.settings.iconSize + controller.densityUnit + 2 * controller.pillHorizontalPadding : controller.barSize)
          : target.labelWidth + 2 * Math.max(controller.pillHorizontalPadding, target.scaledHorizontalMargin)))
      property Binding horizontalPaddingBinding: Binding {
        target: watch.target
        property: "horizontalMargin"
        value: watch.controller ? watch.controller.pillHorizontalPadding / Style.spaceReal(1) : 0
        when: watch.layoutApplied && (!watch.target.settings || watch.target.settings.horizontalMargin === undefined)
        restoreMode: Binding.RestoreBindingOrValue
      }
      property Binding axisWidthBinding: Binding {
        target: watch.target
        property: "fixedWidth"
        value: watch.target && watch.target.vertical ? -1 : watch.axisExtent
        when: watch.layoutApplied
        restoreMode: Binding.RestoreBindingOrValue
      }
      property Binding axisHeightBinding: Binding {
        target: watch.target
        property: "fixedHeight"
        value: watch.target && watch.target.vertical ? watch.axisExtent : -1
        when: watch.layoutApplied
        restoreMode: Binding.RestoreBindingOrValue
      }
      property Binding fontBinding: Binding {
        target:watch.target instanceof WidgetButton && !(watch.target instanceof BarIconButton) ? watch.target : null
        property:"fontSize"
        value:adapter.settings.fontSize || Style.font.body
        when:watch.labelFontApplied
        restoreMode:watch.fontRestoreMode
      }
      property Connections signals: Connections {
        target: watch.target
        ignoreUnknownSignals: true
        function onChildrenChanged() { adapter.schedule(watch.target) }
        function onParentChanged() { adapter.schedule(watch.target) }
        function onItemChanged() { adapter.schedule(watch.target) }
        function onLoaded() { adapter.schedule(watch.target) }
        function onFontSizeChanged() {
          if (!watch.fontCheck.running) watch.fontCheck.start()
        }
        function onVisibleChanged() { adapter.schedule(watch.target) }
        function onModuleNameChanged() { adapter.schedule(watch.target) }
      }
    }
  }
  Component {
    id: recordComponent
    Item {
      id: record
      property bool prismOwned: true
      required property Item target
      onTargetChanged: if (!target) adapter.schedule(null)
      required property string context
      required property var slot
      required property bool custom
      property bool conflict: false
      property bool detached: false
      property bool probeReload: false
      readonly property var resolved: Resolver.resolve(context, target ? target.text : "", adapter.resolutionSettings)
      readonly property url asset: {
        var source = resolved.source
        if (!source) return ""
        if (source.indexOf("~/") === 0) source = Quickshell.env("HOME") + source.substring(1)
        return source[0] === "/" ? Util.fileUrl(source) : Qt.resolvedUrl(source)
      }
      readonly property bool editableAsset: resolved.origin === "widget-override" || resolved.origin === "semantic-override"
      readonly property int probeStatus: probe.status
      readonly property bool composite: resolved.prefix !== ""
      readonly property real separation: composite ? 4 : 0
      readonly property real iconExtent: composite ? Math.min(adapter.settings.iconSize, Math.max(12, (target ? target.width : 0) - minimumPrefix.advanceWidth - separation)) : adapter.settings.iconSize
      readonly property bool geometryReady: !composite || !!target && minimumPrefix.advanceWidth + 12 + separation <= target.width
      readonly property bool canAdapt: !custom && !conflict && !detached && !probeReload && geometryReady && !!asset && probe.status === Image.Ready
      TextMetrics {
        id: minimumPrefix
        text: record.resolved.prefix.trim()
        font.family: record.target ? record.target.fontFamily : ""
        font.pixelSize: 8
      }
      property Item paintItem: null
      readonly property real paintedExtent: canAdapt && paintItem ? paintItem.paintedExtent : 0
      readonly property color ink: target && target.active && target.useActiveColor ? target.activeColor : (target ? target.foreground : "white")
      readonly property var motionConfig: target ? adapter.motionConfigFor(target) : ({})
      readonly property string semanticPolicy: adapter.policyFor(context)
      readonly property string semanticEffect: motionConfig.effect !== undefined ? motionConfig.effect
        : semanticPolicy === "microphone" && target && target.active && resolved.semantic !== "microphone-muted" ? "breathe" : "none"
      property string previousSemantic: ""
      property bool semanticReady: false
      property bool replaceIcon: false
      function updateSemantic() {
        var current = resolved.semantic
        replaceIcon = motionConfig.replace !== undefined ? motionConfig.replace
          : semanticReady && adapter.replacementFor(context, previousSemantic, current)
        if (semanticReady && semanticPolicy === "bluetooth" && current === "bluetooth-connected" && previousSemantic !== current
            && motionConfig.effect === undefined && paintItem) paintItem.triggerEffect("bounce")
        previousSemantic = current
        semanticReady = true
      }
      property alias component: replacement
      onResolvedChanged: { updateSemantic(); adapter.notifyChanged() }
      onProbeStatusChanged: adapter.notifyChanged()
      onCanAdaptChanged: { queueOwnershipCheck(); adapter.notifyChanged() }
      Component.onCompleted: { updateSemantic(); queueOwnershipCheck() }
      property bool bindingApplied: false
      onBindingAppliedChanged: adapter.notifyChanged()
      property int iconRestoreMode: Binding.RestoreBindingOrValue
      Timer { id: ownershipCheck; interval: 0; onTriggered: record.checkOwnership() }
      Timer { id: probeReset; interval: 0; onTriggered: record.probeReload = false }
      function queueOwnershipCheck() {
        if (!detached && !ownershipCheck.running) ownershipCheck.start()
      }
      function checkOwnership() {
        if (!target || detached) return
        // A target notification can run inside Binding's assignment/restoration.
        // Wait until it unwinds before changing restore policy or disabling it.
        if (!custom && !conflict && target.iconComponent !== null && target.iconComponent !== component) {
          iconRestoreMode = Binding.RestoreNone
          conflict = true
          adapter.notifyChanged()
        }
        bindingApplied = canAdapt
      }
      function detach() {
        detached = true
        ownershipCheck.stop()
        probeReset.stop()
        bindingApplied = false
      }
      function refreshProbe() {
        if (detached) return
        probeReload = true
        probeReset.restart()
      }
      Image {
        id: probe
        visible: false
        source: record.probeReload ? "" : record.asset
        sourceSize: Qt.size(adapter.settings.iconSize || 18,adapter.settings.iconSize || 18)
        cache: !record.editableAsset
        asynchronous: record.editableAsset
      }
      Binding {
        id: iconBinding
        target: record.target
        property: "iconComponent"
        value: record.component
        when: record.bindingApplied
        restoreMode: record.iconRestoreMode
      }
      Connections {
        target: record.target
        function onIconComponentChanged() { record.queueOwnershipCheck() }
      }
      Component {
        id: replacement
        Item {
          id: painting
          property bool prismOwned: true
          function triggerEffect(effect) { paintedSvg.triggerEffect(effect) }
          readonly property int status: paintedSvg.status
          readonly property real paintedExtent: prefix.visible ? prefix.paintedWidth + record.separation + paintedSvg.paintedExtent : paintedSvg.paintedExtent
          readonly property real effectiveFontSize: record.composite ? prefix.fontInfo.pixelSize : 0
          Component.onCompleted: record.paintItem = painting
          Component.onDestruction: if (record.paintItem === painting) record.paintItem = null
          onPaintedExtentChanged: adapter.notifyChanged()
          onEffectiveFontSizeChanged: adapter.notifyChanged()
          Item {
            anchors.centerIn: parent
            width: painting.paintedExtent
            height: record.target ? record.target.height : record.iconExtent
            rotation: record.target ? record.target.textRotation : 0
            Text {
              id: prefix
              visible: record.composite
              anchors.verticalCenter: parent.verticalCenter
              text: record.resolved.prefix.trim()
              textFormat: Text.PlainText
              color: record.ink
              font.family: record.target ? record.target.fontFamily : ""
              font.pixelSize: adapter.settings.fontSize
              fontSizeMode: Text.Fit
              minimumPixelSize: 8
              width: Math.max(0,(record.target ? record.target.width : 0)-record.iconExtent-record.separation)
              height: record.target ? record.target.height : record.iconExtent
              verticalAlignment: Text.AlignVCenter
              renderType: Text.NativeRendering
            }
            Shared.AnimatedIcon {
              id: paintedSvg
              anchors.verticalCenter: parent.verticalCenter
              x: prefix.visible ? prefix.paintedWidth + record.separation : 0
              width: record.iconExtent
              height: width
              opticalSize: width
              source: record.probeReload ? "" : record.asset
              cache: !record.editableAsset
              asynchronous: record.editableAsset
              ink: record.ink
              tintPolicy: adapter.settings.tintPolicy
              motionEnabled: adapter.settings.motionEnabled !== false
              reducedMotion: adapter.settings.reducedMotion === true
              expressiveMotion: adapter.settings.animationIntensity === "expressive"
              activityEnabled: !!record.target && record.target.visible && record.target.opacity > 0
                && !record.target.concealed && (!record.slot || record.slot.visible && record.slot.opacity > 0 && record.slot.motionVisible !== false)
              enabledOverride: record.motionConfig.iconEnabled ?? null
              reducedMotionOverride: record.motionConfig.reducedMotion ?? null
              effect: record.semanticEffect
              replaceEnabled: record.motionConfig.replace !== undefined ? record.motionConfig.replace : record.replaceIcon
              onStatusChanged: adapter.notifyChanged()
            }
          }
        }
      }
    }
  }
}
