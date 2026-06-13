# Fix: assessment_screen.dart compile errors

## Current state
`lib/features/assessments/assessment_screen.dart` has major syntax/structure issues leading to many downstream errors.

## Primary fixes to apply
1. Remove/replace the corrupted duplicated section that starts around line ~250 with invalid braces.
2. Ensure `AssessmentQuestion` in `lib/core/models/models.dart` has a `toMap()` method (currently missing).
3. Ensure `AssessmentScreen` only defines one `build` and no extra stray `@override`/methods after widget tree.
4. After syntax is clean, re-run `flutter analyze` and `flutter run -d chrome`.

## Secondary
- `RiskEngine` import/usage if required for UI.
- Keep widgets non-const where appropriate.

