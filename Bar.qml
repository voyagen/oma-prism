// Derived from lobo.islands and Omarchy's MIT-licensed bar engine.
// Copyright (c) 2026 Daniel Lobo; Copyright (c) David Heinemeier Hansson.
// Prism changes: Copyright (c) 2026 Oma Prism contributors. See LICENSE.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel
import "SettingsModel.js" as SettingsModel

Item {
  id: root

  // The omarchy-shell host injects omarchyPath from OMARCHY_PATH.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  // Injected by the host shell so bar slots can resolve enabled widgets.
  property var barWidgetRegistry: fallbackBarWidgetRegistry
  // Read-only registry view for third-party full bars; the built-in bar does
  // not otherwise need it, but declaring it keeps clone construction atomic.
  property var pluginRegistry: null
  // Injected by the host shell every time shell.json is reloaded. Holds the
  // `bar:` subtree: position, centerAnchor, layout. The host owns file IO;
  // the bar renders injected values and persists explicit edits through shell.
  // An empty Prism font family follows the OS-level fontconfig monospace binding.
  property var barConfig: ({})
  property var diskBarConfig: null
  readonly property var persistedPrismSettings: SettingsModel.normalizeSettings(barConfig.prism)
  property var prismPreview: ({})
  readonly property var prismSettings: SettingsModel.normalizeSettings(Object.assign({},persistedPrismSettings,prismPreview))
  property var geometrySettings: ({})
  function updateGeometrySettings() {
    var next = {}
    for (var key of ["mode","outerMargin","sectionPadding","widgetSpacing"])
      next[key] = prismSettings[key]
    next.groupSpacing = Math.max(prismSettings.widgetSpacing, 3 * prismSettings.thickness / 8)
    if (!equalSettingsValue(next, geometrySettings)) geometrySettings = next
  }
  property string settingsError:""
  property var pendingSettingsWrite:null
  readonly property bool settingsWritePending:pendingSettingsWrite !== null
  readonly property bool canSavePrismSettings:!!shell && typeof shell.mutateShellConfig==="function"
  Settings { id:prismPanel; bar:root }
  readonly property alias settingsPanel: prismPanel
  IpcHandler {
    target:"voyagen.prism"
    function settings():void { root.openPrismSettings(null) }
    function health():string {
      return JSON.stringify({id:"voyagen.prism",version:root.manifest ? root.manifest.version : "",source:Qt.resolvedUrl("Bar.qml").toString(),
        ready:!!root.shell && root.barConfig.id==="voyagen.prism" && root.barPanels.length===root.selectedScreens.length && root.barPanels.length>0,
        screenCount:root.barPanels.length,recordCount:icons.records.length,settingsWritePending:root.settingsWritePending,settingsError:root.settingsError})
    }
  }
  Timer {
    id:settingsWriteDeadline
    interval:2500
    onTriggered: {
      root.settingsError="The configuration was not confirmed on disk. Check shell.json permissions and shell write errors."
      root.pendingSettingsWrite=null
      root.cancelPrismPreview()
    }
  }
  FileView {
    id: savedConfigFile
    path: root.omarchyConfigDir + "/shell.json"
    watchChanges: true
    printErrors: false
    onLoaded: {
      try {
        var saved=JSON.parse(text())
        root.diskBarConfig=saved.version===1 && SettingsModel.isPlainObject(saved.bar) ? saved.bar : null
      }
      catch (error) { root.diskBarConfig = null }
      root.confirmSettingsWrite()
    }
    onLoadFailed: { root.diskBarConfig = null }
    onFileChanged: reload()
  }
  Timer {
    interval: 100
    repeat: true
    running: root.settingsWritePending
    onTriggered: savedConfigFile.reload()
  }
  readonly property alias iconAdapter: icons
  IconAdapter { id: icons; settings: root.prismSettings }
  // Injected by the host shell. Used for shell-wide actions such as opening
  // settings and persisting inline widget state.
  property var shell: null
  // Manifest for the active bar option. Present for custom bars and useful for
  // diagnostics; the built-in bar does not otherwise need it.
  property var manifest: null
  QtObject {
    id: fallbackBarWidgetRegistry
    property var widgets: ({})
    property int revision: 0
    function metadataFor(id) { return null }
  }
  // Mirrors the on-disk `bar-off` flag so the user can hide the bar without
  // killing the entire shell. Hidden panels stay mapped but park off-screen
  // without an exclusion zone; updated by the FileView watcher further down.
  property bool barHidden: false
  property string home: Quickshell.env("HOME")
  property string stateHome: home + "/.local/state"
  property string omarchyConfigDir: home + "/.config/omarchy"
  property var fallbackBarConfig: ({
    position: "top",
    transparent: false,
    centerAnchor: "omarchy.clock",
    layout: { left: [], center: [], right: [] }
  })
  property var layoutConfig: fallbackBarConfig.layout
  property string centerAnchor: ""
  property bool requestedTransparent: false
  property bool useTransparentForeground: false
  property bool transparent: false
  property bool centerSectionHovered: false
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing from one monitor's bar to another's stays counted however
  // the enter and leave interleave. A single shared bool would be left false by
  // whichever event landed last.
  property int barHoverCount: 0
  // True while the pointer is over any bar, widgets included.
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  property bool centerHoverRevealSuppressed: false
  property int barConfigSerial: 0
  property string position: "top"
  // Resolves through fontconfig at paint time (Style.font.family defaults
  // to "monospace"), so changing the system font (via `omarchy-font-set`)
  // updates the bar without a reload.
  property string fontFamily: prismSettings.fontFamily || Style.font.family
  // Bound to the central Color singleton so the bar tracks shell.toml's
  // [bar] section. Property names kept for the rest of this file's bindings.
  // Keep text readable against the island color, whatever the theme's bar text is.
  readonly property color effectiveBarBackground:Qt.rgba(
    islandBaseColor.r*islandOpacity+Color.background.r*(1-islandOpacity),
    islandBaseColor.g*islandOpacity+Color.background.g*(1-islandOpacity),
    islandBaseColor.b*islandOpacity+Color.background.b*(1-islandOpacity),1)
  property color themeForeground: BarModel.readableForeground(effectiveBarBackground, Color.bar.text)
  property color themeContrastForeground: Color.background
  property color transparentForeground: Color.bar.text
  property color foreground: themeForeground
  property color barForeground: islandOpacity===0 && useTransparentForeground ? transparentForeground : themeForeground
  property bool foregroundAnimationEnabled: true
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  Behavior on barForeground { enabled: root.foregroundAnimationEnabled; ColorAnimation { duration: root.prismDuration; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: root.prismDuration; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: root.prismDuration; easing.type: Easing.InOutCubic } }
  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property var activePopout: null
  property var barDragSource: null
  property var barDragTarget: null
  property var barDragTargetGeometry: null
  property bool barDragAfter: false
  property var barDragWindow: null
  property var barDragScreen: null
  property url barDragImageUrl: ""
  property real barDragScreenX: 0
  property real barDragScreenY: 0
  property real barDragOffsetX: 0
  property real barDragOffsetY: 0
  property bool barMoveActive: false
  property string barMoveCandidate: ""
  property var barMoveWindow: null
  property var barMoveScreen: null
  property var clickTargets: []
  property var controlMotions: []
  Component {
    id: interactionMotionComponent
    InteractionMotion {
      pointerScope: root.iconAdapter.pointerScopeFor(control)
      backgroundCovered: root.iconAdapter.panelPillFor(control)
      activityEnabled: root.iconAdapter.motionVisibleFor(control)
      pillHorizontalPadding: root.pillHorizontalPadding
      motionEnabled: root.prismSettings.motionEnabled
      reducedMotion: root.prismSettings.reducedMotion
      expressiveMotion: root.prismSettings.animationIntensity === "expressive"
      enabledOverride: root.iconAdapter.motionConfigFor(control).interactionEnabled ?? null
      reducedMotionOverride: root.iconAdapter.motionConfigFor(control).reducedMotion ?? null
    }
  }
  property var moduleSlots: []
  property var pluginBarApis: ({})
  property var pluginObjectOwners: []

  Component {
    id: pluginBarApiComponent
    PluginBarApi {
      readonly property bool prismSettingsOpened: prismPanel.opened
      readonly property real prismIconSize: root.prismSettings.iconSize
      function openPrismSettings(anchorItem) { return root.openPrismSettings(anchorItem) }
    }
  }

  function publicLayoutConfig() {
    return JSON.parse(JSON.stringify(root.layoutConfig || {}))
  }

  function bindPluginBarApi(api) {
    if (!api) return
    api.foreground = Qt.binding(function() { return root.foreground })
    api.barForeground = Qt.binding(function() { return root.barForeground })
    api.background = Qt.binding(function() { return root.background })
    api.urgent = Qt.binding(function() { return root.urgent })
    api.fontFamily = Qt.binding(function() { return root.fontFamily })
    api.position = Qt.binding(function() { return root.position })
    api.vertical = Qt.binding(function() { return root.vertical })
    api.barSize = Qt.binding(function() { return root.barSize })
    api.transparent = Qt.binding(function() { return root.transparent })
    api.foregroundAnimationEnabled = Qt.binding(function() { return root.foregroundAnimationEnabled })
    api.centerSectionRevealHeld = Qt.binding(function() { return root.centerSectionRevealHeld })
    api._centerHoverRevealSuppressed = Qt.binding(function() { return root.centerHoverRevealSuppressed })
    root.syncPluginBarApiObjects(api)
  }

  function syncPluginBarApiObjects(api) {
    if (!api) return
    api.activePopout = root.pluginOwnsBarObject(api.pluginId, root.activePopout)
      ? root.activePopout : (root.activePopout ? api.foreignPopoutMarker : null)
    api.clickTargets = root.pluginClickTargets(api.pluginId)
    api.layoutConfig = root.publicLayoutConfig()
  }

  function pluginObjectRecord(target) {
    return pluginObjectOwners.find(function(record) { return record && record.target === target }) || null
  }

  function markPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    if (!key || !target) return false
    var record = root.pluginObjectRecord(target)
    if (record && record.pluginId !== key) return false
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var existing = pluginObjectOwners[i]
      if (!existing || existing.target !== target) next.push(existing)
    }
    var updated = record || { target: target, pluginId: key, clickTarget: false, popout: false }
    updated[role] = true
    next.push(updated)
    pluginObjectOwners = next
    return true
  }

  function unmarkPluginObject(pluginId, target, role) {
    var key = String(pluginId || "")
    var next = []
    for (var i = 0; i < pluginObjectOwners.length; i++) {
      var record = pluginObjectOwners[i]
      if (!record || record.target !== target || record.pluginId !== key) {
        next.push(record)
        continue
      }
      record[role] = false
      if (record.clickTarget || record.popout) next.push(record)
    }
    pluginObjectOwners = next
  }

  function pluginOwnsBarObject(pluginId, target) {
    var record = target ? root.pluginObjectRecord(target) : null
    return !!record && record.pluginId === String(pluginId || "")
  }

  function pluginClickTargets(pluginId) {
    return root.clickTargets.filter(function(target) { return root.pluginOwnsBarObject(pluginId, target) })
  }

  function syncAllPluginBarApiObjects() {
    for (var id in pluginBarApis) root.syncPluginBarApiObjects(pluginBarApis[id])
  }

  function registerPluginClickTarget(pluginId, target) {
    if (!root.markPluginObject(pluginId, target, "clickTarget")) return
    root.registerClickTarget(target)
  }

  function unregisterPluginClickTarget(pluginId, target) {
    if (!root.pluginOwnsBarObject(pluginId, target)) return
    root.unregisterClickTarget(target)
    root.unmarkPluginObject(pluginId, target, "clickTarget")
  }

  function requestPluginPopout(pluginId, owner) {
    if (!root.markPluginObject(pluginId, owner, "popout")) return
    root.requestPopout(owner)
  }

  function releasePluginPopout(pluginId, owner) {
    if (!root.pluginOwnsBarObject(pluginId, owner)) return
    root.releasePopout(owner)
    root.unmarkPluginObject(pluginId, owner, "popout")
  }

  function pluginBarApiFor(pluginId, moduleName, registered) {
    var key = String(pluginId || "")
    if (!key) return null

    var pluginShell = null
    if (registered && root.shell && typeof root.shell.pluginShellForId === "function") {
      // Only the trusted built-in bar receives ShellRoot and can request a
      // service-capable facade for the widget it is instantiating.
      pluginShell = root.shell.pluginShellForId(moduleName)
    } else if (root.shell && typeof root.shell.pluginShellForBarEntry === "function") {
      // Replacement bars receive a service-less entry facade. Giving an
      // untrusted bar a generic facade factory would let it retrieve another
      // third-party plugin's live service object.
      pluginShell = root.shell.pluginShellForBarEntry(key, moduleName)
    }

    if (pluginBarApis[key]) {
      pluginBarApis[key].shell = pluginShell
      return pluginBarApis[key]
    }

    var api = pluginBarApiComponent.createObject(null, {
      pluginId: key,
      moduleName: String(moduleName || ""),
      shell: pluginShell,
      _showTooltip: function(target, text) { root.showTooltip(target, text) },
      _hideTooltip: function(target) { root.hideTooltip(target) },
      _registerClickTarget: function(target) { root.registerPluginClickTarget(key, target) },
      _unregisterClickTarget: function(target) { root.unregisterPluginClickTarget(key, target) },
      _requestPopout: function(owner) { root.requestPluginPopout(key, owner) },
      _releasePopout: function(owner) { root.releasePluginPopout(key, owner) },
      _switchPanelFrom: function(owner, direction) { return root.switchPanelFrom(owner, direction) },
      _targetBelongsToWindow: function(target, window) { return root.targetBelongsToWindow(target, window) },
      _moduleWidgets: function(requestedId) {
        return String(requestedId || "") === String(moduleName || "")
          ? root.moduleWidgets(moduleName) : []
      },
      _run: function(command) { root.run(command) },
      _setCenterHoverRevealSuppressed: function(value) {
        root.centerHoverRevealSuppressed = !!value
      }
    })
    if (!api) return null
    root.bindPluginBarApi(api)

    var next = ({})
    for (var id in pluginBarApis) next[id] = pluginBarApis[id]
    next[key] = api
    pluginBarApis = next
    return api
  }

  function pluginBarApiUsed(pluginId) {
    return moduleSlots.some(function(slot) { return slot && slot.pluginApiId === pluginId })
  }

  function releasePluginObjects(pluginId) {
    var owned = pluginObjectOwners.slice()
    for (var i = 0; i < owned.length; i++) {
      var record = owned[i]
      if (!record || record.pluginId !== pluginId) continue
      if (record.clickTarget) root.unregisterClickTarget(record.target)
      if (record.popout && root.activePopout === record.target) root.releasePopout(record.target)
    }
    pluginObjectOwners = pluginObjectOwners.filter(function(record) {
      return record && record.pluginId !== pluginId
    })
  }

  function prunePluginBarApis() {
    var next = ({})
    for (var id in pluginBarApis) {
      var api = pluginBarApis[id]
      if (root.pluginBarApiUsed(id)) {
        next[id] = api
        continue
      }
      root.releasePluginObjects(id)
      if (api && typeof api.destroy === "function") api.destroy()
    }
    pluginBarApis = next
  }

  onActivePopoutChanged: syncAllPluginBarApiObjects()
  onClickTargetsChanged: syncAllPluginBarApiObjects()
  onLayoutConfigChanged: syncAllPluginBarApiObjects()
  Timer { id: pruneTimer; interval: 0; onTriggered: root.prunePluginBarApis() }
  onModuleSlotsChanged: pruneTimer.restart()

  Component.onDestruction: {
    for (var motion of controlMotions) if (motion) motion.detach()
    controlMotions = []
    for (var id in pluginBarApis) {
      root.releasePluginObjects(id)
      if (pluginBarApis[id] && typeof pluginBarApis[id].destroy === "function")
        pluginBarApis[id].destroy()
    }
    pluginBarApis = ({})
  }

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
    if (target instanceof WidgetButton) {
      var motion = interactionMotionComponent.createObject(root, {parent:target, control:target})
      if (motion) controlMotions = controlMotions.concat([motion])
    }
  }

  function unregisterClickTarget(target) {
    controlMotions = controlMotions.filter(function(motion) {
      if (!motion) return false
      if (motion.control !== target) return true
      motion.detach()
      motion.destroy()
      return false
    })
    var next = clickTargets.filter(function(item) { return item !== target })
    clickTargets = next
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    var next = moduleSlots.filter(function(item) { return item !== slot })
    moduleSlots = next
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    pendingTooltipClock.stop()
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function clearBarDrag() {
    barDragSource = null
    barDragWindow = null
    barDragScreen = null
    barDragImageUrl = ""
    barDragTarget = null
    barDragTargetGeometry = null
    barDragAfter = false
    barDragScreenX = 0
    barDragScreenY = 0
    barDragOffsetX = 0
    barDragOffsetY = 0
  }

  function windowScreenPoint(scenePoint, window) {
    var x = scenePoint ? scenePoint.x : 0
    var y = scenePoint ? scenePoint.y : 0
    if (!window || !window.screen) return { x: x, y: y }

    if (root.position === "bottom")
      y += Math.max(0, window.screen.height - window.height)
    else if (root.position === "right")
      x += Math.max(0, window.screen.width - window.width)

    return { x: x, y: y }
  }

  function barDragScreenPoint(scenePoint) {
    return windowScreenPoint(scenePoint, barDragWindow)
  }

  function dropMarkerRect(slot, after) {
    var rect=drawnSlotRect(slot)
    if(!rect)return null
    var point=barDragScreenPoint({x:rect.x,y:rect.y})
    var thickness=Style.spacing.xs
    return vertical
      ? {x:point.x,y:point.y+(after ? rect.height : 0)-thickness/2,width:rect.width,height:thickness}
      : {x:point.x+(after ? rect.width : 0)-thickness/2,y:point.y,width:thickness,height:rect.height}
  }

  // Split the screen along its diagonals (in normalized space, so widescreens
  // don't bias toward left/right): whichever triangle holds the cursor names
  // the candidate edge.
  function nearestScreenEdge(point, screen) {
    var nx = screen.width > 0 ? Util.clamp(point.x / screen.width, 0, 1) : 0.5
    var ny = screen.height > 0 ? Util.clamp(point.y / screen.height, 0, 1) : 0.5

    var edge = "top"
    var best = ny
    if (1 - ny < best) { edge = "bottom"; best = 1 - ny }
    if (nx < best) { edge = "left"; best = nx }
    if (1 - nx < best) { edge = "right"; best = 1 - nx }
    return edge
  }

  function beginBarMove(window) {
    barMoveWindow = window
    barMoveScreen = window ? window.screen : null
    barMoveCandidate = position
    barMoveActive = true
  }

  function updateBarMove(screenPoint) {
    if (!barMoveActive || !barMoveScreen) return
    barMoveCandidate = nearestScreenEdge(screenPoint, barMoveScreen)
  }

  function clearBarMove() {
    barMoveActive = false
    barMoveCandidate = ""
    barMoveWindow = null
    barMoveScreen = null
  }

  function finishBarMove() {
    var edge = barMoveCandidate
    if (!barMoveActive || !edge || edge === position) {
      clearBarMove()
      return
    }

    clearBarMove()
    setBarPosition(edge)
  }

  function setBarPosition(value) {
    var next = normalizePosition(value)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.position = next
      })
    } else {
      root.position = next
    }
  }

  function captureBarDragGhost(slot) {
    var item = slot && slot.activeItem ? slot.activeItem : null
    barDragImageUrl = ""
    if (!item || typeof item.grabToImage !== "function") return

    var grabWidth = Math.max(1, Math.ceil(item.width || item.implicitWidth || slot.width || 1))
    var grabHeight = Math.max(1, Math.ceil(item.height || item.implicitHeight || slot.height || 1))
    item.grabToImage(function(result) {
      if (root.barDragSource !== slot || !result || !result.url) return
      root.barDragImageUrl = result.url
    }, Qt.size(grabWidth, grabHeight))
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  readonly property bool vertical: position === "left" || position === "right"
  readonly property real densityUnit: prismSettings.thickness / 8
  readonly property real barCrossPadding: Math.max(densityUnit, prismSettings.outlineWidth + 2)
  readonly property real pillHorizontalPadding: 2 * densityUnit
  readonly property int barSize: Math.ceil(Math.max(18, prismSettings.thickness - 2 * barCrossPadding,
    prismSettings.iconSize + densityUnit, prismSettings.fontSize + 2 * densityUnit))
  readonly property real nativeCrossExtent: {
    var extent = barSize
    for (var i=0;i<moduleSlots.length;i++) {
      var item = moduleSlots[i].activeItem
      var native = item && item.visible ? (root.vertical ? item.implicitWidth : item.implicitHeight) : 0
      if(typeof native === "number" && isFinite(native))extent=Math.max(extent,native)
    }
    return extent
  }
  readonly property color islandBaseColor: prismSettings.background === "theme" ? Color.bar.background : prismSettings.color
  readonly property real islandOpacity: barConfig.transparent === true ? prismSettings.transparentOpacity : prismSettings.opacity
  readonly property color islandColor: Qt.rgba(islandBaseColor.r,islandBaseColor.g,islandBaseColor.b,islandOpacity)
  readonly property color islandBorder: Qt.rgba(themeForeground.r,themeForeground.g,themeForeground.b,prismSettings.outlineOpacity)
  readonly property real islandBorderWidth: prismSettings.outlineWidth
  readonly property int islandEdgeGap: prismSettings.mode === "docked" ? 0 : prismSettings.edgeGap
  readonly property real islandThickness: Math.max(barSize,nativeCrossExtent) + 2 * barCrossPadding
  readonly property real islandRadius: Math.min(prismSettings.radius,islandThickness/2)
  readonly property real barWindowSize: islandEdgeGap+islandThickness
  readonly property int prismDuration: !prismSettings.motionEnabled || prismSettings.reducedMotion ? 0
    : Math.round(prismSettings.transitionDuration * (prismSettings.animationIntensity === "expressive" ? 1.5 : 1))
  onPrismSettingsChanged: {
    foregroundAnimationEnabled = prismSettings.motionEnabled && !prismSettings.reducedMotion
    updateGeometrySettings()
  }
  readonly property var selectedScreens: {
    var screens=Quickshell.screens
    if(prismSettings.display === "all")return screens
    var matching=[]
    for(var i=0;i<screens.length;i++)if(screens[i].name===prismSettings.display)matching.push(screens[i])
    return matching.length ? matching : screens
  }
  property var barPanels: []
  function registerBarPanel(panel) { barPanels=barPanels.concat([panel]) }
  function unregisterBarPanel(panel) { barPanels=barPanels.filter(function(p){return p!==panel}) }

  function equalSettingsValue(a,b) {
    if(a===b)return true
    if(!a || !b || typeof a!=="object" || typeof b!=="object" || Array.isArray(a)!==Array.isArray(b))return false
    var keys=Object.keys(a)
    if(keys.length!==Object.keys(b).length)return false
    for(var i=0;i<keys.length;i++)if(!Object.prototype.hasOwnProperty.call(b,keys[i]) || !equalSettingsValue(a[keys[i]],b[keys[i]]))return false
    return true
  }
  function savedSettingValue(kind,key,value,source) {
    var config = arguments.length > 3 ? (source || {}) : barConfig
    if(kind==="prism")return SettingsModel.isPlainObject(config.prism) ? config.prism[key] : undefined
    if(kind==="spacing" || kind==="patch") {
      var current=SettingsModel.normalizeSettings(config.prism), values={}
      for(var field of Object.keys(value))values[field]=current[field]
      return values
    }
    return kind==="layout" ? normalizeLayout(config.layout) : config[key]
  }
  function removePrismPreview(key) {
    var next=Object.assign({},prismPreview)
    delete next[key]
    prismPreview=next
  }
  function confirmSettingsWrite() {
    var pending=pendingSettingsWrite
    if(!pending || !diskBarConfig || diskBarConfig.id!=="voyagen.prism"
      || !equalSettingsValue(savedSettingValue(pending.kind,pending.key,pending.value,diskBarConfig),pending.value)
      || !equalSettingsValue(savedSettingValue(pending.kind,pending.key,pending.value),pending.value))return
    settingsWriteDeadline.stop()
    pendingSettingsWrite=null
    if(pending.kind==="prism")removePrismPreview(pending.key)
    if(pending.kind==="spacing" || pending.kind==="patch")cancelPrismPreview()
    settingsError=""
  }
  function writeSettingsValue(kind,key,value) {
    settingsError=""
    if(!canSavePrismSettings){settingsError="This shell does not expose active-bar configuration mutation.";return false}
    if(settingsWritePending){settingsError="Wait for the previous configuration write to be confirmed.";return false}
    if(diskBarConfig && equalSettingsValue(savedSettingValue(kind,key,value),value)
       && equalSettingsValue(savedSettingValue(kind,key,value,diskBarConfig),value)) {
      if(kind==="prism")removePrismPreview(key)
      if(kind==="spacing" || kind==="patch")cancelPrismPreview()
      return true
    }
    try {
      var snapshot=JSON.parse(JSON.stringify(value))
      pendingSettingsWrite={kind:kind,key:key,value:kind==="layout" ? normalizeLayout(snapshot) : snapshot}
      diskBarConfig = null
      settingsWriteDeadline.restart()
      var accepted=shell.mutateShellConfig(function(config) {
        if(!SettingsModel.isPlainObject(config.bar) || config.bar.id!=="voyagen.prism")throw new Error("Prism is no longer the active bar.")
        if(kind==="prism" || kind==="spacing" || kind==="patch") {
          if(!SettingsModel.isPlainObject(config.bar.prism))config.bar.prism={}
          if(config.bar.prism.mode==="floating")config.bar.prism.mode="islands"
          if(kind==="spacing" || kind==="patch")for(var field of Object.keys(snapshot))config.bar.prism[field]=snapshot[field]
          else config.bar.prism[key]=snapshot
        } else if(kind==="layout") {
          if(!SettingsModel.isPlainObject(config.bar.layout))config.bar.layout={}
          for(var section of ["left","center","right"])config.bar.layout[section]=snapshot[section]
        } else config.bar[key]=snapshot
      })
      savedConfigFile.reload()
      if(accepted===false && settingsWritePending)throw new Error("The shell rejected the configuration mutation.")
      return true
    } catch(error) {
      settingsWriteDeadline.stop()
      pendingSettingsWrite=null
      settingsError=String(error)
      cancelPrismPreview()
      return false
    }
  }
  function commitPrismSetting(key,value) {
    var result=SettingsModel.normalizeSetting(key,value)
    if(!result.valid){settingsError=result.error;return false}
    return writeSettingsValue("prism",key,result.value)
  }
  function commitSpacingPreset(name) {
    if(!Object.prototype.hasOwnProperty.call(SettingsModel.spacingPresets,name)) {
      settingsError="Unknown spacing preset: "+name
      return false
    }
    return writeSettingsValue("spacing","",SettingsModel.spacingPresets[name])
  }
  function commitPrismPatch(patch) {
    if(!SettingsModel.isPlainObject(patch)){settingsError="Settings patch must be an object.";return false}
    var values = {}
    for(var key of Object.keys(patch)) {
      var checked = SettingsModel.normalizeSetting(key,patch[key])
      if(!checked.valid){settingsError=checked.error;return false}
      values[key]=checked.value
    }
    return writeSettingsValue("patch","",values)
  }
  function resetPrismGroup(group) {
    var iconKeys = ["iconPack","iconSize","tintPolicy","semanticOverrides","widgetOverrides","fontFamily","fontSize"]
    if(group!=="appearance" && group!=="icons"){settingsError="Unknown settings reset group.";return false}
    var patch = {}
    for(var key of Object.keys(SettingsModel.defaults))
      if((iconKeys.indexOf(key)>=0)===(group==="icons"))patch[key]=SettingsModel.defaults[key]
    return commitPrismPatch(patch)
  }
  function previewPrismSetting(key,value) {
    var result=SettingsModel.normalizeSetting(key,value)
    if(!result.valid){settingsError=result.error;return false}
    var next=Object.assign({},prismPreview)
    next[key]=result.value
    prismPreview=next
    return true
  }
  function cancelPrismPreview() { if(Object.keys(prismPreview).length)prismPreview=({}) }
  function commitHostSetting(key,value) {
    if(key==="position" && ["top","bottom","left","right"].indexOf(value)<0 ||
       key==="transparent" && typeof value!=="boolean" ||
       key==="centerAnchor" && typeof value!=="string" ||
       ["position","transparent","centerAnchor"].indexOf(key)<0) {
      settingsError="Invalid host bar field or value: "+key
      return false
    }
    return writeSettingsValue("host",key,key==="centerAnchor" ? canonicalWidgetId(value) : value)
  }
  function commitLayout(layout) {
    if(!SettingsModel.isPlainObject(layout)){settingsError="Layout must be a plain object.";return false}
    for(var section of ["left","center","right"]) {
      if(!Array.isArray(layout[section])){settingsError="Layout "+section+" must be an array.";return false}
      for(var entry of layout[section]) {
        if(!(typeof entry==="string" && entry.trim()!=="" ||
             SettingsModel.isPlainObject(entry) && typeof entry.id==="string" && entry.id.trim()!=="")) {
          settingsError="Layout contains an invalid entry in "+section
          return false
        }
      }
    }
    return writeSettingsValue("layout","layout",layout)
  }
  function openPrismSettings(anchorItem) {
    if(barHidden){settingsError="Show the bar before opening its settings.";return false}
    var anchor=anchorItem
    if(!anchor) {
      var focused=focusedScreenName(), panel=null
      for(var candidate of barPanels)
        if(candidate.screen && candidate.screen.name===focused){panel=candidate;break}
      if(!panel && barPanels.length)panel=barPanels[0]
      if(panel)anchor=panel.settingsButton || panel.surface
    }
    if(!anchor){settingsError="No selected bar window is available.";return false}
    prismPanel.anchorItem=anchor
    prismPanel.open()
    return true
  }
  function canConfigurePrismWidget(widgetId) {
    var metadata=barWidgetRegistry.metadataFor(canonicalWidgetId(widgetId))
    if(metadata && SettingsModel.supportedSchemaFields(metadata.schema).length>0)return true
    return moduleWidgets(widgetId).some(function(item){return typeof item.openSettings==="function"})
  }
  function openWidgetConfiguration(widgetId) {
    var metadata=barWidgetRegistry.metadataFor(canonicalWidgetId(widgetId))
    if(metadata && SettingsModel.supportedSchemaFields(metadata.schema).length>0)
      return prismPanel.openSchemaConfiguration(widgetId)
    for(var item of moduleWidgets(widgetId))if(typeof item.openSettings==="function") {
      prismPanel.close()
      item.openSettings()
      return true
    }
    settingsError="This widget has no public settings schema or configuration action; use Advanced inline JSON."
    return false
  }
  readonly property var availablePrismWidgets: {
    var widgets=barWidgetRegistry.widgets, result=[]
    for(var id of Object.keys(widgets).sort()) {
      if(!widgets[id] || !widgets[id].component || id==="akshit.island")continue
      var metadata=barWidgetRegistry.metadataFor(id) || {}
      result.push({id:id,name:metadata.displayName || id,metadata:metadata})
    }
    return result
  }
  readonly property var settingsDiagnostics: {
    var rows=[], counts=Object.create(null), records=icons.records, issues=icons.diagnostics
    for(var issue of SettingsModel.diagnostics(barConfig.prism))
      rows.push({context:issue.key,status:"invalid",detail:issue.error+" · Effective: "+(issue.effective===undefined ? "ignored" : JSON.stringify(issue.effective))})
    for(var record of records) {
      var problem=issues.find(function(issue){return issue.target===record.target && issue.glyph===record.glyph})
      if(!record.glyph && !problem)continue
      rows.push({context:record.widgetId,widgetId:record.widgetId,glyph:record.glyph,semantic:record.semantic,source:record.source,
        section:record.slot ? record.slot.region || "" : "",screen:record.slot ? slotScreenName(record.slot) : "",
        status:problem ? (problem.reason==="Existing custom iconComponent retained" ? "supported" : "partial") : record.adapted ? "supported" : "unmapped",
        detail:problem ? problem.reason : record.semantic || "Original surface retained"})
    }
    for(var issue of issues)if(!records.some(function(record){return issue.target===record.target && issue.glyph===record.glyph}))
      rows.push({context:issue.widgetId,widgetId:issue.widgetId,glyph:issue.glyph || "",semantic:issue.semantic || "",source:issue.source || "",
        section:issue.slot ? issue.slot.region || "" : "",screen:issue.slot ? slotScreenName(issue.slot) : "",status:"partial",detail:issue.reason})
    for(var section of ["left","center","right"])for(var entry of layoutEntries(section)) {
      var id=canonicalWidgetId(entryId(entry))
      counts[id]=(counts[id] || 0)+1
      if(!customModuleType(entry) && !Object.prototype.hasOwnProperty.call(barWidgetRegistry.widgets,id))
        rows.push({context:id,status:"missing",detail:"No enabled registry component; saved entry retained in "+section})
    }
    for(var id of Object.keys(counts)) {
      var metadata=barWidgetRegistry.metadataFor(id)
      if(counts[id]>1 && metadata && metadata.allowMultiple===false)rows.push({context:id,status:"duplicate",detail:"Existing single-instance duplicates retained; remove explicitly in Layout."})
    }
    if(prismSettings.display!=="all" && !Array.from(Quickshell.screens).some(function(screen){return screen.name===root.prismSettings.display}))
      rows.push({context:"display",status:"fallback",detail:"Selected display is unavailable; rendering on all current displays."})
    rows.push({context:"geometry",status:"effective",detail:"Requested "+prismSettings.thickness+"px; effective "+islandThickness+"px; reserved "+(prismSettings.reserveSpace && !barHidden ? barWindowSize : 0)+"px; radius "+islandRadius+"px."})
    for(var panel of barPanels)for(var detail of panel.surface.geometry.diagnostics)rows.push({context:panel.screen ? panel.screen.name : "display",status:"constrained",detail:detail})
    return rows
  }

  function normalizePosition(value) {
    return BarModel.normalizePosition(value)
  }

  // Normalize entry shapes without changing the user's order or inline data.
  function normalizeLayout(layout) {
    return Util.normalizeLayout(Util.isPlainObject(layout) ? layout : fallbackBarConfig.layout)
  }

  function applyBarConfig() {
    confirmSettingsWrite()
    var config = Util.isPlainObject(barConfig) ? barConfig : fallbackBarConfig

    position = normalizePosition(config.position)
    setRequestedTransparency(config.transparent === true)
    centerAnchor = Util.canonicalWidgetId(config.centerAnchor || "")

    // layoutEntries feeds plain JS arrays to the module Repeaters, and QML
    // cannot diff those: reassigning layoutConfig rebuilds every widget on
    // every monitor. When a shell.json write only changed inline widget
    // settings, patch the live layout and running widgets in place instead.
    var next = normalizeLayout(config.layout)
    var delta = BarModel.inlineSettingsDelta(layoutConfig, next)
    if (delta) {
      applySettingsDelta(delta)
      return
    }
    layoutConfig = next
    barConfigSerial++
  }

  function applySettingsDelta(delta) {
    for (var i = 0; i < delta.length; i++) {
      var change = delta[i]
      layoutConfig[change.region][change.index] = change.entry
      var settings = entrySettings(change.entry)
      for (var s = 0; s < moduleSlots.length; s++) {
        var slot = moduleSlots[s]
        if (!slot || slot.region !== change.region || slot.moduleName !== entryId(change.entry)) continue
        var item = slot.activeItem
        if (item && "settings" in item) item.settings = settings
      }
    }
  }

  onBarConfigChanged: applyBarConfig()

  function layoutEntries(region) {
    var serial = barConfigSerial
    var entries = layoutConfig ? layoutConfig[region] : null
    return Array.isArray(entries) ? entries : []
  }

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var entries = layoutEntries(region)
    var slots = []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      for (var j = 0; j < moduleSlots.length; j++) {
        var slot = moduleSlots[j]
        if (!slot || slot.region !== region || slot.moduleName !== id) continue
        if (window && !sameWindow(slotWindow(slot), window)) continue
        var item = slot.activeItem
        if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
        if(!drawnSlotRect(slot))continue
        if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
        slots.push(slot)
        break
      }
    }
    return slots
  }
  function drawnSlotRect(slot) {
    if(!slot || !slot.visible || slot.width<=0 || slot.height<=0)return null
    try {
      var point=slot.mapToItem(null,0,0)
      var rect={x:point.x,y:point.y,width:slot.width,height:slot.height}
      for(var parent=slot.parent;parent;parent=parent.parent) {
        if(!parent.visible)return null
        if(!parent.clip)continue
        var origin=parent.mapToItem(null,0,0)
        rect=BarModel.intersectRect(rect,{x:origin.x,y:origin.y,width:parent.width,height:parent.height})
        if(!rect)return null
      }
      return rect
    } catch(error) { return null }
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth layout entry.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  //
  // Counting any bar surface is enough: every monitor lays its bar out from the
  // one layout, and summoning the id routes through pickPanelSlot, which opens
  // the focused monitor's copy whichever surface was counted.
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = slots.indexOf(currentSlot)
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // The output Hyprland has focused, which is where a keyboard-summoned panel
  // belongs. Empty until Hyprland reports one, which leaves panel routing on
  // its per-monitor fallback rather than guessing at an output.
  function focusedScreenName() {
    var monitor = Hyprland.focusedMonitor
    return monitor ? String(monitor.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id (e.g. "omarchy.bluetooth").
  // Only widgets that expose popup open/close methods count; plain indicators
  // (clock, workspaces, tray) return null. Used by shell.summon/toggle so
  // panel hotkeys route through the bar instead of a per-target IPC handler
  // that only reaches whichever per-monitor instance claimed the target.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      if (slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, focusedScreenName())
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.open !== "function") return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item || typeof item.close !== "function") return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  function entrySettings(entry) {
    return BarModel.entrySettings(entry)
  }

  function entryId(entry) {
    return BarModel.entryId(entry)
  }

  function entryIndex(entries, name) {
    return BarModel.entryIndex(entries, name)
  }


  function canonicalWidgetId(name) {
    return Util.canonicalWidgetId(name)
  }

  function customModuleType(entry) {
    return BarModel.customModuleType(entry)
  }

  function customModuleSource(entry) {
    var source = BarModel.customModulePath(entry, home, omarchyConfigDir)
    return source ? Util.fileUrl(source) : ""
  }

  Component.onCompleted: { updateGeometrySettings(); applyBarConfig() }

  // Revealing the indicators widens their section, which can slide a neighbour
  // under a stationary pointer. Collapsing on that un-hover would move it back
  // out and re-open the peek, so hold until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  function setCenterHoverRevealSuppressed(value) {
    centerHoverRevealSuppressed = !!value
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // Collapse only. Opening the peek is the center section's own gesture, done
    // in setCenterSectionHovered, so a timer left pending by a pointer that dipped
    // off the bar and came back cannot reveal indicators it never pointed at.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function toggleTransparency() {
    var nextTransparent = !(root.requestedTransparent === true)
    if (root.shell && typeof root.shell.mutateShellConfig === "function") {
      root.shell.mutateShellConfig(function(config) {
        if (!Util.isPlainObject(config.bar)) config.bar = {}
        config.bar.transparent = nextTransparent
      })
    } else {
      root.setRequestedTransparency(nextTransparent)
    }
  }

  function rawLayoutSection(config, region) {
    if (!Util.isPlainObject(config.bar)) config.bar = {}
    if (!Util.isPlainObject(config.bar.layout)) config.bar.layout = {}
    if (!Array.isArray(config.bar.layout[region])) config.bar.layout[region] = []

    return config.bar.layout[region]
  }

  function moveModuleInConfig(config, fromRegion, fromName, toRegion, beforeName) {
    var fromEntries = rawLayoutSection(config, fromRegion)
    var toEntries = rawLayoutSection(config, toRegion)
    var fromIndex = entryIndex(fromEntries, fromName)
    if (fromIndex < 0) return false

    var toIndex = beforeName ? entryIndex(toEntries, beforeName) : toEntries.length
    if (toIndex < 0) toIndex = toEntries.length

    if (fromRegion === toRegion && fromIndex === toIndex) return false

    var movedEntry = fromEntries[fromIndex]
    fromEntries.splice(fromIndex, 1)

    if (fromRegion === toRegion && fromIndex < toIndex) toIndex -= 1
    if (toIndex < 0) toIndex = 0
    if (toIndex > toEntries.length) toIndex = toEntries.length
    if (fromRegion === toRegion && fromIndex === toIndex) {
      fromEntries.splice(fromIndex, 0, movedEntry)
      return false
    }

    toEntries.splice(toIndex, 0, movedEntry)
    return true
  }

  function dropBarModule(source, toRegion, beforeName) {
    if (!source || !source.region || !source.moduleName || !toRegion) return false
    if (source.region === toRegion && source.moduleName === beforeName) return false
    if (!root.shell || typeof root.shell.mutateShellConfig !== "function") return false

    var changed = false
    root.shell.mutateShellConfig(function(config) {
      changed = moveModuleInConfig(config, source.region, source.moduleName, toRegion, beforeName)
    })
    return changed
  }

  function moduleDropAtScene(scenePoint, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    if (sourceWindow && sourceWindow.contentItem) {
      var barPoint = sourceWindow.contentItem.mapFromItem(null, scenePoint.x, scenePoint.y)
      if (barPoint.x < 0 || barPoint.x > sourceWindow.contentItem.width ||
          barPoint.y < 0 || barPoint.y > sourceWindow.contentItem.height)
        return null
    }

    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue

      var rect=drawnSlotRect(slot)
      if(!rect)continue
      candidates.push({slot:slot,x:rect.x,y:rect.y,width:rect.width,height:rect.height})
    }

    return BarModel.nearestDropTarget(candidates, scenePoint, root.vertical)
  }

  function visibleModuleSlot(region, name, sourceSlot) {
    var sourceWindow = root.slotWindow(sourceSlot) || root.barDragWindow
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot === sourceSlot || slot.region !== region || slot.moduleName !== name ||
          !slot.visible || slot.width <= 0 || slot.height <= 0) continue
      if (sourceWindow && !root.sameWindow(root.slotWindow(slot), sourceWindow)) continue
      if(!drawnSlotRect(slot))continue
      return slot
    }

    return null
  }

  function nextVisibleModuleName(region, afterName, sourceSlot) {
    var entries = layoutEntries(region)
    var found = false
    for (var i = 0; i < entries.length; i++) {
      var name = entryId(entries[i])
      if (!found) {
        found = name === afterName
        continue
      }

      if (visibleModuleSlot(region, name, sourceSlot)) return name
    }

    return ""
  }

  function dropBarModuleAtTarget(sourceSlot, targetSlot, afterTarget) {
    if (!sourceSlot || !targetSlot) return false

    var beforeName = afterTarget ? nextVisibleModuleName(targetSlot.region, targetSlot.moduleName, sourceSlot) : targetSlot.moduleName
    return dropBarModule(sourceSlot, targetSlot.region, beforeName)
  }

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }

  function colorHex(colorValue) {
    var c = colorValue
    if (typeof c === "string") c = Qt.color(c)
    function hexChannel(value) {
      var s = Math.round(Util.clamp(value, 0, 1) * 255).toString(16)
      return s.length < 2 ? "0" + s : s
    }
    return "#" + hexChannel(c.r) + hexChannel(c.g) + hexChannel(c.b)
  }

  function setRequestedTransparency(value) {
    var nextTransparent = value === true
    requestedTransparent = nextTransparent
    if (!nextTransparent) {
      foregroundAnimationEnabled = false
      useTransparentForeground = false
      transparent = false
      transparentForeground = themeForeground
      restoreForegroundAnimation()
      return
    }
    scheduleTransparentForegroundRefresh()
  }

  Timer {
    id: foregroundRestore
    interval: 0
    repeat: true
    property int remaining: 0
    onTriggered: {
      if (--remaining <= 0) {
        stop()
        root.foregroundAnimationEnabled = root.prismSettings.motionEnabled && !root.prismSettings.reducedMotion
      }
    }
  }
  function restoreForegroundAnimation() {
    foregroundRestore.remaining = 2
    foregroundRestore.restart()
  }

  function scheduleTransparentForegroundRefresh() {
    if (!requestedTransparent) {
      transparentForeground = themeForeground
      return
    }
    transparentForegroundTimer.restart()
  }

  function refreshTransparentForeground() {
    if (!requestedTransparent || transparentForegroundProc.running) return

    transparentForegroundProc.command = [
      "omarchy-bar-text-color",
      root.position,
      String(root.barSize),
      colorHex(root.themeForeground),
      colorHex(root.themeContrastForeground)
    ]
    transparentForegroundProc.running = true
  }

  onRequestedTransparentChanged: scheduleTransparentForegroundRefresh()
  onPositionChanged: scheduleTransparentForegroundRefresh()
  onThemeForegroundChanged: scheduleTransparentForegroundRefresh()
  onThemeContrastForegroundChanged: scheduleTransparentForegroundRefresh()

  Timer {
    id: transparentForegroundTimer
    interval: 120
    repeat: false
    onTriggered: root.refreshTransparentForeground()
  }

  Process {
    id: transparentForegroundProc
    stdout: SplitParser {
      onRead: function(line) {
        var value = String(line || "").trim()
        if (!/^#[0-9A-Fa-f]{6}$/.test(value)) return

        root.foregroundAnimationEnabled = false
        root.transparentForeground = value
        if (root.requestedTransparent) {
          root.useTransparentForeground = true
          root.transparent = true
        }
        root.restoreForegroundAnimation()
      }
    }
  }

  FileView {
    path: root.stateHome + "/omarchy/current"
    watchChanges: true
    printErrors: false
    onFileChanged: root.scheduleTransparentForegroundRefresh()
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  Timer {
    id: pendingTooltipClock
    interval: 0
    onTriggered: {
      if (!root.targetTooltipHovered(root.pendingTooltipTarget)) {
        root.clearTooltip()
        return
      }
      root.tooltipTarget = root.pendingTooltipTarget
      root.tooltipText = root.pendingTooltipText
      root.pendingTooltipTarget = null
      root.pendingTooltipText = ""
      tooltipTimer.restart()
    }
  }
  function showTooltip(target, text) {
    clearTooltip()
    if (!targetTooltipHovered(target) || !text) return
    pendingTooltipTarget = target
    pendingTooltipText = text
    pendingTooltipClock.restart()
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // Presence of the `bar-off` flag = bar hidden. Watching the parent toggles
  // directory because FileView can't observe a file that doesn't exist yet,
  // and the flag is created/removed by `omarchy-toggle-bar`.
  Process {
    id: barHiddenProbe
    running: true
    command: ["bash", "-c", "[[ -f $HOME/.local/state/omarchy/toggles/bar-off ]] && echo yes || echo no"]
    stdout: SplitParser { onRead: function(line) { root.barHidden = String(line).trim() === "yes" } }
  }
  FileView {
    path: root.home + "/.local/state/omarchy/toggles"
    watchChanges: true
    printErrors: false
    onFileChanged: barHiddenProbe.running = true
  }

  // The directory watch can permanently stop delivering events after flag
  // changes land in quick succession, stranding the bar off screen until the
  // shell restarts. `omarchy-toggle-bar` nudges this after flipping the flag
  // so the probe re-reads it even when the watch has gone quiet.
  IpcHandler {
    target: "omarchy.bar"

    // Start rather than restart: a probe already in flight was launched by the
    // directory watch after the flag flipped, so its answer is current, and
    // killing it here can swallow the result entirely.
    function syncHidden(): void {
      barHiddenProbe.running = true
    }
  }

  Variants {
    model: root.selectedScreens

    delegate: Component {
      BarSurface {
        required property var modelData
        controller: root

        screen: modelData
      }
    }
  }

  Variants {
    model: root.selectedScreens

    delegate: Component {
      DragGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }

  Variants {
    model: root.selectedScreens

    delegate: Component {
      BarMoveGhostPanel {
        required property var modelData

        screen: modelData
        ghostScreen: modelData
      }
    }
  }



  component DragGhostPanel: PanelWindow {
    id: ghostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barDragScreen === ghostScreen ||
      (root.barDragScreen && ghostScreen && root.barDragScreen.name && ghostScreen.name && root.barDragScreen.name === ghostScreen.name)
    readonly property bool active: root.barDragSource && root.barDragScreen && screenMatches
    readonly property var sourceItem: root.barDragSource ? root.barDragSource.activeItem : null
    readonly property int ghostPadding: Style.space(1)
    readonly property int ghostWidth: sourceItem ? Math.max(1, Math.ceil(sourceItem.width)) : 1
    readonly property int ghostHeight: sourceItem ? Math.max(1, Math.ceil(sourceItem.height)) : 1

    visible: active && sourceItem !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-drag-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only drag feedback. Keep the input region empty so the ghost can
    // sit under the cursor without stealing the MouseArea's active pointer grab.
    mask: Region {}

    Item {
      visible: ghostWindow.visible
      x: Math.round(root.barDragScreenX - root.barDragOffsetX - ghostWindow.ghostPadding)
      y: Math.round(root.barDragScreenY - root.barDragOffsetY - ghostWindow.ghostPadding)
      width: ghostWindow.ghostWidth + ghostWindow.ghostPadding * 2
      height: ghostWindow.ghostHeight + ghostWindow.ghostPadding * 2

      BorderSurface {
        anchors.fill: parent
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        radius: Math.min(Style.cornerRadius, height / 2)
        opacity: root.transparent ? 0.45 : 0.94
      }

      Image {
        anchors.fill: parent
        anchors.margins: ghostWindow.ghostPadding
        source: root.barDragImageUrl
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }

    Rectangle {
      readonly property var targetRect: root.barDragTargetGeometry

      visible: ghostWindow.active && targetRect !== null
      x: targetRect ? Math.round(targetRect.x) : 0
      y: targetRect ? Math.round(targetRect.y) : 0
      width: targetRect ? targetRect.width : 0
      height: targetRect ? targetRect.height : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
    }
  }

  component BarMoveGhostPanel: PanelWindow {
    id: moveGhostWindow

    required property var ghostScreen
    readonly property bool screenMatches: root.barMoveScreen === ghostScreen ||
      (root.barMoveScreen && ghostScreen && root.barMoveScreen.name && ghostScreen.name && root.barMoveScreen.name === ghostScreen.name)
    visible: root.barMoveActive && screenMatches
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-bar-move-ghost"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Visual-only preview of the candidate edge. Keep the input region empty
    // so the overlay never steals the gesture area's active pointer grab.
    mask: Region {}

    // One fixed-geometry slab per edge, crossfaded on candidate changes.
    // Resizing a single slab between edges repaints mid-transition and
    // flickers; fading between static ones does not.
    Repeater {
      model: ["top", "bottom", "left", "right"]

      BorderSurface {
        id: edgeSlab

        required property string modelData
        readonly property bool edgeVertical: modelData === "left" || modelData === "right"
        readonly property int edgeSize: edgeVertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal

        x: modelData === "right" ? parent.width - edgeSize : 0
        y: modelData === "bottom" ? parent.height - edgeSize : 0
        width: edgeVertical ? edgeSize : parent.width
        height: edgeVertical ? parent.height : edgeSize
        color: root.transparent ? "transparent" : root.background
        borderSpec: Border.flat(root.barForeground, 1)
        visible: opacity > 0
        opacity: root.barMoveCandidate === modelData ? (root.transparent ? 0.45 : 0.7) : 0

        Behavior on opacity {
          NumberAnimation { duration: root.prismDuration; easing.type: Easing.OutCubic }
        }
      }
    }
  }

}
