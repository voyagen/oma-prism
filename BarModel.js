// Derived from lobo.islands and Omarchy's MIT-licensed bar engine.
// Copyright (c) 2026 Daniel Lobo; Copyright (c) David Heinemeier Hansson.
// Prism changes: Copyright (c) 2026 Oma Prism contributors. See LICENSE.
function isPlainObject(value) {
  return !!value && typeof value === "object" && !Array.isArray(value)
}

function normalizePosition(value) {
  var next = String(value || "").trim()
  return /^(top|bottom|left|right)$/.test(next) ? next : "top"
}

function entrySettings(entry) {
  if (!isPlainObject(entry)) return {}
  var copy = {}
  for (var key in entry) {
    if (key === "id" || !Object.prototype.hasOwnProperty.call(entry, key)) continue
    Object.defineProperty(copy, key, { value: entry[key], enumerable: true, writable: true, configurable: true })
  }
  return copy
}

function entryId(entry) {
  if (typeof entry === "string") return entry
  if (isPlainObject(entry)) {
    var id = entry["id"]
    if (id !== undefined && id !== null && String(id) !== "") return String(id)
  }
  return ""
}

function editorPlainObject(value) {
  if (!isPlainObject(value)) return false
  var prototype = Object.getPrototypeOf(value)
  return prototype === Object.prototype || prototype === null
}

// Define own keys rather than assigning them: JSON can contain "__proto__".
function cloneLayoutData(value) {
  if (!value || typeof value !== "object") return value
  var copy = Array.isArray(value) ? [] : {}
  var keys = Object.keys(value)
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i]
    Object.defineProperty(copy, key, {
      value: cloneLayoutData(value[key]), enumerable: true, writable: true, configurable: true
    })
  }
  if (Array.isArray(value)) copy.length = value.length
  return copy
}

function validLayoutSection(section) {
  return section === "left" || section === "center" || section === "right"
}

function layoutEditorError(layout) {
  if (!editorPlainObject(layout)) return "Layout must be a plain object."
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var section = sections[s]
    if (!Object.prototype.hasOwnProperty.call(layout, section) || !Array.isArray(layout[section]))
      return "Layout section must be an array: " + section
    for (var i = 0; i < layout[section].length; i++) {
      var entry = layout[section][i]
      if (typeof entry === "string" && entry.trim() !== "") continue
      if (editorPlainObject(entry) && Object.prototype.hasOwnProperty.call(entry, "id")
          && typeof entry.id === "string" && entry.id.trim() !== "") continue
      return "Invalid layout entry in " + section + " at " + i
    }
  }
  return ""
}

function validLayoutIndex(index, length, insertion) {
  return typeof index === "number" && isFinite(index) && Math.floor(index) === index
    && index >= 0 && index < length + (insertion ? 1 : 0)
}

function moveLayoutEntry(layout, fromSection, fromIndex, toSection, toIndex) {
  var error = layoutEditorError(layout)
  if (!error && (!validLayoutSection(fromSection) || !validLayoutSection(toSection)))
    error = "Unknown layout section."
  if (!error && !validLayoutIndex(fromIndex, layout[fromSection].length, false))
    error = "Source index is outside the layout section."
  var destinationLength = !error ? layout[toSection].length - (fromSection === toSection ? 1 : 0) : 0
  if (!error && !validLayoutIndex(toIndex, destinationLength, true))
    error = "Destination index is outside the section after removal."
  if (error) return { layout: layout, error: error }
  var copy = cloneLayoutData(layout)
  var entry = copy[fromSection].splice(fromIndex, 1)[0]
  copy[toSection].splice(toIndex, 0, entry)
  return { layout: copy, error: "" }
}

