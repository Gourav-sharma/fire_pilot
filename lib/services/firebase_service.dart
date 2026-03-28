/// Documentation for the Firebase service library.
library firebase_service;

import 'dart:convert';
import 'dart:io';
import 'package:fire_pilot/services/prompt_service.dart';

import '../utils/process_runner.dart';

/// {@template firebase_service}
/// Service for managing Firebase CLI operations such as login, 
/// project creation, and SHA registration.
/// 
/// This service provides an abstraction over common Firebase CLI 
/// commands and handles complex multi-account switching logic.
/// {@endtemplate}
class FirebaseService {
  /// Default constructor for [FirebaseService].
  FirebaseService();

  /// Ensures the user is logged into Firebase and prompts for account 
  /// selection if multiple accounts are available.
  /// 
  /// This method provides:
  /// * Interactive account selection.
  /// * Support for adding new accounts (`--reauth` flow).
  /// * Account switching with automatic session cleanup.
  /// * Logout functionality.
  Future<void> login() async {
    print('🔐 Checking Firebase account...\n');

    try {
      final result = await runWithResult('firebase', ['login:list']);
      final output = result.stdout.toString() + result.stderr.toString();

      final emailRegex =
          RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
      final lines = output.split('\n');
      final allAccounts = <String>[];
      String? currentAccount;

      for (var line in lines) {
        final match = emailRegex.firstMatch(line);
        if (match != null) {
          final email = match.group(0)!;
          if (!allAccounts.contains(email)) {
            allAccounts.add(email);
          }
          // Firebase CLI marks active account with * or (current)
          // Or if it just says "Logged in as email"
          if (line.contains('*') ||
              line.contains('(current)') ||
              line.contains('Logged in as $email')) {
            currentAccount = email;
          }
        }
      }

      // Fallback: If only one account exists, it must be the current one
      if (allAccounts.length == 1 && currentAccount == null) {
        currentAccount = allAccounts.first;
      }

      // If no accounts, need to log in
      if (allAccounts.isEmpty) {
        print('❌ No Firebase accounts found');
        print('📦 Triggering interactive login...\n');
        await runInteractive('firebase', ['login']);
        return;
      }

      // If we have accounts, ask which one to use
      final prompt = PromptService();
      final options = [
        ...allAccounts,
        '+ Add a new account',
        '❌ Logout from active account'
      ];

      print('👤 Currently logged in accounts:');
      for (int i = 0; i < allAccounts.length; i++) {
        final isCurrent = allAccounts[i] == currentAccount;
        print('  ${i + 1}. ${allAccounts[i]} ${isCurrent ? "⭐️ (active)" : ""}');
      }
      print('');

      final index =
          prompt.select('Select Google account to use for this project', options);

      if (index == allAccounts.length) {
        // Add new account
        print('📦 Adding new account...\n');
        
        // 🔥 CRITICAL: Logout from current to prevent the "login_hint" in URL
        if (currentAccount != null) {
          print('🧹 Clearing current session hint ($currentAccount)...');
          await run('firebase', ['logout', currentAccount]);
        }

        print('🔄 Opening browser for fresh login...\n');
        await runInteractive('firebase', ['login']);

        // Refresh the check to show the new account list
        print('\n🔄 Refreshing account list...');
        await login();
        return;
      } else if (index == allAccounts.length + 1) {
        // Logout
        if (currentAccount != null) {
          print('🚫 Logging out from $currentAccount...\n');
          await run('firebase', ['logout', currentAccount]);
          print('✅ Logged out successfully');
          await login(); // Refresh
          return;
        } else {
          print('🚫 Logging out from all accounts...\n');
          await run('firebase', ['logout']);
          await login();
          return;
        }
      } else {
        final selectedEmail = allAccounts[index];
        if (selectedEmail != currentAccount) {
          print('🔄 Switching to account: $selectedEmail...\n');
          print('⚠️ Switching requires logging out of $currentAccount first.');
          
          if (currentAccount != null) {
             await run('firebase', ['logout', currentAccount]);
          }
          
          print('📦 Now please log in to $selectedEmail in the browser...\n');
          await runInteractive('firebase', ['login']);
          
          await login(); // Re-verify to confirm switch worked
          return;
        } else {
          print('✅ Using active account: $selectedEmail');
        }
      }

    } catch (e) {
      print('❌ Firebase account check failed');
      rethrow;
    }
  }

