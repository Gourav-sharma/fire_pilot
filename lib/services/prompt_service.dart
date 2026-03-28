import 'package:interact/interact.dart';

class PromptService {
  String ask(String msg) => Input(prompt: msg).interact();
  bool confirm(String msg) => Confirm(prompt: msg).interact();
  int select(String msg, List<String> options) =>
      Select(prompt: msg, options: options).interact();
}