function addLayoutEntry(layout, section, id, metadata) {
  var error = layoutEditorError(layout)
  if (!error && !validLayoutSection(section)) error = "Unknown layout section."
  if (!error && (typeof id !== "string" || id.trim() === "")) error = "Widget ID must be a nonempty string."
  if (!error && metadata !== undefined && !editorPlainObject(metadata)) error = "Widget metadata must be a plain object."
  if (!error && metadata && Object.prototype.hasOwnProperty.call(metadata, "allowMultiple") && metadata.allowMultiple === false) {
    var sections = ["left", "center", "right"]
    for (var s = 0; s < sections.length; s++) {
      for (var i = 0; i < layout[sections[s]].length; i++) {
        if (entryId(layout[sections[s]][i]) === id) error = "This widget permits only one instance."
      }
    }
  }
  if (error) return { layout: layout, error: error }
  var copy = cloneLayoutData(layout)
  copy[section].push({ id: id })
  return { layout: copy, error: "" }
}

function removeLayoutEntry(layout, section, index) {
  var error = layoutEditorError(layout)
  if (!error && !validLayoutSection(section)) error = "Unknown layout section."
  if (!error && !validLayoutIndex(index, layout[section].length, false))
    error = "Entry index is outside the layout section."
  if (error) return { layout: layout, error: error }
  var copy = cloneLayoutData(layout)
  copy[section].splice(index, 1)
  return { layout: copy, error: "" }
}

function replaceEntrySettings(layout, section, index, settings) {
  var error = layoutEditorError(layout)
  if (!error && !validLayoutSection(section)) error = "Unknown layout section."
  if (!error && !validLayoutIndex(index, layout[section].length, false))
    error = "Entry index is outside the layout section."
  if (!error && (!editorPlainObject(settings) || Object.prototype.hasOwnProperty.call(settings, "id")))
    error = "Inline settings must be a plain object without an id."
  if (error) return { layout: layout, error: error }
  var copy = cloneLayoutData(layout)
  var replacement = cloneLayoutData(settings)
  Object.defineProperty(replacement, "id", {
    value: entryId(layout[section][index]), enumerable: true, writable: true, configurable: true
  })
  copy[section][index] = replacement
  return { layout: copy, error: "" }
}


function moduleString(entry, key, fallback) {
  var settings = entrySettings(entry)
  var value = settings[key]
  return value === undefined || value === null ? fallback : String(value)
}

function entryIndex(entries, name) {
  if (!Array.isArray(entries)) return -1
  for (var i = 0; i < entries.length; i++) {
    if (entryId(entries[i]) === name) return i
  }
  return -1
}


// A shell.json write that only changes inline widget settings (the battery
// percentage toggle, a clock format change) must not rebuild the bar.
// Compare two normalized layouts: when the structure is unchanged (same
// entry ids in the same order per region), return the settings-only changes
// as {region, index, entry}. Return null when the change is structural, or
// touches an entry a live settings push cannot safely reach: custom modules
// read their entry directly rather than an injected settings property, and
// a duplicated id makes the push ambiguous.
function inlineSettingsDelta(current, next) {
  if (!isPlainObject(current) || !isPlainObject(next)) return null
  var regions = ["left", "center", "right"]
  var counts = {}
  for (var r = 0; r < regions.length; r++) {
    var entries = Array.isArray(next[regions[r]]) ? next[regions[r]] : []
    for (var i = 0; i < entries.length; i++) {
      var id = entryId(entries[i])
      counts[id] = (counts[id] || 0) + 1
    }
  }
  var changes = []
  for (var s = 0; s < regions.length; s++) {
    var region = regions[s]
    var a = Array.isArray(current[region]) ? current[region] : []
    var b = Array.isArray(next[region]) ? next[region] : []
    if (a.length !== b.length) return null
    for (var j = 0; j < a.length; j++) {
      if (entryId(a[j]) !== entryId(b[j])) return null
      if (JSON.stringify(a[j]) === JSON.stringify(b[j])) continue
      if (customModuleType(a[j]) || customModuleType(b[j])) return null
      if (counts[entryId(b[j])] > 1) return null
      changes.push({ region: region, index: j, entry: b[j] })
    }
  }
  return changes
}

