import 'dart:io';

/// Service for managing environment-specific configurations.
class EnvService {
  /// Creates a new environment directory structure for the given [env] name.
  /// 
  /// Example: `create('dev')` will ensure `lib/config/dev/` exists.
  void create(String env) {
    final dir = Directory('lib/config/$env');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      print('✅ Env created: $env');
    }
  }
}