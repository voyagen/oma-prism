import QtQuick
import QtTest
import Quickshell
import qs.Ui
import qs.Commons
import "../../plugins/panels/clock" as NativeClock
import Quickshell.Io
import "../" as Prism
import "../SettingsModel.js" as SettingsModel

Item {
  id: suite
  property int index: 0
  property int actions: 0
  property var cases: []
  property var current: null
  function check(value, message) { if (!value) throw new Error(message) }
  TestEvent { id: input }
  QtObject {
    id: registry
    property var widgets: ({"prism.group":{component:group},"omarchy.clock":{component:clock},"prism.power":{component:power},"prism.zero":{component:zero}})
    function metadataFor(id) { return {firstParty:true} }
  }
  Component {
    id: group
    BarWidget {
      implicitWidth: row.implicitWidth
      implicitHeight: vertical ? row.implicitHeight : barSize
      Grid {
        id: row
        anchors.centerIn: parent
        columns: parent.vertical ? 1 : 3
        spacing: bar ? bar.densityUnit : 0
        BarIconButton { property string moduleName:"omarchy.audio"; bar: parent.parent.bar; text:""; active:true; onPressed:suite.actions++ }
        BarIconButton { property string moduleName:"omarchy.bluetooth"; bar: parent.parent.bar; text:"󰂲"; active:true }
        WidgetButton { bar: parent.parent.bar; text:"Workspaces"; active:true }
      }
    }
  }
  Component { id: clock; NativeClock.BarWidget {} }
  Component { id: power; BarIconButton { property string moduleName:"omarchy.power"; text:"100% 󰁹"; active:true } }
  Component { id:zero; BarWidget { implicitWidth:vertical?barSize:0; implicitHeight:vertical?0:barSize } }
  Prism.Bar {
    id: bar
    home: Quickshell.env("PRISM_TEST_HOME")
    barWidgetRegistry: registry
    barConfig: ({id:"voyagen.prism",position:"top",centerAnchor:"omarchy.clock",layout:{left:["prism.group","prism.zero"],center:["omarchy.clock"],right:["prism.power"]},prism:{reserveSpace:false,motionEnabled:false}})
  }
  function configure() {
    current=cases[index]
    bar.barConfig=Object.assign({},bar.barConfig,{position:current.position,prism:Object.assign({},SettingsModel.spacingPresets[current.density],{mode:current.mode,reserveSpace:false,motionEnabled:false,iconSize:current.large?32:18,fontSize:current.large?24:12})})
  }
  function inspect() {
    var panel=bar.barPanels[0], surface=panel.surface
    check(!!panel,"mapped bar panel")
    for (var slot of bar.moduleSlots) {
      check(!!slot.activeItem,"native slot loaded")
      if(slot.moduleName==="prism.zero")check((bar.vertical?slot.implicitHeight:slot.implicitWidth)===0,"zero-axis spacer remains zero instead of inventing a pill")
      var slotCross=bar.vertical?slot.width:slot.height
      check(surface[bar.vertical?"width":"height"]-slotCross>=2*bar.barCrossPadding,"cross-axis breathing room")
      var controls=[]
      function collect(item) {
        if(item instanceof WidgetButton)controls.push(item)
        else for(var child of item.children)collect(child)
      }
      collect(slot.activeItem)
      if(slot.moduleName==="omarchy.clock" && bar.vertical) {
        var nativeClock=slot.activeItem, button=controls[0]
        check(!button.labelVisible && nativeClock.verticalLines.length>1,"real native clock paints a multiline vertical stack")
        check(button.height>=nativeClock.verticalLines.length*Style.bar.iconSlot,"native clock reserves every vertical line without clipping")
      }
      for(var control of controls) {
        var motion=bar.controlMotions.find(function(m){return m.control===control})
        check(!!motion,"native control motion registered")
        var pill=motion.statePill
        var point=pill.mapToItem(surface,0,0)
        var cross=bar.vertical?point.x:point.y
        var crossSize=bar.vertical?pill.width:pill.height
        check(cross>=bar.barCrossPadding-0.01 && cross+crossSize<=bar.islandThickness-bar.barCrossPadding+0.01,"pill stays inside cross-axis inset")
        check(pill.x>=-0.01 && pill.y>=-0.01 && pill.width<=control.width+0.01 && pill.height<=control.height+0.01,"paint stays in reserved hit/layout bounds")
        if(control.labelWidth>0)check(pill.width>=control.labelWidth+2*bar.pillHorizontalPadding-0.01 || bar.vertical,"label has density padding")
      }
      if(!bar.vertical) {
        controls.sort(function(a,b){return a.mapToItem(surface,0,0).x-b.mapToItem(surface,0,0).x})
        for(var i=1;i<controls.length;i++)check(controls[i].mapToItem(surface,0,0).x-(controls[i-1].mapToItem(surface,0,0).x+controls[i-1].width)>=bar.densityUnit-0.01,"nested pills retain a visible gap")
      }
    }
    var geometry=surface.geometry
    var left=geometry.groups.left, right=geometry.groups.right
    var axis=surface.axisLength
    var margin=current.mode==="docked"?0:bar.prismSettings.outerMargin
    check(Math.abs(left.start-margin-bar.prismSettings.sectionPadding)<0.01,"left edge inset")
    check(Math.abs(axis-margin-right.start-right.extent-bar.prismSettings.sectionPadding)<0.01,"matching right edge inset")
    check(Math.abs(geometry.groups.centerAnchor.start+geometry.groups.centerAnchor.extent/2-axis/2)<0.01,"clock remains physically centered")
    if(!bar.vertical && !current.large)check(bar.islandThickness===bar.prismSettings.thickness,"density controls overall bar height")
    var control=bar.controlMotions.find(function(m){return m.control.text===""}).control
    input.mouseClick(control,control.width/2,control.height/2,Qt.LeftButton,Qt.NoModifier,0)
    check(actions===index+1,"native action remains immediate")
    console.log("PRISM LAYOUT CHECK "+JSON.stringify(current)+" bar="+bar.islandThickness+" pill="+bar.barSize+" inset="+bar.barCrossPadding)
    if(current.position==="top" && current.mode==="floating-bar" && !current.large && Quickshell.env("PRISM_LAYOUT_CAPTURE")) {
      var screen=panel.screen
      capture.command=["grim","-g",screen.x+","+screen.y+" "+screen.width+"x"+bar.barWindowSize,Quickshell.env("PRISM_LAYOUT_CAPTURE")+"/prism-"+current.density+".png"]
      capture.running=true
      return true
    }
    return false
  }
  function advance() {
    if(++index===cases.length) { console.log("PRISM RUNTIME PASS — layout"); sequence.stop(); Qt.quit() }
    else { configure(); sequence.start() }
  }
  Process {
    id: capture
    onExited: function(code) {
      if(code!==0) { console.error("PRISM RUNTIME FAIL screenshot"); Qt.quit() }
      else suite.advance()
    }
  }
  Component.onCompleted: {
    for(var density of ["compact","default","comfortable"])for(var mode of ["docked","floating-bar","islands"])for(var position of ["top","left"])cases.push({density:density,mode:mode,position:position})
    cases.push({density:"compact",mode:"floating-bar",position:"top",large:true})
    configure()
    sequence.start()
  }
  Timer {
    id: sequence
    interval:350
    repeat:true
    onTriggered: {
      try {
        if(suite.inspect())stop()
        else suite.advance()
      } catch(error) { console.error("PRISM RUNTIME FAIL layout "+JSON.stringify(suite.current)+": "+error); stop(); Qt.quit() }
    }
  }
}
