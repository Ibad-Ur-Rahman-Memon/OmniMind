# TODO_fix_bottomnav_glow

## Goal
Remove unwanted blue glow/line at bottom-right of navigation bar while keeping selected tab styling and clean rounded corners across platforms.

## Info gathered
- Navigation bar is implemented as a custom `_FloatingNav` widget in `lib/features/dashboard/patient_home.dart`.
- `_FloatingNav` uses:
  - `ClipRRect(borderRadius: 28)`
  - `BackdropFilter`
  - `Container` with `boxShadow` (two shadows) and `borderRadius: 28`
  - interactive items using `GestureDetector` (no InkWell).

## Plan (code changes)
1. In `patient_home.dart`, wrap the nav in an additional clipping layer to ensure shadows/overdraw do not bleed.
2. Reduce/adjust the top shadow and/or remove any shadow that produces blue artifacts near edges.
3. Ensure `SafeArea` padding/margins don’t create an unclipped region at bottom-right by:
   - applying `clipBehavior` / clipping at the outermost level.
   - verifying `Padding(bottom: 12)` doesn’t expose outside pixels.
4. Re-run the Flutter app in the same layout(s) where the artifact appears.

## Follow-up steps
- Hot reload and visually confirm no blue line/glow artifact at bottom-right edge.
- Smoke test switching tabs (selected indicator should remain correct).
- Test on desktop/web/mobile if available.

