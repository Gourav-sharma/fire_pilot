import 'package:args/args.dart';
import 'package:fire_pilot/commands/firebase_setup.dart';
import 'package:fire_pilot/commands/force_update.dart';
import 'package:fire_pilot/services/feature_service.dart';
import 'package:fire_pilot/services/firebase_service.dart';

/// The main entry point for the FirePilot CLI.
/// 
/// Parses command-line [arguments] and dispatches them to the 
/// appropriate service or command handler.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser();

  final firebase = parser.addCommand('firebase');

  /// 🔹 SETUP COMMAND
  final setup = firebase.addCommand('setup');
  setup.addFlag('full', negatable: false);
  setup.addOption('env', defaultsTo: 'dev');

  /// 🔹 ENABLE COMMAND
  firebase.addCommand('enable');

  /// 🔹 DISABLE COMMAND
  firebase.addCommand('disable');

  /// 🔹 SHA COMMAND
  final sha = firebase.addCommand('sha');
  final shaAdd = sha.addCommand('add');
  shaAdd.addOption('project');

  /// 🔹 FORCE UPDATE COMMAND
  final forceUpdate = firebase.addCommand('force-update');
  forceUpdate.addOption('path', defaultsTo: 'lib/services/remote_config_service.dart');

  final result = parser.parse(arguments);

  if (result.command?.name == 'firebase') {
    final sub = result.command!.command;

    /// 🔥 SETUP
    if (sub?.name == 'setup') {
      final cmd = sub!;
      await firebaseSetupCommand(
        full: cmd['full'],
        env: cmd['env'],
      );
      return;
    }

    /// ✅ ENABLE
    if (sub?.name == 'enable') {
      if (sub!.arguments.isEmpty) {
        print('❌ Please provide feature name');
        return;
      }

      final featureName = sub.arguments.join('-').toLowerCase();
      final firebase = FirebaseService();
      final projectId = await firebase.getProjectIdFromFirebaseJson();

      await FeatureService().enable(
        featureName,
        projectId: projectId,
      );
      return;
    }

    /// ❌ DISABLE
    if (sub?.name == 'disable') {
      if (sub!.arguments.isEmpty) {
        print('❌ Please provide feature name');
        return;
      }

      final featureName = sub.arguments.join('-').toLowerCase();
      await FeatureService().disable(featureName);
      return;
    }

    /// 🔑 SHA ADD
    if (sub?.name == 'sha') {
      final shaSub = sub!.command;

      if (shaSub?.name == 'add') {
        final projectId = shaSub!['project'];

        if (projectId == null || projectId.isEmpty) {
          print('❌ Please provide project ID');
          print('👉 Example: fire_pilot firebase sha add --project=my-app');
          return;
        }

        await FirebaseService().setupSha(projectId);
        return;
      }
    }

    /// 🚀 FORCE UPDATE
    if (sub?.name == 'force-update') {
      final cmd = sub!;
      await firebaseForceUpdateCommand(
        path: cmd['path'],
      );
      return;
    }
  }

  /// 🔻 DEFAULT HELP
  print('Usage:\n');
  print('  fire_pilot firebase setup --full --env=dev');
  print('  fire_pilot firebase enable <feature>');
  print('  fire_pilot firebase disable <feature>');
  print('  fire_pilot firebase sha add --project=<projectId>');
  print('  fire_pilot firebase force-update --path=<filePath>\n');

  print('Examples:');
  print('  fire_pilot firebase enable auth');
  print('  fire_pilot firebase disable firestore');
  print('  fire_pilot firebase sha add --project=my-app');
  print('  fire_pilot firebase force-update');
}