// Copyright (c) 2026 Oma Prism contributors. See LICENSE.
// Pure QML JavaScript: filesystem readability/renderability belongs to the adapter's Image probe.
var packs = ["lucide", "material-symbols"]
var catalogue = [
  { widgetId: "omarchy.audio", glyph: "\uEEE8", semantic: "volume-muted", lucide: "volume-x", materialSymbols: "volume_off" },
  { widgetId: "omarchy.audio", glyph: "󰋋", semantic: "headphones", lucide: "headphones", materialSymbols: "headphones" },
  { widgetId: "omarchy.audio", glyph: "\uF026", semantic: "volume-low", lucide: "volume", materialSymbols: "volume_mute" },
  { widgetId: "omarchy.audio", glyph: "\uF027", semantic: "volume-medium", lucide: "volume-1", materialSymbols: "volume_down" },
  { widgetId: "omarchy.audio", glyph: "\uF028", semantic: "volume-high", lucide: "volume-2", materialSymbols: "volume_up" }
]

// Exact contexts only: shared Nerd glyphs have different meanings in different widgets.
function addRows(context, rows) {
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    catalogue.push({widgetId:context, glyph:row[0], semantic:row[1], lucide:row[2], materialSymbols:row[3]})
  }
}
addRows("omarchy.network", [
  ["󰤯","wifi-signal-0","wifi-zero","signal_wifi_0_bar"],
  ["󰤟","wifi-signal-1","wifi-low","network_wifi_1_bar"],
  ["󰤢","wifi-signal-2","wifi-low","network_wifi_2_bar"],
  ["󰤥","wifi-signal-3","wifi-high","network_wifi_3_bar"],
  ["󰤨","wifi-signal-4","wifi","signal_wifi_4_bar"],
  ["󰈀","ethernet","ethernet-port","settings_ethernet"],
  ["󰤮","network-disconnected","wifi-off","wifi_off"]
])
addRows("omarchy.bluetooth", [
  ["󰂲","bluetooth-off","bluetooth-off","bluetooth_disabled"],
  ["󰂱","bluetooth-connected","bluetooth-connected","bluetooth_connected"],
  ["󰂯","bluetooth-enabled","bluetooth","bluetooth"]
])
var batteryGlyphs = ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"]
var chargingGlyphs = ["󰢜","󰂆","󰂇","󰂈","󰢝","󰂉","󰢞","󰂊","󰂋","󰂅"]
for (var level = 0; level < 10; level++) {
  addRows("omarchy.power", [
    [batteryGlyphs[level],"battery-level-"+level,"battery","battery_0_bar"],
    [chargingGlyphs[level],"battery-charging-level-"+level,"battery-charging","battery_charging_full"]
  ])
}
addRows("omarchy.monitor", [["󰍹","display","monitor","monitor"],["󰍺","displays-multiple","panels-top-left","desktop_windows"]])
addRows("omarchy.microphone", [["󰍭","microphone-muted","mic-off","mic_off"],["󰍬","microphone-enabled","mic","mic"]])
addRows("omarchy.weather", [
  ["","weather-clear-day","sun","clear_day"],
  ["","weather-clear-night","moon","clear_night"],
  ["","weather-partly-cloudy-day","cloud-sun","partly_cloudy_day"],
  ["","weather-partly-cloudy-night","cloud-moon","partly_cloudy_night"],
  ["","weather-cloudy","cloud","cloud"],
  ["\uE313","weather-fog-day","cloud-fog","foggy"],
  ["\uE346","weather-fog-night","cloud-fog","foggy"],
  ["","weather-showers-day","cloud-sun-rain","rainy"],
  ["","weather-showers-night","cloud-moon-rain","rainy"],
  ["","weather-snow-showers-day","cloud-snow","weather_snowy"],
  ["","weather-snow-showers-night","cloud-snow","weather_snowy"],
  ["","weather-sleet","cloud-hail","weather_mix"],
  ["","weather-thunderstorm","cloud-lightning","thunderstorm"],
  ["","weather-rain","cloud-rain","rainy"],
  ["","weather-snow","snowflake","weather_snowy"]
])
addRows("Dnd", [["󰂛","notifications-silenced","bell-off","notifications_off"]])
addRows("NightLight", [["󰔎","night-light","eclipse","nightlight"]])
addRows("StayAwake", [["󰅶","stay-awake","coffee","coffee"]])
addRows("Reminder", [["󰢌","reminder","alarm-clock","alarm"]])
addRows("ScreenRecording", [["󰻂","screen-recording","video","screen_record"]])
addRows("Dictation", [["󰍬","dictation","mic","keyboard_voice"],["󰔟","dictation-transcribing","hourglass","hourglass_top"]])
addRows("omarchy.system-update", [["\uF021","system-update","refresh-cw","system_update_alt"]])
addRows("omarchy.agents", [["\uDB85\uDEA3","agents","bot","smart_toy"]])
addRows("omarchy.tray", [["\uF053","tray-drawer-chevron","chevron-left","chevron_left"]])
addRows("jrmmhm.pocket", [["\uDB80\uDDD8","drawer-chevron","chevron-right","chevron_right"]])
addRows("omaplug", [["\uDB85\uDCD3","plugin-manager-open","package-open","deployed_code"],["\uDB85\uDCD9","plugin-manager-closed","package","deployed_code"]])
addRows("njpatel.omaherdr", [
  ["\uDB81\uDEA9","robot","bot","smart_toy"], ["\uDB85\uDF19","robot-happy","bot","smart_toy"],
  ["\uDB80\uDD8D","console","terminal","terminal"], ["\uDB81\uDC89","terminal","terminal","terminal"],
  ["\uDB82\uDDD1","brain","brain","psychology"], ["\uDB80\uDC0E","users","users","groups"],
  ["\uDB81\uDD6E","dashboard","gauge","dashboard"], ["\uDB80\uDE3B","flag","flag","flag"],
  ["\uDB80\uDC9A","bell","bell","notifications"], ["\uDB81\uDC8B","server","server","dns"],
  ["\uDB80\uDF17","lan","network","lan"], ["\uDB81\uDE1A","cpu","cpu","memory"],
  ["\uDB81\uDC30","activity","activity","ecg"]
])

