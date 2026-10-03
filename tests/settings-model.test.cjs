const test = require("node:test")
const assert = require("node:assert/strict")
const { normalizeSetting, normalizeSettings, diagnostics, defaults, bounds } = require("../SettingsModel.js")

function accepted(key, input, expected) {
  const result = normalizeSetting(key, input)
  assert.equal(result.valid, true, result.error)
  assert.equal(result.error, "")
  assert.deepEqual(result.value, expected)
}

function rejected(key, input) {
  const result = normalizeSetting(key, input)
  assert.equal(result.valid, false, `${key} accepted ${String(input)}`)
  assert.equal(typeof result.error, "string")
  assert.ok(result.error.includes(key), result.error)
  return result
}

test("geometry and duration bound finite numeric updates without coercion", () => {
  const ranges = {
    edgeGap: [0, 64], outerMargin: [0, 64], sectionPadding: [0, 32],
    widgetSpacing: [0, 32], thickness: [24, 96], radius: [0, 48],
    outlineWidth: [0, 1], iconSize: [12, 32], fontSize: [8, 24],
    transitionDuration: [0, 1000]
  }
  for (const [key, [min, max]] of Object.entries(ranges)) {
    assert.equal(bounds[key].min, min)
    assert.equal(bounds[key].max, max)
    accepted(key, min - 100, min)
    accepted(key, max + 100, max)
    accepted(key, min + 0.49, min)
    accepted(key, min + 0.5, min + 1)
    accepted(key, Number.MAX_VALUE, max)
    for (const input of [NaN, Infinity, -Infinity, "18", null, undefined, true, false, [], {}, new Number(18)])
      rejected(key, input)
  }
  accepted("edgeGap", -0, 0)
  // Persistence retains the requested radius; effective geometry caps it later.
  assert.equal(normalizeSettings({ thickness: 24, radius: 48 }).radius, 48)
})

test("opacity bounds preserve fractions and reject nonnumbers", () => {
  for (const key of ["opacity", "transparentOpacity", "outlineOpacity"]) {
    accepted(key, -0.01, 0)
    accepted(key, 0.375, 0.375)
    accepted(key, 1.01, 1)
    for (const input of ["0.5", NaN, Infinity, null, true, []]) rejected(key, input)
  }
})

test("layout defaults and legacy islands survive normalization and restart", () => {
  assert.equal(normalizeSettings().mode, "docked")
  assert.equal(normalizeSettings({mode:"invalid"}).mode, "docked")
  const legacy = {mode:"floating",edgeGap:17,outerMargin:23,radius:19}
  const migrated = normalizeSettings(legacy)
  assert.equal(migrated.mode, "islands")
  assert.equal(migrated.edgeGap, 17)
  assert.equal(migrated.outerMargin, 23)
  assert.equal(migrated.radius, 19)
  assert.deepEqual(diagnostics(legacy), [])
  for (const mode of ["docked","floating-bar","islands"])
    assert.equal(normalizeSettings(JSON.parse(JSON.stringify({...migrated,mode}))).mode, mode)
})

test("enumerations are exact, and booleans never accept truthy substitutes", () => {
  const options = {
    mode: ["docked", "floating-bar", "islands"], background: ["theme", "custom"],
    iconPack: ["lucide", "material-symbols"], tintPolicy: ["foreground", "source"]
  }
  for (const [key, values] of Object.entries(options)) {
    for (const value of values) accepted(key, value, value)
    for (const value of [values[0].toUpperCase(), ` ${values[0]}`, "", "unknown", 0, null, {}, new String(values[0])])
      rejected(key, value)
  }
  for (const key of ["reserveSpace", "reducedMotion", "motionEnabled"]) {
    accepted(key, false, false)
    accepted(key, true, true)
    for (const value of [0, 1, "false", "true", null, undefined, {}, []]) rejected(key, value)
  }
})

