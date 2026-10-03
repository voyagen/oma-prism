# Oma Prism

A Docked, Floating or Islands Omarchy bar with Lucide / Material Symbols icons and live appearance settings. Native widgets still own their actions, menus and service state. Prism replaces supported public icon surfaces, not widget implementations.

## Host requirements and compatibility

- Linux, a running Omarchy Quickshell session, Qt Quick / Controls / SVG, `Qt5Compat.GraphicalEffects`, and Quickshell's Hyprland, Wayland and Io modules; the host must expose `qs.Commons` and `qs.Ui`.
- Bash and Node.js 18+ for installation. Activation also requires the native `omarchy-shell`, `omarchy-bar`, `omarchy-plugin-catalog` commands and their host dependencies (including `jq`, `qs` and `timeout`). Set `OMARCHY_PATH` to your Omarchy installation.
- The host must support version-1 plugin manifests, full-bar and bar-widget discovery, injection of `barConfig`, widget/plugin registries and the shell persistence API. Prism relies on native `omarchy-bar use`, plugin rescan and configuration reload IPC.

Release 1.0.1 was exercised on **Omarchy 4.0.4-1, Quickshell 0.3.1 (Arch), Qt 6.11.2**: a 3440×1440 output at scale 1, plus two temporary 1920×1080 headless outputs at scales 1 and 1.25. Floating/docked placement on all four edges, focused-monitor settings and native audio popup routing were exercised. These host contracts are not a guarantee for every Omarchy release, physical multi-monitor/GPU combination or hardware state. Current evidence and the original review are separated in `REVIEW.md`.

Release **1.0.3** intentionally replaces the former technical settings menu with a beginner-friendly, **simple menu only**, as requested by the user. Saved customizations remain supported; removing their editors does not remove their values. Scrolling over a slider moves the page, not its value; click, drag and keyboard adjustment still work. Checkout and installed-resource QML checks and 62 Node regressions passed; activation reported ready. Current evidence and limits are in `REVIEW.md`; earlier display checks remain historical.

## Install, activate, update and recover

From this checkout:

```sh
bash install.sh install
bash install.sh activate
```

Installation copies runtime QML/JavaScript, licensed SVG assets and shared resources to `~/.config/omarchy/plugins/voyagen.prism` and `voyagen.prism.settings`. It **does not select a bar**. The copy does not depend on the checkout after installation and excludes development fixtures, tests and tools. Runtime resources live in a content-addressed directory; the installed manifest points there so a changed release gets a fresh QML URL rather than the host's cached component. Run `install` again to update, then `activate` to confirm the new runtime. Only marked Prism installations or this checkout's own development links can be replaced; unrelated paths are refused. A failed staged install restores both previous plugin targets.

Activation prints `Backup: <path>` under `~/.local/state/oma-prism/backups`, selects Prism through the host and waits up to ten seconds for version- and source-URL-matched production health. Loader failure or timeout restores the previous bar configuration. For a slower startup, set `PRISM_ACTIVATION_TIMEOUT_MS` (integer 1–120000). No host packaged files are edited.

```sh
bash install.sh rollback ~/.local/state/oma-prism/backups/shell-EXACT-BACKUP-NAME.json
# Explicit development mode; QML code changes may need a host reload/restart.
bash install.sh install --dev
```

Rollback restores only the backed-up `bar` subtree, retaining unrelated current configuration and enabled plugins. An originally absent or zero-byte user configuration returns to that state if unrelated settings have not changed; otherwise a user file is retained to preserve the new unrelated settings. On first run, activation uses `$OMARCHY_PATH/config/omarchy/shell.json`, like the native configuration helper. Backup JSON is installer metadata, not a replacement shell configuration. Keep it private.

## Open settings and inspect readiness

```sh
omarchy-shell voyagen.prism settings
omarchy-shell voyagen.prism health
```

You can also right-click bar padding or enable/place the `voyagen.prism.settings` native bar widget. The health method returns JSON:

