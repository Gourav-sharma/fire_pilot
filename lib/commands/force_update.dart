import 'dart:io';

import '../services/flutter_service.dart';
import '../services/firebase_service.dart';
import '../services/prompt_service.dart';
import '../utils/code_generator_helper.dart';
import 'firebase_setup.dart';

/// Implements the Firebase Force Update setup for Flutter project (Android & iOS).
Future<void> firebaseForceUpdateCommand({
  required String path,
}) async {
  print('🚀 FirePilot: Firebase Force Update Setup\n');

  // 1. Verify Flutter project
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('❌ Not a Flutter project');
    print('👉 Run this inside a Flutter project folder');
    return;
  }

  // 2. Check if Firebase is setup in the project
  final firebase = FirebaseService();
  final projectId = await firebase.getProjectIdFromFirebaseJson();
  if (projectId == null) {
    print('⚠️ Firebase is not set up for this project.');
    final prompt = PromptService();
    final runSetup = prompt.confirm('Would you like to run the Firebase setup command first?');
    if (runSetup) {
      final envInput = prompt.ask('Enter environment name (Optional, press Enter for "dev")');
      final env = envInput.isEmpty ? 'dev' : envInput;
      print('\n🔄 Running Firebase setup for environment "$env"...\n');
      await firebaseSetupCommand(full: true, env: env);
      print('\n🔄 Continuing with Firebase Force Update Setup...\n');
    } else {
      print('⚠️ Continuing without running Firebase setup. Note that Firebase Remote Config will require Firebase configuration to work.');
    }
  } else {
    print('✅ Firebase setup detected (Project ID: $projectId)');
  }

  // 3. Add dependencies if missing
  final flutter = FlutterService();
  final pubspecContent = pubspecFile.readAsStringSync();

  print('📦 Checking dependencies...');
  if (!pubspecContent.contains('firebase_remote_config')) {
    await flutter.addDep('firebase_remote_config');
  } else {
    print('ℹ️ firebase_remote_config already exists in pubspec.yaml');
  }

  if (!pubspecContent.contains('package_info_plus')) {
    await flutter.addDep('package_info_plus');
  } else {
    print('ℹ️ package_info_plus already exists in pubspec.yaml');
  }

  print('\n⚙️ Configuring Force Update service in: $path\n');

  // 4. Setup imports
  CodeGeneratorHelper.addImportIfMissing(path, "import 'dart:io';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:firebase_remote_config/firebase_remote_config.dart';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:package_info_plus/package_info_plus.dart';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:flutter/foundation.dart';");

  // 5. Setup Class
  const classTemplate = '''class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Force update — app cannot be used below this version
  static const String _minVersionAndroidKey = 'min_version_android';
  static const String _minVersionIosKey = 'min_version_ios';

  // Optional update — nudge users to upgrade to the latest version
  static const String _latestVersionAndroidKey = 'latest_version_android';
  static const String _latestVersionIosKey = 'latest_version_ios';

  // Store URLs
  static const String _storeUrlAndroidKey = 'store_url_android';
  static const String _storeUrlIosKey = 'store_url_ios';
}''';

  CodeGeneratorHelper.addClassIfMissing(path, 'RemoteConfigService', classTemplate);

  // 6. Setup Methods
  const initializeTemplate = '''Future<void> initialize() async {
    await _remoteConfig.setDefaults({
      _minVersionAndroidKey: '1.0.0',
      _minVersionIosKey: '1.0.0',
      _latestVersionAndroidKey: '1.0.0',
      _latestVersionIosKey: '1.0.0',
      _storeUrlAndroidKey: 'https://play.google.com/store/apps/details?id=your.package.name',
      _storeUrlIosKey: 'https://apps.apple.com/app/idyour-app-id',
    });

    // In debug mode, use zero interval so we ALWAYS fetch fresh values from Firebase.
    // In production, use a reasonable interval (e.g. 1 hour) to avoid rate limits.
    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 30),
      minimumFetchInterval: kDebugMode
          ? Duration.zero          // Always fetch fresh in debug/dev
          : const Duration(hours: 1), // Cache for 1 hour in production
    ));

    try {
      // Fetch and activate — pulls latest values from Firebase console
      final updated = await _remoteConfig.fetchAndActivate();
      debugPrint('[RemoteConfig] fetchAndActivate completed. Updated: \$updated');
    } catch (e) {
      debugPrint('[RemoteConfig] fetchAndActivate failed: \$e');
      // Activate any previously cached values as fallback
      await _remoteConfig.activate();
    }

    // Log all fetched version values
    debugPrint('[RemoteConfig] min_version_android    = \${_remoteConfig.getString(_minVersionAndroidKey)}');
    debugPrint('[RemoteConfig] min_version_ios         = \${_remoteConfig.getString(_minVersionIosKey)}');
    debugPrint('[RemoteConfig] latest_version_android  = \${_remoteConfig.getString(_latestVersionAndroidKey)}');
    debugPrint('[RemoteConfig] latest_version_ios      = \${_remoteConfig.getString(_latestVersionIosKey)}');
  }''';

  const isForceUpdateRequiredTemplate = '''Future<bool> isForceUpdateRequired() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final minVersion = Platform.isAndroid
        ? _remoteConfig.getString(_minVersionAndroidKey)
        : _remoteConfig.getString(_minVersionIosKey);

    final isRequired = _isVersionLessThan(currentVersion, minVersion);
    debugPrint('[ForceUpdate] current=\$currentVersion  min=\$minVersion  required=\$isRequired');
    return isRequired;
  }''';

  const isOptionalUpdateAvailableTemplate = '''Future<bool> isOptionalUpdateAvailable() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final minVersion = Platform.isAndroid
        ? _remoteConfig.getString(_minVersionAndroidKey)
        : _remoteConfig.getString(_minVersionIosKey);

    final latestVersion = Platform.isAndroid
        ? _remoteConfig.getString(_latestVersionAndroidKey)
        : _remoteConfig.getString(_latestVersionIosKey);

    // Must be >= min (not forced) AND < latest (an update exists)
    final isAboveMin = !_isVersionLessThan(currentVersion, minVersion);
    final isBelowLatest = _isVersionLessThan(currentVersion, latestVersion);
    final isAvailable = isAboveMin && isBelowLatest;
    debugPrint('[OptionalUpdate] current=\$currentVersion  min=\$minVersion  latest=\$latestVersion  available=\$isAvailable');
    return isAvailable;
  }''';

  const getStoreUrlTemplate = '''String getStoreUrl() {
    return Platform.isAndroid
        ? _remoteConfig.getString(_storeUrlAndroidKey)
        : _remoteConfig.getString(_storeUrlIosKey);
  }''';

  const isVersionLessThanTemplate = '''bool _isVersionLessThan(String current, String minimum) {
    // Strip build metadata (+1) and pre-release labels (-dev) before parsing
    String cleanVersion(String version) {
      final dashIndex = version.indexOf('-');
      if (dashIndex != -1) version = version.substring(0, dashIndex);
      final plusIndex = version.indexOf('+');
      if (plusIndex != -1) version = version.substring(0, plusIndex);
      return version.trim();
    }

    // Safely parse a version part — returns 0 for non-numeric segments
    int parsePart(String part) {
      final match = RegExp(r'^(\\d+)').firstMatch(part.trim());
      return match != null ? int.parse(match.group(1)!) : 0;
    }

    final currentParts = cleanVersion(current).split('.').map(parsePart).toList();
    final minParts = cleanVersion(minimum).split('.').map(parsePart).toList();

    for (var i = 0; i < minParts.length; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final minPart = minParts[i];

      if (currentPart < minPart) return true;
      if (currentPart > minPart) return false;
    }
    return false;
  }''';

  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', 'initialize', initializeTemplate);
  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', 'isOptionalUpdateAvailable', isOptionalUpdateAvailableTemplate);
  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', 'isForceUpdateRequired', isForceUpdateRequiredTemplate);
  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', 'getStoreUrl', getStoreUrlTemplate);
  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', '_isVersionLessThan', isVersionLessThanTemplate);

  print('\n🎉 Firebase Force Update Service configured successfully at $path!');
}
