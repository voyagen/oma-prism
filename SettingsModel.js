// Pure Prism appearance settings. Importable by QML and Node without dependencies.
var defaults = {
  mode: "docked",
  display: "all",
  reserveSpace: true,
  edgeGap: 5,
  outerMargin: 10,
  sectionPadding: 10,
  widgetSpacing: 6,
  thickness: 40,
  radius: 12,
  outlineWidth: 0,
  outlineOpacity: 0.12,
  background: "custom",
  color: "#000000",
  opacity: 0.84,
  transparentOpacity: 0.6,
  iconPack: "lucide",
  iconSize: 18,
  tintPolicy: "foreground",
  semanticOverrides: {},
  widgetOverrides: {},
  fontFamily: "",
  fontSize: 12,
  transitionDuration: 160,
  reducedMotion: false,
  motionEnabled: true,
  animationIntensity: "default",
  motionOverrides: {}
}

// One density unit controls the entire spacing rhythm; Default uses 5px.
function densityPreset(unit) {
  return {edgeGap:unit, outerMargin:2*unit, sectionPadding:2*unit, widgetSpacing:2*unit-4, thickness:8*unit}
}
var spacingPresets = {
  compact: densityPreset(4),
  default: densityPreset(5),
  comfortable: densityPreset(6)
}

function spacingPreset(raw) {
  var settings = normalizeSettings(raw)
  for (var name of Object.keys(spacingPresets)) {
    var preset = spacingPresets[name]
    if (Object.keys(preset).every(function(key) { return settings[key] === preset[key] })) return name
  }
  return ""
}

// Radius's effective half-thickness cap belongs to layout, not persistence:
// stored floating geometry must survive changing mode or thickness.
var bounds = {
  edgeGap: { min: 0, max: 64, integer: true },
  outerMargin: { min: 0, max: 64, integer: true },
  sectionPadding: { min: 0, max: 32, integer: true },
  widgetSpacing: { min: 0, max: 32, integer: true },
  thickness: { min: 24, max: 96, integer: true },
  radius: { min: 0, max: 48, integer: true },
  outlineWidth: { min: 0, max: 1, integer: true },
  iconSize: { min: 12, max: 32, integer: true },
  fontSize: { min: 8, max: 24, integer: true },
  transitionDuration: { min: 0, max: 1000, integer: true },
  opacity: { min: 0, max: 1, integer: false },
  transparentOpacity: { min: 0, max: 1, integer: false },
  outlineOpacity: { min: 0, max: 1, integer: false }
}

var enums = {
  mode: ["docked", "floating-bar", "islands"],
  background: ["theme", "custom"],
  iconPack: ["lucide", "material-symbols"],
  tintPolicy: ["foreground", "source"],
  animationIntensity: ["default", "expressive"]
}

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key)
}

function isPlainObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false
  var prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

// In particular, never invoke Object.prototype.__proto__'s setter for user keys.
function setOwn(object, key, value) {
  Object.defineProperty(object, key, {
    value: value, enumerable: true, writable: true, configurable: true
  })
}

function valid(value) {
  return { valid: true, value: value, error: "" }
}

function invalid(error) {
  return { valid: false, value: undefined, error: error }
}

function normalizeOverridePath(value, location) {
  if (typeof value !== "string") return invalid(location + " must be an SVG path string")
  if (value.trim() === "") return valid("")
  // Keep the exact filename: whitespace inside an absolute path can be real.
  if (/[\u0000-\u001f\u007f]/.test(value))
    return invalid(location + " contains a control character")
  if (value.indexOf("//") === 0 || !(value.charAt(0) === "/" || value.indexOf("~/") === 0))
    return invalid(location + " must be a local absolute path or ~/ path, not a URL or relative path: " + value)
  if (!/\.svg$/i.test(value)) return invalid(location + " must have an .svg extension: " + value)
  return valid(value)
}

function normalizeOverrides(value, nested, persisted) {
  var name = nested ? "widgetOverrides" : "semanticOverrides"
  if (!isPlainObject(value)) return invalid(name + " must be a plain object")
  var output = {}
  var errors = []
  var keys = Object.keys(value)
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    var location = name + "[" + JSON.stringify(key) + "]"
    if (!nested) {
      var path = persisted && typeof value[key] === "string" ? valid(value[key].trim() === "" ? "" : value[key]) : normalizeOverridePath(value[key], location)
      if (!path.valid) errors.push(path.error)
      else if (path.value !== "") setOwn(output, key, path.value)
      continue
    }
    if (!isPlainObject(value[key])) {
      errors.push(location + " must be a plain object of glyph-to-SVG paths")
      continue
    }
    var glyphs = Object.keys(value[key])
    var overrides = {}
    for (var j = 0; j < glyphs.length; j++) {
      var glyph = glyphs[j]
      var glyphPath = persisted && typeof value[key][glyph] === "string" ? valid(value[key][glyph].trim() === "" ? "" : value[key][glyph]) : normalizeOverridePath(value[key][glyph], location + "[" + JSON.stringify(glyph) + "]")
      if (!glyphPath.valid) errors.push(glyphPath.error)
      else if (glyphPath.value !== "") setOwn(overrides, glyph, glyphPath.value)
    }
    if (Object.keys(overrides).length > 0) setOwn(output, key, overrides)
  }
  // Updates are atomic: do not save a partially accepted editor draft.
  return errors.length > 0 ? invalid(errors.join("; ")) : valid(output)
}

