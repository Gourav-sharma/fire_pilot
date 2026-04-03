/// Documentation for the feature service library.
library feature_service;

import '../utils/process_runner.dart';
import 'flutter_service.dart';

/// Service for managing Firebase feature activation and deactivation.
class FeatureService {
  /// Default constructor for [FeatureService].
  FeatureService();

  /// Enables a specific Firebase [feature] for the project.
  /// 
  /// Supported features: 'auth', 'firestore', 'fcm'.
  /// Some features like 'firestore' require a [projectId] for 
  /// deep-linking to the console.
  Future<void> enable(String feature, {String? projectId}) async {
    final normalized = feature.toLowerCase();

    switch (normalized) {
      case 'auth':
        await _enableAuth(projectId);
        break;

      case 'firestore':
        await _enableFirestore(projectId);
        break;

      case 'fcm':
        await _enableFCM(projectId);
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

  Future<void> _enableAuth(String? projectId) async {
    print('🔐 Enabling Firebase Auth...\n');
    
    // 1. Add dependency
    await FlutterService().addDep('firebase_auth');

    // 2. Open Console
    if (projectId != null) {
      final url = 'https://console.firebase.google.com/project/$projectId/authentication';
      print('🌐 Opening Authentication Console...');
      print(url);
      await openUrl(url);
    }

    print('\n✅ Project set up with firebase_auth');
    print('👉 Next Step: Enable providers (Google, Email) in the Console.');
  }

  Future<void> _enableFirestore(String? projectId) async {
    print('🗄️ Enabling Firestore...\n');

    // 1. Add dependency
    await FlutterService().addDep('cloud_firestore');

    // 2. Attempt CLI creation
    if (projectId != null) {
      try {
        print('🚀 Initializing Firestore Database for $projectId...');
        await run('firebase', [
          'firestore:databases:create',
          '--project=$projectId',
          '--location=us-central1'
        ]);
      } catch (e) {
        print('⚠️ Automatic DB creation skipped (It might already exist)');
      }

      final url = 'https://console.firebase.google.com/project/$projectId/firestore';
      print('\n🌐 Opening Firestore Console...');
      print(url);
      await openUrl(url);
    } else {
      print('❌ Project ID missing. Unable to create database via CLI.');
    }

    print('\n✅ Project set up with cloud_firestore');
  }

  Future<void> _enableFCM(String? projectId) async {
    print('🔔 Setting up FCM...\n');

    // 1. Add dependency
    await FlutterService().addDep('firebase_messaging');

    // 2. Open Console
    if (projectId != null) {
      final url = 'https://console.firebase.google.com/project/$projectId/messaging';
      print('🌐 Opening Cloud Messaging Console...');
      print(url);
      await openUrl(url);
    }

    print('\n✅ Project set up with firebase_messaging');
    print('👉 Next Step (iOS): Add "Push Notifications" and "Background Modes" in Xcode.');
    print('👉 Next Step (Android): No additional config usually needed for core messaging.');
  }
}