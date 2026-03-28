import 'dart:io';

class EnvService {
  void create(String env) {
    final dir = Directory('lib/config/$env');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
      print('✅ Env created: $env');
    }
  }
}