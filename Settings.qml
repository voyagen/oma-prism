import "shared" as Shared
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Dialogs
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Ui as Ui
import "SettingsModel.js" as SettingsModel
import "BarModel.js" as BarModel

Ui.Panel {
  id: root
  manageIpc: false
  property Item anchorItem: null
  readonly property Item acceptanceFocusItem:body
  property int selectedTab: 0
  readonly property bool editable: opened && !!bar && bar.canSavePrismSettings && !bar.settingsWritePending
  readonly property var effective: bar ? bar.prismSettings : SettingsModel.normalizeSettings({})
  readonly property var persisted: bar ? bar.persistedPrismSettings : SettingsModel.normalizeSettings({})
  readonly property var layout: bar ? bar.layoutConfig : ({left: [], center: [], right: []})
  property string localError: ""
  readonly property alias backgroundColorDialog: colorPickerDialog
  readonly property bool verticalBar: !!bar && (bar.position === "left" || bar.position === "right")
  readonly property var sectionOptions: sections.map(function(section) { return {value: section, label: root.sectionName(section)} })
  readonly property real densityUnit: bar && bar.densityUnit !== undefined ? bar.densityUnit : 5
  readonly property real densityScale: densityUnit / 5
  readonly property real labelGap: 6 * densityScale
  readonly property real controlGap: 8 * densityScale
  readonly property real groupGap: 12 * densityScale
  readonly property real panelPadding: 16 * densityScale
  readonly property real sectionGap: 24 * densityScale
  readonly property real controlHeight: 30 * densityScale
  readonly property real controlPadding: 10 * densityScale
  readonly property real controlRadius: 6 * densityScale
  readonly property real iconSize: 16 * densityScale
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family
  readonly property real bodySize: Math.max(12, Style.font.body) + densityUnit - 4
  readonly property real titleSize: Math.max(20, bodySize * 1.5)
  function sectionName(section) {
    return section === "center" ? "Center" : section === "left" ? (verticalBar ? "Top" : "Left") : (verticalBar ? "Bottom" : "Right")
  }
  function widgetName(id) {
    if (bar) for (var widget of availableWidgets)
      if (bar.canonicalWidgetId(widget.id) === bar.canonicalWidgetId(id)) return widget.name || "Widget"
    return "Unavailable widget"
  }
  function fieldLabel(field) {
    return field.label || field.key.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/[_-]/g, " ").replace(/^./, function(letter) { return letter.toUpperCase() })
  }
  function openBackgroundColorPicker() {
    if (!editable) return false
    colorPickerDialog.selectedColor = persisted.color
    colorPickerDialog.open()
    return true
  }
  ColorDialog {
    id: colorPickerDialog
    objectName: "background-color-dialog"
    title: "Choose background color"
    parentWindow: body.Window.window
    onAccepted: {
      root.open()
      root.commit("color", selectedColor.toString().toUpperCase())
    }
  }
  property string selectedSection: ""
  property int selectedIndex: -1
  property string selectedEntrySnapshot: ""
  property string selectedLayoutSnapshot: ""
  property string entryDraft: ""
  property bool layoutSaveRequested:false
  property string entryError: ""
  property bool schemaVisible: false
  property var schemaErrors: ({})
  readonly property var selectedMetadata: {
    if (!hasSelection || !bar) return ({})
    var id = bar.canonicalWidgetId(bar.entryId(JSON.parse(selectedEntrySnapshot)))
    for (var widget of availableWidgets) if (bar.canonicalWidgetId(widget.id) === id) return widget.metadata || ({})
    return ({})
  }
  readonly property var schemaFields: SettingsModel.supportedSchemaFields(selectedMetadata.schema)
  function openSchemaConfiguration(widgetId) {
    if (!hasSelection || !bar || bar.canonicalWidgetId(bar.entryId(JSON.parse(selectedEntrySnapshot))) !== bar.canonicalWidgetId(widgetId)) return false
    if (!selectionCurrent() || schemaFields.length === 0) return false
    schemaVisible = true
    selectedTab = 2
    return true
  }
  function schemaValue(field) {
    var draft
    try { draft = JSON.parse(entryDraft) } catch (error) { return undefined }
    if (SettingsModel.isPlainObject(draft) && Object.prototype.hasOwnProperty.call(draft, field.key)) return draft[field.key]
    var defaults = selectedMetadata.defaults || ({})
    if (Object.prototype.hasOwnProperty.call(defaults, field.key)) return defaults[field.key]
    return Object.prototype.hasOwnProperty.call(field, "defaultValue") ? field.defaultValue : field.default
  }
  function editSchemaField(field, value) {
    var draft = validateEntryDraft()
    if (draft === null) return false
    var result = SettingsModel.updateEntryField(draft, field, value)
    var errors = Object.assign({}, schemaErrors)
    if (result.valid) { delete errors[field.key]; entryDraft = JSON.stringify(result.value, null, 2) }
    else errors[field.key] = result.error
    schemaErrors = errors
    return result.valid
  }
  function saveSchemaEntry() {
    var draft = validateEntryDraft()
    if (draft === null || Object.keys(schemaErrors).length > 0) return false
    var errors = {}
    for (var field of schemaFields) if (Object.prototype.hasOwnProperty.call(draft, field.key)) {
      var checked = SettingsModel.updateEntryField(draft, field, draft[field.key])
      if (!checked.valid) errors[field.key] = checked.error
    }
    schemaErrors = errors
    return Object.keys(errors).length === 0 && saveEntry()
  }
  property string destinationSection: "center"
  property string addSection: "left"
  property string addWidget: ""
  readonly property bool hasSelection: selectedIndex >= 0 && selectedSection !== ""
  readonly property var sections: ["left", "center", "right"]
  readonly property var displayOptions: {
    var result = [{value: "all", label: "All screens"}]
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) if (!result.some(function(option) { return option.value === screens[i].name })) result.push({value: screens[i].name, label: screens[i].name})
    if (!result.some(function(option) { return option.value === effective.display })) result.push({value: effective.display, label: effective.display + " (disconnected)"})
    return result
  }
  readonly property var availableWidgets: bar ? bar.availablePrismWidgets : []
  readonly property var widgetOptions: {
    var result = []
    for (var i = 0; i < availableWidgets.length; i++) {
      var widget = availableWidgets[i]
      if (bar.canonicalWidgetId(widget.id) === "akshit.island") continue
      result.push({value: widget.id, label: widget.name || "Widget"})
    }
    return result
  }
  readonly property var anchorOptions: {
    var result = [{value: "", label: "Whole center section"}]
    var center = layout.center || []
    for (var i = 0; i < center.length; i++) {
      var id = bar ? bar.entryId(center[i]) : ""
      if (!result.some(function(option) { return option.value === id })) result.push({value: id, label: root.widgetName(id)})
    }
    if (bar && bar.centerAnchor && !result.some(function(option) { return option.value === bar.centerAnchor }))
      result.push({value: bar.centerAnchor, label: root.widgetName(bar.centerAnchor) + " (not in center)"})
    return result
  }

  function commit(key, value) {
    if (!editable) { localError = "Please wait until settings can be saved."; return false }
    localError = ""
    return bar.commitPrismSetting(key, value)
  }
  function commitHost(key, value) {
    if (!editable) return false
    localError = ""
    return bar.commitHostSetting(key, value)
  }
  function commitSpacing(name) {
    if(!editable)return false
    localError=""
    return bar.commitSpacingPreset(name)
  }
  function selectEntry(section, index) {
    var entries = layout[section]
    if (!entries || index < 0 || index >= entries.length) return false
    selectedIndex = -1
    selectedEntrySnapshot = JSON.stringify(entries[index])
    selectedLayoutSnapshot = JSON.stringify(layout)
    entryDraft = JSON.stringify(bar.entrySettings(entries[index]), null, 2)
    entryError = ""
    schemaVisible = false
    schemaErrors = ({})
    localError = ""
    selectedSection = section
    selectedIndex = index
    return true
  }
  function clearSelection() {
    selectedSection = ""
    selectedIndex = -1
    selectedEntrySnapshot = ""
    selectedLayoutSnapshot = ""
    entryDraft = ""
    entryError = ""
    schemaVisible = false
    schemaErrors = ({})
  }
  function selectionCurrent() {
    if (!hasSelection || JSON.stringify(layout) !== selectedLayoutSnapshot ||
        !layout[selectedSection] || JSON.stringify(layout[selectedSection][selectedIndex]) !== selectedEntrySnapshot) {
      localError = "Your widgets changed. Select the widget again before saving or moving it."
      return false
    }
    return true
  }
  function applyLayout(result) {
    if (result.error) { localError = result.error; return false }
    if (!editable) return false
    localError = ""
    var accepted = bar.commitLayout(result.layout)
    if (accepted) {
      if(bar.settingsWritePending)layoutSaveRequested=true
      else clearSelection()
    }
    return accepted
  }
  function moveSelected(section, index) {
    if (!editable || !selectionCurrent()) return false
    return applyLayout(BarModel.moveLayoutEntry(layout, selectedSection, selectedIndex, section, index))
  }
  function removeSelected() {
    if (!editable || !selectionCurrent()) return false
    return applyLayout(BarModel.removeLayoutEntry(layout, selectedSection, selectedIndex))
  }
  function validateEntryDraft() {
    try {
      var parsed = JSON.parse(entryDraft)
      if (!SettingsModel.isPlainObject(parsed) || Object.prototype.hasOwnProperty.call(parsed, "id")) { entryError = "These widget settings cannot be saved. Select the widget again."; return null }
      entryError = ""
      return parsed
    } catch (error) { entryError = "These widget settings cannot be read. Select the widget again."; return null }
  }
  function saveEntry() {
    var parsed = validateEntryDraft()
    if (parsed === null || !editable || !selectionCurrent()) return false
    return applyLayout(BarModel.replaceEntrySettings(layout, selectedSection, selectedIndex, parsed))
  }
  function addEntry() {
    if (!editable) return false
    var widget = null
    for (var i = 0; i < availableWidgets.length; i++) if (availableWidgets[i].id === addWidget) widget = availableWidgets[i]
    if (!widget || bar.canonicalWidgetId(widget.id) === "akshit.island") { localError = "Choose an available widget to add."; return false }
    if (widget.metadata && widget.metadata.allowMultiple === false) {
      var canonical = bar.canonicalWidgetId(widget.id)
      for (var s = 0; s < sections.length; s++) {
        var entries = layout[sections[s]] || []
        for (var j = 0; j < entries.length; j++) if (bar.canonicalWidgetId(bar.entryId(entries[j])) === canonical) {
          localError = root.widgetName(widget.id) + " can only be added once and is already on the bar."
          return false
        }
      }
    }
    return applyLayout(BarModel.addLayoutEntry(layout, addSection, widget.id, widget.metadata))
  }

  onOpenedChanged: {
    if (opened) localError = ""
    else {
      colorPickerDialog.close()
      if (bar) bar.cancelPrismPreview()
    }
  }
  Component.onDestruction: if (bar) bar.cancelPrismPreview()
  Connections {
    target: root.bar
    function onPositionChanged() { root.close() }
    function onBarHiddenChanged() { if (root.bar.barHidden) root.close() }
    function onSettingsWritePendingChanged() {
      if(root.layoutSaveRequested && !root.bar.settingsWritePending) {
        root.layoutSaveRequested=false
        if(root.bar.settingsError==="")root.clearSelection()
      }
    }
  }

  component Caption: Text {
    color: Color.popups.text
    font.family: root.fontFamily
    font.pixelSize: root.bodySize
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }
  component Group: Column {
    width: parent.width
    spacing: root.controlGap
  }
  component Actions: Flow {
    width: parent.width
    spacing: root.controlGap
  }
  component Action: Controls.AbstractButton {
    id: action
    property string svg: ""
    property bool selected: false
    property bool primary: false
    property bool destructive: false
    readonly property color actionAccent: destructive ? Color.urgent : Color.accent
    readonly property color foreground: Color.popups.text
    readonly property real iconInset: svg !== "" ? root.iconSize + root.labelGap : 0
    width: Math.min(implicitWidth, parent.width)
    implicitWidth: Math.ceil(Math.max(labelMetrics.advanceWidth, labelMetrics.boundingRect.width)) + root.controlPadding * 2 + iconInset + 1
    implicitHeight: Math.max(root.controlHeight, actionLabel.implicitHeight + root.labelGap * 2)
    leftPadding: root.controlPadding + iconInset
    rightPadding: root.controlPadding
    topPadding: root.labelGap
    bottomPadding: root.labelGap
    activeFocusOnTab: true
    hoverEnabled: true
    opacity: enabled ? 1 : 0.55
    Accessible.name: text
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Accessible.selected: selected
    TextMetrics {
      id: labelMetrics
      text: action.text
      font.family: root.fontFamily
      font.pixelSize: root.bodySize
      font.bold: action.selected || action.primary
    }
    background: Ui.BorderSurface {
      radius: root.controlRadius
      color: action.down ? Style.pressedFillFor(action.foreground, action.actionAccent)
        : action.activeFocus ? Style.focusFillFor(action.foreground, action.actionAccent)
        : action.hovered ? Style.hoverFillFor(action.foreground, action.actionAccent)
        : action.selected || action.primary ? Style.selectedFillFor(action.foreground, action.actionAccent)
        : "transparent"
      borderSpec: Border.controlSpec(action.activeFocus ? "focus" : action.hovered ? "hover-cursor" : action.selected || action.primary ? "selected" : "normal", action.foreground, action.actionAccent)
      Rectangle {
        visible: action.selected
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: root.labelGap / 2
        width: Math.min(root.iconSize, parent.width / 3)
        height: 1
        color: action.foreground
      }
    }
    contentItem: Caption {
      id: actionLabel
      text: action.text
      font.bold: action.selected || action.primary
      color: action.destructive ? Color.urgent : action.foreground
      verticalAlignment: Text.AlignVCenter
      horizontalAlignment: Text.AlignLeft
    }
    Shared.SvgIcon {
      visible: action.svg !== ""
      x: root.controlPadding
      anchors.verticalCenter: parent.verticalCenter
      width: root.iconSize
      height: width
      opticalSize: width
      source: action.svg !== "" ? Qt.resolvedUrl("assets/menu/" + action.svg + ".svg") : ""
      ink: action.foreground
    }
  }
  component Segments: Group {
    id: segments
    property string label: ""
    property string value: ""
    property var options: []
    signal changed(string value)
    spacing: root.labelGap
    Caption { width: parent.width; text: segments.label; visible: text !== "" }
    Actions {
      Repeater {
        model: segments.options
        Action {
          required property var modelData
          objectName: modelData.name || ""
          width: Math.min(parent.width, Math.max(implicitWidth, (parent.width - parent.spacing * (segments.options.length - 1)) / segments.options.length))
          text: modelData.label
          svg: modelData.icon || ""
          selected: segments.value === modelData.value
          enabled: root.editable
          onClicked: segments.changed(modelData.value)
        }
      }
    }
  }
  component Dropdown: Group {
    id: dropdown
    property string label: ""
    property bool showLabel: true
    property alias value: nativeChoice.value
    property alias options: nativeChoice.options
    signal changed(string value)
    spacing: root.labelGap
    opacity: enabled ? 1 : 0.55
    Caption { width: parent.width; visible: dropdown.showLabel && text !== ""; text: dropdown.label }
    Ui.Dropdown {
      id: nativeChoice
      width: parent.width
      label: dropdown.label
      showLabel: false
      rowHeight: Math.round(root.controlHeight)
      popupRowHeight: Math.round(root.controlHeight)
      fontFamily: root.fontFamily
      onChanged: function(value) { dropdown.changed(value) }
    }
  }
  component Choice: Dropdown {
    id: choice
    function bindValue() { value = Qt.binding(function() { return root.effective[choice.settingKey] || "" }) }
    property string settingKey: ""
    options: SettingsModel.enums[settingKey] || []
    value: root.effective[settingKey] || ""
    enabled: root.editable
    onChanged: function(value) { root.commit(settingKey, value); bindValue() }
  }
  component HostChoice: Dropdown {
    id: hostChoice
    property string hostKey: ""
    value: root.bar ? root.bar[hostKey] : ""
    enabled: root.editable
    function bindValue() { value = Qt.binding(function() { return root.bar ? root.bar[hostChoice.hostKey] : "" }) }
    onChanged: function(value) { root.commitHost(hostKey, value); bindValue() }
  }
  component Toggle: Controls.AbstractButton {
    id: toggle
    property string label: ""
    width: parent.width
    implicitHeight: Math.max(root.controlHeight, toggleLabel.implicitHeight + root.labelGap * 2)
    leftPadding: root.controlPadding
    rightPadding: root.controlPadding + toggleTrack.width + root.controlGap
    topPadding: root.labelGap
    bottomPadding: root.labelGap
    activeFocusOnTab: true
    hoverEnabled: true
    opacity: enabled ? 1 : 0.55
    Keys.onReturnPressed: clicked()
    Keys.onEnterPressed: clicked()
    Accessible.name: label
    Accessible.role: Accessible.CheckBox
    Accessible.checked: checked
    contentItem: Caption { id: toggleLabel; text: toggle.label; verticalAlignment: Text.AlignVCenter }
    background: Ui.BorderSurface {
      radius: root.controlRadius
      color: Style.controlFill(toggle.activeFocus, toggle.hovered, Color.popups.text, Color.accent)
      borderSpec: Border.controlSpec(toggle.activeFocus ? "focus" : toggle.hovered ? "hover-cursor" : "normal", Color.popups.text, Color.accent)
    }
    Ui.ToggleSwitch {
      id: toggleTrack
      anchors.right: parent.right
      anchors.rightMargin: root.controlPadding
      anchors.verticalCenter: parent.verticalCenter
      checked: toggle.checked
      interactive: false
      trackHeight: Math.round(root.controlHeight * 0.6)
      foreground: Color.popups.text
    }
  }
  component Flag: Toggle {
    property string settingKey: ""
    checked: !!root.effective[settingKey]
    enabled: root.editable
    onClicked: root.commit(settingKey, !checked)
  }
  component Numeric: Column {
    id: numeric
    property string settingKey: ""
    property string title: ""
    readonly property var range: SettingsModel.bounds[settingKey]
    width: parent.width
    spacing: root.labelGap
    Caption { width: parent.width; text: numeric.title + " · " + (numeric.settingKey === "opacity" || numeric.settingKey === "transparentOpacity" ? Math.round(slider.value * 100) + "%" : numeric.range.integer ? slider.value : slider.value.toFixed(2)) }
    Controls.Slider {
      id: slider
      objectName: "slider-" + numeric.settingKey
      width: parent.width
      implicitHeight: root.controlHeight
      enabled: root.editable
      activeFocusOnTab: true
      Accessible.name: numeric.title
      wheelEnabled: false
      from: numeric.range.min
      to: numeric.range.max
      stepSize: numeric.range.integer ? 1 : 0.01
      snapMode: Controls.Slider.SnapAlways
      value: root.effective[numeric.settingKey]
      onMoved: {
        if (pressed) root.bar.previewPrismSetting(numeric.settingKey, value)
        else root.commit(numeric.settingKey, value)
      }
      onPressedChanged: if (!pressed && root.editable) root.commit(numeric.settingKey, value)
      background: Rectangle {
        x: slider.leftPadding
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: slider.availableWidth
        height: root.densityUnit * 0.8
        radius: height / 2
        color: Color.popups.text
        opacity: 0.35
        Rectangle { width: slider.visualPosition * parent.width; height: parent.height; radius: parent.radius; color: Color.accent }
      }
      handle: Rectangle {
        x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
        y: slider.topPadding + slider.availableHeight / 2 - height / 2
        width: root.iconSize
        height: width
        radius: width / 2
        color: Color.popups.text
        border.width: Math.max(1, root.densityScale * 2)
        border.color: slider.activeFocus ? Color.accent : Color.popups.background
      }
    }
  }
  component Reset: Column {
    id: reset
    property string group: ""
    property bool confirming: false
    readonly property string fields: group === "icons" ? "icon style, icon size, icon colors, custom icons, font and text size" : "bar style, screen choice, spacing, window overlap, roundness, outline, background color and opacity, and animations"
    width: parent.width
    spacing: root.controlGap
    Action { objectName: "reset-" + reset.group; text: reset.group === "icons" ? "Reset icons and text" : "Reset appearance"; destructive: true; enabled: root.editable; onClicked: reset.confirming = true }
    Caption { width: parent.width; visible: reset.confirming; text: "Restore the default " + reset.fields + "? Bar position, transparency and widgets will stay unchanged." }
    Flow {
      visible: reset.confirming
      width: Math.min(parent.width, cancelReset.implicitWidth + confirmReset.implicitWidth + spacing)
      anchors.right: parent.right
      spacing: root.controlGap
      Action { id: cancelReset; objectName: "reset-cancel"; text: "Cancel"; onClicked: reset.confirming = false }
      Action { id: confirmReset; objectName: "reset-confirm"; text: "Confirm reset"; destructive: true; primary: true; enabled: root.editable; onClicked: { if (root.bar.resetPrismGroup(reset.group)) reset.confirming = false } }
    }
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: body
    padding: Math.round(root.panelPadding)
    contentWidth: fittedContentWidth(Style.space(660))
    contentHeight: fittedContentHeight(Style.space(620))

    FocusScope {
      id: body
      anchors.fill: parent
      enabled:root.opened
      focus: true
      Keys.onEscapePressed: function(event) { root.close(); event.accepted = true }
      Column {
        anchors.fill: parent
        spacing: root.groupGap
        Row {
          width: parent.width
          Caption { width: Math.max(0, parent.width - closeButton.width - root.controlGap); text: "Oma Prism"; font.pixelSize: root.titleSize; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
          Action { id: closeButton; text: "Close"; svg:"x"; onClicked: root.close() }
        }
        Flow {
          readonly property var tabIcons:["palette","shapes","layout-panel-top"]
          width: parent.width
          spacing: root.controlGap
          Repeater {
            model: ["Appearance", "Icons & Text", "Widgets"]
            Action {
              required property int index
              required property string modelData
              objectName: ["tab-appearance", "tab-icons", "tab-widgets"][index]
              width: Math.min(parent.width, Math.max(implicitWidth, (parent.width - parent.spacing * 2) / 3))
              text: modelData
              svg:parent.tabIcons[index]
              selected: root.selectedTab === index
              onClicked: root.selectedTab = index
            }
          }
        }
        Caption {
          width: parent.width
          visible: text !== ""
          text: root.localError || (root.bar ? root.bar.settingsError : "")
        }
        Caption {
          width: parent.width
          visible: text !== ""
          text: root.bar && root.bar.settingsWritePending ? "Saving your changes…" :
            root.bar && !root.bar.canSavePrismSettings ? "Settings are currently unavailable." : ""
        }
        Item {
          width: parent.width
          height: Math.max(0, body.height - y)
          Repeater {
            model: 3
            Controls.ScrollView {
              id: tabScroll
              objectName: "settings-scroll-" + index
              required property int index
              property bool loaded:false
              Component.onCompleted:if(visible)loaded=true
              onVisibleChanged:if(visible)loaded=true
              anchors.fill: parent
              visible: root.selectedTab === index
              clip: true
              Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
              Controls.ScrollBar.vertical.policy: Controls.ScrollBar.AsNeeded
              contentWidth: availableWidth
              Loader {
                width: tabScroll.availableWidth
                active:tabScroll.loaded
                sourceComponent: tabScroll.index === 0 ? appearanceTab : tabScroll.index === 1 ? iconsTab : layoutTab
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: appearanceTab
    Group {
      spacing: root.sectionGap
      Group {
      Segments {
        label:"Style"; value:root.bar ? root.bar.prismSettings.mode : "docked"
        options:[{value:"docked",label:"Docked",icon:"panel-top",name:"mode-docked"},{value:"floating-bar",label:"Floating",icon:"panel-top",name:"mode-floating-bar"},{value:"islands",label:"Islands",icon:"layers",name:"mode-islands"}]
        onChanged:function(value){root.commit("mode",value)}
      }
      Segments {
        label:"Position"; value:root.bar ? root.bar.position : "top"
        options:[{value:"top",label:"Top",icon:"arrow-up"},{value:"bottom",label:"Bottom",icon:"arrow-down"},{value:"left",label:"Left",icon:"arrow-left"},{value:"right",label:"Right",icon:"arrow-right"}]
        onChanged:function(value){root.commitHost("position",value)}
      }
      Segments {
        label:"Spacing"; value:SettingsModel.spacingPreset(root.effective)
        options:[{value:"compact",label:"Compact",name:"spacing-compact"},{value:"default",label:"Default",name:"spacing-default"},{value:"comfortable",label:"Comfortable",name:"spacing-comfortable"}]
        onChanged:function(value){root.commitSpacing(value)}
      }
      Caption { width:parent.width; visible:SettingsModel.spacingPreset(root.effective)===""; text:"Existing custom spacing is preserved. Pick a preset to replace it." }
      Choice { label: "Screen"; settingKey: "display"; options: root.displayOptions }
      Flag { label: "Prevent windows from covering the bar"; settingKey: "reserveSpace" }
      }
      Group {
      Numeric { title:"Roundness"; settingKey:"radius" }
      Toggle {
        label:"Outline"
        checked:root.effective.outlineWidth===1; enabled:root.editable
        onClicked:root.commit("outlineWidth",checked ? 0 : 1)
      }
      Caption { width: parent.width; text: "Docked sits against the screen edge. Floating is one continuous bar with margins. Islands separates the sections." }
      }
      Group {
      Choice { label: "Background"; settingKey: "background"; options: [{value:"theme",label:"Follow theme"},{value:"custom",label:"Custom color"}] }
      Actions {
        visible: root.effective.background === "custom"
        Action { objectName: "background-color-picker"; text: "Choose background color"; enabled: root.editable; onClicked: root.openBackgroundColorPicker() }
        Row {
          spacing: root.labelGap
          height: root.controlHeight
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: width
            radius: root.controlRadius / 2
            color: root.persisted.color
            border.width: 1
            border.color: Color.popups.text
          }
          Caption { anchors.verticalCenter: parent.verticalCenter; text: root.persisted.color; Accessible.name: "Background color " + text }
        }
      }
      Numeric { title: "Background visibility"; settingKey: "opacity"; visible: !(root.bar && root.bar.transparent) }
      Numeric { title: "Background visibility"; settingKey: "transparentOpacity"; visible: !!root.bar && root.bar.transparent }
      Caption { width: parent.width; text: "Lower values make the background more see-through." }
      Toggle { label: "Transparent background"; checked: root.bar ? root.bar.transparent : false; enabled: root.editable; onClicked: root.commitHost("transparent", !checked) }
      }
      Group {
      Segments {
        label: "Animations"
        value: !root.effective.motionEnabled ? "off" : root.effective.reducedMotion ? "reduced" : root.effective.animationIntensity
        options: [{value:"off",label:"Off",name:"animations-off"},{value:"reduced",label:"Reduced",name:"animations-reduced"},{value:"default",label:"Default",name:"animations-default"},{value:"expressive",label:"Expressive",name:"animations-expressive"}]
        onChanged: function(value) {
          if (root.editable) root.bar.commitPrismPatch({
            motionEnabled: value !== "off",
            reducedMotion: value === "reduced",
            animationIntensity: value === "expressive" ? "expressive" : "default"
          })
        }
      }
      Caption { width: parent.width; text: "Expressive adds stronger hover, press and icon motion. Reduced keeps feedback gentle; Off makes it immediate." }
      }
      Reset { group: "appearance" }
    }
  }
  Component {
    id: iconsTab
    Group {
      spacing: root.sectionGap
      Group {
      Choice { label: "Icon style"; settingKey: "iconPack"; options: [{value:"lucide",label:"Lucide"},{value:"material-symbols",label:"Material Symbols"}] }
      Numeric { title: "Icon size"; settingKey: "iconSize" }
      Choice { label: "Icon colors"; settingKey: "tintPolicy"; options: [{value:"foreground",label:"Match bar text"},{value:"source",label:"Keep original colors"}] }
      }
      Numeric { title: "Text size"; settingKey: "fontSize" }
      Reset { group: "icons" }
    }
  }
  Component {
    id: layoutTab
    Group {
      spacing: root.sectionGap
      Caption { width: parent.width; text: "Add your enabled widgets below, or select a widget to move, remove or configure it. Unavailable widgets are kept until you remove them." }
      HostChoice { label:"Keep centered"; hostKey:"centerAnchor"; options:root.anchorOptions }
      Repeater {
        model: root.sections
        Column {
          id: sectionColumn
          required property string modelData
          width: parent.width
          spacing: root.controlGap
          Caption { width: parent.width; text: root.sectionName(sectionColumn.modelData); font.bold: true }
          Caption { width: parent.width; visible: (root.layout[sectionColumn.modelData] || []).length === 0; text: "Empty section" }
          Repeater {
            model: root.layout[sectionColumn.modelData] || []
            Action {
              required property int index
              required property var modelData
              width: parent.width
              selected: root.selectedSection === sectionColumn.modelData && root.selectedIndex === index
              text: (index + 1) + ". " + root.widgetName(root.bar ? root.bar.entryId(modelData) : "")
              onClicked: root.selectEntry(sectionColumn.modelData, index)
            }
          }
        }
      }
      Group {
        Dropdown { label: "Widget to add"; options: root.widgetOptions; value: root.addWidget; enabled: root.editable; onChanged: function(value) { root.addWidget = value } }
        Dropdown { label: "Add to"; options: root.sectionOptions; value: root.addSection; enabled: root.editable; onChanged: function(value) { root.addSection = value } }
        Action { text: "Add widget"; svg:"plus"; primary: true; enabled: root.editable && root.addWidget !== ""; onClicked: root.addEntry() }
      }
      Group {
        spacing: root.groupGap
        visible: root.hasSelection
        Caption { width: parent.width; text: "Selected: " + root.sectionName(root.selectedSection) + " · " + (root.selectedIndex + 1) + " · " + (root.selectedEntrySnapshot ? root.widgetName(root.bar.entryId(JSON.parse(root.selectedEntrySnapshot))) : "") }
        Actions {
          Action { text: "Earlier"; svg:"arrow-up"; enabled: root.editable && root.selectedIndex > 0; onClicked: root.moveSelected(root.selectedSection, root.selectedIndex - 1) }
          Action { text: "Later"; svg:"arrow-down"; enabled: root.editable && root.hasSelection && root.selectedIndex < (root.layout[root.selectedSection] || []).length - 1; onClicked: root.moveSelected(root.selectedSection, root.selectedIndex + 1) }
          Action { text: "Remove"; svg:"trash-2"; destructive: true; enabled: root.editable; onClicked: root.removeSelected() }
          Action { text: "Select again"; svg:"rotate-ccw"; onClicked: root.selectEntry(root.selectedSection, root.selectedIndex) }
        }
        Dropdown { label: "Move to"; options: root.sectionOptions; value: root.destinationSection; enabled: root.editable; onChanged: function(value) { root.destinationSection = value } }
        Actions {
          Action { text: "Move to beginning"; enabled: root.editable; onClicked: root.moveSelected(root.destinationSection, 0) }
          Action { text: "Move to end"; enabled: root.editable; onClicked: root.moveSelected(root.destinationSection, (root.layout[root.destinationSection] || []).length - (root.destinationSection === root.selectedSection ? 1 : 0)) }
        }
        Action {
          text: "Configure widget"
          visible: root.hasSelection && !!root.bar && typeof root.bar.canConfigurePrismWidget === "function" && root.bar.canConfigurePrismWidget(root.bar.entryId(JSON.parse(root.selectedEntrySnapshot)))
          enabled: root.editable
          onClicked: root.bar.openWidgetConfiguration(root.bar.entryId(JSON.parse(root.selectedEntrySnapshot)))
        }
        Action { text: "Widget settings"; visible: root.schemaFields.length > 0; enabled: root.editable; onClicked: root.openSchemaConfiguration(root.bar.entryId(JSON.parse(root.selectedEntrySnapshot))) }
        Group {
          spacing: root.groupGap
          visible: root.schemaVisible && root.schemaFields.length > 0
          Caption { width: parent.width; text: "Changes apply only to this widget. Other saved options are kept."; font.bold: true }
          Repeater {
            model: root.schemaFields
            Column {
              id: schemaRow
              required property var modelData
              readonly property var field: modelData
              readonly property bool booleanField: field.type === "boolean" || field.type === "bool"
              width: parent.width
              spacing: root.labelGap
              Caption { width: parent.width; visible: !schemaRow.booleanField; text: root.fieldLabel(schemaRow.field) }
              Caption { width: parent.width; visible: text !== ""; text: schemaRow.field.description || "" }
              Toggle {
                visible: schemaRow.booleanField; enabled: root.editable
                label: root.fieldLabel(schemaRow.field)
                checked: !!root.schemaValue(schemaRow.field)
                onClicked: root.editSchemaField(schemaRow.field, !checked)
              }
              Dropdown {
                width: parent.width; label: root.fieldLabel(schemaRow.field); showLabel: false; visible: schemaRow.field.type === "enum"; enabled: root.editable
                options: schemaRow.field.options || []; value: root.schemaValue(schemaRow.field) === undefined ? "" : root.schemaValue(schemaRow.field)
                onChanged: function(value) { root.editSchemaField(schemaRow.field, value) }
              }
              Controls.TextField {
                id: schemaInput
                width: parent.width; visible: !schemaRow.booleanField && schemaRow.field.type !== "enum"; enabled: root.editable
                activeFocusOnTab: true; Accessible.name: root.fieldLabel(schemaRow.field)
                text: root.schemaValue(schemaRow.field) === undefined ? "" : String(root.schemaValue(schemaRow.field))
                implicitHeight: root.controlHeight
                leftPadding: root.controlPadding; rightPadding: root.controlPadding
                topPadding: root.labelGap; bottomPadding: root.labelGap
                font.family: root.fontFamily; font.pixelSize: root.bodySize; color: Color.popups.text
                selectionColor: Color.accent
                selectedTextColor: Color.popups.background
                opacity: enabled ? 1 : 0.55
                background: Ui.BorderSurface { color: Color.popups.background; radius: root.controlRadius; borderSpec: Border.controlSpec(schemaInput.activeFocus ? "focus" : "normal", Color.popups.text, Color.accent) }
                onTextEdited: root.editSchemaField(schemaRow.field, text)
              }
              Caption { width: parent.width; visible: text !== ""; text: root.schemaErrors[schemaRow.field.key] || "" }
            }
          }
          Action { text: "Save widget settings"; primary: true; enabled: root.editable && root.entryError === "" && Object.keys(root.schemaErrors).length === 0; onClicked: root.saveSchemaEntry() }
        }
      }
    }
  }
}
