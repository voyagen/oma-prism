import QtQuick
import QtTest
import Quickshell.Io
import Quickshell
import qs.Ui
import "SettingsModel.js" as SettingsModel

Item {
  id: smoke
  required property var bar
  SmokeGrid { id: catalogueGrid; bar: smoke.bar }
  Timer { id: gridCheck; interval:1500; onTriggered: { try { catalogueGrid.inspect() } catch(error) { console.error("PRISM GRID FAIL " + error) } } }
  property var widget: null
  property var button: null
  property var steps: []
  property int index: 0
  property string suite: ""
  property bool settingsOverride: false
  property var draftSettings: ({})
  property bool textOverride: false
  property string draftText: ""
  property var savedAudio: []
  property int recordCount: 0
  property var oldSource: ""
  property bool orientationOverride: false
  property string draftPosition: "top"
  Binding { target: smoke.bar; property:"position"; value:smoke.draftPosition; when:smoke.orientationOverride; restoreMode:Binding.RestoreBindingOrValue }
  property bool foreignEnabled: false
  property bool foreignActive: false
  Component { id: foreignIcon; Item {} }
  Binding { target: smoke.button; property: "iconComponent"; value: smoke.foreignActive ? foreignIcon : null; when: smoke.foreignEnabled; restoreMode: Binding.RestoreBindingOrValue }
  Binding { target: smoke.bar.iconAdapter; property: "settings"; value: smoke.draftSettings; when: smoke.settingsOverride; restoreMode: Binding.RestoreBindingOrValue }
  Binding { target: smoke.button; property: "text"; value: smoke.draftText; when: smoke.textOverride; restoreMode: Binding.RestoreBindingOrValue }
  function restore() {
    textOverride = false
    settingsOverride = false
    foreignEnabled = false
    orientationOverride = false
    savedAudio.forEach(function(s) { s.audio.volume = s.volume; s.audio.muted = s.muted })
    if (widget) widget.close()
  }
  function audioRecord() {
    return bar.iconAdapter.records.filter(function(r) { return r.target === button })[0]
  }
  function ready() {
    var record = audioRecord()
    check(record && record.status === Image.Ready && record.renderedStatus === Image.Ready && record.adapted && record.paintedExtent > 0, "literal SVG paints ready with measured extent")
    return record
  }
  function click(which) { events.mouseClick(button,button.width/2,button.height/2,which,Qt.NoModifier,0) }
  TestEvent { id: events }
  Timer {
    id: sequence
    interval: 600
    repeat: true
    onTriggered: {
      try {
        if (smoke.index === smoke.steps.length) {
          console.log("PRISM SMOKE PASS " + smoke.suite)
          smoke.restore()
          stop()
          return
        }
        smoke.steps[smoke.index++]()
      } catch (error) {
        console.error("PRISM SMOKE FAIL " + smoke.suite + ": " + error)
        stop()
        smoke.restore()
      }
    }
  }
  function check(value, message) {
    if (!value) throw new Error(message)
    console.log("PRISM CHECK " + message)
  }
  function findButton(item) {
    if (item instanceof BarIconButton) return item
    for (var i = 0; i < item.children.length; ++i) {
      var found = findButton(item.children[i])
      if (found) return found
    }
    return null
  }
  function run(name) {
    suite = name
    index = 0
    if (name === "grid-close") { catalogueGrid.shown = false; return }
    if (name.indexOf("grid-") === 0 || name.indexOf("power-") === 0) {
      catalogueGrid.percentages = name.indexOf("power-") === 0
      catalogueGrid.pack = name.substring(catalogueGrid.percentages ? 6 : 5)
      catalogueGrid.shown = true
      gridCheck.restart()
      return
    }
    if(name==="inspect") {
      console.log("PRISM ICON AUDIT "+JSON.stringify(bar.iconAdapter.records.map(function(record){return {widgetId:record.widgetId,glyph:record.target.text,semantic:record.semantic,adapted:record.adapted,status:record.status,renderedStatus:record.renderedStatus}})))
      console.log("PRISM LIMITS "+JSON.stringify(bar.iconAdapter.diagnostics))
      return
    }
    widget = bar.moduleWidgets("omarchy.audio")[0]
    check(!!widget, "original registered audio widget present")
    button = findButton(widget)
    check(!!button, "qs.Ui BarIconButton type identifies actual registry button")
    console.log("PRISM GEOMETRY " + JSON.stringify(bar.debugBarGeometry()))
    console.log("PRISM LAYOUT " + JSON.stringify(bar.layoutConfig))
    if (name === "host") {
      steps = [
        function() { widget.close(); events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0) },
        function() { check(widget.opened, "left click opens original audio popup"); events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0) },
        function() { check(!widget.opened, "left click closes original audio popup"); check(bar.moduleWidgets("omarchy.audio")[0] === widget, "audio identity retained") }
      ]
      sequence.start()
    }
    if (name === "audio") {
      savedAudio = []
      ;[widget.volumeSink,widget.source].forEach(function(node) {
        if (node && node.audio) savedAudio.push({audio:node.audio,volume:node.audio.volume,muted:node.audio.muted})
      })
      check(widget.hasOutput, "real audio output available")
      recordCount = bar.iconAdapter.records.length
      draftSettings = SettingsModel.normalizeSettings(bar.prismSettings)
      settingsOverride = true
      steps = [
        function() { ready(); widget.close(); click(Qt.LeftButton) },
        function() { check(widget.opened,"SVG left click opens native popup"); click(Qt.LeftButton) },
        function() { check(!widget.opened,"SVG left click closes native popup"); click(Qt.MiddleButton) },
        function() { check(widget.opened,"SVG middle click retains native toggle"); widget.close(); click(Qt.RightButton) },
        function() { check(widget.outputMuted && (!widget.hasInput || widget.inputMuted),"SVG right click changes actual mute state"); ready(); widget.volumeSink.audio.muted = false; widget.setOutputVolume(0.4) },
        function() { oldSource = ready().source; events.mouseWheel(button,button.width/2,button.height/2,Qt.NoButton,Qt.NoModifier,0,120,0) },
        function() { check(Math.abs(widget.outputVolume-0.45)<0.001,"SVG wheel changes actual volume by native step"); events.mouseMove(button,button.width/2,button.height/2,0,Qt.NoButton,Qt.NoModifier) },
        function() { check(button.tooltipHovered,"native tooltip hover remains active"); draftSettings = Object.assign({},draftSettings,{iconPack:"material-symbols"}) },
        function() { check(ready().source !== oldSource,"pack switch changes literal source"); check(bar.iconAdapter.records.length === recordCount,"pack switch preserves record count"); draftSettings = Object.assign({},draftSettings,{widgetOverrides:{"omarchy.audio":{[button.text]:"/tmp/prism-definitely-missing.svg"}}}) },
        function() { check(audioRecord().status === Image.Error && !audioRecord().adapted && button.iconComponent === null,"unreadable SVG restores original glyph"); draftSettings = Object.assign({},draftSettings,{widgetOverrides:{}}) },
        function() { ready(); draftText = ""; textOverride = true },
        function() { check(button.iconComponent === null,"empty glyph restores original absent surface"); draftText = "unknown composite" },
        function() { check(button.iconComponent === null,"unknown glyph retains original"); textOverride = false },
        function() { ready(); bar.iconAdapter.release(widget) },
        function() { check(button.iconComponent === null,"detach restores original icon binding"); widget.volumeSink.audio.muted = true },
        function() { check(button.text === widget.outputIcon(),"detached text remains live upstream binding"); bar.iconAdapter.observe(widget,"omarchy.audio",bar.moduleSlots.filter(function(s){return s.activeItem===widget})[0]) },
        function() { ready(); check(bar.moduleWidgets("omarchy.audio")[0] === widget,"all adaptation operations preserve actual widget identity"); bar.iconAdapter.refresh() },
        function() { ready(); check(bar.iconAdapter.records.length === recordCount,"refresh preserves record count") }
      ]
      sequence.start()
    }
    if (name === "ownership") {
      savedAudio = []
      steps = [
        function() { ready(); bar.iconAdapter.release(widget); foreignEnabled = true },
        function() { check(button.iconComponent === null,"synthetic upstream icon binding starts null"); bar.iconAdapter.observe(widget,"omarchy.audio",bar.moduleSlots.filter(function(s){return s.activeItem===widget})[0]) },
        function() { ready(); foreignActive = true },
        function() { check(button.iconComponent === foreignIcon && audioRecord().conflict && !audioRecord().adapted,"foreign icon owner preserved and conflict diagnosed"); bar.iconAdapter.release(widget) },
        function() { check(button.iconComponent === foreignIcon,"release never overwrites foreign component"); foreignActive = false },
        function() { check(button.iconComponent === null,"foreign upstream binding remains live after release"); foreignEnabled = false; bar.iconAdapter.observe(widget,"omarchy.audio",bar.moduleSlots.filter(function(s){return s.activeItem===widget})[0]) },
        function() { ready() }
      ]
      sequence.start()
    }
    if (name === "indicators") {
      savedAudio = []
      var priorCount = bar.iconAdapter.records.length
      steps = [
        function() { draftPosition="left"; orientationOverride=true },
        function() { checkUniqueRecords(); draftPosition="top" },
        function() { checkUniqueRecords(); orientationOverride=false },
        function() { checkUniqueRecords(); check(bar.iconAdapter.records.length === priorCount,"orientation lazy replacements clean up records"); console.log("PRISM LIVE CONTEXTS "+JSON.stringify(bar.iconAdapter.records.filter(function(r){return bar.moduleSlots.indexOf(r.slot)>=0}).map(function(r){return {context:r.widgetId,semantic:r.semantic,adapted:r.adapted}}))) }
      ]
      sequence.start()
    }
  }
  function checkUniqueRecords() {
    var list=bar.iconAdapter.records
    for(var i=0;i<list.length;i++)for(var j=i+1;j<list.length;j++)if(list[i].target===list[j].target)throw new Error("Duplicate QObject icon ownership")
    check(true,"unique QObject icon ownership across "+list.length+" records")
  }
  IpcHandler {
    target: "prism.smoke"
    function run(name: string): void { smoke.run(name) }
    function reload(): void { Quickshell.reload(true) }
  }
}