```json
{"id":"voyagen.prism","version":"1.0.3","ready":true,"screenCount":1,"recordCount":12}
```

The counts above are illustrative, not measured. `ready` means host injection is complete and the selected screen panels exist. Health also returns the loaded QML `source` URL, `settingsWritePending` and `settingsError`; the installer compares the source with the installed manifest. Health is production-only; development fixture IPC is not installed.

## Configuration and customization

Use the settings menu for everyday changes. It has exactly three tabs:

- **Appearance:** Docked → Floating → Islands style, bar position, spacing presets, screen choice, prevent window overlap, roundness, outline, background, opacity, transparency and reduced animations. Custom background colors use a native color picker.
- **Icons & Text:** icon style and size, understandable color choices and text size.
- **Widgets:** add, move or remove ordinary widgets and configure supported typed widget options. Widgets use readable names; unavailable saved widgets remain in the layout with a clear label.


Layout modes always appear in this order:

1. **Docked** (default): one full-width continuous bar attached directly to the screen edge.
2. **Floating**: one continuous rounded bar, inset from the screen edge by `edgeGap` and from the axis ends by `outerMargin`.
3. **Islands**: separate floating backgrounds for the left, center and right sections; empty sections paint nothing.

Saved `bar.prism.mode` values are `docked`, `floating-bar` and `islands`. Existing `floating` values meant islands: they load as Islands without changing geometry and migrate to `islands` on the next appearance save. Saved Docked configurations remain unchanged.

The UI waits for both the host's injected configuration **and the actual disk file** to confirm each write. An in-memory echo alone is not success. If confirmation has not arrived after 2.5 seconds, the panel reports an error; the host may still display the unpersisted in-memory edit until configuration reload. Fix permissions/write errors and retry; matching memory alone never skips the retry.

**Reset appearance** and **Reset icons** ask for confirmation, explain the affected preferences in plain language and save each group together; neither rewrites the widget layout. Cancel leaves settings unchanged. Keyboard navigation and Escape remain available.

Scrolling with a mouse wheel or trackpad over a slider scrolls the page without changing that preference. Deliberate click/drag and keyboard slider adjustments still change settings.

The production menu has no Advanced sections, JSON editors, SVG override/path editors, Compatibility tab, detailed geometry diagnostics or adapter Refresh button. Those were technical/testing surfaces in earlier releases, deliberately removed for this beginner-focused cutover.

Existing custom SVG overrides, custom font family, detailed spacing and animation settings remain supported in the saved configuration. Opening the menu or changing another preference does not clear them. Selecting a spacing preset intentionally changes its spacing settings; confirming a reset intentionally resets that group's existing fields.

The host owns `~/.config/omarchy/shell.json` (schema `version: 1`). Prism preferences live in `bar.prism`; `bar.position`, `bar.layout`, widget options and `plugins` remain host configuration. Bundled SVG assets are installed locally; missing/unreadable custom assets and unsupported private icon surfaces retain native rendering. The simple menu does not promise universal icon replacement or wallpaper contrast.

### Spacing and macOS-inspired UI

Prism-owned surfaces follow the supplied macOS-inspired guidelines: restrained hierarchy, aligned controls, semantic grouping, subtle state feedback and visible keyboard focus. Native widget menus and the native color chooser remain host-owned; Prism does not replace their behavior or edit packaged host components.

The bar uses one density unit (`thickness / 8`) rather than independent pill tweaks. Default is the reference for new configurations:

| Geometry (logical px) | Compact | Default | Comfortable |
|---|---:|---:|---:|
| Bar height | 32 | 40 | 48 |
| Pill height / icon hit area | 24 | 30 | 36 |
| Top/bottom internal inset | 4 | 5 | 6 |
| Horizontal text padding per side | 8 | 10 | 12 |
| Gap between controls | 4 | 6 | 8 |
| Minimum gap between major sections | 12 | 15 | 18 |
| Left/right internal inset | 8 | 10 | 12 |
| Floating outer margin | 8 | 10 | 12 |
| Floating screen-edge gap | 4 | 5 | 6 |

