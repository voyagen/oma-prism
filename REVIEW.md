# Oma Prism — Critical Review and Release Remediation

## Release 1.0.3 — intentional simple-menu cutover

The user identified the technical settings as testing controls and explicitly chose **Simple menu only** for a Linux/software beginner. The shipped menu now has exactly **Appearance**, **Icons & Text** and **Widgets**. This is an intentional product change, not a rollback of backend settings, icon resolution or the earlier correctness fixes.

Appearance retains style, position, spacing presets, screen choice, prevent window overlap, roundness, outline, background/opacity/transparency and reduced animations. Custom backgrounds use a native color picker. Icons & Text retains icon style/size, understandable color choices and text size. Widgets retains add/move/remove and real typed-schema configuration, readable widget names and unavailable saved entries. Reset confirmation/cancel, disk-save errors and keyboard accessibility remain part of the product.

Advanced sections, raw JSON and SVG override/path editors, detailed compatibility/glyph/source/geometry diagnostics and the adapter refresh button are deliberately absent. Existing custom fonts, SVG overrides, detailed geometry, animation duration and opaque widget options remain supported in storage; opening the panel or saving another preference must not clear them. Spacing presets and confirmed group resets still intentionally change their own fields.

The user also requested that scrolling over sliders must never change their values. Native sliders use `wheelEnabled: false`: wheel/trackpad input scrolls the page, while deliberate click/drag and keyboard adjustments remain supported. Actual QML checks verified page movement with unchanged slider/effective/disk values, persisted clicks and keyboard steps, and drag preview followed by save on release.

### Verification of the simple menu

- **62 Node regressions passed**, covering settings, layout, icon resolution and installation.
- `node tools/test-runtime.mjs` and `node tools/test-runtime.mjs ~/.config/omarchy/plugins/voyagen.prism` both reported **PRISM RUNTIME PASS**. They exercised all three tabs, ordinary saves retaining hidden customizations, slider scrolling/click/keyboard/drag behavior, native color-dialog dismissal/confirmation, typed widget configuration and add/move/remove, reset confirmation/cancel, disk acknowledgment and command widgets.
- The three-tab appearance/icon/widget surfaces and native color chooser were visually inspected using the installed UI/resources and a throwaway persistence host. This visual driver was not installed in production.
- `bash install.sh install` / `bash install.sh activate` completed; live health reported **1.0.3**, `ready: true`, one screen, no pending settings write and an empty settings error. Loaded source matched the content-addressed installed resource tree.
- All saved configuration values matched the **immediate activation backup** after the installed-runtime scenarios; object-key ordering was ignored. Earlier concurrent preference changes were retained, not reverted.
- Concurrent motion/pill changes in the checkout were preserved and included in that installed resource tree. These menu checks do not certify their performance or a broad GPU/compositor matrix.

Expected missing-SVG warnings belong to negative cases; the isolated host also emits native floating-window deprecation/portal warnings. Physical trackpad hardware and the earlier temporary multi-output matrix were not independently retested for this menu. The evidence below belongs to releases 1.0.1–1.0.2.

## Releases 1.0.1–1.0.2 — historical remediation complete

**All 18 original findings were implemented, plus the disk-acknowledgment and command-widget injection issues recorded as findings 19 and 20 below. No review item was deferred.** Those releases were installed and active on the inspected host at verification time. Native widget implementations remained host-owned; unsupported private rendering surfaces retained their original behavior.

### Resolution ledger

Every row was resolved for releases 1.0.1–1.0.2. The technical UI resolutions in rows 13–15 describe that historical release, not a requirement to restore the removed developer menu. File names refer to that implementation; the original review's line numbers later in this document refer to its historical snapshot.

