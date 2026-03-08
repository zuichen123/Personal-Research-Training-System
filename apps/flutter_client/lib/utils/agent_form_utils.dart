import '../models/ai_agent_chat.dart';

class AgentFormUtils {
  const AgentFormUtils._();

  static AIAgentSummary? preferredTemplate(
    List<AIAgentSummary> agents,
    String selectedAgentId,
  ) {
    if (agents.isEmpty) {
      return null;
    }
    final normalizedSelected = selectedAgentId.trim();
    if (normalizedSelected.isNotEmpty) {
      for (final item in agents) {
        if (item.id == normalizedSelected) {
          return item;
        }
      }
    }
    return agents.first;
  }

  static String firstNonEmpty(Iterable<String> values, {String fallback = ''}) {
    for (final item in values) {
      final text = item.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return fallback;
  }

  static Future<Map<String, dynamic>> loadDefaultProvider(
    Future<Map<String, dynamic>> Function() loader,
  ) async {
    try {
      final value = await loader();
      return Map<String, dynamic>.from(value);
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  static bool asBool(dynamic value, {bool fallback = true}) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }
}
