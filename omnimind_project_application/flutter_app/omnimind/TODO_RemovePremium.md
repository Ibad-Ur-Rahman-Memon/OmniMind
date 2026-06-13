# TODO_RemovePremium

## Plan (approved)
- Remove premium UI widgets and screens:
  - Delete `lib/shared/widgets/premium/*`.
  - Delete `lib/features/dashboard/patient_dashboard_premium.dart`.
- Remove premium code usage:
  - Update `lib/features/auth/login_screen.dart` to use non-premium equivalents (or inline widgets) and remove imports.
  - Update `lib/features/dashboard/patient_home.dart` to stop using `PatientDashboardPremium`.
  - Update any other Dart files that import/remove premium widgets.
- Clean premium docs:
  - Delete any `*Premium*.md` files in `omnimind_project/flutter_app/omnimind/`.

## Steps
1. Delete premium widget files under `lib/shared/widgets/premium/`.
2. Delete `lib/features/dashboard/patient_dashboard_premium.dart`.
3. Edit `lib/features/auth/login_screen.dart` (remove premium imports and widgets; use standard Flutter widgets).
4. Edit `lib/features/dashboard/patient_home.dart` (swap premium dashboard with non-premium one).
5. Delete `*Premium*.md` docs.
6. Run `flutter analyze` / `flutter test` (if available) to ensure compilation.