function expandPath(value, home) {
  var path = String(value || "")
  if (path === "") return ""
  if (path.indexOf("~/") === 0) return home + path.substring(1)
  if (path.indexOf("$HOME/") === 0) return home + path.substring(5)
  return path
}

function customModuleSafeName(name) {
  var value = String(name || "")
  return value !== "" && value.indexOf("..") === -1 && value[0] !== "/"
}

function customModuleType(entry) {
  var settings = entrySettings(entry)
  var type = String(settings.type || "")
  if (type) return type
  if (settings.exec) return "command"
  if (settings.source) return "qml"
  return ""
}

function customModulePath(entry, home, configDir) {
  var settings = entrySettings(entry)
  var name = entryId(entry)
  var source = settings.source ? expandPath(settings.source, home) : ""
  if (!source && customModuleSafeName(name))
    source = String(configDir || "") + "/bar/modules/" + String(name) + ".qml"
  return source
}

// A center module is mounted twice once an anchor is set: the copy that is
// actually drawn, and a zero-size placeholder holding its place in the flow
// beside the anchor. Panel routing has to pick the drawn one; it is the only
// one that can anchor a popup, carry the open-panel mark, or be found again
// by switchPanelFrom. Fall back to the placeholder only when nothing is
// on screen. The order the two are registered in is not stable across a live
// bar reconfiguration, so picking the first match is not good enough.
function isDrawnSlot(slot) {
  return !!slot && slot.visible === true && slot.width > 0 && slot.height > 0
}

function pickDrawnSlot(slots) {
  var placeholder = null
  var list = slots || []
  for (var i = 0; i < list.length; i++) {
    if (!list[i]) continue
    if (isDrawnSlot(list[i])) return list[i]
    if (!placeholder) placeholder = list[i]
  }
  return placeholder
}

// A bar surface is built per monitor, so a panel hotkey has several live
// copies of the same widget to route to, and the panel opens on whichever
// monitor's copy answers. Candidates are `{ slot, screenName, opened }`.
//
// An open copy wins first: hide and toggle have to reach the panel the user
// can actually see, wherever it was opened from. Otherwise the focused
// monitor's copy wins, so a summon lands where the user is working instead of
// on whichever output registered its slot first. Neither narrowing applies on
// a single monitor, or when the focused output has no bar of its own.
function pickPanelSlot(candidates, focusedScreen) {
  var rows = Array.isArray(candidates) ? candidates : []
  var pool = rows.filter(function(row) { return row && row.opened === true })
  if (pool.length === 0) pool = rows.filter(function(row) { return !!row })

  var focused = String(focusedScreen || "")
  if (focused) {
    var onFocused = pool.filter(function(row) { return row.screenName === focused })
    if (onFocused.length > 0) pool = onFocused
  }

  return pickDrawnSlot(pool.map(function(row) { return row.slot }))
}

// Resolve a pointer anywhere along the bar to the closest insertion edge.
// Requiring the pointer to sit inside another widget makes the empty space
// around a centered group a dead zone, even though it visually reads as the
// most natural place to drop.
function nearestDropTarget(candidates, point, vertical) {
  var rows = Array.isArray(candidates) ? candidates : []
  var axis = vertical ? Number(point && point.y) : Number(point && point.x)
  if (!isFinite(axis)) return null

  var best = null
  var bestDistance = Infinity
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row || !row.slot) continue

    var start = Number(vertical ? row.y : row.x)
    var size = Number(vertical ? row.height : row.width)
    if (!isFinite(start) || !isFinite(size) || size <= 0) continue

    var beforeDistance = Math.abs(axis - start)
    var afterDistance = Math.abs(axis - (start + size))
    var after = afterDistance < beforeDistance
    var distance = after ? afterDistance : beforeDistance
    if (distance < bestDistance) {
      best = { slot: row.slot, after: after }
      bestDistance = distance
    }
  }
  return best
}

