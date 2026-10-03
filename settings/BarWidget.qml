import QtQuick
import qs.Commons
import qs.Ui as Ui
import "shared" as Shared

Ui.BarWidget {
  id: root
  moduleName: "voyagen.prism.settings"
  readonly property Item settingsButton: control
  readonly property bool canOpen: !!bar && typeof bar.openPrismSettings === "function"
  implicitWidth: control.implicitWidth
  implicitHeight: control.implicitHeight

  Ui.BarIconButton {
    id: control
    anchors.fill: parent
    bar: root.bar
    enabled: root.canOpen
    active: root.canOpen && root.bar.prismSettingsOpened === true
    tooltipText: root.canOpen ? "Oma Prism settings" : "Activate Oma Prism to use its settings"
    onPressed: function(button) {
      if (button === Qt.LeftButton || button === Qt.RightButton)
        root.bar.openPrismSettings(control)
    }
    iconComponent: Component {
      Item {
        Shared.SvgIcon {
          anchors.centerIn: parent
          width: root.canOpen && typeof root.bar.prismIconSize === "number" ? root.bar.prismIconSize : Style.barIconVisual
          height: width
          opticalSize: width
          source: Qt.resolvedUrl("shared/prism.svg")
          ink: control.active ? control.activeColor : control.foreground
        }
      }
    }
  }
}