test("motion overrides validate atomically and preserve scoped opt-outs", () => {
  const raw = { "omarchy.audio": { interactionEnabled: false, iconEnabled: false, reducedMotion: true, effect: "none", replace: false } }
  accepted("motionOverrides", raw, raw)
  assert.equal(normalizeSettings({motionEnabled:false, motionOverrides:raw}).motionOverrides["omarchy.audio"].iconEnabled, false)
  for (const value of [[], null, {audio:false}, {audio:{effect:"boing"}}, {audio:{replace:1}}, {audio:{unknown:true}}])
    rejected("motionOverrides", value)
  const invalid = {audio:{effect:"breathe"}, microphone:{effect:"invalid"}}
  assert.deepEqual(normalizeSettings({motionOverrides:invalid}).motionOverrides, {})
  const prototypeKey = JSON.parse('{"__proto__":{"effect":"pulse"}}')
  const normalized = normalizeSetting("motionOverrides", prototypeKey).value
  assert.equal(Object.getPrototypeOf(normalized), Object.prototype)
  assert.deepEqual(normalized.__proto__, {effect:"pulse"})
  normalized.__proto__.effect = "none"
  assert.equal(prototypeKey.__proto__.effect, "pulse")
})

test("screen names, theme-following font names, and six-digit colors are strict", () => {
  accepted("display", "all", "all")
  accepted("display", " DP-1 ", "DP-1")
  accepted("display", "__proto__", "__proto__")
  for (const value of ["", "  ", "DP-1\n", "DP-\u0000", false, 1, null]) rejected("display", value)
  accepted("fontFamily", "", "")
  accepted("fontFamily", "  JetBrains Mono  ", "JetBrains Mono")
  accepted("fontFamily", "  ", "")
  for (const value of ["font\nname", "font\u007f", false, 1, null, []]) rejected("fontFamily", value)
  accepted("color", "#Ab09EF", "#ab09ef")
  for (const value of ["#abc", "#11223344", "112233", "red", " #112233", "#gg1122", null, 112233])
    rejected("color", value)
})

test("override syntax accepts local SVG filenames but rejects remote and non-SVG drafts", () => {
  for (const path of ["/tmp/icon.svg", "~/icons/a.SVG", "/tmp/an icon.svg", "/tmp/ icon.svg"])
    accepted("semanticOverrides", { "volume-muted": path }, { "volume-muted": path })
  for (const path of ["relative.svg", "file:///tmp/icon.svg", "https://example.com/a.svg", "//server/a.svg", "~icon.svg", "/tmp/a.png", "/tmp/a.svg?x=1", "/tmp/a\u0000.svg", "/tmp/a\n.svg", 42, null]) {
    const result = rejected("semanticOverrides", { "volume-muted": path })
    assert.ok(result.error.includes("volume-muted"), result.error)
    const nested = rejected("widgetOverrides", { "omarchy.audio": { "": path } })
    assert.ok(nested.error.includes("omarchy.audio"), nested.error)
    assert.ok(nested.error.includes(""), nested.error)
  }
})

test("empty path drafts remove overrides and empty nested contexts", () => {
  accepted("semanticOverrides", { removed: "", whitespace: "   ", kept: "~/kept.svg" }, { kept: "~/kept.svg" })
  accepted("widgetOverrides", {
    removed: { "󰋋": "", "": "   " },
    empty: {},
    kept: { "": "", "": "/tmp/volume.svg" }
  }, { kept: { "": "/tmp/volume.svg" } })
})

