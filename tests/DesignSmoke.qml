import QtQuick
import QtQuick.Controls as Controls
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui
import "../" as Prism
import "../SettingsModel.js" as SettingsModel

Item {
  id: suite
  readonly property string testHome: Quickshell.env("PRISM_TEST_HOME")
  readonly property string captureDirectory: Quickshell.env("PRISM_DESIGN_CAPTURE")
  property var phases: []
  property int phaseIndex: 0
  property int attempts: 0
  property int captures: 0
  property bool capturePending: false
  property bool failed: false
  property var popup: null
  property var nativeWidth: null
  property Item focusSeed: null
  TestEvent { id: input }

  function check(value, message) { if (!value) throw new Error(message) }
  function find(item, predicate) {
    if (predicate(item)) return item
    for (var child of item.children) {
      var result = find(child, predicate)
      if (result) return result
    }
    return null
  }
  function action(name) {
    return find(bar.settingsPanel.acceptanceFocusItem, function(item) { return item.objectName === name })
  }
  function scroll() { return action("settings-scroll-" + bar.settingsPanel.selectedTab) }
  function reveal(item) {
    check(!!item, "native settings control exists")
    for (var parent = item.parent; parent; parent = parent.parent) {
      if (parent instanceof Controls.ScrollView) {
        var flick = parent.contentItem
        var point = item.mapToItem(flick.contentItem, 0, 0)
        flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, point.y - 12))
      }
    }
  }
  function click(item) {
    reveal(item)
    input.mouseClick(item, item.width / 2, item.height / 2, Qt.LeftButton, Qt.NoModifier, 0)
  }
  function isControl(item) {
    return item instanceof Controls.AbstractButton || item instanceof Button || item instanceof Toggle || item instanceof Dropdown ||
      item instanceof Controls.Slider || item instanceof Controls.TextField
  }
  function inspect(label) {
    var body = bar.settingsPanel.acceptanceFocusItem
    check(bar.settingsPanel.opened && bar.settingsPanel.editable, label + ": save-ready settings")
    check(popup && popup.visible && popup.screen === bar.barPanels[0].screen, label + ": native panel on anchor screen")
    check(popup.cardOrigin.x >= -1 && popup.cardOrigin.y >= -1 &&
      popup.cardOrigin.x + popup.contentWidth <= popup.screen.width + 1 &&
      popup.cardOrigin.y + popup.contentHeight <= popup.screen.height + 1,
      label + ": panel stays screen bounded")
    check(body.width > 0 && body.height > 0, label + ": rendered content has area")
    var count = 0
    function visit(item) {
      if (!item.visible) return
      if (isControl(item) && item.width > 0 && item.height > 0) {
        var point = item.mapToItem(body, 0, 0)
        // Vertical overflow belongs to the real ScrollView. Horizontal overflow
        // is never permitted, including controls currently below its viewport.
        check(point.x >= -1 && point.x + item.width <= body.width + 1,
          label + ": control stays inside content width (" + item.objectName + ")")
        check(item.x >= -1 && item.y >= -1 && item.x + item.width <= item.parent.width + 1 &&
          item.y + item.height <= item.parent.height + 1,
          label + ": control stays inside layout container (" + item.objectName + ")")
        var clipped = false
        for (var ancestor = item.parent; ancestor && ancestor !== body; ancestor = ancestor.parent) {
          if (ancestor.clip) {
            clipped = true
            var local = item.mapToItem(ancestor, 0, 0)
            check(local.x >= -1 && local.x + item.width <= ancestor.width + 1,
              label + ": control fits clipped viewport horizontally")
          }
        }
        if (!clipped) check(point.y >= -1 && point.y + item.height <= body.height + 1,
          label + ": unscrolled control stays inside panel height")
        count++
        return
      }
      for (var child of item.children) visit(child)
    }
    visit(body)
    var viewport = scroll()
    check(viewport && viewport.width > 0 && viewport.height > 0, label + ": usable scroll viewport")
    check(viewport.contentWidth <= viewport.availableWidth + 1, label + ": no horizontal scrolling")
    console.log("PRISM DESIGN CHECK " + label + " content=" + body.width + "x" + body.height +
      " panel=" + popup.contentWidth + "x" + popup.contentHeight + " controls=" + count)
  }
  function capture(label) {
    inspect(label)
    if (!captureDirectory) return true
    var screen = popup.screen
    captureProcess.command = ["grim", "-g", screen.x + "," + screen.y + " " + screen.width + "x" + screen.height,
      captureDirectory + "/prism-design-" + label + ".png"]
    capturePending = true
    captureProcess.running = true
    return true
  }
  function addState(label, prepare) {
    phases.push(prepare)
    // Separate ticks allow native layout, focus and compositor rendering to settle.
    phases.push(function() {
      if (bar.settingsWritePending) return false
      return capture(label)
    })
  }
  QtObject {
    id: host
    property var config: ({version:1,bar:{id:"voyagen.prism",position:"top",centerAnchor:"prism.clock",
      layout:{left:[{id:"prism.status",label:"Studio",enabled:true,count:3,mode:"balanced"},"prism.audio","prism.network"],
        center:["prism.clock"],right:["prism.power","prism.session"]},
      prism:{reserveSpace:false,motionEnabled:false,radius:12}}})
    function mutateShellConfig(mutator) {
      var next = JSON.parse(JSON.stringify(config))
      mutator(next)
      config = next
      configFile.setText(JSON.stringify(next))
      return true
    }
  }
  FileView { id: configFile; path: suite.testHome + "/.config/omarchy/shell.json"; printErrors:false }
  QtObject {
    id: registry
    property var widgets: ({"prism.status":{component:statusWidget},"prism.audio":{component:audioWidget},
      "prism.network":{component:networkWidget},"prism.clock":{component:clockWidget},
      "prism.power":{component:powerWidget},"prism.session":{component:sessionWidget}})
    function metadataFor(id) {
      if (id === "prism.status") return {displayName:"Workspace status",firstParty:true,allowMultiple:true,
        defaults:{label:"Studio",enabled:true,count:3,mode:"balanced"},schema:[
          {key:"label",label:"Workspace label",type:"string",description:"A short label shown on the bar."},
          {key:"enabled",label:"Show status",type:"boolean"},
          {key:"count",label:"Workspace count",type:"integer",min:1,max:9},
          {key:"mode",label:"Status detail",type:"enum",options:[{value:"balanced",label:"Balanced"},{value:"minimal",label:"Minimal"}]}
        ]}
      return {displayName:({"prism.audio":"Audio","prism.network":"Network","prism.clock":"Clock",
        "prism.power":"Battery","prism.session":"Session"})[id],firstParty:true}
    }
  }
  Component { id: statusWidget; WidgetButton { property var settings: ({}); text: settings.label || "Studio"; active:true } }
  Component { id: audioWidget; BarIconButton { property string moduleName:"omarchy.audio"; text:""; active:true } }
  Component { id: networkWidget; BarIconButton { property string moduleName:"omarchy.network"; text:"󰤨"; active:true } }
  Component { id: clockWidget; WidgetButton { text:"Saturday 09:48"; active:true } }
  Component { id: powerWidget; WidgetButton { text:"100%"; active:true } }
  Component { id: sessionWidget; BarIconButton { property string moduleName:"omarchy.power"; text:""; active:true } }
  Prism.Bar {
    id: bar
    home: suite.testHome
    shell: host
    barConfig: host.config.bar
    barWidgetRegistry: registry
    manifest: ({id:"voyagen.prism",version:"1.0.3"})
  }
  Process {
    id: captureProcess
    onExited: function(code) {
      suite.capturePending = false
      if (code !== 0) suite.fail("grim capture exited " + code)
      else suite.captures++
    }
  }
  function fail(message) {
    if (failed) return
    failed = true
    console.error("PRISM RUNTIME FAIL design phase " + phaseIndex + ": " + message)
    sequence.stop()
    Qt.quit()
  }
  Component.onCompleted: {
    phases.push(function() { configFile.setText(JSON.stringify(host.config)); return true })
    phases.push(function() {
      if (!bar.diskBarConfig || !bar.diskBarConfig.layout.left.length || !bar.barPanels.length ||
          bar.moduleSlots.length < 6 || bar.moduleSlots.some(function(slot) { return !slot.activeItem })) return false
      check(bar.canSavePrismSettings, "isolated persisting host can save")
      check(bar.openPrismSettings(bar.barPanels[0].settingsButton), "native anchored settings opens")
      popup = bar.targetWindow(bar.settingsPanel.acceptanceFocusItem)
      check(!!popup && "contentWidth" in popup, "public native panel width is accessible")
      nativeWidth = popup.contentWidth
      return true
    })
    for (var density of ["compact", "default", "comfortable"]) {
      (function(density) {
        phases.push(function() {
          bar.settingsPanel.selectedTab = 0
          click(action("spacing-" + density))
          return true
        })
        phases.push(function() {
          if (bar.settingsWritePending) return false
          check(SettingsModel.spacingPreset(bar.persistedPrismSettings) === density, "density saved to isolated disk")
          return true
        })
        for (var tab of ["appearance", "icons", "widgets"]) {
          (function(tab) {
            addState(density + "-" + tab, function() {
              click(action("tab-" + tab))
              scroll().contentItem.contentY = 0
              return true
            })
          })(tab)
        }
        addState(density + "-schema", function() {
          var entry = find(bar.settingsPanel.acceptanceFocusItem, function(item) {
            return item instanceof Controls.AbstractButton && "index" in item && item.index === 0 && item.parent.modelData === "left"
          })
          click(entry)
          check(bar.settingsPanel.hasSelection && bar.openWidgetConfiguration("prism.status"), "selected native widget reveals typed configuration")
          return true
        })
        // Scroll after the schema Loader has laid out, then capture the typed controls.
        phases.splice(phases.length - 1, 0, function() {
          var textInput = find(bar.settingsPanel.acceptanceFocusItem, function(item) { return item instanceof Controls.TextField && item.visible })
          reveal(textInput)
          return true
        })
        addState(density + "-reset", function() {
          click(action("tab-icons"))
          click(action("reset-icons"))
          reveal(action("reset-confirm"))
          return true
        })
        phases.push(function() { click(action("reset-cancel")); bar.settingsPanel.clearSelection(); return true })
      })(density)
    }
    for (var tab of ["appearance", "icons", "widgets"]) {
      (function(tab) {
        addState("narrow-" + tab, function() {
          // Exercise the real public panel content size, not a fabricated screen.
          popup.contentWidth = popup.fittedContentWidth(480)
          click(action("tab-" + tab))
          scroll().contentItem.contentY = 0
          return true
        })
      })(tab)
    }
    phases.push(function() {
      focusSeed=action("tab-appearance")
      focusSeed.forceActiveFocus()
      check(focusSeed.activeFocus,"keyboard scenario starts on a native tab control")
      input.keyClick(Qt.Key_Tab, Qt.NoModifier, 0)
      return true
    })
    phases.push(function() {
      var focused = find(bar.settingsPanel.acceptanceFocusItem, function(item) { return isControl(item) && item.activeFocus })
      check(!!focused && focused!==focusSeed && focused.enabled && focused.visible, "Tab advances to a visible enabled native control")
      input.keyClick(Qt.Key_Escape, Qt.NoModifier, 0)
      return true
    })
    phases.push(function() {
      check(!bar.settingsPanel.opened, "Escape dismisses settings from a focused control")
      check(bar.openPrismSettings(bar.barPanels[0].settingsButton), "native panel reopens after Escape")
      return true
    })
    phases.push(function() { inspect("keyboard-reopen"); bar.settingsPanel.close(); return true })
    sequence.start()
  }
  Timer {
    id: sequence
    interval: 180
    repeat:true
    onTriggered: {
      if (suite.capturePending || suite.failed) return
      try {
        if (suite.phaseIndex === suite.phases.length) {
          console.log("PRISM RUNTIME PASS — design; captures=" + suite.captures + "; native-width=" + suite.nativeWidth + "; narrow-width=" + suite.popup.contentWidth)
          stop()
          Qt.quit()
        } else if (suite.phases[suite.phaseIndex]()) { suite.phaseIndex++; suite.attempts = 0 }
        else if (++suite.attempts > 30) throw new Error("Timed out waiting for rendered design state")
      } catch (error) { suite.fail(error) }
    }
  }
  Timer { interval:27000; running:true; onTriggered:suite.fail("Design fixture exceeded 27 seconds") }
}
