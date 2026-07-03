# 🚀 FirePilot

**FirePilot** is the elite command-line companion for Flutter developers who want to skip the frustration of Firebase setup. It's a "one-click" orchestrator that automates everything from Node.js installation to SHA key registration.

---

## 🔥 Why FirePilot?

The official Firebase CLI is powerful, but it requires many manual steps. **FirePilot** bridges the gap by automating the boring parts:

- **🛠️ Self-Healing Environment**: Automatically detects and installs Node.js/NPM (via Winget on Windows or Homebrew on macOS).
- **💉 Smart PATH Injection**: No terminal restarts required. Newly installed tools work instantly.
- **👥 Multi-Account Support**: Effortlessly switch between multiple client Google accounts directly from an interactive menu.
- **🔑 Automatic SHA Extraction**: Automatically finds and registers SHA-1 and SHA-256 certificates for your Android apps.
- **🛰️ Intelligent Orchestration**: Combines Firebase project creation, FlutterFire configuration, and dependency setup into a single flow.
- **🔍 Real-Time Diagnostics**: Interactive error reporting that actually tells you *why* a project creation failed (e.g., Quota exceeded).

---

## 🚀 Usage

Activate FirePilot globally using Dart:

```bash
dart pub global activate fire_pilot
```

### Usage

Run the full setup wizard inside your Flutter project:

```bash
fire_pilot firebase setup --full
```

### Available Commands

| Command | Description |
|---------|-------------|
| `firebase setup --full` | The complete "Pilot" experience: Tools -> Login -> Project -> FlutterFire -> Deps -> SHA. |
| `firebase sha add` | Automatically extract and add SHA keys to your Firebase project. |
| `firebase login` | Manage and switch between multiple Google accounts. |
| `firebase enable <feature>` | Quickly enable Firebase features (auth, firestore, etc). |
| `firebase force-update` | Generate a Remote Config Force Update service and UI Dialogs. |

### 🚀 Firebase Force Update Setup

Setting up a force-update or optional-update mechanism is as simple as running:

```bash
fire_pilot firebase force-update --path=lib/services/remote_config_service.dart
```

This command will:
1. Add necessary dependencies (`firebase_remote_config`, `package_info_plus`, and `url_launcher`) to your `pubspec.yaml`.
2. Generate a ready-to-use `RemoteConfigService` class at the specified path.
3. Auto-generate premium, beautiful dialogs (`ForceUpdateDialog` and `OptionalUpdateDialog`) inside `update_dialogs.dart` in the same directory.

#### 🛰️ Firebase Console Setup
In your Firebase Console, navigate to **Remote Config** and add the following parameters:

| Parameter Key            | Type | Default Value | Description |
|--------------------------|---|---|---|
| `is_force_update`        | Boolean | `false` | If `true`, all users with an app version below the latest version (`current_version`) will be forced to update. |
| `min_version_android`    | String | `1.0.0` | The minimum required Android version. Users below this version are always forced to update (even if `is_force_update` is `false`). |
| `min_version_ios`        | String | `1.0.0` | The minimum required iOS version. Users below this version are always forced to update (even if `is_force_update` is `false`). |
| `latest_version_android` | String | `1.0.0` | The latest available Android version. Triggers force update if `is_force_update` is `true`, otherwise triggers optional update for older versions. |
| `latest_version_ios`     | String | `1.0.0` | The latest available iOS version. Triggers force update if `is_force_update` is `true`, otherwise triggers optional update for older versions. |
| `store_url_android`      | String | `https://play.google.com/store/apps/details?id=your.package` | Play Store URL of your app. |
| `store_url_ios`          | String | `https://apps.apple.com/app/idyour-app-id` | App Store URL of your app. |

#### 💻 Integration Code Snippet
To use the generated service in your Flutter application:

1. **Initialize in `main.dart`**:
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     
     // Initialize the RemoteConfigService
     final remoteConfig = RemoteConfigService();
     await remoteConfig.initialize();
     
     runApp(const MyApp());
   }
   ```

2. **Trigger Dialog Checks on App Launch**:
   Call the dialog trigger inside the `initState` of your main screen widget (e.g., `HomeScreen` or `MyHomePage`, **not** in the root `MyApp` widget, since the context needs to be a descendant of `MaterialApp` to access the navigator and localizations):
   ```dart
   @override
   void initState() {
     super.initState();
     WidgetsBinding.instance.addPostFrameCallback((_) {
       // Automatically checks configuration and shows the correct dialog
       RemoteConfigService().checkAndShowUpdateDialog(context);
     });
   }
   ```

#### 🧪 Testing Force Updates (QA & Development)

To safely test the Force/Optional update popups with your QA team or developers without impacting live production users (if you share the same Firebase Project), you can use custom **Firebase User Properties**:

1. **Add Firebase Analytics**: Ensure `firebase_analytics` is set up in your Flutter project.
2. **Set User Property on QA Devices**: Set a custom property (e.g., `app_environment` = `qa`) on devices used by developers or QA testers. This can be enabled dynamically (e.g., using `kDebugMode` or an environment flag):
   ```dart
   import 'package:firebase_analytics/firebase_analytics.dart';

   await FirebaseAnalytics.instance.setUserProperty(
     name: 'app_environment',
     value: 'qa',
   );
   ```
3. **Configure Remote Config Values**:
   - Go to your Firebase Console under **Remote Config**.
   - Edit the parameter you want to test (e.g., `is_force_update` or `min_version_android`).
   - Click **Add value for condition** -> **Create new condition**.
   - Define a condition (e.g., "QA Testers") based on **User Property** where `app_environment` matches `qa`.
   - Set the overridden values for this condition (e.g. `is_force_update = true`).
   - Save and publish. Only devices with the `app_environment` user property set to `qa` will receive the overridden values.

---

## 🛠️ Required Tools
FirePilot is smart enough to help you install these if they are missing:
*   Flutter & Dart SDK
*   Node.js & NPM
*   Firebase CLI
*   FlutterFire CLI

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing
Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/your-repo/fire_pilot/issues).

**Made with ❤️ for the Flutter community.**
