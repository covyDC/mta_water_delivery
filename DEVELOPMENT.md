# Development & Production Deployment Guide

This document summarizes commands and steps to run the app locally using Firebase emulators, and how to prepare and deploy to the production Firebase project.

---

## Local development (recommended)

1. Install prerequisites:

```powershell
# Node and npm for Firebase CLI
npm install -g firebase-tools
# If using the admin script, install node deps in tools/
cd tools
npm install
cd ..
```

2. Start Firebase emulators (Auth + Firestore):

```powershell
cd 'C:\COVY\mta_water_delivery'
firebase emulators:start --only firestore,auth

Note: the Firestore emulator requires Java (JRE/JDK 11+) installed on your machine.
On Windows install a JDK (Temurin or OpenJDK are fine) and make sure `java -version` works before starting emulators.

Alternatively you can start the emulators from the repository's emulator-only config
which avoids firebase.json validation issues introduced by unrelated keys:

```powershell
firebase emulators:start --config firebase.emulators.json --only functions,firestore,auth
```
```

The Emulator UI will usually be available at http://localhost:4000.

3. Run the Flutter app in debug mode (emulator wiring is enabled in debug builds):

```powershell
flutter run -d chrome
```

4. Use the `DB Debug (dev)` button from the app's Login page to run connectivity checks, create/delete test users, and exercise flows.

5. Test authentication and database flows using the test users created by the debug page:

- admin@test.local / password
- staff@test.local / password
- driver@test.local / password
- customer@test.local / password

To seed the emulators quickly with test accounts and documents run (with emulators running):

```powershell
# from project root
$env:FIRESTORE_EMULATOR_HOST='localhost:8080'; $env:FIREBASE_AUTH_EMULATOR_HOST='localhost:9099'; cd tools; npm run seed-emulator
```

---

## Create a production admin account (recommended approach)

There are two safe options to create a production admin user and the associated Firestore `users/{uid}` document.

Option A — Console (manual)

1. Firebase Console → Authentication → Add user (set email & password).
2. Firebase Console → Firestore → Create document in `users` collection with the newly created user's UID and the following fields:

```json
{
  "role": "admin",
  "email": "admin@yourdomain.com",
  "createdAt": FieldValue.serverTimestamp()
}
```

Option B — Script (programmatic) — useful for automation

1. Create a service account JSON from Firebase Console → Project Settings → Service accounts → Generate new private key.
2. On your machine set the environment variable `GOOGLE_APPLICATION_CREDENTIALS` to the path of that JSON.
3. Run the Node script included in `tools/create_admin.js`:

```powershell
cd tools
npm install
# set GOOGLE_APPLICATION_CREDENTIALS to service account json path
node create_admin.js admin@yourdomain.com 'SecureP@ssw0rd'
```

This script will create the auth user and add a `users/{uid}` document with `role: 'admin'`.

---

## Deploy Firestore rules and indexes

To publish the rules included in the repository:

```powershell
cd 'C:\COVY\mta_water_delivery'
# Deploy only rules
firebase deploy --only firestore:rules
# Deploy indexes if you add firestore.indexes.json
firebase deploy --only firestore:indexes
```

**Important:** Review `firestore.rules` carefully before deploying to production. Use the Rules Simulator and test common reads/writes with non-admin accounts.

---

## Deploy Storage rules

If you use Firebase Storage, add or review `storage.rules` and deploy them with:

```powershell
firebase deploy --only storage
```

---

## Deploy Cloud Functions

If your project has `functions/`, configure any function environment variables:

```powershell
firebase functions:config:set someservice.key="VALUE"
```

Deploy functions:

```powershell
firebase deploy --only functions
```

---

## CI/CD (sample)

This repo includes a sample GitHub Actions workflow `.github/workflows/firebase-deploy.yml`. You must set a `FIREBASE_TOKEN` secret to allow CI to deploy. Generate it locally with:

```powershell
firebase login:ci
# copy the token and store it in GitHub Actions secrets as FIREBASE_TOKEN
```

---

## Production checklist (quick)

- [ ] Enable Email/Password and Google sign-in in Firebase Console ↦ Authentication ↦ Sign-in method.
- [ ] Upload `google-services.json` / `GoogleService-Info.plist` for Android/iOS and configure web OAuth client.
- [ ] Deploy `firestore.rules` and `storage.rules`.
- [ ] Create an admin account and a `users/{uid}` document with `role: 'admin'`.
- [ ] Enable billing if required by Cloud Functions or high-volume Firestore.
- [ ] Test all dashboards (Customer, Driver, Staff, Admin) with appropriate accounts.

---

If you want, I can add the CI secrets and run a deployment for you, but I need a `FIREBASE_TOKEN` or service account credentials — these must be supplied by you since they are secret.