function nonnegative(value) {
  return typeof value === "number" && isFinite(value) ? Math.max(0, value) : 0
}

function axisPositions(extents, spacing) {
  var positions = [], extent = 0, drawn = false
  var values = Array.isArray(extents) ? extents : []
  var gap = nonnegative(spacing)
  for (var i = 0; i < values.length; i++) {
    var size = nonnegative(values[i])
    if (size > 0 && drawn) extent += gap
    positions.push(extent)
    extent += size
    if (size > 0) drawn = true
  }
  return {positions:positions, extent:extent}
}

function relativeLuminance(color) {
  function linear(value) { return value <= 0.04045 ? value / 12.92 : Math.pow((value + 0.055) / 1.055, 2.4) }
  return 0.2126 * linear(color.r) + 0.7152 * linear(color.g) + 0.0722 * linear(color.b)
}

function contrastRatio(a, b) {
  var x = relativeLuminance(a), y = relativeLuminance(b)
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}

function readableForeground(background, preferred) {
  if (contrastRatio(background, preferred) >= 4.5) return preferred
  return relativeLuminance(background) > 0.179 ? "#000000" : "#ffffff"
}

function intersectRect(a, b) {
  if (!a || !b) return null
  var x = Math.max(a.x, b.x), y = Math.max(a.y, b.y)
  var width = Math.min(a.x + a.width, b.x + b.width) - x
  var height = Math.min(a.y + a.height, b.y + b.height) - y
  return width > 0 && height > 0 ? {x:x,y:y,width:width,height:height} : null
}