function owns(object, key) {
  return object !== null && object !== undefined && Object.prototype.hasOwnProperty.call(object, key)
}

function dictionary(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

function catalogueEntries() {
  var result = []
  for (var i = 0; i < catalogue.length; i++) {
    var row = catalogue[i]
    result.push({ widgetId: row.widgetId, glyph: row.glyph, semantic: row.semantic,
                  lucide: row.lucide, materialSymbols: row.materialSymbols })
  }
  return result
}

function bundledSource(pack, semantic) {
  return "assets/icons/" + pack + "/" + semantic + ".svg"
}

// Enumerate the complete current catalogue for offline installer validation.
function expectedSources() {
  var result = []
  for (var p = 0; p < packs.length; p++) {
    for (var i = 0; i < catalogue.length; i++)
      result.push(bundledSource(packs[p], catalogue[i].semantic))
  }
  return result
}

function validateOverridePath(value) {
  if (typeof value !== "string")
    return { valid: false, value: "", error: "SVG override must be a string local path." }
  if (value.trim() === "") return { valid: true, value: "", error: "" }
  if (/[\u0000-\u001F\u007F]/.test(value))
    return { valid: false, value: value, error: "SVG override path contains a control character: " + JSON.stringify(value) }
  if (value.indexOf("//") === 0 || !(value.charAt(0) === "/" || value.indexOf("~/") === 0))
    return { valid: false, value: value, error: "Use an absolute local path or ~/ path, not a URL or relative path: " + JSON.stringify(value) }
  if (!/\.svg$/i.test(value))
    return { valid: false, value: value, error: "SVG override must end in .svg: " + JSON.stringify(value) }
  return { valid: true, value: value, error: "" }
}

function original(semantic, reason) {
  return { semantic: semantic, prefix: "", source: "", origin: "original", reason: reason }
}

function overrideResult(value, semantic, origin) {
  var checked = validateOverridePath(value)
  if (!checked.valid) return original(semantic, checked.error)
  // A cleared draft removes this precedence tier rather than hiding the icon.
  if (checked.value === "") return null
  return { semantic: semantic, prefix: "", source: checked.value, origin: origin, reason: "" }
}

function resolve(widgetId, text, settings) {
  // Percentage composition is an upstream power-only public contract. Keep
  // every other multichar text intact, including arbitrary custom glyphs.
  var composite = widgetId === "omarchy.power" && typeof text === "string" ? /^(\d{1,3}%\s+)(.+)$/.exec(text) : null
  if (composite) {
    var result = resolveGlyph(widgetId, composite[2], settings)
    if (result.semantic) {
      if (result.source) result.prefix = composite[1]
      return result
    }
  }
  return resolveGlyph(widgetId, text, settings)
}

function resolveGlyph(widgetId, text, settings) {
  if (text === "") return original("", "")
  if (typeof text !== "string") return original("", "Icon text must be a complete Unicode string.")
  if (typeof widgetId !== "string") return original("", "Icon context must be a widget ID string.")
  var row = null
  for (var i = 0; i < catalogue.length; i++) {
    if (catalogue[i].widgetId === widgetId && catalogue[i].glyph === text) {
      row = catalogue[i]
      break
    }
  }
  var semantic = row ? row.semantic : ""
  var config = dictionary(settings) ? settings : {}
  var overrides = owns(config, "widgetOverrides") ? config.widgetOverrides : {}
  if (!dictionary(overrides)) return original(semantic, "widgetOverrides must be a dictionary of widget/glyph SVG paths.")
  if (owns(overrides, widgetId)) {
    var widgetOverrides = overrides[widgetId]
    if (!dictionary(widgetOverrides))
      return original(semantic, "widgetOverrides[" + JSON.stringify(widgetId) + "] must be a glyph/path dictionary.")
    if (owns(widgetOverrides, text)) {
      var widgetResult = overrideResult(widgetOverrides[text], semantic, "widget-override")
      if (widgetResult !== null) return widgetResult
    }
  }
  if (!row) return original("", "No SVG mapping for context " + JSON.stringify(widgetId) + " and complete glyph " + JSON.stringify(text) + "; add a widget/glyph override.")
  var semanticOverrides = owns(config, "semanticOverrides") ? config.semanticOverrides : {}
  if (!dictionary(semanticOverrides)) return original(semantic, "semanticOverrides must be a semantic/path dictionary.")
  if (owns(semanticOverrides, semantic)) {
    var semanticResult = overrideResult(semanticOverrides[semantic], semantic, "semantic-override")
    if (semanticResult !== null) return semanticResult
  }
  var pack = owns(config, "iconPack") ? config.iconPack : "lucide"
  if (pack !== "lucide" && pack !== "material-symbols")
    return original(semantic, "Unknown icon pack " + JSON.stringify(pack) + "; select lucide or material-symbols.")
  return { semantic: semantic, prefix: "", source: bundledSource(pack, semantic), origin: "pack", reason: "" }
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    resolve: resolve,
    validateOverridePath: validateOverridePath,
    catalogueEntries: catalogueEntries,
    expectedSources: expectedSources,
    packs: packs
  }
}