| Finding | Implemented resolution | Verification |
| --- | --- | --- |
| 1. Production fixtures | `Bar.qml` no longer constructs fixtures. `DevelopmentBar.qml` is opt-in; release packaging excludes it and all `Smoke*.qml`. Legacy restore refuses an uninitialized snapshot. | Live IPC has only Prism `settings` / `health`, no three fixture targets. First production health had 26 real records instead of the former 106 fixture-polluted records. |
| 2. Contrast | `BarModel.js` calculates luminance/contrast, retains an adequate theme foreground, otherwise selects readable black/white. | Saturated and neutral background regressions meet 4.5:1; translucent-background approximation is documented. |
| 3. Activation readiness | `tools/install.mjs` validates dependencies, bounds runtime waiting, checks version **and loaded source URL**, and rolls back on failure. | Missing/version/source/not-ready health and missing-dependency regressions; actual stale-QML activation failed and restored configuration, then the corrected release activated successfully. |
| 4. Fallback ownership | `IconAdapter.qml` checks upstream ownership before re-enabling its binding, including while SVG fallback is active. | Actual native QML: invalid SVG → foreign component → valid SVG; upstream null/component bindings remained live after detach. |
| 5. SVG refresh | Editable probe and painting are uncached/asynchronous; Refresh clears and reloads both. Bundled assets remain cached. | Same-path square-to-narrow edit changed painted extent; deleting the file produced Error/native fallback, not stale Ready. |
| 6. Anchor wings | `BarModel.js` requires usable nonempty wing budgets and falls back to ordinary centered scrolling with a diagnostic. | Exact formerly failing `[32,868,32]` case and cramped/overflow model boundaries. |
| 7. Rail position | `AxisRail.qml` preserves/clamps offset; explicit structural layout keys control initial realignment. | Actual native rail retained offset 57 across replacement with equal geometry rather than resetting to 80. |
| 8. Clipped targets | `Bar.qml` intersects slot bounds with visible clipping ancestors for drag targeting, navigation and markers. | Fully clipped slot excluded; partially clipped interval reduced to its drawn width. |
| 9. Monitor routing | Settings use the supplied invoking item, otherwise the focused selected monitor, with an explicit fallback. Padding supplies its own per-screen anchor. | Actual anchored popup window matched the invoking window; live settings and native audio opened on the focused secondary virtual output. |
| 10. First run | Installer handles absent/empty user files using native defaults and records original file semantics. | Activation, failure and rollback for absent, empty and present states; unrelated settings preserved. |
| 11. Invalidation / I/O | Adapter snapshots only resolver inputs; geometry snapshots only layout inputs. Editable SVG loading is asynchronous. | Unrelated radius/opacity preview retained the actual resolver result and geometry-input object identities. |
| 12. QML boundaries | Extracted `BarSurface.qml`, `AxisRail.qml`, `ModuleSlot.qml`, `CustomCommandModule.qml` with explicit controllers and retained attribution. Deferred work is object-owned and cancels on unload. | Actual host loading; pending-work adapter destruction/restoration and fresh reattachment; eight compositor placement/mode scenarios. Host contracts documented in README. |
| 13. Friendly configuration | Override row picker, complete Unicode labels, SVG preview/save/remove, selected-entry schema editor/native configuration action; raw JSON is advanced. | Actual row save/remove and typed schema save changed disk and the live widget, preserving ID and opaque options; invalid integer draft rejected. |
| 14. Geometry controls | Advanced edge gap, margin, section padding, spacing, thickness and outline-opacity controls; requested/effective geometry exposed. | All settings tabs visually inspected; eight floating/docked × edge combinations matched actual compositor axis/cross dimensions. |
| 15. Diagnostics | Unknown/repaired values reported, problems sorted first, benign custom icons informational; exact target matching avoids cross-surface/duplicate errors. Known private-surface section/screen retained. | Model repair regressions; two identical-glyph surfaces kept separate ownership statuses; live private Radio Atlas row showed `right` / `PRISM-DIAG`, with missing legacy widget and effective geometry clearly identified. |
| 16. Atomic resets | Confirm/cancel controls list affected fields; one validated multi-field mutation per group, leaving host layout intact. | Actual mouse events: first click did not save, Cancel preserved values, confirmation persisted only appearance; icon reset persisted defaults without changing appearance/layout. |
| 17. Durable install | Runtime-only copies by default; owned-path checks, two-target staged rollback, explicit `--dev`. Content-addressed resource URLs invalidate the host's QML cache without a shell restart. | Installed-resource QML scenarios passed; owned-link upgrade, unrelated-path refusal and failed-rescan restoration regressions; live fresh-source activation. |
| 18. Release docs | Added README/CHANGELOG; both manifests are 1.0.2; PRD distinguishes completed implementation from original observations. | Documented commands were exercised; exact host versions and display/hardware limits recorded. |
| 19. Disk acknowledgment | `Bar.qml` confirms both injected configuration and the version-1 disk file, with bounded polling/deadline and actionable failure. Memory equality alone never skips retry. | A host echo without persistence remained pending, timed out with error and unchanged disk; retry persisted and confirmed correctly. |
| 20. Command injection | `ModuleSlot.injectProps()` skips command-owned `bar`, `moduleName` and `settings`; adapter observation still runs. | Real `exec` JSON output, saved command/settings changes and removal cleanup passed against checkout and installed resources; the pre-fix run failed on read-only assignment and missing observation. |

### Historical verification of releases 1.0.1–1.0.2

**Environment:** Omarchy **4.0.4-1**, Quickshell **0.3.1 (Arch)**, Qt **6.11.2**, Linux/Wayland.

