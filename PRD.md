# Oma Prism — Product Requirements Document

## 1. Product definition

Oma Prism is a customizable Omarchy/Quickshell bar with consistent, sharp SVG icons. Its layout modes are Docked (default), Floating and Islands, in that order: a continuous edge-attached bar, a continuous inset bar, and separate floating sections.

The central requirement is automatic replacement of bar-widget Nerd Font icons with equivalents from a selectable icon pack, without copying applications or maintaining forks of every widget. Existing widget behavior, popups, state changes, and interactions must remain functional.

Status: release 1.0.3 adopts the user's explicit **Simple menu only** choice. The production menu has exactly **Appearance**, **Icons & Text** and **Widgets** tabs. Former Advanced, JSON/SVG editors and detailed diagnostics were technical/testing UI, not the current beginner product. Backend saved settings and resolver functionality remain supported. The 1.0.1–1.0.2 review remediation and observations below are engineering history; release-specific evidence and limits are recorded separately in `REVIEW.md`.

## 2. User problem

Existing widgets choose their own Nerd Font glyphs. Their icons are not universally exposed as configurable SVG sources. Building a new bar should not require duplicating audio, network, Bluetooth, power, and other plugins just to change how their icons look.

Application logos in workspace widgets and application-provided system-tray icons are separate from Nerd Font widget icons. Those images are not the target of automatic replacement.

## 3. Goals

- Render supported Nerd Font widget icons as actual SVG assets, not screenshots or font glyphs.
- Start with Lucide as the default pack and support a Material Symbols SVG pack.
- Switch packs globally without changing the bar layout or reinstalling widgets.
- Preserve existing plugins and their behavior wherever their rendering surface permits adaptation.
- Provide Docked, Floating and Islands layouts with live customization, in that order.
- Keep ordinary text, application logos, artwork, and tray images unchanged.
- Install entirely in user-owned locations and survive Omarchy package updates.

## 4. Non-goals

- Replacing or copying installed applications.
- Globally changing the desktop icon theme or system fonts.
- Reimplementing existing plugin services and popup logic.
- Modifying `/usr/share/omarchy/`.
- Claiming universal SVG substitution for arbitrary third-party QML without a verified rendering contract.
- Restyling every icon inside popup panels; initial scope is the bar surface itself.

## 5. Original host-contract observations and constraints

These observations were captured during initial feasibility inspection, before the completed Prism release:

- Full-bar plugins declare `kinds: ["bar"]` and a bar entry point in their manifest. The initially inspected bar was `lobo.islands`.
- The inspected Islands bar loaded existing widget components from the injected registry. Its `registryComponent`, `registryLoader`, and `injectProps()` established the integration pattern retained by Prism.
- `/usr/share/omarchy/shell/Ui/BarIconButton.qml` exposes `iconComponent`. When set, it renders that component instead of its `OpticalGlyph` child.
- Widgets own their icon rendering. There is no verified, universal host-level SVG override property in the inspected contracts.
- A child declared with a QML `id` is not automatically an externally accessible property. A widget's private button cannot be assumed accessible to its containing bar.
- Some widgets render glyphs through different components or direct `Text` items. They need separate compatibility handling.
- Nerd Font codepoints do not match the codepoints in unrelated icon fonts. Simply selecting a Lucide or Material font is not equivalent to mapping icons.

These observations establish feasibility for a compatibility layer, not proof that every currently installed widget can already be adapted without changes.

## 6. Icon replacement requirements

### 6.1 Semantic mapping

The icon pipeline must map:

`widget context + current Nerd glyph → semantic icon key → selected pack SVG`

Examples of semantic keys include `volume-muted`, `volume-low`, `volume-high`, `wifi-off`, `wifi-weak`, `wifi-strong`, `bluetooth-off`, `bluetooth-connected`, `battery-empty`, `battery-full`, `battery-charging`, `brightness`, and `microphone-muted`.

Requirements:

