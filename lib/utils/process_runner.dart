import 'dart:io';

/// Generates an environment map with professional tool paths injected.
/// 
/// Automatically detects and adds paths for:
/// * Node.js & NPM
/// * Dart & Pub global binaries
/// * Homebrew (on macOS)
/// 
/// This ensures that newly installed tools can be used immediately 
/// without requiring a terminal restart.
Map<String, String> getInjectedEnvironment() {
  final Map<String, String> env = Map.from(Platform.environment);
  final separator = Platform.isWindows ? ';' : ':';
  String currentPath = env['PATH'] ?? '';

  final pathsToInject = Platform.isWindows
      ? [
          'C:\\Program Files\\nodejs',
          '${env['APPDATA']}\\npm',
          '${env['LOCALAPPDATA']}\\Pub\\Cache\\bin',
        ]
      : [
          '/usr/local/bin',
          '/opt/homebrew/bin',
          '${env['HOME']}/.pub-cache/bin',
          '${env['HOME']}/.npm-global/bin',
        ];

  for (final path in pathsToInject) {
    if (Directory(path).existsSync() && !currentPath.contains(path)) {
      currentPath = '$path$separator$currentPath';
    }
  }
  env['PATH'] = currentPath;

  return env;
}

/// Opens the specified [url] in the system's default browser.
/// 
/// Supports Windows ('start') and macOS ('open').
Future<void> openUrl(String url) async {
  if (Platform.isWindows) {
    await Process.run('start', [url], runInShell: true);
  } else if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else {
    print('🌐 Please open: $url');
  }
}

/// Runs a [cmd] with [args] and returns when the process completes.
/// 
/// This is a convenience wrapper around [runWithResult].
Future<void> run(String cmd, List<String> args) async {
  await runWithResult(cmd, args);
}

/// Runs a [cmd] with [args] and returns the [ProcessResult].
/// 
/// Capture stdout/stderr and prints them to the console. 
/// Throws an [Exception] if the exit code is non-zero.
Future<ProcessResult> runWithResult(String cmd, List<String> args) async {
  print('👉 Running: $cmd ${args.join(" ")}\n');

  final env = getInjectedEnvironment();

  try {
    final result = await Process.run(
      cmd,
      args,
      runInShell: true,
      environment: env,
    );

    /// ✅ STDOUT
    if (result.stdout.toString().isNotEmpty) {
      stdout.write(result.stdout);
    }

    /// ❌ STDERR
    if (result.stderr.toString().isNotEmpty) {
      stderr.write(result.stderr);
    }

    /// ❌ Exit Code Check
    if (result.exitCode != 0) {
      throw Exception(
        '$cmd failed with exit code ${result.exitCode}',
      );
    }

    print('\n✅ $cmd completed\n');
    return result;
  } catch (e) {
    print('\n❌ Error while running $cmd');
    rethrow;
  }
}

/// Runs a [cmd] with [args] in interactive mode.
/// 
/// Uses [ProcessStartMode.inheritStdio] to allow the user to 
/// interact directly with the subprocess (e.g. for login prompts).
Future<void> runInteractive(String cmd, List<String> args) async {
  print('👉 Running interactive: $cmd ${args.join(" ")}\n');

  final env = getInjectedEnvironment();

  try {
    final process = await Process.start(
      cmd,
      args,
      runInShell: true,
      environment: env,
      mode: ProcessStartMode.inheritStdio,
    );

    final exitCode = await process.exitCode;

    if (exitCode != 0) {
      throw Exception('$cmd failed with exit code $exitCode');
    }

    print('\n✅ $cmd completed\n');
  } catch (e) {
    print('\n❌ Error while running interactive $cmd');
    rethrow;
  }
}