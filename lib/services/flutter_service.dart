/// Documentation for the Flutter service library.
library flutter_service;

import '../utils/process_runner.dart';

/// Service for managing Flutter-specific dependencies and commands.
class FlutterService {
  /// Default constructor for [FlutterService].
  FlutterService();

  /// Adds core Firebase and FlutterFire dependencies to the project.
  Future<void> addDeps() async {
    await run('flutter', [
      'pub',
      'add',
      'firebase_core',
      'firebase_auth',
      'cloud_firestore',
      'firebase_messaging'
    ]);
  }

  /// Adds a single dependency to the project.
  Future<void> addDep(String package) async {
    print('📦 Installing $package...');
    await run('flutter', ['pub', 'add', package]);
  }
}