// Widget-scoped motion policy; omitted fields inherit the shared defaults.
function normalizeMotionOverrides(value) {
  if (!isPlainObject(value)) return invalid("motionOverrides must be a plain object")
  var output = {}
  var effects = ["none", "bounce", "wiggle", "pulse", "breathe", "rotate", "appear", "disappear", "replace"]
  for (var context of Object.keys(value)) {
    var input = value[context]
    if (!isPlainObject(input)) return invalid("motionOverrides[" + context + "] must be a plain object")
    var entry = {}
    for (var field of Object.keys(input)) {
      if (field === "effect") {
        if (effects.indexOf(input[field]) < 0) return invalid("Unknown motionOverrides effect: " + input[field])
      } else if (["interactionEnabled", "iconEnabled", "reducedMotion", "replace"].indexOf(field) < 0 || typeof input[field] !== "boolean") {
        return invalid("Invalid motionOverrides field: " + context + "." + field)
      }
      setOwn(entry, field, input[field])
    }
    setOwn(output, context, entry)
  }
  return valid(output)
}

function normalizeSetting(key, value) {
  if (typeof key !== "string" || !hasOwn(defaults, key)) return invalid("Unknown Prism setting: " + String(key))
  if (hasOwn(bounds, key)) {
    if (typeof value !== "number" || !isFinite(value)) return invalid(key + " must be a finite number")
    var range = bounds[key]
    var number = range.integer ? Math.round(value) : value
    return valid(Math.max(range.min, Math.min(range.max, number)))
  }
  if (hasOwn(enums, key)) {
    if (typeof value !== "string" || enums[key].indexOf(value) === -1)
      return invalid(key + " must be one of: " + enums[key].join(", "))
    return valid(value)
  }
  if (key === "reserveSpace" || key === "reducedMotion" || key === "motionEnabled")
    return typeof value === "boolean" ? valid(value) : invalid(key + " must be a boolean")
  if (key === "display") {
    if (typeof value !== "string" || value.trim() === "" || /[\u0000-\u001f\u007f]/.test(value))
      return invalid("display must be all or a nonempty screen name")
    return valid(value.trim())
  }
  if (key === "fontFamily") {
    if (typeof value !== "string" || /[\u0000-\u001f\u007f]/.test(value))
      return invalid("fontFamily must be a font name string, or empty to follow the theme")
    return valid(value.trim())
  }
  if (key === "color") {
    if (typeof value !== "string" || !/^#[0-9a-f]{6}$/i.test(value))
      return invalid("color must use #RRGGBB format")
    return valid(value.toLowerCase())
  }
  if (key === "motionOverrides") return normalizeMotionOverrides(value)
  return normalizeOverrides(value, key === "widgetOverrides")
}

function normalizeSettings(raw) {
  var input = isPlainObject(raw) ? raw : {}
  var normalized = {}
  var keys = Object.keys(defaults)
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    // Persisted invalid string paths must reach the resolver, which retains
    // the original icon instead of silently selecting a lower-priority pack.
    var result = !hasOwn(input, key) ? invalid("")
      : key === "semanticOverrides" || key === "widgetOverrides"
        ? normalizeOverrides(input[key], key === "widgetOverrides", true)
        : normalizeSetting(key, key === "mode" && input[key] === "floating" ? "islands" : input[key])
    // Also normalize defaults so every dictionary returned is a fresh object.
    normalized[key] = result.valid ? result.value : normalizeSetting(key, defaults[key]).value
  }
  return normalized
}

function diagnostics(raw) {
  if (raw === undefined) return []
  if (!isPlainObject(raw)) return [{ key: "prism", error: "bar.prism must be a plain object", effective: normalizeSettings({}) }]
  var issues = []
  var effective = normalizeSettings(raw)
  var keys = Object.keys(raw)
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    if (!hasOwn(defaults, key)) {
      issues.push({ key: key, error: "Unknown Prism setting: " + key + "; ignored", requested: raw[key], effective: undefined })
      continue
    }
    if (key === "mode" && raw[key] === "floating") continue // Legacy islands configuration.
    var result = normalizeSetting(key, raw[key])
    if (!result.valid) issues.push({ key: key, error: result.error, requested: raw[key], effective: effective[key] })
    else if (hasOwn(bounds, key) && result.value !== raw[key])
      issues.push({ key: key, error: key + " repaired from " + String(raw[key]) + " to " + String(result.value), requested: raw[key], effective: result.value })
  }
  return issues
}

