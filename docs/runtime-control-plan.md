# Runtime Control Plan

This document defines the recommended split between:

- `Firestore-backed runtime controls` for security-enforced gating
- `Firebase Remote Config` for client UX/config behavior

## Short Answer

Yes. The `system/runtime` document should live in Firestore and be separate from Remote Config.

They solve different problems:

- `Firestore runtime controls` are for values that must be enforceable in Firestore Security Rules.
- `Remote Config` is for app behavior and messaging that the client should react to without an app release.

Use both together.

## Recommended Split

### Firestore `system/runtime`

Use Firestore for flags that should be enforceable at the database layer:

- `writes_disabled`
- `signups_disabled`
- `maintenance_mode`

These values can be read by Firestore Security Rules via `get(...)`.

Recommended document:

- Collection: `system`
- Document: `runtime`

Example shape:

```json
{
  "writes_disabled": false,
  "signups_disabled": false,
  "maintenance_mode": false,
  "updated_at": "server timestamp",
  "updated_by": "admin uid or email",
  "message_key": "maintenance_default"
}
```

Notes:

- Keep this document admin-owned only.
- Do not let client code write this document.
- Keep the schema small and stable so rules stay simple.

### Firestore `system/blockedUsers`

If we later want a Firestore-backed blocklist in addition to disabling Firebase Auth users, use:

- Collection: `system/blockedUsers/items`
- Document id: user uid

Example shape:

```json
{
  "reason": "abuse",
  "blocked_at": "server timestamp",
  "blocked_by": "admin uid or email"
}
```

This can be checked in rules with `exists(...)`.

In practice, disabling the Firebase Auth user should still be the first response for an abusive account.

### Firebase Remote Config

Use Remote Config for app behavior, UX, and messaging:

- `app_disabled`
- `app_disabled_message`
- `min_supported_build`
  Uses `CFBundleVersion` (build number), not `CFBundleShortVersionString` / marketing version.
- `force_update_message`
- `writes_disabled_message`
- `signups_disabled_message`

These should drive:

- global banners
- blocking overlays
- force-update UI
- disabled buttons/forms

Remote Config is not a security boundary. It is a client control plane.

## How They Work Together

Example emergency write shutdown:

1. Set `system/runtime.writes_disabled = true`
2. Firestore rules reject new writes
3. Set Remote Config `writes_disabled_message`
4. App shows message and disables write UI

This gives both:

- real backend enforcement
- good user-facing behavior

## Firestore Rules Pattern

Conceptual Firestore Security Rules pattern:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function isSignedIn() {
      return request.auth != null;
    }

    function runtimeConfig() {
      return get(/databases/$(database)/documents/system/runtime);
    }

    function writesEnabled() {
      return !runtimeConfig().data.writes_disabled;
    }

    function userIsBlocked() {
      return exists(/databases/$(database)/documents/system/blockedUsers/items/$(request.auth.uid));
    }

    function userCanWrite(targetUid) {
      return isSignedIn()
        && request.auth.uid == targetUid
        && writesEnabled()
        && !userIsBlocked();
    }

    match /users/{userId} {
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow write: if userCanWrite(userId);
    }

    match /users/{userId}/{document=**} {
      allow read: if isSignedIn() && request.auth.uid == userId;
      allow write: if userCanWrite(userId);
    }

    match /system/{document=**} {
      allow read: if false;
      allow write: if false;
    }
  }
}
```

Adjust collection paths to match the app's actual Firestore layout.

## Operational Guidance

### If abuse is happening

Recommended response order:

1. Disable the abusive Firebase Auth user
2. If broader abuse is happening, set `system/runtime.writes_disabled = true`
3. Publish a Remote Config message explaining temporary limited functionality
4. Tighten rules or rollout App Check enforcement if not already enabled

### If signup abuse is happening

Recommended response order:

1. Set Remote Config `signup_disabled` / message for the client
2. Enforce signup shutdown in backend signup controls later if needed
3. Add Auth blocking logic once abuse patterns are better understood

## Recommendation For This Repo

Implement in this order:

1. Add Firestore rules support for `system/runtime.writes_disabled`
2. Add a minimal runtime control service in the app that reads client-safe state
3. Add Remote Config for messaging and force-update UX
4. Add per-user blocking with Firebase Auth disable and optional blocked-user rules check

The Firestore runtime doc and Remote Config should remain separate.
