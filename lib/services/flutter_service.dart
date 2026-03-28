import '../utils/process_runner.dart';

/// Service for managing Flutter-specific dependencies and commands.
class FlutterService {
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
}