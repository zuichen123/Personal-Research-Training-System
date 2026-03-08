class AgentPromptSections {
  const AgentPromptSections._();

  static Map<String, String> split(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const <String, String>{};
    }
    final hasHeaders = RegExp(r'^##\s+', multiLine: true).hasMatch(text);
    if (!hasHeaders) {
      return <String, String>{'task_prompt': text};
    }

    final buckets = <String, List<String>>{};
    var currentKey = 'extra';
    for (final rawLine in text.split('\n')) {
      final line = rawLine.trimRight();
      final match = RegExp(r'^##\s+(.+)$').firstMatch(line.trim());
      if (match != null) {
        final normalized = normalizeKey(match.group(1) ?? '');
        currentKey = normalized.isEmpty ? 'extra' : normalized;
        buckets.putIfAbsent(currentKey, () => <String>[]);
        continue;
      }
      buckets.putIfAbsent(currentKey, () => <String>[]).add(line);
    }

    final result = <String, String>{};
    buckets.forEach((key, lines) {
      final value = lines.join('\n').trim();
      if (value.isNotEmpty) {
        result[key] = value;
      }
    });
    return result;
  }

  static String compose({
    required String role,
    required String taskPrompt,
    required String toolInstructions,
    required String rules,
    required String extra,
  }) {
    final blocks = <String>[];
    final roleText = role.trim();
    final taskText = taskPrompt.trim();
    final toolText = toolInstructions.trim();
    final rulesText = rules.trim();
    final extraText = extra.trim();

    if (roleText.isNotEmpty) {
      blocks.add('## role\n$roleText');
    }
    if (taskText.isNotEmpty) {
      blocks.add('## task_prompt\n$taskText');
    }
    if (toolText.isNotEmpty) {
      blocks.add('## tool_instructions\n$toolText');
    }
    if (rulesText.isNotEmpty) {
      blocks.add('## rules\n$rulesText');
    }
    if (extraText.isNotEmpty) {
      blocks.add(extraText);
    }

    return blocks.join('\n\n').trim();
  }

  static String normalizeKey(String raw) {
    final key = raw.trim().toLowerCase();
    switch (key) {
      case 'role':
      case 'persona':
      case 'identity':
        return 'role';
      case 'task_prompt':
      case 'task':
      case 'instructions':
      case 'instruction':
        return 'task_prompt';
      case 'tool_instructions':
      case 'tools':
      case 'tool':
        return 'tool_instructions';
      case 'rules':
      case 'rule':
        return 'rules';
      case 'extra':
        return 'extra';
      default:
        return '';
    }
  }
}
