# TODO - Fix Doctor Patient Dashboard Reappearing Patients

## Problem
When a doctor removes a patient and the patient logs in again and chats, the patient appears missing/incorrectly in doctor dashboard.

## Current findings
- Doctor list was previously pulling *all* users with `role == patient`.
- `removePatientData()` deletes the patient user document, but if patient re-creates/returns later, the doctor list logic must prevent reappearance unless reassigned.

## Fix implemented
- Updated `AuthService.getDoctorPatients(doctorUid)` to return only patients assigned to the doctor:
  - Reads `doctors/{doctorUid}/patientAssignments/{patientUid}`
  - Filters `active == true`
  - Fetches corresponding patient profiles from `users`.

## Next steps (if needed)
- Ensure doctor assignment documents exist in Firestore with fields:
  - `active: true`
- Ensure doctor removal sets that assignment to inactive (instead of only deleting user data), if you want removal to persist while allowing patient app access.
- Run app and verify:
  1) Removed patient does NOT show on doctor dashboard after re-login.
  2) Newly assigned patients show correctly.

