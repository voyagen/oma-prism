# Changelog

## Unreleased

- Apply the repository-wide complexity audit: remove obsolete SVG-editor helpers/tests, unused controller delegates and state, and unused motion/alignment options. Reuse existing entry lookup and standard array searches; validate settings once at the persistence boundary. Preserve saved overrides, native input, layout and disk-save acknowledgment.
  Verification: 61 Node regressions and all four isolated QML/Wayland runtime, motion, layout and settings-design fixtures passed.
- Apply a coherent bar density scale with Default as the new-configuration reference: 32/40/48 px bars, 24/30/36 px pills, 4/5/6 px cross-axis insets and 8/10/12 px horizontal padding. Reserve pill extents in layout rather than painting into neighboring gaps; keep zero-axis spacers zero and explicit command padding intact.
- Distinguish tight control spacing from major-section separation, scale nested public control groups, and retain physical center anchoring and native overflow rails. Grow the bar for larger icon/text/native content without losing boundary breathing room.
- Follow the supplied macOS-inspired guidelines for restrained default press feedback (0.975×), readable density-aware tooltips and consistent floating-surface proportions. Keep opt-in Expressive behavior and native widget actions/menus.
- Apply the same density rhythm throughout Appearance, Icons & Text, Widgets, typed configuration, inline reset and color selection. Add semantic groups, readable typography, restrained control radii, consistent native dropdown/toggle sizing, wrapping actions/tabs, selected markers and visible keyboard focus. Keep the simple menu, native color dialog and disk-confirmed save contracts.
  Verification: all four isolated QML/Wayland fixtures passed; 19 bar scenarios, three densities, all settings tabs/configuration/reset, 480 px narrow fit, Tab and Escape/reopen covered. Eighteen compositor settings captures produced; representative states visually inspected and short-label wrapping corrected. Native color acceptance/cancellation and immediate actions retained; 63 Node regressions passed. No production installation or activation.
- Preserve native geometry for custom-painted, hidden-label text controls instead of replacing their vertical height with a single pill. Reproduced the native clock's clipped multiline stack, corrected shared sizing eligibility, and verified the actual host clock across all three densities and layout modes; 63 Node regressions passed.
  Deployment: installed and activated the updated 1.0.3 runtime; one production screen ready, no pending settings write or error. Installed-resource native clock/layout scenarios passed and the desktop bar was visually inspected. The complete saved configuration matches the activation backup.
- Order layout modes as Docked (new/default configurations), Floating (one continuous rounded bar with edge gap and outer margins), Islands (separate floating sections). Preserve existing Docked and Islands geometry; migrate legacy saved `floating` values to Islands and store the new Floating mode as `floating-bar`.
  Verification: 63 Node regressions passed; actual QML/Wayland UI selections persisted all three modes and checked continuous/section backgrounds, margins, radius and edge spacing on all four edges. Rendered top-edge backgrounds visually inspected in isolation; no production activation.
- Replace the two animation toggles with an Animations selector: Off, Reduced, Default and Expressive. Save mode changes atomically; keep existing defaults and saved motion preferences. Expressive strengthens paint-only interaction and semantic icon motion and lengthens bar transitions without resizing hit targets.
- Add reusable, independent native-control and SVG-symbol motion layers; preserve click/wheel routing, native hit targets and layout bounds.
- Add global motion enable, reduced-motion feedback and validated widget-scoped overrides; keep one-shot effects interruptible and suspend hidden/disabled loops.
- Integrate restrained Bluetooth connection feedback, audio/microphone mute replacement and microphone-in-use breathing; leave ordinary volume adjustments and unrelated icons still.
- Keep two persistent SVG slots for generic fade/scale replacement and use Qt's rotation animator for explicit rotating status.
- Replace open-panel edge underlines with subtle rounded pill backgrounds; add faint hover and combined active/hover feedback through the same reusable state surface. Preserve static feedback when animations are disabled and avoid duplicate module/button highlights.
- Suspend control, pill and semantic motion for fully clipped rail slots; track committed Flickable translation so ongoing effects resume on scroll-back. Add real scroll-out/back, partial-visibility and viewport-boundary regression scenarios.
- Restore subtle pill fills: 5.5% hover, 12% active/open, 16% active + hover, 10% press and 20% active press. Do not treat workspace `focused` as button `active`; preserve native workspace glyphs and transient pointer feedback.
- Share centered pill geometry between controls and open panels: circles for compact icon slots, capsules for wider controls, and minimum horizontal text padding without changing layout or hit targets.

