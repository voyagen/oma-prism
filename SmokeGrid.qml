import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Ui
import qs.Commons
import "IconResolver.js" as Resolver
import "SettingsModel.js" as SettingsModel
import "/usr/share/omarchy/shell/plugins/panels/power/Model.js" as PowerModel
import "/usr/share/omarchy/shell/plugins/panels/network/Model.js" as NetworkModel
import "/usr/share/omarchy/shell/plugins/panels/weather/Model.js" as WeatherModel

PanelWindow {
  id: gridWindow
  required property var bar
  property bool shown: false
  property string pack: "lucide"
  property var cells: []
  property bool percentages: false
  SmokePower { id: realPower; bar:gridWindow.bar; x:20; y:685; running:gridWindow.shown && gridWindow.percentages }
  visible: shown
  color: "#181818"
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "prism-smoke-grid"
  anchors { top: true; left: true }
  margins { top: 90; left: 90 }
  implicitWidth: 1100
  implicitHeight: 730
  Binding {
    target: gridWindow.bar.iconAdapter
    property: "settings"
    value: SettingsModel.normalizeSettings(Object.assign({},gridWindow.bar.prismSettings,{iconPack:gridWindow.pack}))
    when: gridWindow.shown
    restoreMode: Binding.RestoreBindingOrValue
  }
  function emittedGlyph(sample) {
    var battery=/^battery-(charging-)?level-([0-9])$/.exec(sample.semantic)
    if(battery) return PowerModel.batteryIcon({isPresent:true,percentage:(Number(battery[2])+0.1)/10,state:battery[1]?1:2,changeRate:1,timeToFull:60},!battery[1],{Charging:1,Discharging:2,FullyCharged:3,PendingCharge:4})
    var wifi=/^wifi-signal-([0-4])$/.exec(sample.semantic)
    if(wifi)return NetworkModel.wifiIconFor([0,21,41,61,81][Number(wifi[1])])
    var weather={"weather-clear-day":[113,false],"weather-clear-night":[113,true],"weather-partly-cloudy-day":[116,false],"weather-partly-cloudy-night":[116,true],"weather-cloudy":[119,false],"weather-fog-day":[143,false],"weather-fog-night":[143,true],"weather-showers-day":[176,false],"weather-showers-night":[176,true],"weather-snow-showers-day":[179,false],"weather-snow-showers-night":[179,true],"weather-sleet":[182,false],"weather-thunderstorm":[200,false],"weather-rain":[266,false],"weather-snow":[329,false]}
    var state=weather[sample.semantic]
    return state ? WeatherModel.iconForCode(state[0],state[1]) : sample.glyph
  }
  function inspect() {
    var records = bar.iconAdapter.records
    var ready = 0
    cells.forEach(function(cell) {
      var record = records.filter(function(r) { return r.target === cell.button })[0]
      if (!record || record.semantic !== cell.sample.semantic || !record.adapted || record.status !== Image.Ready || record.renderedStatus !== Image.Ready || record.paintedExtent <= 0)
        throw new Error("Grid asset failed: " + cell.sample.semantic + " " + JSON.stringify(record))
      if (percentages && cell.sample.widgetId === "omarchy.power" && (record.prefix !== "100% " || record.effectiveFontSize < 8 || record.paintedExtent > cell.button.width || record.paintedExtent <= 18))
        throw new Error("Power composite lost prefix or exceeded native doubled slot: " + JSON.stringify(record))
      ready++
    })
    if (ready !== Resolver.catalogueEntries().length) throw new Error("Grid lost catalogue targets")
    console.log("PRISM GRID PASS " + pack + " rendered=" + ready + " percentages=" + percentages)
    if (percentages) realPower.inspect()
  }
  Text { x:20; y:15; text:"Prism literal SVG catalogue — " + gridWindow.pack; color:"white"; font.pixelSize:22 }
  Grid {
    x: 20; y: 60
    columns: 10
    spacing: 4
    Repeater {
      model: Resolver.catalogueEntries()
      Item {
        id: cell
        required property var modelData
        property var sample: modelData
        property string moduleName: modelData.widgetId
        property alias button: glyph
        width: 102
        height: 76
        BarIconButton {
          id: glyph
          bar: gridWindow.bar
          text: gridWindow.percentages && cell.sample.widgetId === "omarchy.power" ? "100% " + gridWindow.emittedGlyph(cell.sample) : gridWindow.emittedGlyph(cell.sample)
          slotSize: Style.bar.iconSlot * (gridWindow.percentages && cell.sample.widgetId === "omarchy.power" ? 2 : 1)
          anchors.horizontalCenter: parent.horizontalCenter
          width: implicitWidth
          height: implicitHeight
          foreground: "#72e0b5"
          activeColor: "#72e0b5"
        }
        Text {
          y:40; width:parent.width
          text:cell.sample.semantic
          color:"white"; font.pixelSize:10
          wrapMode:Text.WrapAnywhere
          horizontalAlignment:Text.AlignHCenter
        }
        Component.onCompleted: {
          gridWindow.cells.push(cell)
          gridWindow.bar.iconAdapter.observe(cell,cell.sample.widgetId,cell)
        }
        Component.onDestruction: {
          gridWindow.bar.iconAdapter.release(cell)
          gridWindow.cells = gridWindow.cells.filter(function(c) { return c !== cell })
        }
      }
    }
  }
  MouseArea { anchors.fill:parent; z:-1; acceptedButtons:Qt.RightButton; onClicked:gridWindow.shown=false }
}
