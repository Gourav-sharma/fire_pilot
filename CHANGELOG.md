# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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