# Doctor side empty list fix (Dashboard / Patients)

## Symptom
Doctor screens show empty content.

## Investigation
`AuthService.getDoctorPatients(doctorUid)` is currently reading doctor assignments from:
- `doctors/{doctorUid}/patientAssignments/{patientUid}`
- field: `active` (missing treated as active)

If your database uses a different path/field for assignments, the stream returns `[]`.

## What to do next
1. Confirm the Firestore assignment structure in your project:
   - Where are patient assignments stored?
   - What is the doctorUid field/path?
   - Is there an `active` boolean?

2. After you confirm, update `getDoctorPatients` accordingly.

## Candidate alternatives (pick the one that matches your DB)
A) Relationship stored under patient documents (e.g. `users/{patientUid}` has `doctorUid`)
B) Relationship stored under doctors but with a different collection name/shape
C) Relationship stored under another top-level collection (e.g. `patientDoctors`, `assignments`, etc.)

## Implementation target file
- `lib/core/services/auth_service.dart`
  - function: `Stream<List<AppUser>> getDoctorPatients(String doctorUid)`

