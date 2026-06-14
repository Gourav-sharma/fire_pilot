import 'dart:io';

import '../services/firebase_service.dart';
import '../services/flutter_service.dart';
import '../services/prompt_service.dart';
import '../services/env_service.dart';
import '../services/feature_service.dart';
import '../utils/process_runner.dart';

/// Orchestrates the full Firebase setup flow for a Flutter project.
/// 
/// If [full] is true, it performs a comprehensive setup including tool 
/// checks, login, project creation, and dependency configuration.
/// The [env] parameter specifies the target environment (e.g., 'dev').
Future<void> firebaseSetupCommand({
  required bool full,
  required String env,
}) async {
  final firebase = FirebaseService();
  final flutter = FlutterService();
  final prompt = PromptService();
  final envService = EnvService();
  final feature = FeatureService();

  print('🚀 FirePilot: Elite Firebase Setup ($env)\n');

  try {
    /// 🔹 Validate Flutter project
    if (!File('pubspec.yaml').existsSync()) {
      print('❌ Not a Flutter project');
      print('👉 Run this inside a Flutter project folder');
      return;
    }

    /// 🔹 Check & auto-fix tools
    await _checkAndFixTools();

    /// 🔹 Ask Project ID
    /// 🔹 Ask Project ID with Validation
    String projectId = '';
    while (true) {
      projectId = prompt.ask('Enter Firebase project ID');

      if (projectId.isEmpty) {
        print('❌ Project ID cannot be empty');
        continue;
      }

      final regExp = RegExp(r'^[a-z][a-z0-9-]{5,29}$');
      if (!regExp.hasMatch(projectId)) {
        print('❌ Invalid Project ID format');
        print('👉 Must be 6-30 chars, lowercase, numbers, and hyphens (no underscores)');
        print('👉 Must start with a letter');
        continue;
      }
      break;
    }

    /// 🔹 Firebase Login & Account verification
    print('🔐 Checking Firebase login...');
    final activeAccount = await firebase.login();
    if (activeAccount != null) {
      print('✅ Active Account: $activeAccount\n');
    }

    /// 🔹 List & Check Projects
    print('\n📋 Checking your Firebase projects...');
    final existingProjects = await firebase.listProjects();

    final alreadyExists = existingProjects.contains(projectId);
    
    if (alreadyExists) {
      print('❌ Project ID "$projectId" is already taken in your Firebase console.');
      print('👉 Please choose a unique ID for your new project.');
      print('❌ Setup stopped.');
      return;
    }

    print('📋 Found ${existingProjects.length} existing projects.');
    
    // Suggest similar IDs if any
    final similar = existingProjects.where((p) => p.contains(projectId) || projectId.contains(p)).toList();
    if (similar.isNotEmpty) {
      print('\n💡 Similar projects found in your account:');
      for (var s in similar) {
        print('   - $s');
      }
      final useSimilar = prompt.confirm('Do you want to use one of these instead?');
      if (useSimilar) {
        final index = prompt.select('Select project', similar);
        projectId = similar[index];
        print('✅ Selected: $projectId');
        
        // 🔥 Re-check if the selected "similar" project exists (it obviously does)
        // Since the user wants to STOP if it exists, selecting a similar existing one might also mean we stop?
        // Actually, if we allow them to select an existing one, and then stop, that's confusing.
        // I'll add a warning that choosing an existing one will also stop if they want only NEW projects.
        // Wait, the user said "if i choose project id ... and someone has taken ... then can i make ... No".
        // They want to make a NEW project.
        print('❌ Selected project "$projectId" already exists.');
        print('❌ Setup stopped.');
        return;
      }
    }

    /// 🔹 Create Project (Mandatory for a clean setup)
    final displayName = prompt.ask('Enter Firebase project display name (Optional, press Enter to use ID)');
    final finalDisplayName = displayName.isEmpty ? projectId : displayName;

    print('📦 Creating NEW Firebase project "$projectId" ($finalDisplayName)...');

    try {
      await firebase.createProject(projectId, displayName: finalDisplayName);
      print('✅ Project created successfully');
    } catch (e) {
      print('\n❌ Project creation failed!');
      print('👉 Error: $e');
      print('\n⚠️ POSSIBLE REASONS:');
      print('   1. ID "$projectId" is already taken GLOBALLY by another user.');
      print('   2. Quota Limit: You have exceeded the max number of projects for your account.');
      print('   3. Billing/Policy: Some accounts require billing to create new projects.\n');
      print('👉 TIP: Check your Firebase Console to delete old test projects.');
      print('❌ Setup stopped.');
      return;
    }

    /// 🔹 Interactive Platform Selection
    final platforms = ['android', 'ios'];
    print('🖥️ platform Selection (Android & iOS are default)');
    if (prompt.confirm('Enable Windows support?')) {
      platforms.add('windows');
    }
    if (prompt.confirm('Enable macOS support?')) {
      platforms.add('macos');
    }

    /// 🔹 Interactive Feature Selection
    final selectedFeatures = <String>[];
    if (full) {
      print('\n🚀 Feature Selection');
      if (prompt.confirm('Enable Firebase Auth?')) {
        selectedFeatures.add('auth');
      }
      if (prompt.confirm('Enable Cloud Messaging (FCM)?')) {
        selectedFeatures.add('fcm');
      }
    }

    /// 🔹 Configure FlutterFire
    print('\n⚙️ Configuring FlutterFire for: ${platforms.join(', ')}...');
    await firebase.configure(projectId, platforms: platforms, env: env);

    /// 🔹 Add Dependencies
    print('📦 Adding Firebase dependencies...');
    await flutter.addDeps(); // Adds firebase_core

    // Add feature-specific dependencies
    for (final f in selectedFeatures) {
      if (f == 'auth') await flutter.addDep('firebase_auth');
      if (f == 'fcm') await flutter.addDep('firebase_messaging');
    }

    /// 🔑 Setup SHA
    print('🔑 Setting up SHA...');
    try {
      await firebase.setupSha(projectId);
    } catch (e) {
      print('⚠️ SHA setup failed, skipping...');
    }

    /// 🔹 Create Environment Folder
    print('🌍 Setting up environment...');
    envService.create(env);

    /// 🔥 Enable selected Features in Console
    if (selectedFeatures.isNotEmpty) {
      print('🔥 Enabling selected features...\n');
      for (final f in selectedFeatures) {
        await feature.enable(f, projectId: projectId);
      }
      print('\n📦 Enabled: ${selectedFeatures.join(', ')}');
    } else if (full) {
      print('ℹ️ No additional features selected');
    } else {
      print('ℹ️ Skipping feature setup (use --full to enable selection)');
    }

    print('\n🎉 Firebase setup completed successfully for [$env]');
  } catch (e) {
    print('\n❌ Setup failed!');
    print('Error: $e');
  }
}

