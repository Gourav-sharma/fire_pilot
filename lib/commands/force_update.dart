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

  if (!pubspecContent.contains('url_launcher')) {
    await flutter.addDep('url_launcher');
  } else {
    print('ℹ️ url_launcher already exists in pubspec.yaml');
  }

  print('\n⚙️ Configuring Force Update service in: $path\n');

  // 4. Setup imports
  CodeGeneratorHelper.addImportIfMissing(path, "import 'dart:io';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:firebase_remote_config/firebase_remote_config.dart';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:package_info_plus/package_info_plus.dart';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:flutter/foundation.dart';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'package:flutter/material.dart';");
  CodeGeneratorHelper.addImportIfMissing(path, "import 'update_dialogs.dart';");

  // 5. Setup Class
  const classTemplate = '''class RemoteConfigService {
  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // Force update boolean key — if true, force update is active; if false, optional update is active
  static const String _isForceUpdateKey = 'is_force_update';

  // Target/minimum version keys (optional update if is_force_update is false)
  static const String _minVersionAndroidKey = 'min_version_android';
  static const String _minVersionIosKey = 'min_version_ios';

  // Store URLs
  static const String _storeUrlAndroidKey = 'store_url_android';
  static const String _storeUrlIosKey = 'store_url_ios';
}''';

  CodeGeneratorHelper.addClassIfMissing(path, 'RemoteConfigService', classTemplate);

  // 6. Setup Methods
  const initializeTemplate = '''Future<void> initialize() async {
    await _remoteConfig.setDefaults({
      _isForceUpdateKey: false,
      _minVersionAndroidKey: '1.0.0',
      _minVersionIosKey: '1.0.0',
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

    // Log all fetched values
    debugPrint('[RemoteConfig] is_force_update      = \${_remoteConfig.getBool(_isForceUpdateKey)}');
    debugPrint('[RemoteConfig] min_version_android  = \${_remoteConfig.getString(_minVersionAndroidKey)}');
    debugPrint('[RemoteConfig] min_version_ios      = \${_remoteConfig.getString(_minVersionIosKey)}');
    debugPrint('[RemoteConfig] store_url_android    = \${_remoteConfig.getString(_storeUrlAndroidKey)}');
    debugPrint('[RemoteConfig] store_url_ios        = \${_remoteConfig.getString(_storeUrlIosKey)}');
  }''';

  const isForceUpdateRequiredTemplate = '''Future<bool> isForceUpdateRequired() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final minVersion = Platform.isAndroid
        ? _remoteConfig.getString(_minVersionAndroidKey)
        : _remoteConfig.getString(_minVersionIosKey);

    final isForceUpdate = _remoteConfig.getBool(_isForceUpdateKey);
    final isVersionBelow = _isVersionLessThan(currentVersion, minVersion);

    final isRequired = isForceUpdate && isVersionBelow;
    debugPrint('[ForceUpdate] current=\$currentVersion  min=\$minVersion  isForceUpdate=\$isForceUpdate  required=\$isRequired');
    return isRequired;
  }''';

  const isOptionalUpdateAvailableTemplate = '''Future<bool> isOptionalUpdateAvailable() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final minVersion = Platform.isAndroid
        ? _remoteConfig.getString(_minVersionAndroidKey)
        : _remoteConfig.getString(_minVersionIosKey);

    final isForceUpdate = _remoteConfig.getBool(_isForceUpdateKey);
    final isVersionBelow = _isVersionLessThan(currentVersion, minVersion);

    // If it's NOT a force update, but the version is below the minimum version,
    // then it's an optional update.
    final isAvailable = !isForceUpdate && isVersionBelow;
    debugPrint('[OptionalUpdate] current=\$currentVersion  min=\$minVersion  isForceUpdate=\$isForceUpdate  available=\$isAvailable');
    return isAvailable;
  }''';

  const getStoreUrlTemplate = '''String getStoreUrl() {
    return Platform.isAndroid
        ? _remoteConfig.getString(_storeUrlAndroidKey)
        : _remoteConfig.getString(_storeUrlIosKey);
  }''';

  const checkAndShowUpdateDialogTemplate = '''Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    // Check if the context contains a Navigator and MaterialLocalizations
    if (Navigator.maybeOf(context) == null ||
        Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) == null) {
      debugPrint(
        '❌ [RemoteConfigService] Error: The BuildContext passed to checkAndShowUpdateDialog '
        'does not contain a Navigator or MaterialLocalizations. This usually happens when '
        'passing the context of a widget located above MaterialApp in the widget tree (e.g., '
        'in the initState of the root MyApp widget).\\n'
        '👉 Solution: Call checkAndShowUpdateDialog from a screen widget that is a child of '
        'MaterialApp (like your HomeScreen/MyHomePage), or use a Builder widget inside MaterialApp.'
      );
      return;
    }

    if (await isForceUpdateRequired()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => ForceUpdateDialog(storeUrl: getStoreUrl()),
      );
    } else if (await isOptionalUpdateAvailable()) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => OptionalUpdateDialog(storeUrl: getStoreUrl()),
      );
    }
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
  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', 'checkAndShowUpdateDialog', checkAndShowUpdateDialogTemplate);
  CodeGeneratorHelper.addMethodIfMissing(path, 'RemoteConfigService', '_isVersionLessThan', isVersionLessThanTemplate);

  // 7. Write dialogs UI file in the same directory as the service
  final serviceFile = File(path);
  final parentDir = serviceFile.parent;
  if (!parentDir.existsSync()) {
    parentDir.createSync(recursive: true);
  }

  final dialogsFile = File('${parentDir.path}/update_dialogs.dart');
  
  const dialogsTemplate = '''import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateDialog extends StatelessWidget {
  final String storeUrl;

  const ForceUpdateDialog({
    Key? key,
    required this.storeUrl,
  }) : super(key: key);

  Future<void> _launchStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch \$storeUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing by back button
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: Colors.red.shade600,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Update Required',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'A critical update is available. You must update the app to continue using it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _launchStore,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Update Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OptionalUpdateDialog extends StatelessWidget {
  final String storeUrl;

  const OptionalUpdateDialog({
    Key? key,
    required this.storeUrl,
  }) : super(key: key);

  Future<void> _launchStore() async {
    final uri = Uri.parse(storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch \$storeUrl');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.update_rounded,
                color: Colors.blue.shade600,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Update Available',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A new version of the app is available. Update now to enjoy the latest features and bug fixes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Later',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        _launchStore();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Update',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
''';

  dialogsFile.writeAsStringSync(dialogsTemplate);
  print('✅ Generated Dialog UI file: ${dialogsFile.path}');

  print('\n🎉 Firebase Force Update Service configured successfully at $path!');
}
