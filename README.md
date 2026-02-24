# nurturing_institute_mvp

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Bulk import clients from CSV

You can bulk-import clients by uploading a CSV file to Cloud Storage under the path `imports/{uid}/`. A Cloud Function (`importClientsCsv`) will parse the file and write to `users/{uid}/clients`.

Steps:

1. Deploy functions (first time or after changes):
	- Requires Firebase CLI logged-in and project set.
	- Install and deploy from the root:
	  - `npm --prefix functions install`
	  - `npm --prefix functions run deploy`

2. Prepare your CSV:
	- Use `functions/CLIENTS_IMPORT_TEMPLATE.csv` as a guide.
	- Supported headers (case-insensitive): `ID, First Name, Last Name, Gender, DOB, Email, Phone, Occupation, Description`.
	- If `ID` is omitted, the importer assigns sequential IDs after the current max.

3. Upload to Cloud Storage:
	- Upload to `imports/{uid}/yourfile.csv` (replace `{uid}` with the target Firebase Auth user’s UID).
	- The function will import rows in batches and move the file to `imports/{uid}/processed/` after completion.
	- A log entry will be written to `users/{uid}/import_logs` with counts and timestamp.

Notes:
- The importer uses Firestore writes with `merge: true` so existing docs update.
- Max batch size is respected by committing chunks of ~400 writes.
- Recommended date format: `yyyy-MM-dd` for DOB.
