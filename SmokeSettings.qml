import QtQuick
import QtTest
import QtQuick.Controls as Controls
import Quickshell.Io
import qs.Ui as Ui
import "SettingsModel.js" as SettingsModel
import "shared" as Shared
Item {
  id:proof
  required property var bar
  required property var panel
  parent:panel.acceptanceFocusItem
  property var original:({})
  property var changed:({})
  property var steps:[]
  property int index:0
  property var clock:null
  property var clockButton:null
  property var audio:null
  property var slider:null
  property var packChoice:null
  property var priorLayout:null
  property string expectedPack:""
  property int originalRecordCount:0
  TestEvent { id:events }
  function check(value,message) { if(!value)throw new Error(message);console.log("PRISM SETTINGS CHECK "+message) }
  function find(item,predicate) {
    if(predicate(item))return item
    for(var child of item.children){var found=find(child,predicate);if(found)return found}
    return null
  }
  function control(key,kind) { return find(panel.acceptanceFocusItem,function(item){return item.settingKey===key && item instanceof Ui.Dropdown}) }
  function action(name) { return find(panel.acceptanceFocusItem,function(item){return item.objectName===name}) }
  function ensureVisible(item) {
    for(var parent=item.parent;parent;parent=parent.parent)if(parent instanceof Controls.ScrollView) {
      var flick=parent.contentItem
      if(flick && "contentY" in flick && flick.contentHeight>flick.height) {
        var point=item.mapToItem(flick.contentItem,0,0)
        flick.contentY=Math.max(0,Math.min(flick.contentHeight-flick.height,point.y-flick.height/3))
      }
    }
  }
  function click(item) { check(!!item,"real requested control available");ensureVisible(item);events.mouseClick(item,item.width/2,item.height/2,Qt.LeftButton,Qt.NoModifier,0) }
  function write(key,value) { changed[key]=value;check(bar.commitPrismSetting(key,value),"API accepts validated "+key) }
  function saved(key,value) { check(!bar.settingsWritePending && !bar.settingsError && bar.equalSettingsValue(bar.barConfig.prism[key],value),"shell confirms persisted "+key+" (actual="+JSON.stringify(bar.barConfig.prism[key])+", pressed="+(slider ? slider.pressed : false)+", panel="+panel.opened+", editable="+panel.editable+", error="+bar.settingsError+"/"+panel.localError+")") }
  function customValuesPreserved() {
    for(var key of ["fontFamily","semanticOverrides","widgetOverrides","transitionDuration"])
      check(bar.equalSettingsValue((bar.barConfig.prism || {})[key],(original.prism || {})[key]),"ordinary UI save retains saved "+key)
  }
  function restore() {
    panel.close()
    bar.cancelPrismPreview()
    if(original.id)bar.shell.mutateShellConfig(function(config){
      for(var key of Object.keys(proof.changed)) {
        if(config.bar.prism && proof.bar.equalSettingsValue(config.bar.prism[key],proof.changed[key])) {
          if(proof.original.prism && Object.prototype.hasOwnProperty.call(proof.original.prism,key))config.bar.prism[key]=proof.original.prism[key]
          else delete config.bar.prism[key]
        }
      }
      if(proof.priorLayout)config.bar.layout=proof.priorLayout
    })
    priorLayout=null
  }
  Timer {
    id:sequence
    interval:700
    repeat:true
    onTriggered: {
      try {
        if(proof.index===proof.steps.length){console.log("PRISM SETTINGS PASS");stop();proof.restore();return}
        proof.steps[proof.index++]()
      }catch(error){console.error("PRISM SETTINGS FAIL "+error);stop();proof.restore()}
    }
  }
  function run() {
    original=JSON.parse(JSON.stringify(bar.barConfig));changed=({});priorLayout=null;index=0
    clock=bar.moduleWidgets("omarchy.clock")[0];audio=bar.moduleWidgets("omarchy.audio")[0]
    clockButton=find(clock,function(item){return item instanceof Ui.WidgetButton && !(item instanceof Ui.BarIconButton)})
    originalRecordCount=bar.iconAdapter.records.length
    expectedPack=bar.prismSettings.iconPack==="lucide" ? "material-symbols" : "lucide"
    steps=[
      function(){ panel.close();click(bar.barPanels[0].settingsButton) },
      function(){check(panel.opened,"ordinary draggable Prism widget opens settings");check(bar.equalSettingsValue(bar.barConfig.layout,original.layout),"settings click leaves saved layout intact");click(action("tab-appearance"));slider=action("slider-radius");ensureVisible(slider);events.mousePress(slider,slider.width*0.55,slider.height/2,Qt.LeftButton,Qt.NoModifier,0);events.mouseMove(slider,slider.width*0.7,slider.height/2,0,Qt.LeftButton,Qt.NoModifier);check(slider.pressed && bar.prismSettings.radius===Math.round(slider.value),"actual slider drag previews bounded radius");check((bar.barConfig.prism || {}).radius===(original.prism || {}).radius,"preview does not write configuration");changed.radius=Math.round(slider.value);events.mouseRelease(slider,slider.width*0.7,slider.height/2,Qt.LeftButton,Qt.NoModifier,0) },
      function(){saved("radius",changed.radius) },
      function(){saved("radius",changed.radius);check(bar.moduleWidgets("omarchy.clock")[0]===clock && bar.moduleWidgets("omarchy.audio")[0]===audio,"geometry setting retains original widget identities");check(bar.previewPrismSetting("radius",40),"preview accepted");panel.close() },
      function(){check(bar.prismSettings.radius===changed.radius,"closing cancels preview back to persisted radius");bar.openPrismSettings(null) },
      function(){write("background","custom") },
      function(){click(action("background-color-picker"));check(panel.backgroundColorDialog.visible,"native background color picker opens");panel.backgroundColorDialog.close();panel.backgroundColorDialog.selectedColor="#101820";panel.backgroundColorDialog.open() },
      function(){changed.color="#101820";panel.backgroundColorDialog.accept() },
      function(){saved("color","#101820");customValuesPreserved();click(action("tab-icons"));packChoice=control("iconPack","choice");click(packChoice) },
      function(){check(packChoice.popupOpen,"pack dropdown receives actual click");events.keyClick(expectedPack==="material-symbols" ? Qt.Key_Down : Qt.Key_Up,Qt.NoModifier,0);changed.iconPack=expectedPack;events.keyClick(Qt.Key_Return,Qt.NoModifier,0) },
      function(){saved("iconPack",expectedPack);check(bar.iconAdapter.records.length===originalRecordCount,"pack switch preserves adapter record count");check(bar.moduleWidgets("omarchy.audio")[0]===audio,"pack switch retains native audio instance");write("fontSize",20) },
      function(){saved("fontSize",20);check(clockButton.fontSize===20,"public native clock label receives independent font size");check(bar.previewPrismSetting("fontSize",24),"font preview accepted");panel.close() },
      function(){check(clockButton.fontSize===20,"closing restores persisted text size");bar.openPrismSettings(null);customValuesPreserved();click(action("tab-widgets"));var section="",idx=-1;for(var name of ["left","center","right"])for(var i=0;i<bar.layoutConfig[name].length;i++)if(bar.entryId(bar.layoutConfig[name][i])==="omarchy.clock"){section=name;idx=i};priorLayout=JSON.parse(JSON.stringify(bar.barConfig.layout));check(panel.selectEntry(section,idx),"ordinary clock can be selected");check(panel.moveSelected("center",0),"ordinary clock moves to center through settings") },
      function(){check(!bar.settingsWritePending && bar.entryId(bar.layoutConfig.center[0])==="omarchy.clock","ordinary clock move persists");var originalEntry=null;for(var name of ["left","center","right"])for(var entry of priorLayout[name])if(bar.entryId(entry)==="omarchy.clock")originalEntry=entry;check(bar.equalSettingsValue(bar.layoutConfig.center[0],originalEntry),"widget move preserves all saved inline options");panel.addWidget="omarchy.clock";panel.addSection="left";check(!panel.addEntry() && panel.localError!=="","canonical singleton duplicate addition is rejected");customValuesPreserved();events.keyClick(Qt.Key_Tab,Qt.NoModifier,0);events.keyClick(Qt.Key_Escape,Qt.NoModifier,0) },
      function(){check(!panel.opened,"keyboard Tab / Escape leaves panel closed");var surface=bar.barPanels[0].surface;events.mouseClick(surface,4,surface.height/2,Qt.RightButton,Qt.NoModifier,0) },
      function(){check(panel.opened,"right-click on bar padding opens own settings");panel.close();check(bar.iconAdapter.records.every(function(record,index,list){return list.findIndex(function(other){return other.target===record.target})===index}),"no duplicate QObject icon ownership after settings interaction") }
    ]
    sequence.start()
  }
  function presets() {
    original=JSON.parse(JSON.stringify(bar.barConfig));changed=({});priorLayout=null;index=0
    steps=[function(){clock=bar.moduleWidgets("omarchy.clock")[0];audio=bar.moduleWidgets("omarchy.audio")[0];check(clock && audio && clock.moduleName==="omarchy.clock" && audio.moduleName==="omarchy.audio","settled native clock/audio available");panel.close();bar.openPrismSettings(null);panel.selectedTab=0}]
    for(var name of ["compact","default","comfortable"]) {
      const presetName=name
      steps.push(function(){
        var values=SettingsModel.spacingPresets[presetName]
        for(var key of Object.keys(values))changed[key]=values[key]
        var start=Date.now()
        click(action("spacing-"+presetName))
        check(Date.now()-start<500,"preset click completes within 500ms: "+presetName)
      })
      steps.push(function(){
        for(var key of Object.keys(SettingsModel.spacingPresets[presetName]))saved(key,SettingsModel.spacingPresets[presetName][key])
        check(SettingsModel.spacingPreset(bar.barConfig.prism)===presetName,"persisted spacing selects "+presetName)
        check(bar.moduleWidgets("omarchy.clock")[0]===clock && bar.moduleWidgets("omarchy.audio")[0]===audio,"spacing retains native widget identity")
      })
    }
    for(var mode of ["docked","floating-bar","islands"]) {
      const selectedMode=mode
      steps.push(function(){changed.mode=selectedMode;click(action("mode-"+selectedMode))})
      steps.push(function(){saved("mode",selectedMode);check(bar.prismSettings.outlineWidth===0,"borderless "+selectedMode+" surface");var svg=find(action("tab-appearance"),function(item){return item instanceof Shared.SvgIcon});check(svg && svg.status===Image.Ready && svg.paintedExtent>0,"menu Lucide SVG paints successfully")})
    }
    steps.push(function(){panel.close();check(bar.iconAdapter.records.every(function(record,index,list){return list.findIndex(function(other){return other.target===record.target})===index}),"stable QObject ownership after preset and mode changes")})
    sequence.start()
  }
  IpcHandler {
    target:"prism.settings-proof"
    function run():void { proof.run() }
    function presets():void { proof.presets() }
    function quick():void {
      var original=JSON.parse(JSON.stringify(proof.bar.barConfig))
      var clock=proof.bar.moduleWidgets("omarchy.clock")[0],audio=proof.bar.moduleWidgets("omarchy.audio")[0]
      try {
        var settingsButton=proof.bar.moduleWidgets("voyagen.prism.settings")[0].settingsButton
        var svg=proof.find(settingsButton,function(item){return "source" in item && String(item.source).endsWith("/prism.svg") && "paintedExtent" in item})
        proof.check(svg && svg.status===Image.Ready && svg.opticalSize===proof.bar.prismSettings.iconSize,"Prism SVG matches configured plugin optical size: "+JSON.stringify({found:!!svg,status:svg ? svg.status : -1,size:svg ? svg.opticalSize : -1,expected:proof.bar.prismSettings.iconSize,api:proof.bar.moduleWidgets("voyagen.prism.settings")[0].bar.prismIconSize}))
        var originalWidth=settingsButton.width,originalHeight=settingsButton.height
        for(var size of [12,24,32]) {
          proof.check(proof.bar.commitPrismSetting("iconSize",size),"live icon size accepts "+size)
          proof.check(svg.opticalSize===size && svg.width===size && svg.height===size,"Prism SVG updates to "+size+"px")
          proof.check(settingsButton.width===originalWidth && settingsButton.height===originalHeight,"Prism native hit target is unchanged")
        }
        for(var name of ["compact","default","comfortable"]) {
          var start=Date.now()
          proof.check(proof.bar.commitSpacingPreset(name),"live API accepts "+name)
          proof.check(Date.now()-start<500,"live preset mutation under 500ms: "+name)
          proof.check(!proof.bar.settingsWritePending && SettingsModel.spacingPreset(proof.bar.barConfig.prism)===name,"preset persistence confirmed: "+name)
          proof.check(proof.bar.moduleWidgets("omarchy.clock")[0]===clock && proof.bar.moduleWidgets("omarchy.audio")[0]===audio,"preset preserves native widget identities: "+name)
        }
        for(var mode of ["docked","floating-bar","islands"]) {
          proof.check(proof.bar.commitPrismSetting("mode",mode),"live mode accepts "+mode)
          proof.check(proof.bar.prismSettings.mode===mode && proof.bar.prismSettings.outlineWidth===0,"borderless live "+mode)
        }
        proof.check(proof.bar.commitPrismSetting("fontSize",20),"font update accepts 20px")
        proof.check(proof.bar.previewPrismSetting("fontSize",24),"font preview accepts 24px")
        proof.bar.cancelPrismPreview()
        proof.check(proof.bar.prismSettings.fontSize===20,"font preview cancellation restores persisted 20px")
        console.log("PRISM QUICK PASS")
      } catch(error) {console.error("PRISM QUICK FAIL "+error)}
      finally {proof.bar.shell.mutateShellConfig(function(config){config.bar.prism=original.prism})}
    }
    function padding():void {
      proof.bar.shell.mutateShellConfig(function(config){
        config.bar.prism=Object.assign({},config.bar.prism,{edgeGap:6,outerMargin:8,sectionPadding:12,widgetSpacing:6,thickness:32,outlineWidth:0})
      })
      console.log("PRISM PADDING RESTORED "+JSON.stringify(proof.bar.prismSettings))
    }
  }
}