//
// ======================================================
// 🔥 SMART TOOL CHECKER (PRODUCTION LEVEL)
// ======================================================
//

Future<void> _checkAndFixTools() async {
  print('🔍 Checking required tools...\n');

  bool hasNpm = false;
  bool hasFirebase = false;
  bool hasFlutterFire = false;
  bool hasWinget = false;
  String npmCommand = 'npm';
  String? nodeDir;

  /// 🔥 SAFE checks (no crash)
  hasNpm = await _isCommandAvailable('npm');
  hasFirebase = await _isCommandAvailable('firebase');
  hasFlutterFire = await _isCommandAvailable('flutterfire');

  /// 🔥 SAFE winget detection (Windows only)
  if (Platform.isWindows) {
    hasWinget = await _isCommandAvailable('winget');

    /// 🔹 Direct check for Node.js if PATH is broken
    final nodeSearchPaths = Platform.isWindows
        ? ['C:\\Program Files\\nodejs']
        : ['/usr/local/bin', '/opt/homebrew/bin'];

    String? foundNodePath;
    for (final path in nodeSearchPaths) {
      final npmCmd = Platform.isWindows ? 'npm.cmd' : 'npm';
      final fullPath =
          '$path${Platform.pathSeparator}$npmCmd';
      if (File(fullPath).existsSync()) {
        foundNodePath = fullPath;
        break;
      }
    }

    if (foundNodePath != null) {
      print('🔎 Node.js found in common path: $foundNodePath');
      hasNpm = true;
      npmCommand = foundNodePath;
    }
  }

  /// 🔥 PRINT ALWAYS (now guaranteed)
  print('🔎 hasNpm: $hasNpm');
  print('🔎 hasWinget: $hasWinget');

  /// 🔥 HANDLE npm
  if (!hasNpm) {
    print('\n❌ npm not found (Node.js missing)');

    if (Platform.isWindows && hasWinget) {
      final installed = await _installNodeWithWinget();
      if (installed) {
        throw Exception('Node.js installed. Please RESTART your terminal to apply changes.');
      }
    } else if (Platform.isMacOS) {
      final hasBrew = await _isCommandAvailable('brew');
      if (hasBrew) {
        final success = await _installNodeWithBrew();
        if (success) {
          print('✅ Node.js installed successfully (PATH injection active)');
          return;
        }
      }
      print('👉 Install Node.js from: https://nodejs.org');
      await openUrl('https://nodejs.org');
      throw Exception('Node.js installation required');
    } else {
      print('👉 Install Node.js from: https://nodejs.org');
      await openUrl('https://nodejs.org');
      throw Exception('Node.js installation required');
    }
  }

  /// Firebase CLI
  if (!hasFirebase) {
    print('❌ Firebase CLI not found');
    await _installFirebaseCli(npmCommand, nodeDir);
  }

  /// FlutterFire CLI
  if (!hasFlutterFire) {
    print('❌ FlutterFire CLI not found');
    await _installFlutterFire();
  }

  print('\n✅ All required tools are ready\n');
}
//
// ======================================================
// 🔧 HELPERS
// ======================================================
//

