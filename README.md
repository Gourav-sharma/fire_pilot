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