Earlier verification: 62 Node regressions passed; existing and dedicated motion/pill QML/Wayland scenarios passed in isolation; rounded surface inspected. The Qt render-timing run measured 339 frames, p95 frame-work cost rounded to 0 ms at millisecond precision, maximum 15 ms during window orientation reconfiguration. Concurrent UI fixtures conflicted at the settings keyboard scenario; run them sequentially. No broad GPU/compositor latency claim.

Verification: the dedicated QML/Wayland smoke passes workspace-focus exclusion, circular native-size icon pills, padded rounded text controls, centered open-panel geometry, unchanged hit targets/actions, disabled/reduced motion and viewport suspension/resume. The corrected fixture was visually inspected.
The corrected runtime is installed and ready. Real audio-panel circular pills and clock-panel rounded text pills were captured and visually inspected. Workspace focus no longer adds a Prism interaction background; the workspace plugin's own selection marker remains unchanged.

## 1.0.3

- Follow the user's explicit **Simple menu only** choice: ship exactly Appearance, Icons & Text and Widgets for beginner-friendly everyday settings.
- Remove Advanced sections, raw JSON and SVG override/path editors, detailed compatibility/geometry diagnostics and adapter Refresh from the menu; retain backend support for existing saved customizations.
- Keep appearance presets, screen/position/overlap controls, shape/background/opacity/transparency and reduced animations; use a native color picker for custom backgrounds. Keep icon style/size/color and text size without a freeform font editor.
- Use readable widget names and unavailable-entry labels; retain add/move/remove, typed schema configuration, reset confirmation/cancel, disk-save errors and keyboard navigation.
- Update runtime scenarios to exercise ordinary UI saving without clearing saved custom values, while retaining schema, reset, command-entry, disk acknowledgment and backend icon coverage.
- Prevent accidental slider changes while scrolling with a mouse wheel or trackpad; preserve page scrolling and deliberate click/drag/keyboard adjustments.

Verification: 62 Node regressions passed; checkout and installed-resource QML scenarios passed, including wheel-safe page scrolling, deliberate slider click/drag/keyboard changes, native color confirmation/cancellation and saved-customization preservation. Three tabs and the native chooser were visually inspected. Live 1.0.3 activation reported ready; all saved values matched the immediate activation backup. Detailed limits and concurrent-checkout scope are in `REVIEW.md`.

## 1.0.2

- Keep command widgets' self-owned `bar`, `moduleName` and `settings` bindings out of shared property injection; read-only assignments no longer abort adapter observation.
- Extend the actual QML smoke with an `exec` entry: collected JSON text/tooltip/active state, saved command/settings updates and observation cleanup after removal. Command settings retain the existing rebuild-on-edit behavior.

Verification: reproduced the read-only assignment and missing observation before the fix; 61 Node regressions passed; checkout and installed-runtime QML scenarios passed; live 1.0.2 activation reported ready with saved configuration unchanged. Display/hardware limits from 1.0.1 remain unchanged.

## 1.0.1

- Remove development fixture construction and mutating test IPC from production; guard legacy fixture restoration.
- Use luminance/contrast-based foreground selection; preserve usable anchor wings, scroll offsets and clip-aware drag/navigation targets.
- Preserve foreign icon bindings during fallback; reload editable SVG probes and paintings without shared-cache staleness. Keep resolver/layout inputs stable during unrelated appearance changes.
- Split per-screen surfaces, rails, widget slots and command widgets into explicit-controller QML components. Own deferred work with timers that cancel during unload.
- Add semantic/widget-glyph override rows, SVG preview/removal, supported schema-based widget options, advanced geometry controls, repaired-value diagnostics and confirmed atomic appearance/icon resets.
- Route settings to the invoking or focused monitor. Confirm edits against both injected configuration and the disk file; report failed confirmation and permit a real retry despite an earlier memory echo.
- Default to durable runtime-only copies with content-addressed QML entrypoints; retain explicit development links. Validate loaded version/source/readiness before activation succeeds, and preserve unrelated configuration during rollback, including absent/empty first-run states.
- Add user quickstart and host contracts, update product status, and record all 19 remediation outcomes and verification limits in REVIEW.md.

Verification: 61 Node regressions passed; actual QML/Wayland scenarios passed against checkout and installed resources. Live activation, native settings keyboard/visual checks, two virtual outputs (including scale 1.25), and native audio popup routing were exercised. Detailed evidence and hardware limits are in REVIEW.md.
