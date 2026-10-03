import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "../" as Prism
import "../shared" as Shared

Item {
  id: suite
  property var phases: []
  property int index: 0
  property int attempts: 0
  property int actions: 0
  property int slotActions: 0
  property int labelActions: 0
  property int labelButton: Qt.NoButton
  property int wheelDelta: 0
  property var initialBounds: null
  property real hoverPillOpacity: 0
  property var latestSource: ""
  property Item removedMotion: null
  readonly property string testHome: Quickshell.env("PRISM_TEST_HOME")
  function check(value, message) { if (!value) throw new Error(message); console.log("PRISM MOTION CHECK " + message) }
  function motion(control) { return bar.controlMotions.find(function(item) { return item && item.control === control }) }
  function record(control) { return bar.iconAdapter.targets.find(function(item) { return item.target === control }) }
  function animated(control) {
    function find(item) {
      if (item instanceof Shared.AnimatedIcon) return item
      for (var child of item.children) { var found=find(child); if(found)return found }
      return null
    }
    return find(record(control).paintItem)
  }
  function move(control, x, y, buttons) { input.mouseMove(control, x, y, 0, buttons || Qt.NoButton, Qt.NoModifier) }
  function press(control) { input.mousePress(control, control.width/2, control.height/2, Qt.LeftButton, Qt.NoModifier, 0) }
  function release(control) { input.mouseRelease(control, control.width/2, control.height/2, Qt.LeftButton, Qt.NoModifier, 0) }
  function slotPill() { return slot.children.find(function(item) { return item.objectName === "open-panel-pill" }) }
  TestEvent { id: input }
  QtObject {
    id: registry
    property var widgets: ({"prism.motion":{component:slotButton},"omarchy.microphone":{component:clippedButton}})
    function metadataFor(id) { return {firstParty:true} }
  }
  Component {
    id: slotButton
    BarIconButton { property string moduleName: "prism.motion"; text:""; onPressed:suite.slotActions++ }
  }
  Component {
    id: clippedButton
    BarIconButton { property string moduleName: "omarchy.microphone"; text:"󰍬"; active:true }
  }
  Prism.Bar {
    id: bar
    home: suite.testHome
    barWidgetRegistry: registry
    barConfig: ({id:"voyagen.prism",position:"top",layout:{left:[],center:[],right:[]},prism:{reserveSpace:false}})
  }
  PanelWindow {
    id: window
    color: "#202020"
    visible: true
    implicitWidth: 640
    implicitHeight: 170
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom:true; left:true }
    screen: Quickshell.screens[0]
    Text { x:20; y:10; color:"white"; text:"Prism motion — native controls / independent symbols" }
    BarIconButton { id: button; bar:bar; text:""; x:20; y:50; height:36; onPressed:suite.actions++ }
    BarIconButton { id: microphone; bar:bar; text:"󰍬"; x:80; y:50; height:36 }
    BarIconButton { id: bluetooth; bar:bar; text:"󰂲"; x:140; y:50; height:36 }
    WidgetButton {
      id: label
      property bool focused: false
      bar:bar; text:"Workspace"; x:200; y:50; width:90; height:36
      onPressed:function(button) { suite.labelActions++; suite.labelButton=button }
      onWheelMoved:function(delta) { suite.wheelDelta+=delta }
    }
    Prism.ModuleSlot { id: slot; controller:bar; entry:"prism.motion"; x:320; y:50 }
    Item {
      x:460; y:50; width:160; height:36
      Prism.AxisRail {
        id: motionRail
        controller:bar
        geometry:({start:0,extent:160,contentExtent:500,initialOffset:0})
        Prism.ModuleSlot {
          id: clippedSlot
          parent:motionRail.contentItem
          controller:bar; rail:motionRail; entry:"omarchy.microphone"; x:20
        }
      }
    }
    Shared.AnimatedIcon {
      id: symbol
      x:400; y:52; width:24; height:24
      source: Qt.resolvedUrl("../assets/icons/lucide/wifi-signal-4.svg")
      replaceEnabled: true
    }
    Text { x:20; y:110; color:"#bbbbbb"; text:"Actions are immediate. Layout and pointer bounds remain fixed." }
  }
  Process {
    id: capture
    command: ["grim", "-g", "0," + (window.screen.height - 170) + " 640x170", Quickshell.env("PRISM_MOTION_CAPTURE")]
  }
  Component.onCompleted: {
    phases = [
      function() {
        bar.iconAdapter.observe(button,"omarchy.audio",null)
        bar.iconAdapter.observe(microphone,"omarchy.microphone",null)
        bar.iconAdapter.observe(bluetooth,"omarchy.bluetooth",null)
        return true
      },
      function() {
        if (!record(button) || !record(button).paintItem || symbol.status !== Image.Ready || !slot.activeItem || !motion(slot.activeItem)) return false
        initialBounds = {width:button.width,height:button.height,implicitWidth:button.implicitWidth,implicitHeight:button.implicitHeight,x:button.x,labelX:label.x}
        move(button,20,18)
        return true
      },
      function() { check(motion(button).hovered && motion(button).visualScale > 1,"native hover produces restrained visual feedback"); press(button); return true },
      function() {
        check(motion(button).pressed && motion(button).visualScale < 0.98 && actions === 0,"mouse-down compresses without invoking click action")
        check(button.scale === 1 && button.width === initialBounds.width && button.height === initialBounds.height && button.implicitWidth === initialBounds.implicitWidth && button.implicitHeight === initialBounds.implicitHeight && button.x === initialBounds.x && label.x === initialBounds.labelX,"interaction leaves layout and hit target unchanged")
        if (Quickshell.env("PRISM_MOTION_CAPTURE")) capture.running = true
        release(button)
        check(actions === 1,"native click action fires immediately on release")
        return true
      },
      function() { check(motion(button).visualScale <= 1.025,"release overshoot is bounded"); move(window.contentItem,600,150); return true },
      function() { return !motion(button).running },
      function() { check(Math.abs(motion(button).visualScale-1)<0.001,"release settles without a motion backlog"); press(button); move(window.contentItem,600,150,Qt.LeftButton); return true },
      function() { input.mouseRelease(window.contentItem,600,150,Qt.LeftButton,Qt.NoModifier,0); check(actions===1,"drag-away release does not invent an action"); return true },
      function() { press(button); release(button); press(button); release(button); check(actions===3,"rapid clicks preserve each immediate native action"); return true },
      function() { move(slot,slot.width/2,slot.height/2); press(slot); return true },
      function() { check(motion(slot.activeItem).pressed && motion(slot.activeItem).visualScale<0.98,"slot overlay press reaches shared physical feedback"); release(slot); check(slotActions===1,"slot forwarding invokes exactly one immediate action"); return true },
      function() { microphone.active=true; return true },
      function() { check(animated(microphone).activeEffect==="breathe" && animated(microphone).running,"actual microphone use starts semantic breathing"); press(microphone); return true },
      function() { check(motion(microphone).visualScale<0.98 && animated(microphone).activeEffect==="breathe","press compression and semantic breathing coexist independently"); release(microphone); bluetooth.text="󰂱"; return true },
      function() { check(record(bluetooth).resolved.semantic==="bluetooth-connected" && animated(bluetooth).activeEffect==="bounce","Bluetooth connection emits one discrete semantic bounce"); button.text=""; return true },
      function() { check(record(button).resolved.semantic==="volume-muted" && animated(button).replacing,"mute state crossfades the rendered icon, not a press bounce"); button.text=""; return true },
      function() { button.text=""; return true },
      function() { check(!animated(button).running,"ordinary volume adjustment leaves the icon still"); bar.previewPrismSetting("reducedMotion",true); move(button,20,18); press(button); symbol.effect="rotate"; symbol.reducedMotion=true; return true },
      function() { check(motion(button).visualScale===1 && motion(button).opacityValue<0.9,"reduced-motion press substitutes opacity for compression"); release(button); check(actions===4,"reduced motion preserves immediate action"); symbol.source=Qt.resolvedUrl("../assets/icons/lucide/bluetooth-enabled.svg"); return true },
      function() { check(symbol.semanticScale===1 && symbol.semanticRotation===0 && symbol.incomingScale===1 && symbol.outgoingScale===1 && symbol.replacing,"reduced-motion loading and replacement are opacity-only"); symbol.effect="none"; symbol.triggerEffect("bounce"); return true },
      function() { check(symbol.semanticY===0 && symbol.semanticScale===1 && symbol.semanticOpacity<1,"reduced bounce substitutes brief opacity emphasis"); symbol.triggerEffect("wiggle"); return true },
      function() { check(symbol.semanticRotation===0 && symbol.semanticScale===1 && symbol.semanticOpacity<1,"reduced wiggle avoids angular motion"); bar.previewPrismSetting("motionEnabled",false); return true },
      function() { check(!motion(button).running && motion(button).visualScale===1,"global disable clears interaction animation"); press(button); release(button); check(actions===5,"disabled motion retains native click behavior"); microphone.active=false; bar.cancelPrismPreview(); symbol.effect="none"; symbol.reducedMotion=false; symbol.triggerEffect("bounce"); return true },
      function() { check(symbol.activeEffect==="bounce" && symbol.semanticY<0,"bounce gives tiny upward semantic feedback"); symbol.triggerEffect("wiggle"); return true },
      function() { check(symbol.activeEffect==="wiggle" && Math.abs(symbol.semanticRotation)>0,"new one-shot interrupts rather than queues feedback"); symbol.effect="breathe"; return true },
      function() { check(symbol.activeEffect==="breathe" && symbol.semanticScale>=1 && symbol.semanticScale<=1.025,"breathe remains inside its restrained scale range"); symbol.visible=false; return true },
      function() { check(!symbol.running,"invisible icon suspends ongoing animation"); symbol.visible=true; symbol.activityEnabled=false; return true },
      function() { check(!symbol.running,"concealed-ancestor activity gate suspends animation"); symbol.activityEnabled=true; symbol.effect="pulse"; return true },
      function() { check(symbol.running,"pulse resumes when visible and requested"); symbol.triggerEffect("wiggle"); return true },
      function() { return symbol.activeEffect==="pulse" },
      function() { check(symbol.semanticScale===1 && symbol.semanticOpacity<1,"one-shot completion resumes opacity-only pulse"); symbol.effect="none"; symbol.triggerEffect("disappear"); return true },
      function() { return !symbol.running },
      function() { check(symbol.semanticOpacity===0 && symbol.width===24 && symbol.height===24,"disappear preserves layout footprint"); symbol.triggerEffect("appear"); return true },
      function() { return !symbol.running },
      function() { check(symbol.semanticOpacity===1,"appear restores the icon"); symbol.source=Qt.resolvedUrl("../assets/icons/lucide/microphone-enabled.svg"); return true },
      function() { symbol.source=Qt.resolvedUrl("../assets/icons/lucide/network-disconnected.svg"); latestSource=symbol.source; return true },
      function() { return !symbol.running },
      function() { check(symbol.status===Image.Ready && String(symbol.currentSource)===String(latestSource),"interrupted replacement settles on the newest source"); symbol.effect="rotate"; return true },
      function() { check(symbol.running,"semantic rotation runs when explicitly requested"); symbol.motionEnabled=false; return true },
      function() { check(!symbol.running && symbol.semanticScale===1 && symbol.semanticOpacity===1,"disabled icon motion immediately restores native presentation"); bar.previewPrismSetting("motionOverrides",{"omarchy.audio":{interactionEnabled:false,iconEnabled:false},"omarchy.microphone":{effect:"none"}}); move(button,20,18); press(button); return true },
      function() { check(motion(button).visualScale===1 && !animated(microphone).running,"widget-scoped overrides disable control and semantic motion independently"); release(button); check(actions===6,"per-control opt-out preserves actions"); bar.cancelPrismPreview(); move(label,45,18); press(label); return true },
      function() { check(motion(label).visualScale<0.98,"shared text buttons receive the same press feedback"); release(label); check(labelActions===1,"text-button action remains immediate"); input.mouseClick(label,45,18,Qt.RightButton,Qt.NoModifier,0); check(labelActions===2 && labelButton===Qt.RightButton,"right-click routing remains native"); input.mouseClick(label,45,18,Qt.MiddleButton,Qt.NoModifier,0); check(labelActions===3 && labelButton===Qt.MiddleButton,"middle-click routing remains native"); input.mouseWheel(label,45,18,Qt.NoButton,Qt.NoModifier,0,120,0); check(wheelDelta===120,"passive feedback preserves native wheel delivery"); return true },
      function() { move(window.contentItem,600,150); label.focused=true; button.active=true; bar.activePopout=slot.activeItem; return true },
      function() { return !motion(label).running },
      function() {
        check(label.focused && motion(label).statePill.opacity===0 && motion(label).visualScale===1,"workspace focus alone keeps the interaction pill hidden")
        check(motion(button).statePill.opacity>0.1 && motion(button).statePill.width===motion(button).statePill.height && motion(button).statePill.radius===motion(button).statePill.width/2 && button.width===initialBounds.width && label.x===initialBounds.labelX,"active icon pill is circular without shifting neighbors")
        check(slotPill().opacity>0.1 && slotPill().radius===Math.min(slotPill().width,slotPill().height)/2 && slotPill().width>=slot.width && slotPill().height>=slot.height && slotPill().x===(slot.width-slotPill().width)/2 && slotPill().y===(slot.height-slotPill().height)/2,"open panel uses centered rounded geometry without shrinking native padding")
        check(motion(slot.activeItem).statePill.targetOpacity===0,"module pill suppresses duplicate button highlights")
        bar.clearTooltip()
        if(Quickshell.env("PRISM_MOTION_CAPTURE"))capture.running=true
        return true
      },
      function() { bar.activePopout=null; label.focused=false; button.active=false; move(button,20,18); return true },
      function() { hoverPillOpacity=motion(button).statePill.opacity; check(hoverPillOpacity>0 && !animated(button).running,"hover pill leaves its semantic icon still"); button.active=true; return true },
      function() { check(motion(button).statePill.opacity>hoverPillOpacity,"active and hover states combine without competing highlights"); bar.previewPrismSetting("motionEnabled",false); button.active=false; move(label,45,18); return true },
      function() { var hoverOpacity=motion(label).statePill.opacity; check(!motion(label).statePill.animating && hoverOpacity>0 && motion(label).visualScale===1,"disabled animations retain static hover feedback"); label.focused=true; check(motion(label).statePill.opacity===hoverOpacity,"workspace focus does not strengthen the hover pill"); label.active=true; check(!motion(label).statePill.animating && motion(label).statePill.opacity>hoverOpacity,"disabled animations retain immediate active state"); bar.cancelPrismPreview(); bar.previewPrismSetting("reducedMotion",true); return true },
      function() { check(!motion(label).statePill.animating && motion(label).statePill.opacity>0 && motion(label).visualScale===1 && motion(label).statePill.width>=label.labelWidth+Style.space(12) && motion(label).statePill.radius===motion(label).statePill.height/2,"reduced-motion text pill has padded rounded ends and stable geometry"); label.visible=false; return true },
      function() { check(!motion(label).statePill.animating && !motion(label).running,"invisible control stops pill and physical motion"); label.visible=true; label.focused=false; label.active=false; bar.cancelPrismPreview(); return true },
      function() { bar.previewPrismSetting("animationIntensity","expressive"); move(button,20,18); microphone.active=true; return true },
      function() { return !motion(button).running },
      function() {
        check(motion(button).visualScale>1.06 && button.width===initialBounds.width && button.scale===1,"Expressive hover is stronger without changing the hit target")
        press(button); bluetooth.text="󰂲"; return true
      },
      function() {
        check(motion(button).visualScale<=0.901,"Expressive press visibly compresses the painted control")
        release(button); bluetooth.text="󰂱"; return true
      },
      function() {
        check(animated(bluetooth).semanticY < -2,"Expressive Bluetooth bounce has greater travel")
        bar.previewPrismSetting("reducedMotion",true); press(button); return true
      },
      function() {
        check(motion(button).visualScale===1 && animated(microphone).semanticScale===1,"Reduced motion takes precedence over Expressive geometry")
        release(button); bar.cancelPrismPreview(); return true
      },
      function() { if(!clippedSlot.activeItem || !record(clippedSlot.activeItem) || !record(clippedSlot.activeItem).paintItem)return false; check(animated(clippedSlot.activeItem).activeEffect==="breathe","visible rail icon starts its requested semantic state"); motionRail.scroll(180); return true },
      function() { check(clippedSlot.visible && clippedSlot.opacity>0 && !bar.drawnSlotRect(clippedSlot) && !animated(clippedSlot.activeItem).running,"fully clipped icon stops motion despite native visible and opacity"); motionRail.scroll(-180); return true },
      function() { check(animated(clippedSlot.activeItem).activeEffect==="breathe","scrolling icon back into view resumes semantic state"); motionRail.scroll(25); return true },
      function() { check(!!bar.drawnSlotRect(clippedSlot) && animated(clippedSlot.activeItem).running,"partially drawn icon retains semantic motion"); motionRail.scroll(clippedSlot.x+clippedSlot.width-motionRail.offset); return true },
      function() { check(!bar.drawnSlotRect(clippedSlot) && !animated(clippedSlot.activeItem).running,"viewport boundary without intersection suspends motion"); motionRail.scroll(-motionRail.offset); bar.barConfig=Object.assign({},bar.barConfig,{position:"left"}); bar.activePopout=slot.activeItem; return true },
      function() { check(bar.vertical && slotPill().radius===Math.min(slotPill().width,slotPill().height)/2 && slotPill().width>=slot.width && slotPill().height>=slot.height && slotPill().opacity>0.1,"vertical panel retains centered rounded geometry and native padding"); bar.activePopout=null; removedMotion=motion(slot.activeItem); registry.widgets=({}); return true },
      function() { if(removedMotion)return false; check(bar.controlMotions.every(function(item){return item && item.control}),"unloaded widget removes its pointer observer and helper"); return true }
    ]
    sequence.start()
  }
  Timer {
    id: sequence
    interval:120
    repeat:true
    onTriggered: {
      try {
        if (index===phases.length) { console.log("PRISM RUNTIME PASS — motion"); stop(); Qt.quit(); return }
        if (phases[index]()) { index++; attempts=0 }
        else if (++attempts>50) throw new Error("Timed out in phase " + index)
      } catch(error) { console.error("PRISM RUNTIME FAIL motion phase " + index + ": " + error); stop(); Qt.quit() }
    }
  }
}