  /// Creates a new Firebase project with the given [id].
  /// 
  /// This command runs in [ProcessStartMode.inheritStdio] mode to 
  /// allow for interactive project name entry and real-time feedback.
  Future<void> createProject(String id) async {
    await runInteractive('firebase', ['projects:create', id]);
  }

  /// Lists all Firebase projects associated with the currently 
  /// authenticated account.
  Future<void> listProjects() async {
    await run('firebase', ['projects:list']);
  }

  /// Configures FlutterFire for the current project using the 
  /// provided [projectId].
  /// 
  /// Includes exponential backoff retry logic to handle cases where 
  /// a newly created project's API hasn't propagated across Google's 
  /// backend yet.
  Future<void> configure(String projectId) async {
    print('⚙️ Configuring FlutterFire...');

    try {
      await run('flutterfire', ['--version']);
    } catch (e) {
      print('❌ FlutterFire CLI not installed');
      print('👉 Run: dart pub global activate flutterfire_cli');
      rethrow;
    }

    int retryCount = 0;
    const maxRetries = 5;

    while (retryCount < maxRetries) {
      try {
        if (retryCount > 0) {
          final delay = retryCount * 5;
          print('⏳ Waiting $delay seconds for Firebase project to propagate...');
          await Future.delayed(Duration(seconds: delay));
          print('🔄 Retrying configuration (Attempt ${retryCount + 1}/$maxRetries)...');
        }

        await run('flutterfire', [
          'configure',
          '--project=$projectId',
          '--yes',
        ]);
        return; // Success
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          print('❌ FlutterFire configuration failed after $maxRetries attempts');
          rethrow;
        }
      }
    }
  }

  // =====================================================
  // 🔑 SHA HANDLING (UPDATED)
  // =====================================================

  /// 🔥 Extract both SHA-1 & SHA-256
  Future<Map<String, String>> _extractShas() async {
    final cmd = Platform.isWindows ? 'gradlew.bat' : './gradlew';

    final result = await Process.run(
      cmd,
      ['signingReport'],
      workingDirectory: 'android',
      runInShell: true,
      environment: getInjectedEnvironment(),
    );

    final output = result.stdout.toString();

    String? sha1;
    String? sha256;

    final lines = output.split('\n');

    final sha1Regex = RegExp(r'SHA1:\s+([A-F0-9:]+)', caseSensitive: false);
    final sha256Regex = RegExp(r'SHA-?256:\s+([A-F0-9:]+)', caseSensitive: false);

    for (var line in lines) {
      final sha1Match = sha1Regex.firstMatch(line);
      if (sha1Match != null) {
        sha1 = sha1Match.group(1)?.trim();
      }

      final sha256Match = sha256Regex.firstMatch(line);
      if (sha256Match != null) {
        sha256 = sha256Match.group(1)?.trim();
      }
    }

    if (sha1 != null && sha1.isNotEmpty) {
      print('✅ SHA-1 found: $sha1');
    }

    if (sha256 != null && sha256.isNotEmpty) {
      print('✅ SHA-256 found: $sha256');
    }

    return {
      'sha1': sha1 ?? '',
      'sha256': sha256 ?? '',
    };
  }

  /// Fetches the SHA-1 and SHA-256 fingerprints for the Android project.
  /// 
  /// Attempts to extract fingerprints using the Gradle `signingReport`. 
  /// If it fails, it will attempt a `flutter build apk` to generate 
  /// necessary build artifacts and try again.
  Future<Map<String, String>> getShas() async {
    print('🔍 Fetching SHA values...');

    var shas = await _extractShas();

    if (shas['sha1']!.isNotEmpty || shas['sha256']!.isNotEmpty) {
      return shas;
    }

    print('⚠️ SHA not found. Running Flutter build...');

    await run('flutter', ['build', 'apk']);

    shas = await _extractShas();

    if (shas['sha1']!.isNotEmpty || shas['sha256']!.isNotEmpty) {
      return shas;
    }

    print('❌ Still unable to find SHA');
    return shas;
  }

  /// Retrieves the Android App ID (also known as the App Index) 
  /// from the specified Firebase [projectId].
  /// 
  /// Returns null if no Android app is found linked to the project.
  Future<String?> getAndroidAppId(String projectId) async {
    print('🔍 Fetching Android App ID...');

    final result = await runWithResult(
      'firebase',
      ['apps:list', '--project=$projectId'],
    );

    final output = result.stdout.toString();

    final regex = RegExp(r'1:\d+:android:[a-zA-Z0-9]+');
    final match = regex.firstMatch(output);

    if (match != null) {
      final appId = match.group(0);
      print('✅ Android App ID: $appId');
      return appId;
    }

    print('❌ Android App ID not found');
    return null;
  }

  /// Orchestrates the full SHA setup flow for the specified [projectId].
  /// 
  /// This includes:
  /// 1. Fetching SHA-1 and SHA-256 values locally.
  /// 2. Finding the corresponding Firebase Android App ID.
  /// 3. Uploading both fingerprints to the Firebase Console.
  Future<void> setupSha(String projectId) async {
    print('🔑 Setting up SHA (SHA-1 + SHA-256)...\n');

    final shas = await getShas();

    final sha1 = shas['sha1'];
    final sha256 = shas['sha256'];

    if ((sha1 == null || sha1.isEmpty) &&
        (sha256 == null || sha256.isEmpty)) {
      print('❌ No SHA values found');
      return;
    }

    final appId = await getAndroidAppId(projectId);
    if (appId == null) {
      print('❌ Android app not found in Firebase');
      return;
    }

    /// 🔹 Upload SHA-1
    if (sha1 != null && sha1.isNotEmpty) {
      print('🚀 Adding SHA-1...');
      await run('firebase', [
        'apps:android:sha:create',
        appId,
        sha1,
        '--project=$projectId',
      ]);
    }

    /// 🔹 Upload SHA-256
    if (sha256 != null && sha256.isNotEmpty) {
      print('🚀 Adding SHA-256...');
      await run('firebase', [
        'apps:android:sha:create',
        appId,
        sha256,
        '--project=$projectId',
      ]);
    }

    print('\n🎉 SHA-1 & SHA-256 added successfully');
  }

  // =====================================================
  // 🔥 FEATURE SYSTEM
  // =====================================================

  /// Provides helpful CLI instructions for enabling specific Firebase 
  /// features such as 'auth', 'firestore', or 'fcm'.
  Future<void> enableFeature(String feature) async {
    switch (feature) {
      case 'auth':
        print('🔐 Enabling Auth...');
        print('👉 Firebase Console → Authentication → Enable providers');
        break;

      case 'firestore':
        print('🗄️ Enabling Firestore...');
        print('👉 Firebase Console → Firestore → Create database');
        break;

      case 'fcm':
        print('🔔 Setting up FCM...');
        print('👉 Add firebase_messaging + permissions');
        break;

      default:
        print('❌ Unknown feature: $feature');
    }
  }

  /// Attempts to parse the `firebase.json` file to identify the 
  /// linked Firebase project ID.
  /// 
  /// Checks multiple lookup paths including:
  /// * `flutter/platforms/android/default/projectId`
  /// * `flutter/platforms/ios/default/projectId`
  /// * `flutter/platforms/dart` map values
  Future<String?> getProjectIdFromFirebaseJson() async {
    final file = File('firebase.json');

    if (!file.existsSync()) {
      print('❌ firebase.json not found');
      return null;
    }

    final content = jsonDecode(await file.readAsString());

    try {
      final flutter = content['flutter'];
      if (flutter != null && flutter['platforms'] != null) {
        final platforms = flutter['platforms'];

        // 1. Try Android
        if (platforms['android'] != null &&
            platforms['android']['default'] != null) {
          final id = platforms['android']['default']['projectId'];
          if (id != null) return id;
        }

        // 2. Try iOS
        if (platforms['ios'] != null && platforms['ios']['default'] != null) {
          final id = platforms['ios']['default']['projectId'];
          if (id != null) return id;
        }

        // 3. Try Dart config (most reliable for FlutterFire)
        if (platforms['dart'] is Map) {
          final dart = platforms['dart'] as Map;
          for (final conf in dart.values) {
            if (conf is Map && conf['projectId'] != null) {
              return conf['projectId'];
            }
          }
        }
      }

      print('❌ Unable to extract projectId from firebase.json');
      return null;
    } catch (e) {
      print('❌ Error parsing firebase.json: $e');
      return null;
    }
  }

  /// Provides warnings and manual instructions for disabling features 
  /// that cannot be easily undone via the CLI.
  Future<void> disableFeature(String feature) async {
    switch (feature) {
      case 'auth':
        print('⚠️ Auth cannot be disabled via CLI');
        break;

      case 'firestore':
        print('⚠️ Firestore cannot be disabled once created');
        break;

      case 'fcm':
        print('⚠️ Remove firebase_messaging manually');
        break;

      default:
        print('❌ Unknown feature: $feature');
    }
  }
}