```sh
node --test tests/settings-model.test.cjs tests/bar-model.test.cjs tests/icon-resolver.test.cjs tests/install.test.cjs
# 61 passed, 0 failed

node tools/test-runtime.mjs
node tools/test-runtime.mjs ~/.config/omarchy/plugins/voyagen.prism
# PRISM RUNTIME PASS against checkout and installed QML/resources

bash install.sh install
bash install.sh activate
# Installed runtime copies; Activated voyagen.prism 1.0.2; 1 screen ready

omarchy-shell voyagen.prism health
```

- QML checks use real Prism/native Qt components, temporary files and a throwaway persistence host. They exercise ownership/fallback, edited/deleted assets, live glyphs, clipping, scroll retention, acknowledgment failure/retry, native reset confirmation/cancellation, schema/override editing, command output/settings updates/removal and teardown. They reject QML errors rather than treating compilation as success.
- Actual production settings were opened and keyboard-navigated through Appearance, Icons & Text, Layout and Compatibility; screenshots were visually inspected and Escape closed the panels. No live appearance/layout edits were saved.
- Display checks included the physical **3440×1440 scale-1** surface and two temporary **1920×1080 headless** outputs at **1** and **1.25** scale. The installed QML scenarios exercised both virtual screens and all eight mode/edge combinations. Focused-monitor settings and the preserved native audio popup were visually inspected on the secondary output; audio controls were not changed.
- Production settings/visual checks and the temporary-output display matrix above were performed for 1.0.1. For 1.0.2, the 61 Node regressions and checkout/installed-runtime QML scenarios were rerun, live activation reported ready on one screen, and the complete saved configuration matched the activation backup. The temporary-output matrix was not repeated.
- Initial live upgrade exposed the host retaining an old component at the unchanged entrypoint URL. The bounded health failure actually rolled back. Content-addressed installation plus loaded-source matching resolved it without restarting the desktop shell.
- Current saved bar subtree was compared with the activation backup and remained equal. Unrelated configuration changes were retained. No `/usr/share/omarchy` files were edited. Temporary outputs/screenshots and throwaway test directories were removed.

**Verification limits, not deferred findings:** no physical multi-monitor/GPU matrix or real battery/network hardware-state matrix is certified. Contrast over arbitrary wallpaper remains an approximation. Private artwork, transport and label renderers are deliberately not claimed as universally replaceable. Missing legacy registry entries remain visible diagnostics, not silently removed layout data. Expected missing-SVG warnings occur in negative scenarios; the isolated host also emits native floating-window deprecation/portal warnings. These are distinguished from Prism QML runtime errors, which fail the launcher.

### Additional finding 19 — host echo is not disk-save acknowledgment

**Priority: Medium. Configuration correctness/error handling. Resolved in 1.0.1.**

The inspected host's `shell.qml:109-114` assigns `shellConfig = payload` before calling `userConfigFile.setText(...)`; `mutateShellConfig` at `162-166` invokes that persistence path. The prior echo-based confirmation could therefore report success before asynchronous file writing completed. Prism now independently watches/reloads the actual user file, requires both views to match, and reports timeout instead of acknowledging an unpersisted echo. This is a plugin-side correction; the host was not patched. The failed-save acknowledgment and successful retry were reproduced in the actual QML scenario with a deliberately nonpersisting temporary host.

### Additional finding 20 — command-widget injection aborts observation

**Priority: Medium. Command-widget integration. Resolved in 1.0.2.**

The 1.0.1 verification missed loading an actual command entry. `CustomCommandModule.qml` derives read-only `moduleName` and `settings` from its entry and binds `bar` to its controller; shared injection attempted to overwrite those fields before observation. The added runtime scenario reproduced `Cannot assign to read-only property "moduleName"` and failed its observation check. Injection now leaves those command-owned bindings alone and continues observing the widget. The scenario verifies collected JSON output, saved command/settings changes and cleanup on removal. Custom command edits intentionally retain the existing rebuild behavior rather than promising identity preservation.

---

## Original review — historical verdict

The following findings, locations, counts and verification limits describe the **pre-remediation snapshot**. They are preserved as the evidence behind the work above, not statements that the current release remains unfixed.

The core product idea is useful, but this is not a clean production release. The most serious problem is that the installed bar still constructs development fixtures, exposes configuration-mutating test IPC, and includes hidden catalogue icons in its production adapter. Fix that before adding features.

The implementation already makes several sound decisions: it loads existing widgets rather than copying their service logic, separates pure models from QML, bundles licensed SVG assets, validates override paths, and retains original icons for unsupported surfaces. Preserve those decisions. The next iteration should concentrate on lifecycle correctness, predictable configuration, and reducing the amount of host-engine behavior Prism must maintain.

This review contains **18 findings: 3 high, 14 medium, and 1 low priority**. Findings include defects, design weaknesses, and explicitly identified missing features; they are not all demonstrated runtime failures.

### Evidence terminology

