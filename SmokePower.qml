import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: proof
  required property var bar
  property bool running: false
  readonly property var widget: bar.moduleWidgets("omarchy.power")[0] || null
  property var originalSettings: ({})
  readonly property var slot: bar.moduleSlots.filter(function(s) { return s.activeItem === proof.widget })[0] || null
  property Item button: null
  function find(item) {
    if (item instanceof BarIconButton) return item
    for (var i=0;i<item.children.length;i++) { var result=find(item.children[i]); if(result)return result }
    return null
  }
  onRunningChanged: {
    if (running && widget) {
      originalSettings = widget.settings
      button = find(widget)
      Qt.callLater(function() { bar.iconAdapter.observe(nativeHost,"omarchy.power",slot) })
    } else bar.iconAdapter.release(nativeHost)
  }
  Component.onDestruction: { running=false; bar.iconAdapter.release(nativeHost) }
  Binding { target: proof.widget; property:"settings"; value:Object.assign({},proof.originalSettings,{showPercentage:true}); when:proof.running && !!proof.widget; restoreMode:Binding.RestoreBindingOrValue }
  Binding { target: proof.button; property:"parent"; value:nativeHost; when:proof.running && !!proof.button; restoreMode:Binding.RestoreBindingOrValue }
  Binding { target: proof.button; property:"text"; value:"100% 󰂅"; when:proof.running && !!proof.button; restoreMode:Binding.RestoreBindingOrValue }
  Binding { target: proof.button; property:"visible"; value:true; when:proof.running && !!proof.button; restoreMode:Binding.RestoreBindingOrValue }
  Text { text:"Original registry power button + rounded state surface (projected; no battery)"; color:"white"; font.pixelSize:11; y:8 }
  Item {
    id:nativeHost
    property string moduleName:"omarchy.power"
    x:700
    width:Style.bar.iconSlot*2
    height:proof.bar.barSize
    StatePill {
      anchors.fill: parent
      anchors.margins: 2
      z: -1
      highlighted: true
      motionEnabled: proof.bar.prismSettings.motionEnabled
      reducedMotion: proof.bar.prismSettings.reducedMotion
    }
  }
  function inspect() {
    if (!running || !button || !slot) throw new Error("Original power projection unavailable")
    var record = bar.iconAdapter.records.filter(function(r){return r.target===proof.button})[0]
    if (!record || !record.adapted || record.renderedStatus !== Image.Ready || record.prefix !== "100% " || record.paintedExtent>button.width) throw new Error("Original percentage does not fit the native button")
    console.log("PRISM POWER PASS original registry button identity, native doubled optical surface, percentage fits; batteryPresent="+widget.batteryPresent)
  }
}