Pill dimensions are reserved by native control/slot geometry, so paint does not steal neighboring gaps. Larger icons, text or native widgets can expand the bar while retaining its internal inset. Percentage-plus-icon power controls reserve both text and symbol space. Nested groups of public controls share the control gap; private application/artwork layouts remain widget-owned. Explicit command-widget horizontal padding and saved custom geometry remain supported; old spacing values are not silently rewritten and may appear as Custom until a preset is selected.

Settings use the same density unit for controls, padding, icons and section rhythm. At Default, controls are 30 px high, icons 16 px, panel padding 16 px, related-control gaps 8 px and section gaps 24 px. Text remains readable at Compact (12 px baseline), Default (13 px) and Comfortable (14 px), honoring larger host typography. Tabs and multi-action groups wrap on narrow panels; selected actions use weight and a marker as well as fill, and keyboard focus remains visible. Reset confirmation puts Cancel before Confirm reset; widget configuration retains typed fields and disk-confirmed saves. The background chooser shows the saved color beside the native color picker.

Verification: all four isolated QML/Wayland fixtures passed, including three densities, 19 bar-layout scenarios, all settings tabs, typed configuration, inline reset, 480 px narrow panel fit, Tab traversal and Escape/reopen. Eighteen settings-state captures were produced and representative normal/narrow/density states visually inspected. Native color acceptance/cancellation, saved customization preservation and immediate actions passed the existing runtime scenarios; 63 Node regressions passed. The layout detector reported no findings (its QML coverage is limited). The updated runtime is installed and activated: production health reports ready with no pending write or settings error. Native vertical-clock sizing was reproduced and corrected; the real host clock passes all three densities/layout modes against both checkout and installed resources. The active configuration exactly matches the activation backup.


## Interaction and symbol motion

Native `WidgetButton` / `BarIconButton` controls receive shared paint-only feedback through `Bar.qml`'s existing registration path. No widget-local animations or host edits are needed. `InteractionMotion.qml` observes pointer input passively, scales centered painting children, and leaves mouse geometry, commands, wheel events and keyboard routing native. Hover is 1.022× / 120 ms; press is 0.975× / 80 ms; release rises to at most 1.025× and settles over 220 ms. Motion does not resize density-adjusted layout or hit targets. A bounded two-stage easing response replaces an unconstrained spring; interrupted input retargets from the current value.

Appearance offers an **Animations** selector: **Off**, **Reduced**, **Default**, and **Expressive**. Default preserves the existing restrained motion. Expressive increases hover scale to 1.07×, press compression to 0.90× and release overshoot to 1.09×; it also strengthens icon bounce, wiggle, breathing and replacement movement, and lengthens bar color/opacity transitions by 50%. Layout and hit targets stay fixed. The selection saves atomically through `bar.prism.motionEnabled`, `reducedMotion` and `animationIntensity` (`"default"` or `"expressive"`); existing saved enable/reduced flags remain respected. Global disable takes precedence over local enable. Reduced interaction uses opacity instead of compression; symbol bounce/wiggle use brief opacity emphasis, loading uses opacity instead of rotation, and replacement crossfades without geometric motion. Existing native tint, dimming, menus and focus behavior remain host-owned.

`StatePill.qml` supplies centered rounded state backgrounds. Icon slots use circles; wider text/app controls use capsules with density-based horizontal padding. Both button and open-panel pills share this geometry. Hover uses 5.5% accent fill; active/open uses 12%; active + hover uses 16%. Press uses 10%, or 20% while active. Entry fades over 120 ms and exit over 160 ms; reduced motion uses a 100 ms opacity transition, and global disable makes state changes immediate. Workspace `focused` state keeps its native glyph/opacity indication and does not create a persistent pill; hover/press feedback remains available. Native `active`/`effectiveActive` and open-popup state still highlight controls. Open-module pills suppress duplicate button pills. Hover never triggers a semantic symbol effect.