- **Observed:** exercised against the running plugin.
- **Reproduced:** exercised in a pure-model or isolated Qt scenario; not necessarily on the live desktop.
- **Source-traced [INFERENCE]:** the code establishes a failure path, but that path was not independently exercised.
- **Design finding:** a maintainability or usability assessment, not a claim of measured failure.

High priority means a release blocker, unsafe behavior, or a serious correctness/accessibility defect. Medium means consequential behavior or usability work after those blockers. Low means useful polish without a demonstrated significant failure.

## High-priority findings

### 1. Development fixtures are part of the production bar

**Priority: High.** Architecture, performance, reliability, unnecessary complexity.

**Locations:** `Bar.qml:17-20`; `Smoke.qml:11,175-178`; `SmokeGrid.qml:65-99`; `SmokeLayout.qml:13,93-100`; `tools/install.mjs:10-11,82-86`.

- **Problem:** normal bar construction eagerly creates `Smoke`, `SmokeLayout`, and `SmokeSettings`. The hidden catalogue grid creates and registers all 80 sample icons even when its window is not shown. Test IPC remains registered. In particular, `prism.layout restore` writes `config.bar = proof.originals`, although `originals` starts as `{}` before a fixture has been configured.
- **Why it matters:** production startup and pack changes carry synthetic adapters, image probes, and compatibility records. Diagnostic output is polluted with test states. QtTest and hard-coded host-model imports become production dependencies. The restore endpoint also provides a source-traced path to erasing the saved bar subtree. This is not merely leftover test code; it changes runtime behavior and carries configuration risk.
- **Improve it:** remove the three fixture instances from the installed entry point. Keep the acceptance scenarios in an explicitly launched development entry point outside normal discovery. Do not simply hide them or disable their timers: hidden QML objects are still constructed. Guard fixture restoration against missing snapshots even in development.
- **Evidence:** **Observed:** IPC advertised `prism.smoke`, `prism.layout`, and `prism.settings-proof`; a read-only audit returned **106 records, 103 adapted**. The hidden catalogue accounts for 80 synthetic targets by construction. **Source-traced [INFERENCE]:** destructive restore before configure; deliberately not invoked.

### 2. Foreground selection uses the wrong measure of contrast

**Priority: High.** UX, accessibility, correctness.

**Location:** `Bar.qml:105-114`.

- **Problem:** the foreground heuristic switches between light and dark text at HSL lightness 0.5. HSL lightness is not perceived luminance or a contrast ratio. The supposedly readability-preserving branch can select an unreadable foreground on a valid custom background.
- **Why it matters:** ordinary labels and status symbols become difficult to read. A fully opaque `#0000ff` background with light theme text selects `#1a1a1a`: about **2.03:1** contrast, versus **6.88:1** for `#e6e6e6`.
- **Improve it:** calculate relative luminance and compare contrast ratios for the theme foreground and explicit light/dark candidates. Pick the candidate with adequate contrast rather than an HSL threshold. For translucent islands, document that the underlying wallpaper is not known; using the theme background as an approximation cannot guarantee contrast everywhere.
- **Evidence:** **Reproduced:** isolated Qt 6.11.2 `QColor` execution of the current branch and contrast calculation. The desktop theme/configuration was not changed.

### 3. Activation success does not mean the plugin loaded successfully

**Priority: High.** Installation, reliability, error handling.

**Locations:** `tools/install.mjs:24-39,91-106`; installed host `shell.qml:250-262`.

- **Problem:** activation accepts a successful command and persisted `bar.id === "voyagen.prism"` as proof of success. Project validation checks the entry point and assets, but not whether the complete QML dependency tree can load. The host loads the plugin asynchronously and can fall back to its default bar without correcting the selected ID.
- **Why it matters:** a broken installation can report success while displaying another bar, and the existing rollback-on-error branch never runs. Users get an apparently selected but failed plugin and must diagnose host logs themselves.
- **Improve it:** add a small production readiness/health response that identifies the loaded Prism version. After switching selection, wait for that response with a bounded deadline and restore the backup on failure. Validate required local dependencies before activation; filesystem checks still do not replace runtime confirmation.
- **Evidence:** **Source-traced [INFERENCE].** Example: a project copy missing `IconAdapter.qml` can pass the current explicit file checks yet fail when the asynchronous Loader resolves it. No broken activation was attempted on the user's desktop.

## Medium-priority correctness and reliability findings

### 4. The adapter can overwrite a foreign icon acquired during fallback

**Priority: Medium.** Widget compatibility, ownership, reliability.

**Locations:** `IconAdapter.qml:124-128,254,279-295`.