// Clone the complete raw dictionary, then validate atomically: unrelated bad
// entries must never disappear just because a friendly row was edited.
function updateOverrideRow(raw, widgetId, key, path) {
  var nested = widgetId !== ""
  var name = nested ? "widgetOverrides" : "semanticOverrides"
  if (typeof key !== "string" || key === "") return invalid("Choose an override state")
  if (raw === undefined) raw = {}
  if (!isPlainObject(raw)) return invalid(name + " must be a plain object; repair it in Advanced JSON first")
  var output = {}
  for (var existing of Object.keys(raw)) setOwn(output, existing, raw[existing])
  var checked = normalizeOverridePath(path, name + "[" + JSON.stringify(key) + "]")
  if (!checked.valid) return checked
  var target = output
  if (nested) {
    if (hasOwn(output, widgetId) && !isPlainObject(output[widgetId]))
      return invalid(name + "[" + JSON.stringify(widgetId) + "] must be a plain object; repair it in Advanced JSON first")
    target = {}
    var previous = hasOwn(output, widgetId) ? output[widgetId] : {}
    for (var glyph of Object.keys(previous)) setOwn(target, glyph, previous[glyph])
    setOwn(output, widgetId, target)
  }
  if (checked.value === "") delete target[key]
  else setOwn(target, key, checked.value)
  if (nested && Object.keys(target).length === 0) delete output[widgetId]
  return normalizeSetting(name, output)
}

function codepoints(text) {
  return Array.from(String(text || "")).map(function(character) {
    return "U+" + character.codePointAt(0).toString(16).toUpperCase().padStart(4, "0")
  }).join(" ")
}

function supportedSchemaFields(schema) {
  return Array.isArray(schema) ? schema.filter(function(field) {
    return isPlainObject(field) && typeof field.key === "string" && field.key !== "" && field.key !== "id" &&
      (["string", "number", "integer", "int", "boolean", "bool"].indexOf(field.type) >= 0 ||
       (field.type === "enum" && Array.isArray(field.options) && field.options.length > 0))
  }) : []
}

function updateEntryField(settings, field, value) {
  if (!isPlainObject(settings)) return invalid("Inline settings must be a plain object")
  if (supportedSchemaFields([field]).length !== 1) return invalid("Unsupported schema field")
  var type = field.type
  if (type === "number" || type === "integer" || type === "int") {
    if (typeof value === "string") value = value.trim() === "" ? NaN : Number(value)
    if (typeof value !== "number" || !isFinite(value)) return invalid(field.key + " must be a finite number")
    if (type !== "number" && Math.floor(value) !== value) return invalid(field.key + " must be an integer")
    if (typeof field.min === "number" && value < field.min) return invalid(field.key + " must be at least " + field.min)
    if (typeof field.max === "number" && value > field.max) return invalid(field.key + " must be at most " + field.max)
  } else if (type === "boolean" || type === "bool") {
    if (typeof value !== "boolean") return invalid(field.key + " must be a boolean")
  } else if (type === "string") {
    if (typeof value !== "string") return invalid(field.key + " must be a string")
  } else {
    var options = field.options.map(function(option) { return isPlainObject(option) ? option.value : option })
    if (options.indexOf(value) < 0) return invalid(field.key + " must be an available option")
  }
  var result = {}
  for (var key of Object.keys(settings)) setOwn(result, key, settings[key])
  setOwn(result, field.key, value)
  return valid(result)
}

// Exported schema objects cannot be accidentally changed by a consumer.
Object.freeze(defaults.semanticOverrides)
Object.freeze(defaults.widgetOverrides)
Object.freeze(defaults.motionOverrides)
Object.freeze(defaults)
var boundKeys = Object.keys(bounds)
for (var boundIndex = 0; boundIndex < boundKeys.length; boundIndex++) Object.freeze(bounds[boundKeys[boundIndex]])
Object.freeze(bounds)
for (var name of Object.keys(spacingPresets)) Object.freeze(spacingPresets[name])
Object.freeze(spacingPresets)

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    normalizeSettings: normalizeSettings,
    normalizeSetting: normalizeSetting,
    diagnostics: diagnostics,
    updateOverrideRow: updateOverrideRow,
    codepoints: codepoints,
    supportedSchemaFields: supportedSchemaFields,
    updateEntryField: updateEntryField,
    defaults: defaults,
    bounds: bounds,
    spacingPresets: spacingPresets,
    spacingPreset: spacingPreset,
  }
}