Future<bool> _isCommandAvailable(String cmd) async {
  try {
    final result = await Process.run(
      Platform.isWindows ? 'where' : 'which',
      [cmd],
      runInShell: true,
      environment: getInjectedEnvironment(),
    );

    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<void> _installFirebaseCli(String npmCmd, String? nodeDir) async {
  await run(npmCmd, ['install', '-g', 'firebase-tools']);
  print('✅ Firebase CLI installed');
}

Future<void> _installFlutterFire() async {
  await run('dart', ['pub', 'global', 'activate', 'flutterfire_cli']);
  print('✅ FlutterFire CLI installed');
}

Future<bool> _installNodeWithBrew() async {
  print('📦 Installing Node.js using Homebrew...\n');
  try {
    await run('brew', ['install', 'node']);
    return true;
  } catch (e) {
    print('❌ Homebrew install failed');
    return false;
  }
}


Future<bool> _installNodeWithWinget() async {
  print('📦 Installing Node.js using winget...\n');

  final result = await Process.run(
    'winget',
    [
      'install',
      '--id',
      'OpenJS.NodeJS.LTS',
      '-e',
      '--accept-package-agreements',
      '--accept-source-agreements'
    ],
    runInShell: true,
  );

  print('📤 OUTPUT:\n${result.stdout}');

  if (result.exitCode == 0) {
    print('✅ Node.js installed successfully');
    print('⚠️ Please RESTART your terminal to apply changes and run the command again.');
    return true;
  } else if (result.exitCode == 1602) { // 1602 = Cancelled by user
    print('⚠️ Installation was cancelled by the user.');
    print('👉 You can install Node.js manually from: https://nodejs.org');
    throw Exception('Node.js installation was cancelled.');
  } else if (result.exitCode == -1978335189) { // Already installed
    print('✅ Node.js is already installed (detected by winget)');
    print('⚠️ However, it is NOT in your PATH. Please RESTART your terminal or computer.');
    return true;
  } else {
    print('❌ Winget install failed (Exit Code: ${result.exitCode})');
    print('👉 Please try installing Node.js manually from: https://nodejs.org');
    await openUrl('https://nodejs.org');
    throw Exception('Winget installation failed');
  }
}