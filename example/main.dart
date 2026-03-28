import 'package:fire_pilot/commands/firebase_setup.dart';

void main() async {
  // This is an example of how to programmatically call the setup command.
  // In a real scenario, you would run this from the CLI.
  
  await firebaseSetupCommand(
    full: true,
    env: 'dev',
  );
}
