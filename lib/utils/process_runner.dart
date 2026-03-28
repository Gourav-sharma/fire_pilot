import 'dart:io';

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

Future<void> openUrl(String url) async {
  if (Platform.isWindows) {
    await Process.run('start', [url], runInShell: true);
  } else if (Platform.isMacOS) {
    await Process.run('open', [url]);
  } else {
    print('🌐 Please open: $url');
  }
}

Future<void> run(String cmd, List<String> args) async {
  await runWithResult(cmd, args);
}

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