Widget-scoped overrides live in `bar.prism.motionOverrides`; omitted fields inherit policy. Example:

```json
{
  "motionEnabled": true,
  "reducedMotion": false,
  "animationIntensity": "default",
  "motionOverrides": {
    "omarchy.audio": {"interactionEnabled": false, "iconEnabled": false},
    "omarchy.microphone": {"effect": "none"},
    "omarchy.bluetooth": {"replace": true, "reducedMotion": true}
  }
}
```

Fields are `interactionEnabled`, `iconEnabled`, `reducedMotion`, `replace` (booleans) and `effect` (an effect name). They belong inside `bar.prism`, not the host's top-level configuration. Appearance reset resets this motion policy. A custom native button may additionally declare `prismMotionEnabled` / `prismReducedMotion` for its interaction helper.

`shared/AnimatedIcon.qml` keeps the existing `SvgIcon` URL, tint, sizing and cache contract. It supports `none`, `bounce` (300 ms), `wiggle` (320 ms), `pulse` (1000 ms, opacity only), `breathe` (1600 ms, at most 1.025×), `rotate` (1100 ms), `appear` / `disappear` (160 ms), and `replace` (190 ms). Use declarative `effect` for ongoing state and `triggerEffect("bounce")` for discrete feedback:

```qml
import "shared" as Shared

Shared.AnimatedIcon {
    id: symbol
    required property var motionSettings
    property bool recording: false
    source: Qt.resolvedUrl("assets/icons/lucide/microphone-enabled.svg")
    effect: recording ? "breathe" : "none"
    replaceEnabled: true
    motionEnabled: motionSettings.motionEnabled
    reducedMotion: motionSettings.reducedMotion
    expressiveMotion: motionSettings.animationIntensity === "expressive"
}
// On a meaningful completion event: symbol.triggerEffect("bounce")
```

`enabledOverride` / `reducedMotionOverride` are nullable per-icon overrides. `stopEffect()` restores native presentation and suppresses the current loop until another request/state change; `replaceSource(url)` changes the source, using `replaceEnabled` policy. Disappear retains layout space until appear, a new source, or stop. One-shots interrupt each other rather than queue; ongoing state resumes afterward. Two persistent SVG slots retain the outgoing source during replacement—no SVG path morphing or component recreation per frame. Rotation uses `RotationAnimator`; numeric animations elsewhere keep interruption observable and predictable.

Default semantics are deliberately limited: Bluetooth state replacement plus one bounce on connection; audio/microphone mute replacement; breathing only while the microphone's public in-use state is active. Ordinary volume adjustments, power, battery, workspaces and other icons remain still. `IconAdapter.semanticPolicies` keeps this mapping separate from low-level effects. Unknown connecting/recording service states are not inferred. `activityEnabled` gates loops for ancestor concealment: the adapter supplies native control/slot visibility and opacity; custom callers should supply their own concealment state. Hidden items/windows, zero-opacity icons and disabled motion stop animations.

Rail clipping also gates control, pill and semantic motion. `ModuleSlot.motionVisible` tracks the Flickable's committed content translation and reuses `drawnSlotRect` for the actual clipped intersection. Fully scrolled-out slots suspend motion even though QML still reports `visible: true`; scrolling back resumes ongoing state. The runtime smoke covers scroll-out, scroll-back, partial intersection and the exact viewport boundary.

Verification: 62 Node regressions and both actual QML/Wayland scenario sets passed on Qt 6.11.2 / Quickshell 0.3.1. Motion scenarios exercise immediate actions, overlay forwarding, drag-away/rapid input, independent transforms, replacement interruption, reduced variants, reactive policy changes, active/hover pill precedence, vertical pills and widget teardown. The final rounded surface was inspected in an isolated rendered fixture. A final `QSG_RENDER_TIMING=1` run reported 339 rendered frames, p95 frame-work cost rounded to 0 ms at Qt's millisecond precision, and maximum 15 ms (during bar-window orientation reconfiguration). These coarse timings are not an end-to-end compositor latency or universal frame-drop guarantee. Desktop selection/configuration was not changed.