- Map each required glyph state explicitly; do not infer meaning from its visual shape at runtime.
- Prefer widget-specific mappings when a glyph has ambiguous meanings.
- Keep mappings in one shared catalogue, not copied into each bar instance or widget.
- Preserve live state updates, including mute, connection, signal, charging, and enabled/disabled states.
- Provide pack-specific equivalents for the same semantic keys.
- Allow custom SVG overrides by semantic key and by widget/glyph pair.
- Unknown glyphs retain their original rendering. Internal compatibility diagnostics remain available to the implementation, not as a production settings tab. No silent disappearance or unrelated substitute.

### 6.2 Runtime adaptation

The first implementation must prove whether the containing bar can reach supported visual icon surfaces and supply an SVG component while retaining the original widget.

Preferred order:

1. Use an exposed icon-component or icon-source property when a widget provides one.
2. Use a centralized adapter for a verified shared component surface, such as an accessible `BarIconButton.iconComponent`.
3. Where no accessible rendering contract exists, propose a small upstream icon-override hook rather than duplicating the widget implementation.

If visual-child discovery is necessary, isolate it in the compatibility layer, scope it to bar content, and test it against actual widget instances. Do not depend on undocumented child indices or private QML IDs. Lazy loading, replacement of child objects, plugin reloads, and cleanup must be handled without repeated full-tree scanning every frame.

The adapter must preserve original event handlers, popout ownership, dimensions, tooltips, visibility, enabled state, color, and icon rotation where applicable. It must not cover entire widgets with non-interactive replacement drawings or hide labels to mask incomplete adaptation.

Implemented contract: the bar-owned adapter identifies actual `qs.Ui.BarIconButton` instances by QML type, watches visual children and lazy Loader changes, and supplies lexical replacement Components through reversible Bindings. A persistent hidden Image probes local assets before adaptation; unreadable paths retain the original live icon. Existing custom Components and foreign owners remain untouched. Audio runtime proof passed native left/middle/right clicks, volume wheel, hover, pack switching, invalid-file fallback, empty/unknown text, detach restoration and stable records. A separate actual-QML Binding proof passed foreign-owner relinquishment without destroying its upstream binding.

### 6.3 Literal SVG versus icon-font alternative

Actual SVG rendering is the default product requirement. A remapped icon font generated from the same SVGs is a possible alternative because existing widgets already render Nerd codepoints, but it is not equivalent to literal SVG rendering. Adopting it as the primary implementation requires an explicit product decision; it must not silently replace the SVG requirement.

### 6.4 Pack assets

- Bundle the SVGs needed by supported mappings so rendering does not require network access.
- Preserve source-pack attribution and license files.
- Render icons at the active display scale with a consistent optical size.
- Tint monochrome assets to the widget's effective foreground, including active and disabled states.
- Use an explicit SVG coloring/tinting mechanism; do not assume external SVG files inherit QML `currentColor`.
- Prefer a consistent Lucide outline style and Material Symbols outlined style by default.
- Validate custom asset paths and show errors without breaking the bar.

Bundled sources: Lucide static 0.468.0 (ISC, including Feather attribution) and Material Symbols outlined commit `6d7ca43bd6e6668531a00fcaca06d921b63dd716` (Apache-2.0). Runtime never downloads assets. The catalogue contains 80 contextual states / 160 local SVGs, including the live Agents robot and tray drawer chevron. Some artwork bands intentionally coincide: Lucide Wi-Fi levels 1/2 and day/night fog/snow-showers; Material day/night rain/snow-showers, rain/showers, and the two plugin-manager states. Their semantic keys remain separate. Twenty explicit battery normal/charging-level variants per pack add static monochrome interior fills to licensed upstream frames; charging bolts remain unobscured. Monitor glyphs describe screen count, not brightness.

Power percentage rendering preserves the complete integer prefix in a fitted native-width Text+SVG composition. Runtime grids passed all states in both packs, including model-emitted synthetic network/weather/battery glyphs. With no local battery, a reversible projection of the original registry power button into a native doubled-slot harness verified its percentage SVG and the original ModuleSlot underline metric; this is renderer/geometry proof, not a hardware battery transition.

## 7. Layout and appearance

