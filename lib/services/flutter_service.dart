import '../utils/process_runner.dart';

class FlutterService {
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