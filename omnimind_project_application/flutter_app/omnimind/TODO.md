# TODO - Risk level shown on Doctor patient cards

- [ ] Update `DoctorDashboard` patient list tile to not show "NO RISK DATA" when risk can be derived (use `users/{uid}.riskLevel`, else derive from `assessments/{uid}/results/*` fields).
- [ ] Update `DoctorPatientsScreen` patient list tile to show actual risk (remove fallback "NO DATA" behavior).
- [ ] If necessary, fix `FirestoreService.getPatientRiskLevel` to read the correct Firestore collection path used by `PatientDetailPage`.
- [ ] Run Flutter analyze/tests (if available) to ensure no compile errors.

