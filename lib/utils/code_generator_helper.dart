import 'dart:io';

/// Helper utility to safely modify Dart source code files without duplicating
/// classes, functions/methods, or imports.
class CodeGeneratorHelper {
  /// Safely adds an import statement to the top of the file if it doesn't already exist.
  static void addImportIfMissing(String filePath, String importLine) {
    final file = File(filePath);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsStringSync('$importLine\n');
      print('✅ Created file and added import: $importLine');
      return;
    }

    final content = file.readAsStringSync();
    // Normalize spaces and quotes to check for existence
    final normalizedImport = importLine.replaceAll("'", '"').replaceAll(' ', '');
    final normalizedContent = content.replaceAll("'", '"').replaceAll(' ', '');

    if (!normalizedContent.contains(normalizedImport)) {
      file.writeAsStringSync('$importLine\n$content');
      print('✅ Added import to $filePath: $importLine');
    } else {
      print('ℹ️ Import already exists in $filePath: $importLine');
    }
  }

  /// Safely adds a class to the file if it doesn't already exist.
  /// If the file does not exist, it will create it.
  static void addClassIfMissing(String filePath, String className, String classTemplate) {
    final file = File(filePath);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
      file.writeAsStringSync(classTemplate);
      print('✅ Created file and added class: $className');
      return;
    }

    final content = file.readAsStringSync();
    final classRegex = RegExp(r'\bclass\s+' + className + r'\b');

    if (!classRegex.hasMatch(content)) {
      file.writeAsStringSync('$content\n\n$classTemplate');
      print('✅ Added class $className to $filePath');
    } else {
      print('ℹ️ Class $className already exists in $filePath. Skipping class creation.');
    }
  }

  /// Safely adds a method to a specific class in the file if it doesn't already exist.
  static void addMethodIfMissing(String filePath, String className, String methodName, String methodTemplate) {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('❌ File does not exist: $filePath. Cannot add method $methodName to class $className.');
      return;
    }

    final content = file.readAsStringSync();
    
    // 1. Check if the class exists in the file
    final classRegex = RegExp(r'\bclass\s+' + className + r'\b');
    final classMatch = classRegex.firstMatch(content);
    if (classMatch == null) {
      print('❌ Class $className not found in $filePath. Cannot add method $methodName.');
      return;
    }

    // 2. Check if the method already exists in the file (matching declaration, not calls)
    final methodDeclRegex = RegExp(r'\b' + methodName + r'\s*\([^)]*\)\s*(?:async\s*)?(?:{|\b=>)');
    if (methodDeclRegex.hasMatch(content)) {
      print('ℹ️ Method $methodName already exists in $filePath. Skipping method creation.');
      return;
    }

    // 3. Find the closing brace of the class to insert the method
    final classIndex = classMatch.start;
    final closingBraceIndex = _findClassClosingBraceIndex(content, classIndex);
    
    if (closingBraceIndex == -1) {
      print('❌ Could not find closing brace for class $className in $filePath.');
      return;
    }

    final before = content.substring(0, closingBraceIndex);
    final after = content.substring(closingBraceIndex);
    
    // Format the method to make sure it has proper indentation
    final formattedMethod = '\n  $methodTemplate\n';
    
    file.writeAsStringSync('$before$formattedMethod$after');
    print('✅ Added method $methodName to class $className in $filePath');
  }

  /// Finds the index of the closing brace for the class matching the given classIndex.
  static int _findClassClosingBraceIndex(String content, int classIndex) {
    final openBraceIndex = content.indexOf('{', classIndex);
    if (openBraceIndex == -1) return -1;
    
    int braceCount = 1;
    for (int i = openBraceIndex + 1; i < content.length; i++) {
      if (content[i] == '{') {
        braceCount++;
      } else if (content[i] == '}') {
        braceCount--;
        if (braceCount == 0) {
          return i;
        }
      }
    }
    return -1;
  }
}
