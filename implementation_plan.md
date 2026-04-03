# Implementation Plan - Supercharging Firebase Feature Enablement

Currently, the `fire_pilot firebase enable <feature>` command only prints instructions. This plan upgrades it to be truly "Elite" by automatically adding dependencies and opening the specific Firebase Console page for your project.

## User Review Required

> [!IMPORTANT]
> - **Dependency Management**: Enabling a feature will now automatically run `flutter pub add`, which modifies your `pubspec.yaml` and runs `pub get`.
> - **Browser Interaction**: FirePilot will attempt to open your default browser to the relevant Firebase Console page. This requires the `projectId` to be correctly detected from your `firebase.json`.

## Proposed Changes

### 🔧 Flutter Service Enhancements

#### [MODIFY] [flutter_service.dart](file:///d:/MyAndroidStudioProjects/plugins/my_cli_firebase_elite/my_cli_firebase_elite/lib/services/flutter_service.dart)
- Add a new `addDep(String package)` method to handle single-package installations.

### 🚀 Feature Service Upgrades

#### [MODIFY] [feature_service.dart](file:///d:/MyAndroidStudioProjects/plugins/my_cli_firebase_elite/my_cli_firebase_elite/lib/services/feature_service.dart)

- **Update `enable` entry point**: Ensure `projectId` is passed to all internal handlers.
- **`_enableAuth(String? projectId)`**:
    - Add `firebase_auth` dependency.
    - If `projectId` is found, open the Authentication console URL.
- **`_enableFCM(String? projectId)`**:
    - Add `firebase_messaging` dependency.
    - If `projectId` is found, open the Messaging/Cloud Messaging console URL.
- **`_enableFirestore(String? projectId)`**:
    - Add `cloud_firestore` dependency.
    - Open the Firestore console URL.

## Open Questions

- **Manual Configuration**: For features like FCM, additional platform-specific setup (e.g., `google-services.json` updates or `AppDelegate` changes) is still required. Should we add reminder prints for these steps? (Recommendation: Yes, let's provide clear \"Next Steps\" after the dependency is added).

## Verification Plan

### Manual Verification
1.  **Test Auth**: Run `fire_pilot firebase enable auth`. Verify `firebase_auth` is in `pubspec.yaml` and the browser opens the correct URL.
2.  **Test FCM**: Run `fire_pilot firebase enable fcm`. Verify `firebase_messaging` is added and the Messaging console opens.
3.  **Test Firestore**: Run `fire_pilot firebase enable firestore`. Verify `cloud_firestore` is added and the Firestore console opens.