test("malformed nested dictionaries reject atomically and diagnose persisted failures", () => {
  for (const value of [[], null, "x", new Date(), new Map(), Object.create({ inherited: "/tmp/a.svg" })]) {
    rejected("semanticOverrides", value)
    rejected("widgetOverrides", value)
  }
  const raw = {
    semanticOverrides: { valid: "/tmp/a.svg", broken: false },
    widgetOverrides: { audio: { "": "/tmp/a.svg", broken: 1 }, malformed: [] },
    iconSize: "22",
    mode: "docked",
    vendorSetting: { retainedElsewhere: true }
  }
  const snapshot = JSON.stringify(raw)
  rejected("semanticOverrides", raw.semanticOverrides)
  const result = rejected("widgetOverrides", raw.widgetOverrides)
  assert.ok(result.error.includes("broken"))
  assert.ok(result.error.includes("malformed"))
  const normalized = normalizeSettings(raw)
  assert.deepEqual(normalized.semanticOverrides, {})
  assert.deepEqual(normalized.widgetOverrides, {})
  assert.equal(normalized.iconSize, defaults.iconSize)
  assert.equal(normalized.mode, "docked")
  assert.equal(Object.hasOwn(normalized, "vendorSetting"), false)
  const issues = diagnostics(raw)
  assert.deepEqual(issues.map(issue => issue.key).sort(), ["iconSize", "semanticOverrides", "vendorSetting", "widgetOverrides"])
  assert.ok(issues.find(issue => issue.key === "widgetOverrides").error.includes("malformed"))
  assert.equal(JSON.stringify(raw), snapshot)
})

test("invalid persisted explicit paths block pack fallback while editor updates reject them", () => {
  const raw = { widgetOverrides: { "omarchy.audio": { "": "https://example.com/bad.svg" } } }
  const normalized = normalizeSettings(raw)
  assert.equal(normalized.widgetOverrides["omarchy.audio"][""], raw.widgetOverrides["omarchy.audio"][""])
  const resolved = require("../IconResolver.js").resolve("omarchy.audio", "", normalized)
  assert.equal(resolved.origin, "original")
  assert.equal(resolved.source, "")
  assert.match(resolved.reason, /local path/)
  assert.equal(normalizeSetting("widgetOverrides", raw.widgetOverrides).valid, false)
  assert.equal(diagnostics(raw)[0].key, "widgetOverrides")
})

test("normalization produces isolated dictionary clones and preserves own prototype-like keys", () => {
  const raw = JSON.parse('{"semanticOverrides":{"__proto__":"/tmp/proto.svg","constructor":"/tmp/constructor.svg"},"widgetOverrides":{"__proto__":{"󰋋":"~/headphones.svg"},"omarchy.audio":{"__proto__":"/tmp/glyph.svg","":"/tmp/high.svg"}}}')
  const normalized = normalizeSettings(raw)
  assert.equal(Object.getPrototypeOf(normalized.semanticOverrides), Object.prototype)
  assert.equal(Object.hasOwn(normalized.semanticOverrides, "__proto__"), true)
  assert.equal(normalized.semanticOverrides.__proto__, "/tmp/proto.svg")
  assert.equal(normalized.semanticOverrides.constructor, "/tmp/constructor.svg")
  assert.equal(Object.hasOwn(normalized.widgetOverrides, "__proto__"), true)
  assert.equal(normalized.widgetOverrides.__proto__["󰋋"], "~/headphones.svg")
  assert.equal(Object.getPrototypeOf(normalized.widgetOverrides["omarchy.audio"]), Object.prototype)
  assert.equal(normalized.widgetOverrides["omarchy.audio"].__proto__, "/tmp/glyph.svg")
  normalized.widgetOverrides["omarchy.audio"][""] = "/tmp/changed.svg"
  normalized.semanticOverrides.constructor = "/tmp/changed.svg"
  assert.equal(raw.widgetOverrides["omarchy.audio"][""], "/tmp/high.svg")
  assert.equal(raw.semanticOverrides.constructor, "/tmp/constructor.svg")
  const first = normalizeSettings()
  const second = normalizeSettings()
  first.semanticOverrides.new = "/tmp/new.svg"
  first.widgetOverrides.audio = { glyph: "/tmp/new.svg" }
  assert.deepEqual(second.semanticOverrides, {})
  assert.deepEqual(second.widgetOverrides, {})
  assert.deepEqual(defaults.semanticOverrides, {})
  assert.deepEqual(defaults.widgetOverrides, {})
  const nullDictionary = Object.create(null)
  nullDictionary["󰋋"] = "/tmp/headphones.svg"
  accepted("widgetOverrides", { audio: nullDictionary }, { audio: { "󰋋": "/tmp/headphones.svg" } })
})

