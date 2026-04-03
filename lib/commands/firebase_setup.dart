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

    /// 🔹 Firebase Login
    print('🔐 Checking Firebase login...');
    await firebase.login();

    /// 🔹 List Projects (Helpful for Quota debugging)
    print('\n📋 Your existing Firebase projects:');
    await firebase.listProjects();

    /// 🔹 Create Project (Optional)
    final shouldCreate = prompt.confirm('Create Firebase project?');

    if (shouldCreate) {
      print('📦 Creating Firebase project...');
      try {
        await firebase.createProject(projectId);
      } catch (e) {
        print('\n❌ Project creation failed!');
        print('👉 Possible reasons:');
        print('   1. ID "$projectId" is already taken (globally unique).');
        print('   2. You have reached your Firebase project quota.');
        print('   3. Network or permission issues.');
        print('👉 TIP: Try a MORE UNIQUE ID (e.g. my-elite-$projectId)\n');

        final proceed = prompt.confirm(
            'Continue anyway? (Choose yes ONLY if the project already exists)');
        if (!proceed) {
          print('❌ Setup aborted by user');
          return;
        }
      }
    } else {
      print('⏭ Skipping project creation');
    }

    /// 🔹 Configure FlutterFire
    print('⚙️ Configuring FlutterFire...');
    await firebase.configure(projectId);

    /// 🔹 Add Dependencies
    print('📦 Adding Firebase dependencies...');
    await flutter.addDeps();

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

    /// 🔥 Full Setup (UPDATED: Firestore removed)
    if (full) {
      print('🔥 Running FULL setup...\n');

      final features = ['auth', 'fcm']; // ✅ firestore removed

      for (final f in features) {
        await feature.enable(f, projectId: projectId);
      }

      print('\n📦 Enabled: auth, fcm');
      print('🚫 Skipped: firestore (manual enable recommended)');
    } else {
      print('ℹ️ Skipping feature setup (use --full to enable)');
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