- **Problem:** `custom` is captured at discovery. Later foreign ownership is detected only while `canAdapt` is true. If a widget supplies an `iconComponent` while Prism is falling back because its SVG is unreadable, that ownership change is ignored. Once a valid asset becomes ready, Prism can overwrite the new widget-owned component.
- **Why it matters:** the preservation contract holds for the tested active-replacement transition but not for all transitions. A widget dynamically introducing a custom icon can lose its own rendering.
- **Improve it:** recognize foreign non-null components during fallback as well as active replacement. Distinguish upstream changes from Prism's own binding assignments/restoration, and relinquish the target before re-enabling replacement. Add a regression scenario: invalid override → upstream custom component → valid override.
- **Evidence:** **Source-traced [INFERENCE].** This exact transition was not executed against an actual widget. The existing ownership smoke scenario exercises a different transition.

### 5. Refreshing a custom SVG does not reliably refresh the file

**Priority: Medium.** Configuration, reliability.

**Locations:** `IconAdapter.qml:73-75,269-277`; `shared/SvgIcon.qml:15-19`; `Settings.qml:572-576`.

- **Problem:** refresh clears and restores the same URL, while both the probe and rendered image retain Qt's default `cache: true`. The rendered image can keep the old image alive in the shared cache.
- **Why it matters:** editing or deleting an override can leave stale artwork and a misleading `Image.Ready` status after clicking Refresh. That undermines both live customization and error diagnostics.
- **Improve it:** disable caching for editable custom assets in both images, while retaining caching for immutable bundled assets. Ensure explicit refresh also reloads the painted image; refreshing only the probe is insufficient. Consider file watching only if automatic reload is actually needed.
- **Evidence:** **Reproduced:** an isolated Qt Quick two-image scenario matching the shared-URL probe/render arrangement. Before deletion: `probe=1 painted=1`; after deleting the SVG and clearing/restoring the probe URL: `fileExists=0 probe=1 painted=1`. This was not a destructive test on a user's icon. Qt documents shared caching and its default in the [Image contract](https://doc.qt.io/qt-6/qml-qtquick-image.html#cache-prop).

### 6. A fitting center anchor can make its neighboring widgets unreachable

**Priority: Medium.** Geometry, UX, correctness.

**Locations:** `BarModel.js:345-358,376-377`; `Bar.qml:1860-1863`.

- **Problem:** the anchored branch checks whether the anchor itself fits, not whether nonempty wings retain usable viewports. Both neighboring groups can have positive content extent but zero drawing extent, without producing a diagnostic.
- **Why it matters:** users cannot reach those widgets by arrows, wheel, or keyboard: their viewport and arrow sizes are zero. The ordinary centered-scroll fallback could preserve access but is not selected.
- **Improve it:** accept anchoring only when each nonempty wing has usable space after scroll controls. Otherwise fall back to the ordinary centered rail and explain why. Extend the cramped-geometry diagnostic to individual wings.
- **Evidence:** **Reproduced** with the actual exported model:

  ```js
  sectionGeometry(
    1000,
    { left: [32], center: [32, 868, 32], right: [32] },
    1,
    { mode: "floating", outerMargin: 6, sectionPadding: 8, widgetSpacing: 4 }
  )
  ```

  Both wing groups returned `extent: 0`, `contentExtent: 32`; `diagnostics` returned `[]`. No live layout changes were made.

### 7. Unrelated settings changes reset rail scrolling

**Priority: Medium.** Responsiveness, UX, state preservation.

**Locations:** `Bar.qml:1512,1859-1867`.

- **Problem:** the geometry binding takes the entire `prismSettings` object, and `onGeometryChanged` resets the offset to `initialOffset`. Changing icon pack or opacity therefore recreates geometry and resets scrolling even when its bounds have not changed. Native widget-size changes can also reset it.
- **Why it matters:** a user who scrolls to a widget can lose their place while adjusting appearance or after a dynamic label changes width. A popup anchor can move unexpectedly.
- **Improve it:** initialize alignment on creation or deliberate structural changes. Preserve and clamp the existing offset for ordinary updates. Restrict geometry inputs to settings that actually affect layout.
- **Evidence:** **Source-traced [INFERENCE].** No overflowing desktop rail was reconfigured to exercise this transition.

### 8. Drag targeting includes widgets that are completely clipped out

**Priority: Medium.** Layout editing, correctness.

**Locations:** `Bar.qml:1123-1153,1883-1894`; `BarModel.js:275-299`.

- **Problem:** drop candidates require only `visible` and positive natural size. Flickable clipping does not alter those properties. A clipped slot's mapped bounds can extend into another section and win nearest-edge targeting.
- **Why it matters:** dropping over a visible widget can target an invisible neighbor from a different rail, producing the wrong insertion marker or saved destination.
- **Improve it:** intersect candidate bounds with the owning rail viewport, discard fully clipped candidates, and use the visible interval for nearest-edge selection. Reuse that drawn-interval calculation where panel navigation needs on-screen candidates.
- **Evidence:** **Source-traced [INFERENCE].** Pointer dragging under overflow was not exercised during this review.

