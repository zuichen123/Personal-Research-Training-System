import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_client/models/ai_agent_chat.dart';
import 'package:flutter_client/utils/agent_form_initial_data.dart';

void main() {
  group('AgentFormInitialData', () {
    test('draft values override default provider values', () {
      final template = AIAgentSummary(
        id: 'template-1',
        name: 'Template',
        protocol: 'gemini_native',
        primary: AIAgentConfig(
          baseUrl: 'https://template.example/v1',
          apiKey: 'template-key',
          model: 'template-model',
        ),
        fallback: AIAgentConfig(baseUrl: '', apiKey: '', model: ''),
        systemPrompt: '',
        intentCapabilities: const <String>[],
        enabled: true,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      );

      final initialData = AgentFormInitialData.fromDraft(
        draft: <String, dynamic>{
          'protocol': 'mock',
          'primary_base_url': 'https://draft.example/v1',
          'primary_api_key': 'draft-key',
          'primary_model': 'draft-model',
        },
        defaultProvider: <String, dynamic>{
          'protocol': 'openai_compatible',
          'primary': <String, dynamic>{
            'base_url': 'https://default.example/v1',
            'api_key': 'default-key',
            'model': 'default-model',
          },
        },
        template: template,
      );

      expect(initialData.protocol, 'mock');
      expect(initialData.primary.baseUrl, 'https://draft.example/v1');
      expect(initialData.primary.apiKey, 'draft-key');
      expect(initialData.primary.model, 'draft-model');
    });

    test('default provider still fills missing draft values', () {
      final initialData = AgentFormInitialData.fromDraft(
        draft: <String, dynamic>{},
        defaultProvider: <String, dynamic>{
          'protocol': 'openai_compatible',
          'primary': <String, dynamic>{
            'base_url': 'https://default.example/v1',
            'api_key': 'default-key',
            'model': 'default-model',
          },
        },
      );

      expect(initialData.protocol, 'openai_compatible');
      expect(initialData.primary.baseUrl, 'https://default.example/v1');
      expect(initialData.primary.apiKey, 'default-key');
      expect(initialData.primary.model, 'default-model');
    });
  });
}