test("only own known fields are read and invalid roots never masquerade as settings", () => {
  for (const key of ["unknown", "__proto__", "constructor", "toString", null, 1])
    assert.equal(normalizeSetting(key, "docked").valid, false)
  for (const raw of [null, [], "docked", new Date(), Object.create({ mode: "docked" })]) {
    assert.deepEqual(normalizeSettings(raw), normalizeSettings())
    assert.equal(diagnostics(raw)[0].key, "prism")
  }
  const inheritedFields = Object.create(null)
  inheritedFields.mode = "docked"
  inheritedFields.fontSize = 21.7
  assert.equal(normalizeSettings(inheritedFields).mode, "docked")
  assert.equal(normalizeSettings(inheritedFields).fontSize, 22)
  assert.equal(diagnostics(inheritedFields)[0].effective, 22)
  assert.deepEqual(diagnostics(undefined), [])
  const absent = normalizeSettings({ mode: undefined })
  assert.equal(absent.mode, defaults.mode)
  assert.equal(diagnostics({ mode: undefined })[0].key, "mode")
})

test("spacing recognition preserves custom geometry and ignores unrelated appearance", () => {
  const {spacingPresets,spacingPreset} = require("../SettingsModel.js")
  for (const name of ["compact","default","comfortable"]) {
    const raw = {...spacingPresets[name],mode:"docked",fontSize:23,color:"#123456",unknown:"keep"}
    assert.equal(spacingPreset(raw),name)
    assert.equal(spacingPreset({...raw,sectionPadding:raw.sectionPadding+1}),"")
    assert.equal(spacingPreset({...raw,widgetSpacing:raw.widgetSpacing+1}),"")
    assert.equal(spacingPreset({...raw,thickness:raw.thickness+1}),"")
  }
})


test("diagnostics identify unknown keys and effective repairs without changing saved input", () => {
  const raw = { iconPakc: "material-symbols", opacity: 2, thickness: 25.6, mode: "invalid" }
  const snapshot = JSON.stringify(raw)
  const issues = diagnostics(raw)
  assert.equal(issues.find(issue => issue.key === "iconPakc").effective, undefined)
  assert.equal(issues.find(issue => issue.key === "opacity").requested, 2)
  assert.equal(issues.find(issue => issue.key === "opacity").effective, 1)
  assert.equal(issues.find(issue => issue.key === "thickness").effective, 26)
  assert.equal(issues.find(issue => issue.key === "mode").effective, defaults.mode)
  assert.equal(JSON.stringify(raw), snapshot)
  assert.deepEqual(diagnostics({ opacity: 0.5, thickness: 28 }), [])
})

test("schema edits preserve opaque inline fields and enforce consumer-visible field constraints", () => {
  const { updateEntryField, supportedSchemaFields } = require("../SettingsModel.js")
  const settings = { opaque: { mode: "vendor" }, count: 2 }
  const count = { key: "count", type: "integer", min: 1, max: 5 }
  const updated = updateEntryField(settings, count, "4")
  assert.equal(updated.valid, true)
  assert.deepEqual(updated.value, { opaque: { mode: "vendor" }, count: 4 })
  assert.equal(settings.count, 2)
  for (const value of ["", "NaN", "4.2", "6", "0"]) assert.equal(updateEntryField(settings, count, value).valid, false)
  assert.equal(updateEntryField(settings, {key: "enabled", type: "boolean"}, "false").valid, false)
  assert.equal(updateEntryField(settings, {key: "enabled", type: "bool"}, false).value.enabled, false)
  const choice = {key: "mode", type: "enum", options: ["quiet", "active"]}
  assert.equal(updateEntryField(settings, choice, "other").valid, false)
  assert.equal(updateEntryField(settings, choice, "quiet").value.mode, "quiet")
  const fields = supportedSchemaFields([count, {key: "opaque", type: "object"}, {key: "id", type: "string"}])
  assert.deepEqual(fields, [count])
  assert.equal(updateEntryField(settings, {key: "id", type: "string"}, "changed").valid, false)
})
