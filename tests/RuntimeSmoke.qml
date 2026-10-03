import QtQuick
import QtTest
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import "../" as Prism
import "../SettingsModel.js" as SettingsModel

Item {
  id: suite
  readonly property string testHome: Quickshell.env("PRISM_TEST_HOME")
  readonly property string assetPath: testHome + "/custom.svg"
  property int index: 0
  property int attempts: 0
  property int assetWrites: 0
  property bool deleted: false
  property bool foreignEnabled: false
  property bool foreignActive: false
  property var initialResolution: null
  property var initialGeometry: null
  property real savedOffset: 0
  property var temporaryAdapter: null
  property var phases: []
  property var radiusSlider: null
  property var wheelContent: null
  property real wheelStart: 0
  property real wheelRadius: 0
  property real deliberateRadius: 0
  function check(value, message) { if (!value) throw new Error(message); console.log("PRISM RUNTIME CHECK " + message) }
  function record() { return bar.iconAdapter.targets.find(function(r) { return r.target === button }) }
  function ready() { var r = record(); return r && r.bindingApplied && r.paintItem && r.paintItem.status === Image.Ready }
  function override(path) { var paths = {}; paths[button.text] = path; bar.previewPrismSetting("widgetOverrides", {"omarchy.audio": paths}) }
  TestEvent { id: input }
  function find(item, predicate) {
    if (predicate(item)) return item
    for (var child of item.children) { var found=find(child,predicate); if(found)return found }
    return null
  }
  function action(name) { return find(bar.settingsPanel.acceptanceFocusItem,function(item){return item.objectName===name}) }
  function click(item) {
    check(!!item,"requested native settings action is available")
    for(var parent=item.parent;parent;parent=parent.parent)if(parent instanceof Controls.ScrollView) {
      var flick=parent.contentItem
      if(flick && "contentY" in flick && flick.contentHeight>flick.height) {
        var point=item.mapToItem(flick.contentItem,0,0)
        flick.contentY=Math.max(0,Math.min(flick.contentHeight-flick.height,point.y-flick.height/3))
      }
    }
    input.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0)
  }
  QtObject {
    id: host
    property bool persist: true
    property var config: ({version:1,bar:{id:"voyagen.prism",position:"top",layout:{left:[],center:[],right:[]},prism:{reserveSpace:false,radius:12}}})
    function mutateShellConfig(mutator) {
      var next = JSON.parse(JSON.stringify(config))
      mutator(next)
      config = next
      if (persist) configFile.setText(JSON.stringify(next))
      return true
    }
  }
  FileView { id: configFile; path: suite.testHome + "/.config/omarchy/shell.json"; printErrors:false }
  FileView { id: assetFile; path: suite.assetPath; printErrors:false; onSaved: suite.assetWrites++ }
  Process { id: removeAsset; command:["rm",suite.assetPath]; onExited:suite.deleted=true }
  Component {
    id: schemaWidget
    Item {
      property var settings: ({})
      implicitWidth: (settings.count || 3) * 10
      implicitHeight: 28
    }
  }
  QtObject {
    id: schemaRegistry
    property var widgets: ({"prism.test":{component:schemaWidget}})
    function metadataFor(id) {
      return id === "prism.test" ? {displayName:"Runtime schema widget",defaults:{count:3},schema:[
        {key:"count",type:"integer",min:1,max:9},
        {key:"enabled",type:"boolean"},
        {key:"mode",type:"enum",options:["first","second"]},
        {key:"label",type:"string"}
      ]} : null
    }
  }
  Prism.Bar {
    id: bar
    home: suite.testHome
    shell: host
    barConfig: host.config.bar
    barWidgetRegistry: schemaRegistry
    manifest: ({id:"voyagen.prism",version:"1.0.3"})
  }
  Component { id: foreignIcon; Item {} }
  Component { id: temporaryAdapterComponent; Prism.IconAdapter { settings:bar.prismSettings } }
  Binding {
    target:button; property:"iconComponent"
    value:suite.foreignActive ? foreignIcon : null
    when:suite.foreignEnabled
    restoreMode:Binding.RestoreBindingOrValue
  }
  PanelWindow {
    id: window
    visible:true
    color:"#181818"
    implicitWidth:320
    implicitHeight:90
    exclusionMode:ExclusionMode.Ignore
    anchors { bottom:true; left:true }
    screen:Quickshell.screens[0]
    BarIconButton { id:button; bar:bar; text:""; width:32; height:34 }
    BarIconButton { id:spareButton; bar:bar; text:""; x:240; width:32; height:34 }
    BarIconButton { id:duplicateButton; bar:bar; text:""; x:280; width:32; height:34 }
    Prism.AxisRail {
      id:rail; controller:bar
      geometry:({start:60,extent:140,contentExtent:400,initialOffset:80})
      Item { id:hiddenSlot; parent:rail.contentItem; x:rail.offset+rail.viewportExtent+5; width:20; height:20 }
      Item { id:partialSlot; parent:rail.contentItem; x:rail.offset-5; width:20; height:20 }
    }
  }
  Component.onCompleted: {
    phases = [
      function() {
        if (!bar.diskBarConfig) return false
        bar.iconAdapter.observe(button,"omarchy.audio",null)
        bar.iconAdapter.observe(duplicateButton,"omarchy.audio",null)
        return true
      },
      function() {
        if (!ready()) return false
        check(record().resolved.semantic==="volume-high","actual native icon is adapted")
        initialResolution=record().resolved; initialGeometry=bar.geometrySettings
        bar.previewPrismSetting("radius",30); bar.previewPrismSetting("opacity",0.5)
        return true
      },
      function() {
        check(record().resolved===initialResolution && bar.geometrySettings===initialGeometry,"unrelated appearance retains resolution and layout inputs")
        bar.cancelPrismPreview(); override(testHome+"/missing.svg"); return true
      },
      function() {
        if (!record() || record().probeStatus!==Image.Error || record().bindingApplied) return false
        check(button.iconComponent===null,"unreadable override restores native surface")
        foreignEnabled=true; foreignActive=true; return true
      },
      function() { check(button.iconComponent===foreignIcon,"foreign owner acquired during fallback"); override(assetPath); return true },
      function() {
        var duplicate=bar.iconAdapter.targets.find(function(item){return item.target===duplicateButton})
        if(record().probeStatus!==Image.Ready || !duplicate.bindingApplied)return false
        check(record().conflict && !record().bindingApplied && button.iconComponent===foreignIcon,"valid asset never overwrites foreign fallback owner")
        var rows=bar.settingsDiagnostics.filter(function(row){return row.widgetId==="omarchy.audio" && row.glyph===button.text})
        check(rows.length===2 && rows.filter(function(row){return row.status==="partial"}).length===1 && rows.filter(function(row){return row.status==="supported"}).length===1,"foreign ownership diagnostic stays on its exact surface without duplicate rows")
        bar.iconAdapter.release(button); foreignActive=false; return true
      },
      function() { check(button.iconComponent===null,"foreign upstream null binding remains live after detach"); foreignActive=true; return true },
      function() { check(button.iconComponent===foreignIcon,"foreign upstream component binding remains live after detach"); foreignEnabled=false; return true },
      function() { bar.cancelPrismPreview(); bar.iconAdapter.observe(button,"omarchy.audio",null); override(assetPath); return true },
      function() {
        if (!ready()) return false
        check(record().paintedExtent>16,"custom SVG square initially rendered")
        assetFile.setText("<svg xmlns='http://www.w3.org/2000/svg' width='9' height='18'><rect width='9' height='18' fill='red'/></svg>")
        return true
      },
      function() { if (!assetWrites) return false; bar.iconAdapter.refresh(); return true },
      function() {
        if (!ready() || record().paintedExtent>=12) return false
        check(record().paintedExtent>0,"same-URL edited SVG changes painted aspect after refresh")
        removeAsset.running=true; return true
      },
      function() { if (!deleted) return false; bar.iconAdapter.refresh(); return true },
      function() {
        if (record().probeStatus!==Image.Error || record().bindingApplied) return false
        check(button.iconComponent===null,"deleted SVG refresh falls back, not cached Ready")
        bar.cancelPrismPreview(); button.text=""; return true
      },
      function() {
        if (!ready()) return false
        check(record().resolved.semantic==="volume-low","native live glyph transition remains adapted")
        rail.scroll(57); savedOffset=rail.offset
        rail.geometry=({start:60,extent:140,contentExtent:400,initialOffset:80}); return true
      },
      function() {
        check(rail.offset===savedOffset && rail.offset!==80,"new equal geometry preserves chosen rail offset")
        check(bar.drawnSlotRect(hiddenSlot)===null,"fully clipped slot is not a drawn drag candidate")
        var rect=bar.drawnSlotRect(partialSlot)
        check(rect && Math.abs(rect.width-15)<0.01,"partially clipped slot uses visible interval")
        host.persist=false
        check(bar.commitPrismSetting("radius",25) && bar.settingsWritePending,"in-memory save echo is still pending")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.settingsError!=="" && bar.diskBarConfig.prism.radius===12,"nonpersisted echo expires with error and disk remains unchanged")
        host.persist=true
        check(bar.commitPrismSetting("radius",25) && bar.settingsWritePending,"retry is not skipped because memory already matches")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.settingsError==="" && bar.diskBarConfig.prism.radius===25,"save acknowledged only after actual disk update")
        check(bar.commitPrismPatch({opacity:0.3,iconPack:"material-symbols",fontSize:20}),"atomic multi-setting patch accepted")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.prism.opacity===0.3 && bar.diskBarConfig.prism.fontSize===20,"atomic patch persisted all fields")
        check(bar.resetPrismGroup("icons"),"icon reset accepted"); return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.prism.iconPack===SettingsModel.defaults.iconPack && bar.diskBarConfig.prism.fontSize===SettingsModel.defaults.fontSize,"icon reset uses schema defaults")
        check(bar.diskBarConfig.prism.opacity===0.3 && bar.diskBarConfig.prism.radius===25 && bar.diskBarConfig.layout.left.length===0,"icon reset preserves appearance and layout")
        assetFile.setText("<svg xmlns='http://www.w3.org/2000/svg' width='18' height='18'><rect width='18' height='18'/></svg>")
        check(bar.commitPrismPatch({fontFamily:"Saved Custom Font",semanticOverrides:{"volume-high":suite.assetPath},widgetOverrides:{"omarchy.audio":{"":suite.assetPath}},transitionDuration:321,edgeGap:17}),"existing custom settings seeded before ordinary UI edit")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        bar.openPrismSettings(button)
        check(bar.settingsPanel.opened,"simple settings panel opens")
        check(bar.targetWindow(bar.settingsPanel.acceptanceFocusItem).screen.name===window.screen.name,"anchored popup renders on invoking window's monitor")
        click(action("tab-icons")); check(bar.settingsPanel.selectedTab===1,"icons tab is reachable")
        click(action("tab-widgets")); check(bar.settingsPanel.selectedTab===2,"widgets tab is reachable")
        click(action("tab-appearance")); check(bar.settingsPanel.selectedTab===0,"appearance tab is reachable")
        return true
      },
      function() { click(action("animations-expressive")); return true },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.prism.animationIntensity==="expressive" && bar.prismSettings.motionEnabled && !bar.prismSettings.reducedMotion && bar.prismDuration===482,"Expressive saves atomically and lengthens the existing transition duration")
        click(action("animations-reduced")); return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.prism.reducedMotion && bar.prismDuration===0,"Reduced saves and removes geometric bar transitions")
        click(action("animations-off")); return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(!bar.diskBarConfig.prism.motionEnabled && bar.prismDuration===0,"Off saves and disables animation")
        click(action("animations-default")); return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.prism.animationIntensity==="default" && bar.prismSettings.motionEnabled && !bar.prismSettings.reducedMotion && bar.prismDuration===321,"Default restores motion without replacing the saved transition duration")
        return true
      },
      function() { click(action("mode-docked")); return true },
      function() {
        if (bar.settingsWritePending) return false
        var saved = bar.diskBarConfig.prism
        check(saved.mode==="docked","ordinary style control saves to disk")
        check(saved.edgeGap===17 && saved.fontFamily==="Saved Custom Font" && saved.transitionDuration===321 && saved.semanticOverrides["volume-high"]===suite.assetPath && saved.widgetOverrides["omarchy.audio"][""]===suite.assetPath,"ordinary UI save preserves hidden geometry, font, motion and SVG customizations")
        radiusSlider=action("slider-radius")
        check(!!radiusSlider,"roundness slider is available")
        for(var parent=radiusSlider.parent;parent;parent=parent.parent)if(parent instanceof Controls.ScrollView)wheelContent=parent.contentItem
        check(wheelContent && wheelContent.contentHeight>wheelContent.height,"appearance page has scrollable preferences")
        var point=radiusSlider.mapToItem(wheelContent.contentItem,0,0)
        wheelContent.contentY=Math.max(0,Math.min(wheelContent.contentHeight-wheelContent.height-80,point.y-wheelContent.height/2))
        wheelStart=wheelContent.contentY; wheelRadius=bar.prismSettings.radius
        input.mouseWheel(radiusSlider,radiusSlider.width/2,radiusSlider.height/2,Qt.NoButton,Qt.NoModifier,0,-120,0)
        return true
      },
      function() {
        check(wheelContent.contentY>wheelStart,"wheel over roundness slider scrolls the settings page")
        check(radiusSlider.value===wheelRadius && bar.prismSettings.radius===wheelRadius && bar.diskBarConfig.prism.radius===wheelRadius && !bar.settingsWritePending,"wheel does not preview or save a slider change")
        click(radiusSlider)
        deliberateRadius=Math.round(radiusSlider.value)
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        check(deliberateRadius!==wheelRadius && bar.diskBarConfig.prism.radius===deliberateRadius && bar.prismSettings.radius===deliberateRadius,"deliberate slider click still persists roundness")
        radiusSlider.forceActiveFocus()
        input.keyClick(Qt.Key_Right,Qt.NoModifier,0)
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        check(bar.diskBarConfig.prism.radius===deliberateRadius+1 && bar.prismSettings.radius===deliberateRadius+1,"keyboard slider adjustment persists one step")
        input.mousePress(radiusSlider,radiusSlider.width/2,radiusSlider.height/2,Qt.LeftButton,Qt.NoModifier,0)
        input.mouseMove(radiusSlider,radiusSlider.width*0.7,radiusSlider.height/2,0,Qt.LeftButton,Qt.NoModifier)
        check(radiusSlider.pressed && bar.prismSettings.radius===radiusSlider.value && bar.diskBarConfig.prism.radius===deliberateRadius+1,"slider drag previews without saving")
        deliberateRadius=radiusSlider.value
        input.mouseRelease(radiusSlider,radiusSlider.width*0.7,radiusSlider.height/2,Qt.LeftButton,Qt.NoModifier,0)
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        check(bar.diskBarConfig.prism.radius===deliberateRadius && bar.prismSettings.radius===deliberateRadius,"slider drag saves on release")
        check(bar.settingsPanel.commit("background","custom"),"custom background selection saves")
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        click(action("background-color-picker"))
        return true
      },
      function() {
        if(!bar.settingsPanel.backgroundColorDialog.visible)return false
        check(!bar.settingsWritePending,"opening the color picker does not save")
        var savedColor=bar.diskBarConfig.prism.color
        bar.settingsPanel.backgroundColorDialog.selectedColor="#223344"
        bar.settingsPanel.backgroundColorDialog.close()
        check(bar.diskBarConfig.prism.color===savedColor && !bar.settingsWritePending,"dismissing an unconfirmed color leaves saved color unchanged")
        bar.settingsPanel.backgroundColorDialog.selectedColor="#101820"
        bar.settingsPanel.backgroundColorDialog.open()
        return true
      },
      function() {
        if(!bar.settingsPanel.backgroundColorDialog.visible)return false
        bar.settingsPanel.backgroundColorDialog.accept()
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        check(bar.settingsPanel.opened && !bar.settingsPanel.backgroundColorDialog.visible && bar.diskBarConfig.prism.color==="#101820","native color confirmation persists the chosen background")
        click(action("reset-appearance")); return true
      },
      function() {
        check(action("reset-confirm").visible && !bar.settingsWritePending && bar.diskBarConfig.prism.opacity===0.3,"reset click asks confirmation without saving")
        click(action("reset-cancel"))
        return true
      },
      function() {
        check(!action("reset-confirm").visible && bar.diskBarConfig.prism.opacity===0.3,"cancel reset keeps disk values")
        click(action("reset-appearance"))
        return true
      },
      function() { click(action("reset-confirm")); return true },
      function() {
        if(bar.settingsWritePending)return false
        check(bar.diskBarConfig.prism.opacity===SettingsModel.defaults.opacity && bar.diskBarConfig.prism.radius===SettingsModel.defaults.radius && bar.diskBarConfig.layout.left.length===0 && bar.diskBarConfig.prism.iconPack===SettingsModel.defaults.iconPack,"confirmed native reset persists appearance only")
        bar.settingsPanel.selectedTab=2
        return true
      },
      function() {
        check(bar.commitLayout({left:[{id:"prism.test",count:3,opaque:{token:"preserved"}}],center:[],right:[]}),"schema widget added through actual layout save")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        var panel = bar.settingsPanel
        check(panel.selectEntry("left",0) && bar.canConfigurePrismWidget("prism.test") && bar.openWidgetConfiguration("prism.test"),"selected widget opens typed schema configuration")
        check(!panel.editSchemaField(panel.schemaFields[0],"4.2"),"integer schema rejects fractional draft")
        check(panel.editSchemaField(panel.schemaFields[0],"7") && panel.editSchemaField(panel.schemaFields[1],false) && panel.editSchemaField(panel.schemaFields[2],"second") && panel.editSchemaField(panel.schemaFields[3],"Saved"),"typed schema fields accept valid values")
        check(panel.saveSchemaEntry(),"typed schema edits save atomically")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        var entry = bar.diskBarConfig.layout.left[0]
        var slot = bar.moduleSlots.find(function(item){return item.moduleName==="prism.test"})
        check(entry.id==="prism.test" && entry.count===7 && entry.enabled===false && entry.mode==="second" && entry.label==="Saved" && entry.opaque.token==="preserved","typed schema save preserves ID and opaque settings on disk")
        check(slot && slot.activeItem.settings.count===7 && slot.activeItem.implicitWidth===70,"configured live widget receives saved settings")
        check(bar.diskBarConfig.prism.fontFamily==="Saved Custom Font" && bar.diskBarConfig.prism.semanticOverrides["volume-high"]===suite.assetPath && bar.diskBarConfig.prism.widgetOverrides["omarchy.audio"][""]===suite.assetPath,"schema save preserves saved custom font and SVG overrides")
        check(bar.settingsPanel.selectEntry("left",0) && bar.settingsPanel.moveSelected("center",0),"configured widget moves through simple settings")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.layout.left.length===0 && bar.diskBarConfig.layout.center[0].count===7 && bar.diskBarConfig.layout.center[0].opaque.token==="preserved","widget move persists typed and opaque options")
        check(bar.settingsPanel.selectEntry("center",0) && bar.settingsPanel.removeSelected(),"widget removes through simple settings")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.layout.center.length===0 && !bar.moduleSlots.some(function(slot){return slot.moduleName==="prism.test"}),"widget removal persists and removes live component")
        bar.settingsPanel.addWidget="prism.test"; bar.settingsPanel.addSection="left"
        check(bar.settingsPanel.addEntry(),"available widget adds through simple settings")
        return true
      },
      function() {
        if (bar.settingsWritePending) return false
        check(bar.diskBarConfig.layout.left[0].id==="prism.test" && bar.moduleSlots.some(function(slot){return slot.moduleName==="prism.test" && slot.activeItem && slot.activeItem.visible}),"widget addition persists and renders the available widget")
        bar.settingsPanel.close(); check(!bar.settingsPanel.opened,"settings closes without pending preview")
        return true
      },
      function() {
        temporaryAdapter = temporaryAdapterComponent.createObject(suite)
        temporaryAdapter.observe(spareButton,"omarchy.audio",null)
        return true
      },
      function() {
        if (!temporaryAdapter.targets.length || !temporaryAdapter.targets[0].bindingApplied) return false
        temporaryAdapter.refresh(); temporaryAdapter.schedule(spareButton); temporaryAdapter.notifyChanged()
        temporaryAdapter.destroy(); temporaryAdapter=null
        return true
      },
      function() {
        check(spareButton.iconComponent===null,"adapter destruction restores native ownership with pending work")
        temporaryAdapter = temporaryAdapterComponent.createObject(suite)
        temporaryAdapter.observe(spareButton,"omarchy.audio",null)
        return true
      },
      function() {
        if (!temporaryAdapter.targets.length || !temporaryAdapter.targets[0].bindingApplied) return false
        check(spareButton.iconComponent===temporaryAdapter.targets[0].component,"fresh adapter attaches after queued-work teardown")
        temporaryAdapter.destroy(); temporaryAdapter=null
        return true
      },
      function() { check(spareButton.iconComponent===null,"second adapter teardown leaves original surface"); return true },
      function() {
        var layout=JSON.parse(JSON.stringify(bar.layoutConfig))
        layout.right=[{id:"prism.exec",exec:"printf '%s' '{\"text\":\"Executed\",\"tooltip\":\"command output\",\"class\":\"active\"}'",interval:1,horizontalMargin:7}]
        check(bar.commitLayout(layout),"exec entry accepted")
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        var slot=bar.moduleSlots.find(function(item){return item.moduleName==="prism.exec"})
        if(!slot || !slot.activeItem || slot.activeItem.text!=="Executed")return false
        check(slot.activeItem.active && slot.activeItem.tooltipText==="command output","exec entry renders collected JSON output")
        check(bar.iconAdapter.observations.some(function(item){return item.root===slot.activeItem && item.widgetId==="prism.exec"}),"command widget reaches adapter observation")
        var layout=JSON.parse(JSON.stringify(bar.layoutConfig))
        layout.right[0].horizontalMargin=19
        layout.right[0].exec="printf '%s' '{\"text\":\"Updated\",\"tooltip\":\"updated output\"}'"
        check(bar.commitLayout(layout),"exec inline settings update accepted")
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        var slot=bar.moduleSlots.find(function(item){return item.moduleName==="prism.exec"})
        if(!slot || !slot.activeItem || slot.activeItem.text!=="Updated")return false
        check(slot.activeItem.horizontalMargin===19 && slot.activeItem.tooltipText==="updated output" && !slot.activeItem.active,"command applies updated settings and collected output")
        check(bar.iconAdapter.observations.some(function(item){return item.root===slot.activeItem && item.widgetId==="prism.exec"}),"updated command remains observed")
        var layout=JSON.parse(JSON.stringify(bar.layoutConfig)); layout.right=[]
        check(bar.commitLayout(layout),"exec entry removal accepted")
        return true
      },
      function() {
        if(bar.settingsWritePending)return false
        check(!bar.iconAdapter.observations.some(function(item){return item.widgetId==="prism.exec"}),"command removal releases adapter observation")
        return true
      }
    ];
    phases.push(function() {
      check(bar.commitLayout({left:[{id:"prism.test",count:3}],center:[{id:"prism.test",count:4}],right:[{id:"prism.test",count:5}]}),"three visible sections seeded for layout modes")
      return true
    });
    ["docked","floating-bar","islands"].forEach(function(mode) {
      phases.push(function() {
        if(bar.settingsWritePending)return false
        bar.openPrismSettings(button)
        bar.settingsPanel.selectedTab=0
        return true
      })
      phases.push(function() { click(action("mode-"+mode)); return true })
      phases.push(function() {
        if(bar.settingsWritePending)return false
        check(bar.prismSettings.mode===mode && bar.diskBarConfig.prism.mode===mode,mode+" UI selection persists")
        bar.settingsPanel.close()
        return true
      });
      ["top","bottom","left","right"].forEach(function(edge) {
        phases.push(function() { check(bar.commitPrismPatch({mode:mode,reserveSpace:false,reducedMotion:true}),mode+" geometry mode accepted"); return true })
        phases.push(function() { if(bar.settingsWritePending)return false; check(bar.commitHostSetting("position",edge),edge+" placement accepted"); return true })
        phases.push(function() {
          if(bar.settingsWritePending)return false
          for(var panel of bar.barPanels) {
            var axis = bar.vertical ? panel.height : panel.width
            var cross = bar.vertical ? panel.width : panel.height
            check(axis===(bar.vertical ? panel.screen.height : panel.screen.width) && cross===bar.barWindowSize,mode+" "+edge+" compositor axis and cross-size match effective geometry")
            var background=find(panel.surface,function(item){return item.objectName==="continuous-bar-background"})
            check(!!background && background.visible===(mode!=="islands"),mode+" continuous background visibility")
            if(mode!=="islands") {
              var margin=mode==="docked" ? 0 : bar.geometrySettings.outerMargin
              check((bar.vertical ? background.y : background.x)===margin && (bar.vertical ? background.height : background.width)===axis-2*margin,mode+" continuous background spans the axis with correct margins")
              check(background.radius===(mode==="docked" ? 0 : bar.islandRadius),mode+" continuous background roundness")
            }
            check(bar.islandEdgeGap===(mode==="docked" ? 0 : bar.prismSettings.edgeGap),mode+" screen edge spacing")
            for(var section of ["left","center","right"]) {
              var island=find(panel.surface,function(item){return item.objectName==="island-background-"+section})
              check(!!island && island.visible===(mode==="islands" && panel.surface.geometry.islands[section].extent>0),mode+" "+section+" island visibility")
            }
          }
          return true
        })
      })
    })
    sequence.start()
  }
  Timer {
    id:sequence; interval:120; repeat:true
    onTriggered: {
      try {
        if(index===phases.length) { console.log("PRISM RUNTIME PASS"); stop(); Qt.quit(); return }
        if(phases[index]()) { index++; attempts=0 }
        else if(++attempts>50)throw new Error("Timed out in phase "+index)
      } catch(error) { console.error("PRISM RUNTIME FAIL phase "+index+": "+error); stop(); Qt.quit() }
    }
  }
}