## Local checks

```sh
node --test tests/*.test.cjs
# Actual QML/Wayland scenarios with throwaway configuration:
node tools/test-runtime.mjs
# Dedicated native-pointer and symbol-motion scenarios:
node tools/test-runtime.mjs --motion
# Density, edge insets, nested pills and enlarged content:
node tools/test-runtime.mjs --layout
# All Prism-owned settings surfaces, densities and narrow-panel fit:
node tools/test-runtime.mjs --design
# Optional actual-compositor screenshots, requiring grim:
PRISM_DESIGN_CAPTURE=/tmp/prism-design node tools/test-runtime.mjs --design
# Exercise the installed runtime instead of checkout QML:
node tools/test-runtime.mjs ~/.config/omarchy/plugins/voyagen.prism
# Read-only production runtime confirmation, after activation:
omarchy-shell voyagen.prism health
```

Installer tests use throwaway homes and stub host commands, not your desktop configuration. The QML launcher uses actual Prism/native Qt components and a throwaway persistence host, additionally requires **QtTest for development-only input simulation** and a running Wayland/Omarchy environment, cleans its temporary files, and rejects QML runtime errors. Its scenarios cover fallback ownership, edited/deleted assets, disk acknowledgment failure/retry, clipping, ordinary UI saving with saved customization preservation, actual reset confirmation/cancellation clicks, typed widget configuration, command entries, adapter teardown and eight placement/mode combinations. Live desktop loading, keyboard interaction and visual inspection are recorded separately in `REVIEW.md`. Licensing notices are in `LICENSE` and the bundled asset directories.

Run the QML fixtures sequentially: both use real compositor surfaces and input focus. A concurrent run failed the settings keyboard scenario; the isolated run passed. Node checks can run independently.

## Engineering boundaries and host contract

| Boundary | Responsibility |
| --- | --- |
| `Bar.qml` | Host integration, authoritative layout/settings state, scoped widget APIs, popup routing and disk acknowledgment |
| `BarSurface.qml` | One native layer-shell surface per selected screen and its three islands |
| `AxisRail.qml` | Clipped native-size scrolling, focus and preserved/clamped offsets |
| `ModuleSlot.qml` | Registry/custom loading, widget API/settings injection and interaction |
| `CustomCommandModule.qml` | Existing command-widget behavior |
| `IconAdapter.qml` / `IconResolver.js` | Public-surface ownership/lifecycle and pure contextual resolution |
| `InteractionMotion.qml` / `StatePill.qml` | Passive pointer observation, paint-only physical feedback and active/hover pill state |
| `shared/AnimatedIcon.qml` | Independent semantic effects and persistent-slot SVG replacement |
| `Settings.qml` / `SettingsModel.js` | Native settings UI and shared validation/defaults |

Extracted QML requires an explicit `controller`; it does not depend on another file's lexical IDs. Deferred work uses object-owned timers so unloading a plugin cancels its callbacks.

The tested host injects `shell`, `manifest`, `barConfig`, `barWidgetRegistry` and `pluginRegistry`. Registry `widgets[id].component` and `metadataFor(id)` supply ordinary widget components and metadata (`firstParty`, `allowMultiple`, `defaults`, `schema`). The host re-injects `barConfig` after edits/reload. The scoped `shell.mutateShellConfig(callback)` owns persistence but acknowledges only the request; Prism separately watches the version-1 user file. Native panel/keyboard/layer-shell components remain host-owned. SVG substitution depends specifically on the public `BarIconButton.iconComponent` hook; there is no universal private-QML icon contract.

`DevelopmentBar.qml` is an opt-in legacy fixture entry point requiring a deliberately configured development host with the same injections. Normal manifests still select `Bar.qml`; release packaging excludes `DevelopmentBar.qml` and every `Smoke*.qml`. Use the isolated launcher above for reproducible checks without mutating desktop configuration.