### 9. Anchorless settings requests choose registration order, not the user's monitor

**Priority: Medium.** Multi-monitor UX.

**Locations:** `Bar.qml:42-44,743-752,1827-1831`; `BarModel.js:257-268`.

- **Problem:** an anchorless settings request chooses the first settings widget or `barPanels[0]`. Padding right-click also passes null when its window has no settings widget. Neither path necessarily selects the invoking or focused output.
- **Why it matters:** requesting settings on a second monitor can open the panel on the first, despite other panel-routing logic already understanding the focused monitor.
- **Improve it:** pass the invoking surface as the padding-click fallback. For IPC, select the focused monitor's bar surface, then fall back to another selected screen. Reuse the existing monitor-routing convention rather than inventing another one.
- **Evidence:** **Source-traced [INFERENCE].** The inspected desktop provided one output; multi-monitor behavior was not reproduced.

### 10. Activation rejects a legitimate first-run shell configuration

**Priority: Medium.** Installation, reliability.

**Locations:** `tools/install.mjs:18-22,95`; installed `omarchy-shell-config:20-25`.

- **Problem:** activation unconditionally reads and parses the user `shell.json`. Native Omarchy tooling falls back to packaged defaults when that file is absent or empty.
- **Why it matters:** a reachable shell running its valid defaults cannot complete Prism activation without the user first creating a configuration file manually.
- **Improve it:** use the host's effective defaults fallback for activation input. Record whether the original user file was absent or empty so rollback can preserve its previous semantics, instead of treating every starting state as an existing JSON document.
- **Evidence:** **Source-traced [INFERENCE]** against the installer and installed native configuration helper. No user file was removed or emptied to reproduce it.

## Medium-priority architecture, performance, and UX improvements

### 11. Appearance edits invalidate too much icon and layout work

**Priority: Medium.** Performance, responsiveness.

**Locations:** `Bar.qml:34-36,56,1512`; `Settings.qml:263-277`; `IconAdapter.qml:24-34,242,265-267,273-277`.