### Default presentation

- Three independently configurable ordinary widget sections: left, center and right.
- Rounded corners for Floating and Islands, no border by default (`outlineWidth: 0` in all modes), restrained background opacity, and consistent icon spacing.
- Reuse all current widget entries in their original sections on activation, preserving order and inline settings.
- Leave application logos and tray icons visually distinct from monochrome status symbols.
- Compact is the startup spacing default: 28px requested thickness, 8px section-end padding, 4px widget gaps, 4px edge gap and 6px outer margin. Default uses the former Comfortable geometry (40/16/8/10/12px respectively); Comfortable increases it to 48/20/10/14/16px. Existing saved/custom geometry is preserved. Native widget hit targets stay intact; fixed larger widgets can expand effective thickness.

### Customization

Expose only everyday controls through the three-tab settings interface; preserve existing persistent custom settings that no longer have editors:

| Area | Controls |
| --- | --- |
| Appearance: placement | Top, bottom, left, right; screen choice; prevent window overlap |
| Appearance: style and spacing | Docked (default), Floating, Islands in that order; Compact / Default / Comfortable presets; existing custom geometry retained until intentionally changed |
| Appearance: shape | Roundness and Off/On outline |
| Appearance: background | Theme/custom background; native color picker; opacity and transparency |
| Appearance: motion | Reduced animations; saved transition duration retained without a duration editor |
| Icons & Text | Icon style and optical size, understandable color choices, text size; saved custom font family retained without a freeform editor |
| Widgets | Add, move, remove and typed schema/native configuration for ordinary widgets; readable names and unavailable-entry labels |

No Advanced sections, raw JSON editors, SVG path/override editors, detailed geometry/source/glyph diagnostics or adapter refresh action ship in this menu. Existing SVG overrides and opaque widget options remain stored and functional. Opening or saving another preference must not clear them. Reset confirmation/cancellation and disk-save errors remain visible; reset explanations use friendly preference names while retaining the existing reset groups and fields.

Sliders must ignore mouse-wheel and trackpad scroll adjustments so the page scrolls without accidental setting changes; deliberate click/drag and keyboard adjustments remain functional.

Every section accepts the same ordinary widgets. Center is a normal floating island, centered on the physical bar axis independently of unequal side widths by default. An optional matching center-entry anchor keeps that entry's midpoint at the physical center. Bound and scroll oversized sections without overlap, preserving native widget dimensions and access.

Floating and Islands modes must reserve enough space for thickness and edge gap when reservation is enabled. Floating paints one continuous rounded background with outer margins; Islands paints separate section backgrounds and no empty islands. Docked removes floating margins and retains its full-width square background. All four positions must support matching popup placement and pointer behavior. Legacy saved `floating` values load as Islands; the new Floating mode persists as `floating-bar`.

Implemented geometry uses one live slot tree per section/screen, native-size clipped scroll rails, 12px arrow controls, padding-wheel scrolling and focused keyboard arrows. An ordinary center group or selected visible anchor remains physically centered; overflow does not overlap neighboring islands. Runtime checks on the scale-1 DP-1 output passed all four positions in floating/docked modes with ordinary and oversized anchored center content, stable settled widget identities and native audio popups. Earlier checks with 40px requested thickness and 10px edge gap observed 50px floating and 40px docked reservations; effective thickness remains native-widget dependent. Keyboard rail focus follows the host's Exclusive-prime → OnDemand convention; Escape releases it.

Settings changes must apply live, persist across shell restarts, and recover gracefully from invalid values. Geometry values need bounded ranges to prevent unusable layouts.

## 8. Plugin compatibility

Initial acceptance set:

- Audio: muted, low, medium, high, headphone output where present.
- Network: disconnected, Ethernet, Wi-Fi signal states.
- Bluetooth: unavailable/disabled, enabled, connected.
- Power: available battery levels, charging, AC-only behavior where applicable.
- Monitor: brightness/display icon.
- Microphone: enabled and muted.
- Weather: the condition glyphs emitted by the installed widget.
- Indicators: DND, night light, stay awake, reminder, dictation, and recording states.
- System update: its displayed update glyph/state.

