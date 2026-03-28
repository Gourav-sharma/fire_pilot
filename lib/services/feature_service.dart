import '../utils/process_runner.dart';

/// Service for managing Firebase feature activation and deactivation.
class FeatureService {
  /// Enables a specific Firebase [feature] for the project.
  /// 
  /// Supported features: 'auth', 'firestore', 'fcm'.
  /// Some features like 'firestore' require a [projectId] for 
  /// deep-linking to the console.
  Future<void> enable(String feature, {String? projectId}) async {
    final normalized = feature.toLowerCase();

    switch (normalized) {
      case 'auth':
        await _enableAuth();
        break;

      case 'firestore':
        if (projectId == null || projectId.isEmpty) {
          print('❌ Project ID is required for Firestore');
          print('👉 Use setup command or pass projectId properly');
          return;
        }

        await _enableFirestore(projectId);
        break;

      case 'fcm':
        await _enableFCM();
        break;

      default:
        print('❌ Unknown feature: $feature');
        print('👉 Supported: auth, firestore, fcm');
    }
  }

  /// Disables (or provides instructions for disabling) a [feature].
  /// 
  /// Note: Many Firebase features cannot be fully disabled via 
  /// the CLI and require manual action in the Firebase Console.
  Future<void> disable(String feature) async {
    final normalized = feature.toLowerCase();

    print('🚫 Disabling $normalized...\n');

    switch (normalized) {
      case 'auth':
        print('⚠️ Auth cannot be disabled via CLI');
        print('👉 Firebase Console → Authentication → Disable providers');
        break;

      case 'firestore':
        print('⚠️ Firestore cannot be disabled once created');
        break;

      case 'fcm':
        print('⚠️ Remove firebase_messaging from pubspec.yaml');
        break;

      case 'data-connect':
        print('⚠️ Data Connect cannot be disabled via CLI');
        print('👉 Firebase Console → Data Connect → Disable manually');
        break;

      default:
        print('⚠️ Unknown feature: $feature');
        print('👉 Try: auth, firestore, fcm, data-connect');
    }
  }

  // =============================
  // PRIVATE IMPLEMENTATIONS
  // =============================

  Future<void> _enableAuth() async {
    print('🔐 Enabling Firebase Auth...\n');
    print('👉 Firebase Console → Authentication → Enable providers');
  }

  Future<void> _enableFirestore(String projectId) async {
    print('🗄️ Enabling Firestore...\n');

    final url =
        'https://console.firebase.google.com/project/$projectId/firestore';

    print('🌐 Opening Firestore Console...');
    print(url);
    await openUrl(url);

    print('\n👉 Steps:');
    print('1. Click "Create Database"');
    print('2. Select region');
  }

  Future<void> _enableFCM() async {
    print('🔔 Setting up FCM...\n');
    print('👉 Add firebase_messaging package');
    print('👉 Configure Android & iOS permissions');
  }
}