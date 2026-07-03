# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2026-07-03

### 🚀 Firebase Force Update Fixes

- **Corrected Force/Optional Update Logic**: Modified the generated template to compare the local app version (retrieved via `package_info_plus`) against remote config version parameters (`min_version` and `current_version`).
- **Dependency & Import Fixes**: Restored `package_info_plus` automatic dependency addition and imports in the generated service template.
- **Improved Dialog Triggering Rules**:
  - If `is_force_update` is `false`, users on dangerously old versions (below `min_version`) are still forced to update.
  - If `is_force_update` is `true`, all users below `current_version` are forced to update.

## [1.0.4] - 2026-06-16

### 🚀 Firebase Force Update Enhancements

- **Fully Remote Version Checks**: Modified the `firebase force-update` code templates to fetch the current version from Remote Config (`current_version_android` / `current_version_ios`), making the entire update mechanism configurable from the cloud.
- **Removed local dependencies**: Removed `package_info_plus` dependency checks and import generation from the generator template.
- **Duplicate Checking Safeguard**: Added a static variable safeguard (`_hasCheckedUpdate`) inside the generated `RemoteConfigService` class template to prevent duplicate dialog popups when running within build methods.
- **Documentation**: Updated the `README.md` to cover setup instructions for the new Remote Config variables.

## [1.0.3] - 2026-06-15

### 🛠️ FlutterFire & Project Creation Fixes

- **Enhanced Interactivity**: Users are now prompted to choose which platforms (Windows, macOS) and features (Auth, FCM) to enable during setup, giving full control over the project footprint.
- **Improved Dependency Management**: Only core dependencies are added by default; optional features now add their own packages individually.
- **Strict ID Enforcement**: The tool now stops immediately if a project ID is already taken in the user's console or globally, preventing redundant or incorrect configurations.

### 🚀 Firebase Force Update

- **Force Update Command**: Added the `firebase force-update` command to automate setting up force and optional update dialogs. This automatically adds required dependencies (`firebase_remote_config`, `package_info_plus`, `url_launcher`), creates a `RemoteConfigService` wrapper, and generates premium customizable update dialogs.

## [1.0.2] - 2026-04-03

### 🛠️ Process Execution & Interactivity Fix

- **Interactive Run**: Switched the default `run` behavior to use `inheritStdio`. This fixes hangs during version checks and allows users to respond to interactive prompts (like `flutterfire` update checks) in real-time.
- **Improved Tool Installation**: Updated tool installation methods (npm, flutterfire) to use the interactive run, providing better visibility and manual error handling.

## [1.0.1] - 2026-03-28

### 🚀 Pub.dev Optimization & Documentation

- **Update Documentation**: Added library-level documentation and doc comments for all missing constructors and symbols.
- **Improved Metadata**: Shortened package description to optimal length (126 chars) for better search engine indexing.
- **Added Example**: Created a functional `example/main.dart` demonstrating programmatic usage of the Firebase orchestrator.
- **Code Cleanup**: Removed unused imports and refined internal service documentation.

## [1.0.0] - 2026-03-28

### ✨ Initial Release (Rebranded as FirePilot)

- **Complete Rebranding**: Project officially renamed from `my_cli` to `FirePilot`.
- **Automatic Prerequisites**: Added support for auto-installing Node.js via `winget` (Windows) and `homebrew` (macOS).
- **Environment Injection**: Implemented real-time `PATH` injection to allow tool usage without terminal restarts.
- **Multi-Account Support**: Added an interactive system to manage and switch between multiple Google accounts.
- **Forced Re-auth**: Optimized the "Add Account" flow to bypass sticky browser sessions using `--reauth` and session clearing.
- **SHA-256 Support**: Improved certificate extraction to handle both SHA-1 and SHA-256 for Android apps.
- **Resilient Config**: Added exponential backoff and retry logic for `flutterfire configure` to handle API propagation delays.
- **Cross-Platform Audit**: Verified 100% compatibility across Windows and macOS environments.
- **Real-time Diagnostics**: Switched critical steps to interactive mode for better error visibility (e.g., Quota limits).