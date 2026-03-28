import 'package:interact/interact.dart';

/// Service for handling interactive user prompts and selections.
class PromptService {
  /// Prompts the user for a text input with the given [msg].
  String ask(String msg) => Input(prompt: msg).interact();

  /// Prompts the user for a yes/no confirmation with the given [msg].
  bool confirm(String msg) => Confirm(prompt: msg).interact();

  /// Prompts the user to select one option from a list of [options].
  /// 
  /// Returns the 0-based index of the selected option.
  int select(String msg, List<String> options) =>
      Select(prompt: msg, options: options).interact();
}