function sectionGeometry(axisLength, sizes, anchorIndex, settings) {
  var length = nonnegative(axisLength), config = settings || {}
  var pad = nonnegative(config.sectionPadding), spacing = nonnegative(config.widgetSpacing)
  var gap = Math.max(spacing, nonnegative(config.groupSpacing))
  var margin = Math.min(length / 2, config.mode === "docked" ? 0 : nonnegative(config.outerMargin))
  var groups = {}, islands = {}, diagnostics = []
  var names = ["left","right","center","centerBefore","centerAnchor","centerAfter"]
  function group(start, extent, content, alignment) {
    var size = nonnegative(extent), natural = nonnegative(content)
    if (natural === 0) return {start:0,extent:0,contentExtent:0,initialOffset:0}
    var viewport = Math.max(0,size-(natural > size ? 24 : 0))
    var maximum = Math.max(0,natural-viewport)
    return {start:nonnegative(start),extent:size,contentExtent:natural,initialOffset:alignment === "end" ? maximum : alignment === "center" ? maximum/2 : 0}
  }
  for (var n=0;n<names.length;n++) groups[names[n]]=group(0,0,0,"start")
  var left = axisPositions(sizes && sizes.left,spacing).extent
  var right = axisPositions(sizes && sizes.right,spacing).extent
  var centerValues = sizes && Array.isArray(sizes.center) ? sizes.center : []
  var center = axisPositions(centerValues,spacing).extent
  var leftNatural = left > 0 ? left+2*pad : 0
  var rightNatural = right > 0 ? right+2*pad : 0
  // Reserve native scroll access, not just two buttons with a zero-size viewport.
  // This is at least the required 24px side rail, including controls/padding.
  var leftRail = left > 0 ? Math.min(leftNatural,48+2*pad) : 0
  var rightRail = right > 0 ? Math.min(rightNatural,48+2*pad) : 0
  var centerStart = length/2, centerEnd = length/2
  var anchor = Number.isInteger(anchorIndex) && anchorIndex >= 0 && anchorIndex < centerValues.length ? nonnegative(centerValues[anchorIndex]) : 0
  var leftHalf = Math.max(0,length/2-margin-gap-leftRail)
  var rightHalf = Math.max(0,length/2-margin-gap-rightRail)
  var before = anchor > 0 ? axisPositions(centerValues.slice(0,anchorIndex),spacing).extent : 0
  var after = anchor > 0 ? axisPositions(centerValues.slice(anchorIndex+1),spacing).extent : 0
  var beforeGap = before > 0 ? spacing : 0, afterGap = after > 0 ? spacing : 0
  var anchored = center > 0 && anchor > 0
    && anchor/2+pad+beforeGap+Math.min(before,48) <= leftHalf
    && anchor/2+pad+afterGap+Math.min(after,48) <= rightHalf
  if (anchored) {
    var beforePaint = Math.min(before+beforeGap,Math.max(0,leftHalf-pad-anchor/2))
    var afterPaint = Math.min(after+afterGap,Math.max(0,rightHalf-pad-anchor/2))
    var anchorStart = length/2-anchor/2
    groups.centerAnchor = group(anchorStart,anchor,anchor,"start")
    groups.centerBefore = group(anchorStart-beforePaint,Math.max(0,beforePaint-beforeGap),before,"end")
    groups.centerAfter = group(anchorStart+anchor+Math.min(afterGap,afterPaint),Math.max(0,afterPaint-afterGap),after,"start")
    centerStart = anchorStart-beforePaint-pad
    centerEnd = anchorStart+anchor+afterPaint+pad
  } else if (center > 0) {
    var painted = Math.min(center+2*pad,2*Math.max(0,length/2-margin-gap-Math.max(leftRail,rightRail)))
    centerStart = length/2-painted/2
    centerEnd = centerStart+painted
    groups.center = group(centerStart+Math.min(pad,painted/2),Math.max(0,painted-2*pad),center,"center")
    if (anchor > 0) diagnostics.push("Selected center anchor or its neighboring viewports cannot fit; using centered scrollable group")
  }
  islands.center = {start:centerStart,extent:Math.max(0,centerEnd-centerStart)}
  var leftBudget = Math.max(0,(center > 0 ? centerStart-gap : length/2-gap/2)-margin)
  var rightBudget = Math.max(0,length-margin-(center > 0 ? centerEnd+gap : length/2+gap/2))
  var leftPaint = Math.min(leftNatural,leftBudget), rightPaint = Math.min(rightNatural,rightBudget)
  islands.left = {start:margin,extent:leftPaint}
  islands.right = {start:Math.max(margin,length-margin-rightPaint),extent:rightPaint}
  groups.left = group(margin+Math.min(pad,leftPaint/2),Math.max(0,leftPaint-2*pad),left,"start")
  groups.right = group(islands.right.start+Math.min(pad,rightPaint/2),Math.max(0,rightPaint-2*pad),right,"end")
  if (left > 0 && groups.left.extent <= 24 || right > 0 && groups.right.extent <= 24 || center > 0 && islands.center.extent <= 2*pad+24)
    diagnostics.push("Cramped geometry: native viewports are constrained; settings remain reachable through IPC")
  return {groups:groups,islands:islands,diagnostics:diagnostics}
}

if (typeof module !== "undefined") {
  module.exports = {
    axisPositions: axisPositions,
    sectionGeometry: sectionGeometry,
    readableForeground: readableForeground,
    contrastRatio: contrastRatio,
    intersectRect: intersectRect,
    moveLayoutEntry: moveLayoutEntry,
    addLayoutEntry: addLayoutEntry,
    removeLayoutEntry: removeLayoutEntry,
    replaceEntrySettings: replaceEntrySettings,
    isDrawnSlot: isDrawnSlot,
    pickDrawnSlot: pickDrawnSlot,
    pickPanelSlot: pickPanelSlot,
    nearestDropTarget: nearestDropTarget,
    normalizePosition: normalizePosition,
    entrySettings: entrySettings,
    entryId: entryId,
    moduleString: moduleString,
    entryIndex: entryIndex,
    inlineSettingsDelta: inlineSettingsDelta,
    expandPath: expandPath,
    customModuleSafeName: customModuleSafeName,
    customModuleType: customModuleType,
    customModulePath: customModulePath
  }
}
