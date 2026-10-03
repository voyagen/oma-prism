import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui
Item {
  id: proof
  required property var bar
  parent:bar.barPanels.length ? bar.barPanels[0].surface : null
  property bool active:false
  property var draft:({})
  property var originals:({})
  property var identities:({})
  property int slotCount:0
  property string expectedAnchor:""
  TestEvent { id:events }
  function check(value,message) { if(!value)throw new Error(message); console.log("PRISM LAYOUT CHECK "+message) }
  function findButton(item) {
    if(item instanceof BarIconButton)return item
    for(var i=0;i<item.children.length;i++){var found=findButton(item.children[i]);if(found)return found}
    return null
  }
  function configure(position,mode,anchor,overflow) {
    if(!active) {
      originals=JSON.parse(JSON.stringify(bar.barConfig))
      var clock=null,audio=null
      for(var section of ["left","center","right"])for(var entry of originals.layout[section]) {
        if(bar.entryId(entry)==="omarchy.clock")clock=entry
        if(bar.entryId(entry)==="omarchy.audio")audio=entry
      }
      check(!!clock && !!audio,"real saved clock and audio entries available")
      draft=Object.assign({},originals,{layout:{left:[{id:"omarchy.spacer",size:overflow?3500:210},{id:"omarchy.monitor"}],center:[{id:"omarchy.spacer",size:overflow?3500:110},clock,{id:"omarchy.spacer",size:overflow?3500:40}],right:[{id:"omarchy.spacer",size:overflow?3500:32},audio]}})
      active=true
      slotCount=0
      identities=({})
    }
    expectedAnchor=anchor
    draft=Object.assign({},draft,{position:position,centerAnchor:anchor,prism:Object.assign({},draft.prism,{mode:mode})})
    bar.shell.mutateShellConfig(function(config){config.bar=proof.draft})
  }
  function inspect() {
    var panel=bar.barPanels[0], surface=panel.surface, geometry=surface.geometry
    var axis=bar.vertical?surface.height:surface.width
    var painted=[]
    for(var name of ["left","center","right"]) {
      var island=geometry.islands[name]
      check(island.start>=0 && island.extent>=0 && island.start+island.extent<=axis+0.01,name+" island bounded")
      if(island.extent>0)painted.push(island)
    }
    painted.sort(function(a,b){return a.start-b.start})
    for(var i=1;i<painted.length;i++)check(painted[i-1].start+painted[i-1].extent<=painted[i].start,"painted sections do not overlap")
    var group=geometry.groups[expectedAnchor?"centerAnchor":"center"]
    check(Math.abs(group.start+group.extent/2-axis/2)<0.01,"ordinary center / selected anchor is physically centered")
    check(bar.moduleSlots.length===7,"one slot per saved fixture entry")
    if(slotCount)check(bar.moduleSlots.length===slotCount,"position/mode preserve slot count")
    slotCount=bar.moduleSlots.length
    for(var slot of bar.moduleSlots) {
      var id=slot.region+":"+slot.layoutIndex
      if(identities[id])check(identities[id]===slot.activeItem,"native widget identity retained "+id)
      else identities[id]=slot.activeItem
    }
    var records=bar.iconAdapter.records
    for(var a=0;a<records.length;a++)for(var b=a+1;b<records.length;b++)if(records[a].target===records[b].target)throw new Error("duplicate icon QObject ownership")
    console.log("PRISM LAYOUT PASS "+bar.position+" "+bar.prismSettings.mode+" "+JSON.stringify(geometry))
  }
  function scroll() {
    var surface=bar.barPanels[0].surface
    for(var name of ["left","right","centerBefore","centerAfter"]) {
      var rail=surface.rails[name]
      if(!rail.overflow)continue
      rail.scroll(-100000)
      check(rail.offset===0,name+" scroll reaches first native entry")
      events.mouseWheel(rail,rail.width/2,rail.height/2,Qt.NoButton,Qt.NoModifier,0,-120,0)
      check(rail.offset>0,name+" empty-rail wheel changes viewport")
      bar.barPanels[0].focusRail(rail)
      events.keyClick(Qt.Key_Right,Qt.NoModifier,200)
      check(rail.offset>=96,name+" keyboard moves viewport")
      rail.scroll(100000)
      check(rail.offset===rail.maximumOffset,name+" scroll reaches last native entry")
    }
  }
  function popup() {
    var audio=bar.moduleWidgets("omarchy.audio")[0]
    var button=findButton(audio)
    var rail=bar.barPanels[0].surface.rails.right
    rail.scroll(100000)
    audio.close()
    events.mouseClick(button,button.width/2,button.height/2,Qt.LeftButton,Qt.NoModifier,0)
    check(audio.opened,"native audio popup opens at "+bar.position)
    console.log("PRISM POPUP GEOMETRY "+bar.position+" "+JSON.stringify({x:button.mapToItem(null,0,0).x,y:button.mapToItem(null,0,0).y,width:button.width,height:button.height}))
  }
  IpcHandler {
    target:"prism.layout"
    function baseline():void { proof.identities=({});proof.slotCount=0 }
    function configure(position:string,mode:string,anchor:string,overflow:bool):void { proof.configure(position,mode,anchor,overflow) }
    function inspect():void { try { proof.inspect() }catch(error){console.error("PRISM LAYOUT FAIL "+error)} }
    function scroll():void { try { proof.scroll() }catch(error){console.error("PRISM SCROLL FAIL "+error)} }
    function popup():void { try { proof.popup() }catch(error){console.error("PRISM POPUP FAIL "+error)} }
    function restore():void {
      if(!proof.active || !proof.originals.id)return
      proof.bar.shell.mutateShellConfig(function(config){config.bar=proof.originals})
      proof.active=false
      proof.originals=({})
    }
  }
}