Enumerate the installed widget's actual glyphs before defining mapping coverage. Conditions that hardware cannot produce locally need a deterministic rendering harness, while real device transitions should also be exercised where available.

Other plugins may reuse the same shared adapter automatically, but compatibility is claimed only after verification. Internal diagnostics identify supported, partially supported and unmapped widgets/glyphs; the beginner menu does not expose this technical report.

Existing application workspace icons, system-tray menus, media artwork, clock text, and plugin labels must continue to work unchanged.

Observed Pocket limit: its installed standing startup repair may rewrite its own `members` ordering to match the saved layout. Prism does not pin or reorder tray entries. Preserving that widget's original behavior means its autonomous configuration writes remain possible; exact rollback restores the saved bar subtree.

The separately configured Dynamic Island overlay is outside Prism's scope. Do not install, load, inject or disable it; leave unrelated plugin configuration untouched.

## 9. Architecture

Project directory: `~/Projects/oma-prism/`.

Plugin identity: `voyagen.prism`. Display name: `Oma Prism`.

Implemented responsibilities:

- `Bar.qml`: authoritative state, scoped APIs, host integration, popup routing and disk-confirmed persistence.
- `BarSurface.qml`: per-monitor layer-shell surface and islands.
- `AxisRail.qml`: bounded native-size scrolling and offset preservation.
- `ModuleSlot.qml`: registry/custom loading, settings/API injection and native interaction.
- `CustomCommandModule.qml`: command-widget behavior.
- `IconResolver.js`: glyph/context to semantic key and pack asset resolution.
- `shared/SvgIcon.qml`: SVG sizing and tinting, shared with the settings widget through the acyclic `settings/shared` resource link.
- `IconAdapter.qml`: attaching and releasing adapters on supported widget instances.
- `Settings.qml` / `SettingsModel.js`: three-tab beginner UI, validated saved settings, typed widget options, confirmed resets and persistence errors; technical saved configuration support remains in the model/backend.
- `assets/icons/<pack>/`: bundled SVG assets and license notices.
- `manifest.json`: plugin entry points and supported settings.
- `settings/manifest.json` and `settings/BarWidget.qml`: ordinary draggable `voyagen.prism.settings` widget with a literal prism SVG. Install makes it available but never places it automatically. Its SVG follows Prism's configured `iconSize`, while the native click/drag target stays unchanged.

Keep host/widget integration compatible with the installed Omarchy shell. Reuse proven bar-loading and interaction patterns rather than inventing a second plugin lifecycle. Any reused bar-engine source must retain its license and attribution. Avoid duplicate implementations of plugin service logic.

Preserve registry component identity, native input, settings updates, owned APIs and creation/destruction behavior. Missing components remain diagnosed layout entries, not substitute widgets.

Persist Prism-specific settings under `bar.prism` using the active bar's scoped mutation API. Keep host `bar.layout`, `bar.position`, `bar.transparent` and `bar.centerAnchor` authoritative. Activation must preserve all existing sections and arbitrary inline settings without migration or reordering.

The host mutation API can echo requested configuration before its asynchronous file save finishes. Prism confirms both injected values and the version-1 disk file, with a bounded timeout and explicit error. No second settings store or host-file patch is introduced. Object-owned timers cancel deferred work during unload.

## 10. Installation and activation

- Develop in `~/Projects/oma-prism/`.
- Default to durable, runtime-only content-addressed copies in `~/.config/omarchy/plugins/voyagen.prism/` and the settings-widget directory; retain checkout links only under explicit `install --dev`.
- Preserve the user's existing shell configuration before activation.
- Switch only the selected full-bar identity and required Prism settings; preserve widget entries and their inline settings.
- Document bounded version/source-checked activation and subtree rollback to the backed-up previous selection, including absent and empty first-run files.
- Installing the project must not select it automatically.
- A short, reversible activation is permitted for verification; restore the prior selection afterward unless the user requests permanent activation.

## 11. Acceptance criteria