- **Problem:** one freshly normalized settings object feeds the whole adapter and geometry. Every slider preview replaces it. Even radius or background-opacity edits invalidate icon resolution bindings; the resolver returns fresh result objects, which trigger diagnostic notifications. Icon-size dragging also changes SVG source sizes repeatedly. Local images use synchronous loading by default.
- **Why it matters:** unrelated settings cause avoidable work on the UI thread. The production fixture problem currently multiplies that work. Custom SVG parsing can be disproportionately expensive compared with these small bundled assets.
- **Improve it:** remove fixtures first. Keep icon-resolution inputs stable unless pack or override mappings change; feed layout only geometry inputs. Use asynchronous loading for custom SVGs in both probe and painted paths. Profile slider dragging after those small changes before introducing caches, worker systems, or a rewritten renderer.
- **Evidence:** **Source-traced [INFERENCE]** invalidation and loading paths; no per-plugin latency/GPU benchmark was collected. Qt documents synchronous local loading under [Image performance](https://doc.qt.io/qt-6/qml-qtquick-image.html#asynchronous-prop). This review does not claim measured frame drops.

### 12. The bar entry point has too many responsibilities and too much host-engine duplication

**Priority: Medium.** Architecture, code quality, simplification.

**Locations:** `Bar.qml` — 2,295 lines; API/ownership machinery at `155-363`, persistence at `632-741`, window/rail/slot rendering around `1430-2230`, custom commands at `2233-2293`.

- **Problem:** one file owns plugin facades, ownership tracking, popouts, tooltips, drag routing, settings persistence, screen windows, section geometry, widget loading, and command execution. It also derives substantial behavior from the host/islands engine, creating another implementation to keep in step with upstream.
- **Why it matters:** a small presentation change can touch host integration and object lifecycle. Upstream changes require manual reconciliation in a large file. The pure models help, but do not remove the QML coupling.
- **Improve it:** keep `Bar.qml` as the controller and extract only real boundaries, such as the per-screen surface and registry slot. Retain the existing pure models. Reuse a public host primitive when one exists; otherwise make the upstream compatibility contract explicit. Prefer a public widget icon-rendering hook over expanding discovery heuristics. Do not add factories, generic registries, or a new framework, and do not delete scoped plugin facades merely to reduce line count.
- **Evidence:** **Design finding.** File size was measured; responsibilities and duplicated-engine origin are visible in the source.

### 13. Icon overrides require users to understand implementation-level JSON

**Priority: Medium.** UX, configuration, missing useful feature.

**Locations:** `Settings.qml:287-350,481-484,537-563`.

- **Problem:** custom icon configuration requires editing full JSON dictionaries, knowing semantic keys, and sometimes copying private-use glyphs. Inline widget settings similarly use an untyped complete-object editor.
- **Why it matters:** customization is technically available but unnecessarily error-prone. JSON syntax validation does not help users discover a supported state or choose a file. Editing one override requires handling the entire dictionary.
- **Improve it:** add a small row editor for semantic key → local SVG path, with an icon preview and remove action. Provide a widget/state picker using discovered glyphs and their Unicode code points. Keep JSON in an Advanced section. For inline settings, reuse a widget's settings schema or existing host configuration UI when available; retain JSON for opaque third-party fields.
- **Evidence:** **Observed/design finding:** the actual Icons & Text panel was opened and visually inspected; its primary override workflow is the JSON editor shown by the source.

### 14. The settings UI omits most of the geometry that the model supports

**Priority: Medium.** UX, missing useful feature.

**Locations:** `SettingsModel.js:29-59`; `Settings.qml:434-470`.

- **Problem:** presets replace five spacing fields, while the UI exposes radius but not individual thickness, edge gap, outer margin, section padding, or widget spacing. Outline opacity is also modeled but not exposed. Existing custom geometry is preserved, yet users cannot tune most of it in the panel.
- **Why it matters:** users must jump to manual configuration for basic bar fitting, especially when native widget sizes make the effective thickness differ from the preset. This weakens the live customization feature.
- **Improve it:** add one collapsed Advanced geometry section using the existing bounded numeric control, showing requested versus effective thickness. Keep presets as the default path rather than filling the main panel with more sliders.
- **Evidence:** **Design finding:** direct comparison of the schema and appearance controls. Effective geometry is already available in Compatibility.

### 15. Diagnostics silently accept configuration mistakes and bury useful context

**Priority: Medium.** Configuration, error handling, troubleshooting.

**Locations:** `SettingsModel.js:139-145,190-201`; `Bar.qml:766-785`; `Settings.qml:567-587`.

- **Problem:** diagnostics iterate known settings only, so unknown keys are invisible. Out-of-range numeric input is clamped but not reported as a repair. Compatibility rows are primarily per-record status/semantic descriptions; they do not give a compact problem-first summary or a direct override action.
- **Why it matters:** a misspelled setting appears to do nothing with no explanation. Manual configuration can differ from effective configuration without an actionable warning. Large record lists make real failures harder to find, especially while test fixtures are present.
- **Improve it:** report unknown keys and repaired numeric values with their effective replacement. Default Compatibility to actionable problems, then allow expanding supported surfaces. Include the widget, glyph/code point, semantic key, source path and relevant screen/section where available, with copyable details or an Edit override action.
- **Evidence:** **Reproduced:** `{iconPakc: "material-symbols", opacity: 2}` normalized to `iconPack: "lucide"` and `opacity: 1`, while `diagnostics()` returned `[]`. The diagnostic UI structure was source-inspected.

### 16. Configuration has no simple reset or recovery action

**Priority: Medium.** UX, missing useful feature.

**Locations:** `SettingsModel.js:2-27`; `Settings.qml:434-563`; `Bar.qml:663-741`.

- **Problem:** the UI supports many immediate persistent edits but no reset-to-defaults or undo-last-edit action. Selecting a spacing preset only resets those five fields, not the whole appearance or icon configuration.
- **Why it matters:** experimentation is easy; returning to a known-good state is manual. A confusing combination of transparency, colors, icon overrides and geometry takes multiple independent edits to recover.
- **Improve it:** start with Reset appearance and Reset icons actions, showing the fields affected and requiring confirmation. Keep layout out of appearance resets. Commit each reset atomically through the existing host mutation API. A one-step undo is useful later; a profile/version-history framework is not required.
- **Evidence:** **Design finding:** defaults already exist, but no recovery action is present among the settings controls.

### 17. Installation is a development link, not a durable release install

**Priority: Medium.** Packaging, reliability, missing useful feature.

**Locations:** `tools/install.mjs:7-11,77-90`.

- **Problem:** installation points both plugin directories directly at the project checkout. Moving/deleting that checkout breaks the installed plugin, and editing development files immediately changes the installed resource tree.
- **Why it matters:** this is useful during development but fragile as the only end-user installation mode. It also makes it difficult to distinguish the version selected in the manifest from the files currently being edited.
- **Improve it:** keep symlinks as an explicit development mode. Provide a durable release install containing only runtime files and licensed assets in the user plugin directory, with a deliberate update path. Do not copy the acceptance harness into the runtime bundle. Avoid a package-manager abstraction: a deterministic file list and ordinary installation are sufficient.
- **Evidence:** **Design finding/source-traced:** both destinations are symlinks. No project directory was moved to demonstrate breakage. Linking is permitted by the PRD; the missing distinction between development and release installation is the issue.

## Low-priority documentation improvement

### 18. The repository has a requirements document instead of a user entry point

**Priority: Low.** Onboarding, configuration, release clarity.

**Locations:** `PRD.md:9,38-48,184-225`; `manifest.json:5`; installer usage at `tools/install.mjs:108`.

- **Problem:** the manifest says `1.0.0`, while the PRD still describes verification in progress and mixes requirements, implementation details, installation-specific observations, and historical acceptance evidence. There is no concise README in the inspected root.
- **Why it matters:** a new user has to infer dependencies, installation versus activation, rollback, settings access, and real compatibility limits. Historical verification is easy to mistake for coverage of the current build and machine.
- **Improve it:** add a short quickstart: supported/tested Omarchy and Qt versions, install/activate commands, how to open settings, configuration location, rollback, and known unsupported surfaces. Keep the PRD as engineering history. State hardware/display verification limits and align version/release status with what is actually shipped.
- **Evidence:** **Design finding:** repository layout, manifest, installer usage and PRD were inspected.

## What to simplify or avoid adding

- **Remove development runtime state first.** The five `Smoke*.qml` files contain **614 lines**; they should be outside normal bar construction, not thrown away as tests. Removing the three constructor lines and their temporary comment cuts four lines from `Bar.qml` and disconnects the fixtures from production. This is a runtime-surface reduction, not a claim of 614 repository lines deleted.
- **Keep one authoritative configuration model.** Do not introduce a second persistent store, a generic transaction service, or an event bus. The host already owns persistence.
- **Make center-entry anchoring an advanced option.** Ordinary centered scrolling is the boring, understandable default. Fix the wing boundary before expanding anchored-layout features.
- **Keep both icon packs and context-specific mappings.** They serve the stated product goal; they are not dead flexibility. Unknown glyph fallback and local-path validation are also not bloat.
- **Keep native widget behavior.** Do not fix unsupported private icon surfaces by copying audio/network/power implementations. Seek a public icon hook, and report unsupported surfaces honestly.
- **Defer more packs, plugins, animations, a universal theme engine, and saved-layout profile machinery.** Override editing, recovery actions, reliable activation, and truthful diagnostics make this plugin more useful sooner.

## Recommended implementation order

1. Remove production fixtures/test IPC; add a configuration-safe development entry point.
2. Fix contrast selection and verify runtime activation before accepting a selection.
3. Fix ownership acquired during fallback and refresh of editable SVG assets.
4. Fix anchor-wing reachability, preserve rail position, and make drag targets clip-aware.
5. Repair first-run activation and contextual monitor routing.
6. Improve override editing, expose advanced geometry, add focused reset actions, and make diagnostics actionable.
7. Split the QML at real boundaries, provide a durable release install, and document the supported host contract.

## Verification performed

- Ran the existing model/resolver tests:

  ```sh
  node --test tests/settings-model.test.cjs tests/bar-model.test.cjs tests/icon-resolver.test.cjs
  ```

  **Result: 40 passed, 0 failed.** These checks do not cover all QML ownership/lifecycle, packaging, or clipped-interaction defects above.

- Queried the running shell's IPC surface, requested the read-only icon audit, and inspected live bar geometry. Observed the three development IPC targets and 106 adapter records, of which 103 were adapted.
- Opened and visually inspected the actual settings panel, including Icons & Text. Sent Escape afterward. No settings were intentionally saved.
- Executed the exported geometry model at the exact oversized-anchor boundary; observed zero-width nonempty wings and an empty diagnostic list.
- Ran a settings-model scenario demonstrating invisible unknown keys and silent numeric repair.
- Ran isolated Qt 6.11.2 reproductions for the HSL contrast branch and same-URL image-cache refresh. Temporary files were outside the repository.
- Read the installed Omarchy host loading/configuration contracts and Qt's Image documentation to distinguish plugin defects from host behavior.

### Limits and non-findings

- This was a snapshot review, not a diff review; the directory did not provide a Git baseline. No plugin implementation was modified.
- Did not intentionally corrupt the live configuration, invoke fixture restore, run activation/rollback, change real audio/network state, or reload the desktop shell.
- Did not exercise multi-monitor, fractional-scale/high-DPI, real battery transitions, ownership acquired during fallback, or overflow drag interactions on the desktop. Relevant unexercised claims are labeled above.
- Did not collect a controlled per-plugin performance profile. Whole-shell CPU or memory cannot be attributed to Prism.
- The apparent duplicate-instance inline-settings fan-out is **not** a reported bug: `BarModel.js:167-189` rejects ambiguous deltas for changed duplicate IDs, so the bar rebuilds instead of applying that ambiguous in-place update.
- Preserving an existing custom icon component is intentional. The observed Tailscale/settings-widget custom components and Radio Atlas private-surface limitation are not evidence that fallback itself is broken.