1. Oma Prism is discoverable and loadable as a full-bar plugin without packaged-file edits.
2. Existing supported widget components are loaded directly; no application copies or per-widget implementation forks are required.
3. All glyph states in the initial acceptance set have verified SVG equivalents, or the missing rendering hook is explicitly resolved before claiming completion.
4. Changing the selected icon pack changes supported bar icons live while leaving text, application logos, and tray images unchanged.
5. Audio mute/volume, network connection/signal, Bluetooth, and battery state changes update icons correctly without restarting the shell.
6. Original widget clicks, middle/right clicks, scrolling, tooltips, popup opening/closing, and keyboard behavior remain functional where provided.
7. Docked, Floating and Islands modes and four positions render without clipping, misplaced popups, or incorrect reserved space.
8. Icons are sharp and consistently aligned on standard and high-DPI displays.
9. Saved custom overrides take precedence over pack mappings. Missing/unknown mappings retain the original icon and remain identifiable by internal diagnostics.
10. Appearance settings survive restart and apply live without resetting existing widget settings.
11. Plugin reloads and repeated pack changes do not create duplicate adapters or stale bindings.
12. Rollback restores the previous bar selection and layout.
13. All three ordinary sections remain configurable; center accepts the same widgets as either side. Activation preserves existing center entries and inline settings.
14. Center is an ordinary island, not a reserved Dynamic Island integration; no dedicated Island dependency is installed or injected.
15. Unequal side widths do not displace the ordinary center group or selected anchor. Bounded scrolling keeps sections non-overlapping and all widgets reachable.
16. Empty sections paint no islands. Docked, Floating and Islands and four-edge changes preserve original widgets, popup placement, pointer behavior and reservation.
17. The bar-owned settings button depicts a literal pyramid/prism SVG, opens Prism settings and never inserts a settings widget into saved layout.
18. The production settings menu has exactly Appearance, Icons & Text and Widgets, without developer editors or diagnostics. Custom background uses a native color picker; ordinary saves preserve existing hidden custom values. Typed widget configuration, confirmed resets, save errors and keyboard access remain usable.

## 12. Verification plan

- Build a minimal runtime proof first: load an existing audio or network widget and replace its live glyph with a real SVG through the bar-owned adapter. Confirm state changes and original interaction before expanding the design.
- If that proof requires an inaccessible private component, document the exact missing hook and choose an explicit upstream/API change; do not compensate by pretending a universal adapter exists.
- Exercise mapping boundaries and precedence with deterministic tests for the shared resolver.
- Launch the real Omarchy shell integration and inspect screenshots plus runtime logs.
- Exercise mute, volume, popup controls, pack switching, geometry customization, reload, and rollback on the running desktop.
- Move real ordinary widgets between left, center and right; confirm center renders them and inline settings survive.
- Compare center group/selected-anchor midpoints with the physical display center under unequal and overflowing sides in both modes and all four positions; verify bounded rails remain reachable without overlap.
- Verify no Dynamic Island is installed or injected, and separately configured overlays remain untouched.
- Verify all initial acceptance-set glyphs through actual runtime states or a focused rendering harness when hardware is unavailable.
- Record what was exercised, which displays/hardware were available, and any remaining compatibility limits.

## 13. Main risks and decisions

| Risk | Required response |
| --- | --- |
| Widget exposes no icon surface | Add an explicit hook or obtain approval for a different strategy; no invisible scope reduction |
| Generic traversal modifies non-icon text | Restrict adaptation to verified icon components and mappings |
| Different widgets reuse a glyph with different meanings | Resolve with widget context before global mapping |
| SVG tinting or optical dimensions differ across packs | Normalize sizing and verify tinting in the real renderer |
| Host/plugin API changes | Centralize compatibility code and document supported shell versions |
| Reload creates stale objects | Release adapters when widgets are destroyed and verify repeated reloads |
| Icon pack license obligations | Bundle attribution and applicable licenses |

The critical engineering decision remains the runtime SVG adaptation proof. The desired result is automatic centralized substitution, not a collection of copied widget plugins.
